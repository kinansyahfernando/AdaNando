// src/modules/results/results.service.js
// Riwayat hasil latihan & try out, dipakai halaman "Potensi" (grafik naik/turun).
const { pool } = require('../../config/database');

class ResultError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const SUBTEST_IDS = ['pu', 'ppu', 'pbm', 'pk', 'lbi', 'lbe', 'pm'];

// Poin: benar +4, salah -1, kosong 0 (sama dengan di aplikasi)
const pointsOf = (correct, wrong) => correct * 4 - wrong;

const validCounts = (total, correct, wrong) =>
  Number.isInteger(total) &&
  Number.isInteger(correct) &&
  Number.isInteger(wrong) &&
  total >= 1 &&
  total <= 200 &&
  correct >= 0 &&
  wrong >= 0 &&
  correct + wrong <= total;

// Dipakai juga oleh modul tryout
const addResult = async ({ userId, subtestId, source, attemptId = null, total, correct, wrong }) => {
  await pool.query(
    `INSERT INTO practice_results
       (user_id, subtest_id, source, attempt_id, total, correct, wrong, points, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [userId, subtestId, source, attemptId, total, correct, wrong, pointsOf(correct, wrong), Date.now()]
  );
};

const savePractice = async (user, body) => {
  const { subtestId } = body || {};
  const total = Number((body || {}).total);
  const correct = Number((body || {}).correct);
  const wrong = Number((body || {}).wrong);

  if (!SUBTEST_IDS.includes(subtestId)) throw new ResultError('Subtes tidak valid.');
  if (!validCounts(total, correct, wrong)) throw new ResultError('Data hasil tidak valid.');

  await addResult({ userId: user.id, subtestId, source: 'latihan', total, correct, wrong });
  return { message: 'Hasil tersimpan' };
};

const history = async (user) => {
  // Ambil 1000 terbaru lalu balik urutannya supaya kronologis (lama -> baru)
  const [rows] = await pool.query(
    `SELECT id, subtest_id, source, total, correct, wrong, points, created_at
       FROM practice_results
      WHERE user_id = ?
      ORDER BY created_at DESC, id DESC
      LIMIT 1000`,
    [user.id]
  );

  return {
    items: rows.reverse().map((r) => ({
      id: r.id,
      subtestId: r.subtest_id,
      source: r.source,
      total: r.total,
      correct: r.correct,
      wrong: r.wrong,
      blank: r.total - r.correct - r.wrong,
      points: r.points,
      createdAt: Number(r.created_at),
    })),
  };
};

module.exports = { ResultError, SUBTEST_IDS, validCounts, addResult, savePractice, history };
