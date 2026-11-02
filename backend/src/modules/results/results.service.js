// src/modules/results/results.service.js
// Riwayat hasil latihan / try out / ujian, dipakai halaman "Potensi" (grafik naik-turun).
// Seluruh angka berasal dari penilaian SERVER, bukan dikirim aplikasi.
const { pool } = require('../../config/database');

// Poin: benar +4, salah -1, kosong 0
const pointsOf = (correct, wrong) => correct * 4 - wrong;

const addResult = async ({ userId, subtestId, source, attemptId = null, total, correct, wrong, conn = null }) => {
  await (conn || pool).query(
    `INSERT INTO practice_results
       (user_id, subtest_id, source, attempt_id, total, correct, wrong, points, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [userId, subtestId, source, attemptId, total, correct, wrong, pointsOf(correct, wrong), Date.now()]
  );
};

const history = async (user) => {
  // Ambil 1000 terbaru lalu balik urutannya supaya kronologis (lama -> baru)
  const [rows] = await pool.query(
    `SELECT id, subtest_id, source, total, correct, wrong, points, created_at
       FROM practice_results WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 1000`,
    [user.id]
  );
  return {
    items: rows.reverse().map((r) => ({
      id: r.id, subtestId: r.subtest_id, source: r.source, total: r.total,
      correct: r.correct, wrong: r.wrong, blank: r.total - r.correct - r.wrong,
      points: r.points, createdAt: Number(r.created_at),
    })),
  };
};

module.exports = { pointsOf, addResult, history };
