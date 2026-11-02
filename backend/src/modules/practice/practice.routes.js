// src/modules/practice/practice.routes.js  ->  /api/v1/practice
// Mode latihan: soal dikirim tanpa kunci; kunci + pembahasan diberikan server
// hanya saat siswa menekan "Periksa", dan hanya untuk soal berstatus latihan/semua.
const express = require('express');
const rateLimit = require('express-rate-limit');
const { queryHealing } = require('../../config/schema');
const { HttpError, wrap, toInt, clampInt, str, parseJson } = require('../../utils/http');
const { shuffle } = require('../exams/exams.shared');
const { addResult } = require('../results/results.service');
const { authenticate, requirePasswordChanged } = require('../../middlewares/auth');

const router = express.Router();
router.use(authenticate, requirePasswordChanged);

// Cegah penarikan massal kunci jawaban lewat skrip
const checkLimiter = rateLimit({
  windowMs: 60 * 1000, max: 90, standardHeaders: true, legacyHeaders: false,
  keyGenerator: (req) => `u${req.user.id}`,
  handler: (req, res) => res.status(429).json({ message: 'Terlalu cepat. Tunggu sebentar.' }),
});

router.get('/questions', wrap(async (req, res) => {
  const subtestId = str(req.query.subtestId, 20) || 'mix';
  const count = clampInt(req.query.count, 1, 50, 10);
  const where = ["is_active = 1", "usage_type IN ('latihan','semua')"];
  const args = [];
  if (subtestId !== 'mix') { where.push('subtest_id = ?'); args.push(subtestId); }

  const [rows] = await queryHealing(`SELECT id, subtest_id, passage, text, options FROM questions WHERE ${where.join(' AND ')}`, args);
  const picked = shuffle(rows).slice(0, count);
  res.json({
    items: picked.map((q) => ({
      id: q.id, subtestId: q.subtest_id, passage: q.passage, text: q.text, options: parseJson(q.options, []),
    })),
    available: rows.length,
  });
}));

router.post('/check', checkLimiter, wrap(async (req, res) => {
  const id = toInt((req.body || {}).questionId, 0);
  const chosen = toInt((req.body || {}).chosenIndex, -1);
  const [rows] = await queryHealing(
    "SELECT correct_index, explanation, options FROM questions WHERE id = ? AND is_active = 1 AND usage_type IN ('latihan','semua')", [id]
  );
  if (!rows.length) throw new HttpError('Soal tidak tersedia untuk latihan.', 404);
  const q = rows[0];
  if (chosen < 0 || chosen >= parseJson(q.options, []).length) throw new HttpError('Pilihan tidak valid.');
  res.json({ correct: chosen === q.correct_index, correctIndex: q.correct_index, explanation: q.explanation || '' });
}));

// Simpan hasil satu sesi latihan; nilai dihitung server dari jawaban yang dikirim
router.post('/finish', wrap(async (req, res) => {
  const list = Array.isArray((req.body || {}).answers) ? req.body.answers : [];
  if (!list.length || list.length > 100) throw new HttpError('Data jawaban tidak valid.');

  const seen = new Set();
  const picks = [];
  for (const a of list) {
    const id = toInt(a && a.questionId, 0);
    const chosen = toInt(a && a.chosenIndex, -1);
    if (!id || seen.has(id) || chosen < 0) continue;
    seen.add(id);
    picks.push({ id, chosen });
  }
  if (!picks.length) throw new HttpError('Tidak ada jawaban yang valid.');

  const [qs] = await queryHealing(
    "SELECT id, subtest_id, correct_index FROM questions WHERE id IN (?) AND usage_type IN ('latihan','semua')", [picks.map((p) => p.id)]
  );
  const byId = new Map(qs.map((q) => [q.id, q]));
  const perSubtest = new Map();
  let correct = 0;
  let wrong = 0;
  for (const p of picks) {
    const q = byId.get(p.id);
    if (!q) continue;
    const bucket = perSubtest.get(q.subtest_id) || { total: 0, correct: 0, wrong: 0 };
    bucket.total++;
    if (p.chosen === q.correct_index) { bucket.correct++; correct++; } else { bucket.wrong++; wrong++; }
    perSubtest.set(q.subtest_id, bucket);
  }
  for (const [subtestId, b] of perSubtest) {
    await addResult({ userId: req.user.id, subtestId, source: 'latihan', ...b });
  }
  res.json({ total: correct + wrong, correct, wrong, points: correct * 4 - wrong });
}));

module.exports = router;
