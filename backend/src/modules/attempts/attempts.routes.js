// src/modules/attempts/attempts.routes.js
//   GET  /api/v1/exams                      daftar ujian untuk siswa
//   POST /api/v1/exams/:id/start            mulai / lanjutkan ujian
//   /api/v1/attempts/:id/...                state, soal, autosave, kumpulkan, pelanggaran, pembahasan
const express = require('express');
const rateLimit = require('express-rate-limit');
const { pool } = require('../../config/database');
const { wrap, toInt } = require('../../utils/http');
const { authenticate, requirePasswordChanged, requireRole } = require('../../middlewares/auth');
const { parseExam, totalSeconds, totalQuestions } = require('../exams/exams.shared');
const svc = require('./attempts.service');

const byUser = (req) => `u${req.user ? req.user.id : req.ip}`;
const tokenLimiter = rateLimit({
  windowMs: 60 * 1000, max: 12, keyGenerator: byUser, standardHeaders: true, legacyHeaders: false,
  handler: (req, res) => res.status(429).json({ message: 'Terlalu banyak percobaan. Tunggu 1 menit.' }),
});
// Autosave sering dipanggil; longgarkan tapi tetap dibatasi
const saveLimiter = rateLimit({
  windowMs: 60 * 1000, max: 240, keyGenerator: byUser, standardHeaders: true, legacyHeaders: false,
  handler: (req, res) => res.status(429).json({ message: 'Terlalu cepat.' }),
});

const examsRouter = express.Router();
examsRouter.use(authenticate, requirePasswordChanged, requireRole('siswa'));

examsRouter.get('/', wrap(async (req, res) => {
  const user = req.user;
  const [exams] = await pool.query("SELECT * FROM exams WHERE status IN ('published','closed') ORDER BY (kind = 'tryout') DESC, COALESCE(start_at, created_at) DESC");
  const [targets] = await pool.query('SELECT exam_id, class_id FROM exam_classes');
  const [attempts] = await pool.query(
    "SELECT id, exam_id, status, end_reason, started_at FROM exam_attempts WHERE user_id = ? AND COALESCE(end_reason,'') <> 'reset' ORDER BY id DESC", [user.id]
  );
  const now = Date.now();
  const items = [];
  for (const row of exams) {
    const exam = parseExam(row);
    const cls = targets.filter((t) => t.exam_id === exam.id).map((t) => t.class_id);
    if (cls.length && !cls.includes(user.classId)) continue;
    const mine = attempts.filter((a) => a.exam_id === exam.id);
    const running = mine.find((a) => a.status === 'running');
    const last = mine[0] || null;
    if (exam.status === 'closed' && !last) continue;

    let phase = 'open';
    if (exam.status === 'closed' || (exam.endAt != null && now >= exam.endAt)) phase = 'ended';
    else if (exam.startAt != null && now < exam.startAt) phase = 'upcoming';

    const used = mine.length;
    const limitReached = exam.maxAttempts > 0 && used >= exam.maxAttempts && !running;
    items.push({
      id: exam.id, title: exam.title, description: exam.description, kind: exam.kind,
      startAt: exam.startAt, endAt: exam.endAt, phase,
      totalQuestions: totalQuestions(exam), totalSeconds: totalSeconds(exam),
      sections: exam.sections.length,
      maxViolations: exam.maxViolations,
      requiresToken: !!exam.accessToken,
      maxAttempts: exam.maxAttempts,
      runningAttemptId: running ? running.id : null,
      lastAttemptId: last ? last.id : null,
      lastStatus: last ? last.status : null,
      canStart: phase === 'open' && !limitReached,
    });
  }
  res.json({ items, serverNow: now });
}));

const startLimiterChain = [tokenLimiter];
examsRouter.post('/:id/start', startLimiterChain, wrap(async (req, res) => {
  res.json(await svc.startExam(req, req.user, req.params.id, (req.body || {}).token));
}));

const attemptsRouter = express.Router();
attemptsRouter.use(authenticate, requirePasswordChanged, requireRole('siswa'));

attemptsRouter.get('/:id', wrap(async (req, res) => res.json(await svc.getState(req.user, req.params.id))));
attemptsRouter.get('/:id/section', wrap(async (req, res) => res.json(await svc.getSection(req.user, req.params.id))));
attemptsRouter.put('/:id/answers', saveLimiter, wrap(async (req, res) => res.json(await svc.autosave(req.user, req.params.id, req.body))));
attemptsRouter.post('/:id/submit-section', wrap(async (req, res) => res.json(await svc.submitSection(req.user, req.params.id, req.body))));
attemptsRouter.post('/:id/finish', wrap(async (req, res) => res.json(await svc.finish(req.user, req.params.id, req.body))));
attemptsRouter.post('/:id/violation', saveLimiter, wrap(async (req, res) => res.json(await svc.violation(req.user, req.params.id, req.body))));
attemptsRouter.get('/:id/review', wrap(async (req, res) => res.json(await svc.review(req.user, req.params.id))));

module.exports = { examsRouter, attemptsRouter, toInt };
