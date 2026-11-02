// src/modules/exams/exams.shared.js
// Bagian yang dipakai bersama oleh panel admin (membuat ujian) dan mesin ujian siswa.
const crypto = require('crypto');
const { pool } = require('../../config/database');
const { HttpError, parseJson, str, toInt, clampInt } = require('../../utils/http');

const shuffle = (arr) => {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

/** Baris tabel exams -> objek yang rapi. */
const parseExam = (row) => ({
  id: row.id,
  title: row.title,
  description: row.description,
  kind: row.kind,
  status: row.status,
  sections: parseJson(row.sections, []),
  startAt: row.start_at == null ? null : Number(row.start_at),
  endAt: row.end_at == null ? null : Number(row.end_at),
  accessToken: row.access_token,
  maxAttempts: row.max_attempts,
  maxViolations: row.max_violations,
  shuffleQuestions: !!row.shuffle_questions,
  shuffleOptions: !!row.shuffle_options,
  resultMode: row.result_mode,
  createdAt: Number(row.created_at),
});

const totalSeconds = (exam) => exam.sections.reduce((n, s) => n + s.seconds, 0);
const totalQuestions = (exam) => exam.sections.reduce((n, s) => n + s.questions, 0);

/** Apakah jendela ujian sudah berakhir (dipakai untuk membuka pembahasan). */
const hasEnded = (exam, now = Date.now()) =>
  exam.status === 'closed' || (exam.endAt != null && now >= exam.endAt);

/** Validasi & rapikan susunan subtes yang dikirim dari panel admin. */
async function normalizeSections(input) {
  if (!Array.isArray(input) || input.length < 1) throw new HttpError('Ujian minimal punya 1 bagian / subtes.');
  if (input.length > 12) throw new HttpError('Maksimal 12 bagian per ujian.');

  const out = [];
  const warnings = [];
  for (let i = 0; i < input.length; i++) {
    const s = input[i] || {};
    const label = `Bagian ${i + 1}`;
    const subtestId = str(s.subtestId, 20);
    const [sub] = await pool.query('SELECT id, name FROM subtests WHERE id = ?', [subtestId]);
    if (!sub.length) throw new HttpError(`${label}: mapel tidak ditemukan.`);

    const minutes = Number(s.minutes);
    const seconds = Number.isFinite(minutes) && minutes > 0 ? Math.round(minutes * 60) : toInt(s.seconds, 0);
    if (!seconds || seconds < 60 || seconds > 4 * 3600) throw new HttpError(`${label}: durasi harus 1 menit sampai 4 jam.`);

    let questionIds = [];
    if (Array.isArray(s.questionIds) && s.questionIds.length) {
      questionIds = [...new Set(s.questionIds.map((n) => toInt(n, 0)).filter((n) => n > 0))];
      if (questionIds.length !== s.questionIds.length) throw new HttpError(`${label}: daftar soal tidak valid / ada yang kembar.`);
      const [found] = await pool.query(
        'SELECT id, usage_type FROM questions WHERE id IN (?) AND is_active = 1', [questionIds]
      );
      if (found.length !== questionIds.length) throw new HttpError(`${label}: ada soal yang sudah dihapus / tidak ditemukan.`);
      if (found.some((q) => q.usage_type === 'latihan')) {
        throw new HttpError(`${label}: ada soal berstatus "latihan saja". Ubah status soalnya ke "ujian" atau "semua" dulu, supaya kunci jawabannya tidak bocor lewat mode latihan.`);
      }
    }

    let count = questionIds.length || toInt(s.questions, 0);
    if (!count || count < 1 || count > 200) throw new HttpError(`${label}: jumlah soal harus 1 sampai 200.`);

    if (!questionIds.length) {
      const [[{ n }]] = await pool.query(
        "SELECT COUNT(*) AS n FROM questions WHERE subtest_id = ? AND is_active = 1 AND usage_type IN ('ujian','semua')", [subtestId]
      );
      if (n < count) {
        warnings.push(`${label} (${sub[0].name}): bank soal baru ${n} butir, padahal diminta ${count}. Soal akan diulang. Tambahkan soal dulu sebelum ujian sungguhan.`);
      }
    }

    out.push({
      subtestId,
      name: str(s.name, 100) || sub[0].name,
      questions: count,
      seconds,
      ...(questionIds.length ? { questionIds } : {}),
    });
  }
  return { sections: out, warnings };
}

const makeToken = () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let t = '';
  for (let i = 0; i < 6; i++) t += chars[crypto.randomInt(0, chars.length)];
  return t;
};

module.exports = {
  shuffle, parseExam, totalSeconds, totalQuestions, hasEnded, normalizeSections, makeToken, clampInt,
};
