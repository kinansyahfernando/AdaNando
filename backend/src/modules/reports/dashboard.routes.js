// src/modules/reports/dashboard.routes.js  ->  /api/v1/admin/dashboard, /api/v1/admin/audit
const express = require('express');
const { pool } = require('../../config/database');
const { wrap, clampInt } = require('../../utils/http');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();
router.use(requireRole('admin', 'guru'));

router.get('/dashboard', wrap(async (req, res) => {
  const one = async (sql) => Number((await pool.query(sql))[0][0].n);
  const now = Date.now();
  res.json({
    students: await one("SELECT COUNT(*) AS n FROM users WHERE role = 'siswa' AND is_active = 1"),
    teachers: await one("SELECT COUNT(*) AS n FROM users WHERE role = 'guru' AND is_active = 1"),
    classes: await one('SELECT COUNT(*) AS n FROM classes'),
    questions: await one('SELECT COUNT(*) AS n FROM questions WHERE is_active = 1'),
    exams: await one("SELECT COUNT(*) AS n FROM exams WHERE kind = 'sekolah'"),
    publishedExams: await one("SELECT COUNT(*) AS n FROM exams WHERE kind = 'sekolah' AND status = 'published'"),
    runningNow: await one("SELECT COUNT(*) AS n FROM exam_attempts WHERE status = 'running'"),
    violationsToday: await one(`SELECT COUNT(*) AS n FROM violation_logs WHERE counted = 1 AND created_at > ${now - 86400000}`),
    serverNow: now,
  });
}));

router.get('/audit', requireRole('admin'), wrap(async (req, res) => {
  const limit = clampInt(req.query.limit, 1, 500, 100);
  const [rows] = await pool.query(
    'SELECT l.*, u.name AS actor FROM audit_logs l LEFT JOIN users u ON u.id = l.actor_id ORDER BY l.id DESC LIMIT ?', [limit]
  );
  res.json({ items: rows.map((r) => ({ id: r.id, actor: r.actor, action: r.action, target: r.target, detail: r.detail, ip: r.ip, at: Number(r.created_at) })) });
}));

module.exports = router;
