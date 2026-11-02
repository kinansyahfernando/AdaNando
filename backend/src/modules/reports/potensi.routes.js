// src/modules/reports/potensi.routes.js  ->  /api/v1/admin/potensi
// Perkembangan (potensi) tiap siswa dari riwayat latihan, try out, dan ujian.
const express = require('express');
const { pool } = require('../../config/database');
const { HttpError, wrap, toInt, clampInt, str } = require('../../utils/http');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();
router.use(requireRole('admin', 'guru'));

const pct = (correct, total) => (total ? Math.round((correct / total) * 1000) / 10 : 0);

// Ringkasan semua siswa (bisa disaring kelas / nama)
router.get('/', wrap(async (req, res) => {
  const where = ["u.role = 'siswa'", 'u.is_active = 1'];
  const args = [];
  if (req.query.classId) { where.push('u.class_id = ?'); args.push(toInt(req.query.classId, 0)); }
  if (req.query.q) {
    where.push('(u.name LIKE ? OR u.nis LIKE ?)');
    const like = `%${str(req.query.q, 60).replace(/[%_]/g, '')}%`;
    args.push(like, like);
  }
  const limit = clampInt(req.query.limit, 1, 500, 200);
  const [rows] = await pool.query(
    `SELECT u.id, u.name, u.nis, c.name AS class_name,
            COUNT(r.id) AS sessions,
            COALESCE(SUM(r.source = 'latihan'), 0) AS practice,
            COALESCE(SUM(r.source IN ('tryout','ujian')), 0) AS exams,
            COALESCE(SUM(r.total), 0) AS total, COALESCE(SUM(r.correct), 0) AS correct,
            COALESCE(SUM(r.points), 0) AS points, MAX(r.created_at) AS last_at
       FROM users u
       LEFT JOIN classes c ON c.id = u.class_id
       LEFT JOIN practice_results r ON r.user_id = u.id
      WHERE ${where.join(' AND ')}
      GROUP BY u.id, u.name, u.nis, c.name
      ORDER BY points DESC, u.name ASC LIMIT ?`,
    [...args, limit]
  );
  res.json({
    items: rows.map((r) => ({
      userId: r.id, name: r.name, nis: r.nis, className: r.class_name,
      sessions: Number(r.sessions), practice: Number(r.practice), exams: Number(r.exams),
      accuracy: pct(Number(r.correct), Number(r.total)), points: Number(r.points),
      lastAt: r.last_at == null ? null : Number(r.last_at),
    })),
  });
}));

// Detail satu siswa: per subtes + riwayat terbaru
router.get('/:userId', wrap(async (req, res) => {
  const id = toInt(req.params.userId, 0);
  const [users] = await pool.query(
    `SELECT u.id, u.name, u.nis, c.name AS class_name FROM users u
       LEFT JOIN classes c ON c.id = u.class_id WHERE u.id = ? AND u.role = 'siswa'`, [id]
  );
  if (!users.length) throw new HttpError('Siswa tidak ditemukan.', 404);

  const [perSubtest] = await pool.query(
    `SELECT r.subtest_id, COALESCE(s.name, r.subtest_id) AS name, COUNT(*) AS sessions,
            SUM(r.total) AS total, SUM(r.correct) AS correct, MAX(r.points) AS best
       FROM practice_results r LEFT JOIN subtests s ON s.id = r.subtest_id
      WHERE r.user_id = ? GROUP BY r.subtest_id, name ORDER BY name`, [id]
  );
  const [recent] = await pool.query(
    `SELECT r.subtest_id, COALESCE(s.name, r.subtest_id) AS name, r.source, r.total, r.correct, r.wrong, r.points, r.created_at
       FROM practice_results r LEFT JOIN subtests s ON s.id = r.subtest_id
      WHERE r.user_id = ? ORDER BY r.created_at DESC, r.id DESC LIMIT 40`, [id]
  );
  res.json({
    student: { id: users[0].id, name: users[0].name, nis: users[0].nis, className: users[0].class_name },
    subtests: perSubtest.map((r) => ({
      subtestId: r.subtest_id, name: r.name, sessions: Number(r.sessions),
      accuracy: pct(Number(r.correct), Number(r.total)), best: Number(r.best),
    })),
    recent: recent.map((r) => ({
      subtestId: r.subtest_id, name: r.name, source: r.source, total: r.total, correct: r.correct,
      wrong: r.wrong, points: r.points, at: Number(r.created_at),
    })),
  });
}));

module.exports = router;