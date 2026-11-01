// src/modules/tryout/tryout.service.js
// Try Out Mandiri: 7 subtes berurutan, timer dihitung server.
//
// Aturan waktu:
//  - Subtes dimulai saat try out dimulai / saat subtes sebelumnya dikumpulkan.
//  - Jika waktu subtes habis, server otomatis menganggap subtes itu selesai
//    dan pindah ke subtes berikutnya (walau HP siswa mati / offline).
const { pool } = require('../../config/database');
const { SECTIONS, TOTAL_SECONDS, GRACE_MS } = require('./tryout.config');
const { validCounts, addResult } = require('../results/results.service');

class TryoutError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const END_REASONS = ['violation', 'quit', 'abandoned'];

const loadAttempt = async (id, userId) => {
  const [rows] = await pool.query('SELECT * FROM tryout_attempts WHERE id = ?', [Number(id) || 0]);
  if (rows.length === 0) throw new TryoutError('Try out tidak ditemukan.', 404);
  if (rows[0].user_id !== userId) throw new TryoutError('Ini bukan try out milikmu.', 403);
  return rows[0];
};

const deadlineOf = (attempt) =>
  Number(attempt.section_started_at) + SECTIONS[attempt.current_section].seconds * 1000;

// Majukan subtes yang waktunya sudah lewat (secara "malas", saat ada permintaan)
const advance = async (attempt) => {
  if (attempt.status !== 'running') return attempt;

  const now = Date.now();
  let current = attempt.current_section;
  let start = Number(attempt.section_started_at);
  let status = 'running';
  let reason = null;
  let finishedAt = null;

  while (status === 'running' && now >= start + SECTIONS[current].seconds * 1000 + GRACE_MS) {
    const deadline = start + SECTIONS[current].seconds * 1000;
    if (current >= SECTIONS.length - 1) {
      status = 'finished';
      reason = 'timeout';
      finishedAt = deadline;
    } else {
      current += 1;
      start = deadline;
    }
  }

  if (current === attempt.current_section && status === attempt.status) return attempt;

  await pool.query(
    `UPDATE tryout_attempts
        SET current_section = ?, section_started_at = ?, status = ?, end_reason = ?, finished_at = ?
      WHERE id = ? AND status = 'running'`,
    [current, start, status, reason, finishedAt, attempt.id]
  );
  return {
    ...attempt,
    current_section: current,
    section_started_at: start,
    status,
    end_reason: reason,
    finished_at: finishedAt,
  };
};

const buildState = (attempt) => {
  const running = attempt.status === 'running';
  return {
    attempt: {
      id: attempt.id,
      status: attempt.status,
      currentSection: attempt.current_section,
      sectionStartedAt: running ? Number(attempt.section_started_at) : null,
      sectionEndsAt: running ? deadlineOf(attempt) : null,
      serverNow: Date.now(),
      endReason: attempt.end_reason || null,
    },
    sections: SECTIONS.map((s) => ({ id: s.id, name: s.name, questions: s.questions, seconds: s.seconds })),
    totalSeconds: TOTAL_SECONDS,
  };
};

const stateOf = async (id, userId) => buildState(await advance(await loadAttempt(id, userId)));

// ------------------------------------------------------------------ aksi

const start = async (user) => {
  const now = Date.now();

  // Try out lama yang masih berjalan dianggap ditinggalkan
  await pool.query(
    `UPDATE tryout_attempts
        SET status = 'finished', end_reason = 'abandoned', finished_at = ?
      WHERE user_id = ? AND status = 'running'`,
    [now, user.id]
  );

  const [result] = await pool.query(
    `INSERT INTO tryout_attempts (user_id, status, current_section, section_started_at, started_at)
     VALUES (?, 'running', 0, ?, ?)`,
    [user.id, now, now]
  );
  return stateOf(result.insertId, user.id);
};

const get = (user, id) => stateOf(id, user.id);

const submitSection = async (user, id, body) => {
  const attempt = await advance(await loadAttempt(id, user.id));
  const index = Number((body || {}).sectionIndex);

  if (!Number.isInteger(index) || index < 0 || index >= SECTIONS.length) {
    throw new TryoutError('Nomor subtes tidak valid.');
  }
  // Sudah selesai / subtes itu sudah lewat: kirim ulang tidak mengubah apa pun
  if (attempt.status !== 'running' || index < attempt.current_section) return buildState(attempt);
  if (index > attempt.current_section) throw new TryoutError('Subtes ini belum dimulai.', 409);

  const section = SECTIONS[index];
  const correct = Number(body.correct);
  const wrong = Number(body.wrong);
  if (!validCounts(section.questions, correct, wrong)) throw new TryoutError('Data skor tidak valid.');

  const now = Date.now();
  const deadline = deadlineOf(attempt);
  const isLast = index === SECTIONS.length - 1;

  const [result] = isLast
    ? await pool.query(
        `UPDATE tryout_attempts
            SET status = 'finished', end_reason = 'done', finished_at = ?
          WHERE id = ? AND status = 'running' AND current_section = ?`,
        [Math.min(now, deadline), attempt.id, index]
      )
    : await pool.query(
        `UPDATE tryout_attempts
            SET current_section = ?, section_started_at = ?
          WHERE id = ? AND status = 'running' AND current_section = ?`,
        [index + 1, Math.min(now, deadline), attempt.id, index]
      );

  // affectedRows = 0 berarti sudah diproses permintaan lain (klik ganda): jangan simpan dua kali
  if (result.affectedRows) {
    await addResult({
      userId: user.id,
      subtestId: section.id,
      source: 'tryout',
      attemptId: attempt.id,
      total: section.questions,
      correct,
      wrong,
    });
  }

  return stateOf(attempt.id, user.id);
};

// Mengakhiri seluruh try out lebih awal (pelanggaran / keluar).
const finish = async (user, id, body) => {
  const attempt = await advance(await loadAttempt(id, user.id));
  if (attempt.status !== 'running') return buildState(attempt);

  const { sectionIndex, reason } = body || {};
  const endReason = END_REASONS.includes(reason) ? reason : 'quit';

  const [result] = await pool.query(
    `UPDATE tryout_attempts
        SET status = 'finished', end_reason = ?, finished_at = ?
      WHERE id = ? AND status = 'running'`,
    [endReason, Date.now(), attempt.id]
  );

  // Jawaban subtes yang sedang dikerjakan tetap dinilai bila datanya valid
  const index = Number(sectionIndex);
  if (result.affectedRows && index === attempt.current_section && SECTIONS[index]) {
    const section = SECTIONS[index];
    const correct = Number(body.correct);
    const wrong = Number(body.wrong);
    if (validCounts(section.questions, correct, wrong)) {
      await addResult({
        userId: user.id,
        subtestId: section.id,
        source: 'tryout',
        attemptId: attempt.id,
        total: section.questions,
        correct,
        wrong,
      });
    }
  }

  return stateOf(attempt.id, user.id);
};

module.exports = { TryoutError, start, get, submitSection, finish };
