// src/modules/exams/exams.routes.js  ->  /api/v1/admin/exams  (admin & guru)
// Membuat ujian, mengatur jadwal, memantau langsung, hasil, analisis butir soal, ekspor CSV.
const express = require('express');
const { pool } = require('../../config/database');
const { HttpError, wrap, toInt, clampInt, str, parseJson } = require('../../utils/http');
const { audit } = require('../../utils/audit');
const { toCsv } = require('../../utils/csv');
const { requireRole } = require('../../middlewares/auth');
const { parseExam, normalizeSections, makeToken, totalQuestions, totalSeconds } = require('./exams.shared');
const attempts = require('../attempts/attempts.service');

const router = express.Router();
router.use(requireRole('admin', 'guru'));

const RESULT_MODES = ['full', 'score', 'after_end', 'hidden'];
const STATUSES = ['draft', 'published', 'closed'];

const loadExam = async (id) => {
  const [rows] = await pool.query('SELECT * FROM exams WHERE id = ?', [toInt(id, 0)]);
  if (!rows.length) throw new HttpError('Ujian tidak ditemukan.', 404);
  return parseExam(rows[0]);
};

const classIdsOf = async (examId) => {
  const [rows] = await pool.query('SELECT class_id FROM exam_classes WHERE exam_id = ?', [examId]);
  return rows.map((r) => r.class_id);
};

const examOut = async (exam) => ({
  id: exam.id, title: exam.title, description: exam.description, kind: exam.kind, status: exam.status,
  sections: exam.sections, startAt: exam.startAt, endAt: exam.endAt, accessToken: exam.accessToken,
  maxAttempts: exam.maxAttempts, maxViolations: exam.maxViolations,
  shuffleQuestions: exam.shuffleQuestions, shuffleOptions: exam.shuffleOptions, resultMode: exam.resultMode,
  classIds: await classIdsOf(exam.id),
  totalQuestions: totalQuestions(exam), totalSeconds: totalSeconds(exam),
});

const timeOrNull = (v) => {
  if (v == null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) throw new HttpError('Format waktu tidak valid.');
  return Math.round(n);
};

async function readBody(body, { existing = null } = {}) {
  const b = body || {};
  const title = str(b.title, 150);
  if (!title) throw new HttpError('Judul ujian wajib diisi.');
  const startAt = timeOrNull(b.startAt);
  const endAt = timeOrNull(b.endAt);
  if (startAt && endAt && endAt <= startAt) throw new HttpError('Waktu selesai harus setelah waktu mulai.');
  const resultMode = RESULT_MODES.includes(b.resultMode) ? b.resultMode : 'score';

  let sections = existing ? existing.sections : null;
  let warnings = [];
  if (b.sections !== undefined || !existing) {
    const n = await normalizeSections(b.sections);
    sections = n.sections;
    warnings = n.warnings;
  }
  const classIds = Array.isArray(b.classIds) ? [...new Set(b.classIds.map((x) => toInt(x, 0)).filter(Boolean))] : [];
  if (classIds.length) {
    const [found] = await pool.query('SELECT id FROM classes WHERE id IN (?)', [classIds]);
    if (found.length !== classIds.length) throw new HttpError('Ada kelas target yang tidak ditemukan.');
  }
  return {
    title, sections, warnings, startAt, endAt, resultMode, classIds,
    description: str(b.description, 2000) || null,
    maxAttempts: clampInt(b.maxAttempts, 0, 20, 1),
    maxViolations: clampInt(b.maxViolations, 0, 50, 2),
    shuffleQuestions: b.shuffleQuestions === false ? 0 : 1,
    shuffleOptions: b.shuffleOptions === false ? 0 : 1,
    useToken: b.useToken !== false,
  };
}

const setClasses = async (examId, classIds) => {
  await pool.query('DELETE FROM exam_classes WHERE exam_id = ?', [examId]);
  for (const c of classIds) await pool.query('INSERT INTO exam_classes (exam_id, class_id) VALUES (?, ?)', [examId, c]);
};

// ---------------------------------------------------------------- daftar & detail

router.get('/', wrap(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT e.*,
       (SELECT COUNT(*) FROM exam_attempts a WHERE a.exam_id = e.id) AS attempts,
       (SELECT COUNT(*) FROM exam_attempts a WHERE a.exam_id = e.id AND a.status = 'running') AS running
     FROM exams e ORDER BY e.created_at DESC`
  );
  res.json({
    items: rows.map((r) => {
      const e = parseExam(r);
      return {
        id: e.id, title: e.title, kind: e.kind, status: e.status, startAt: e.startAt, endAt: e.endAt,
        accessToken: e.accessToken, totalQuestions: totalQuestions(e), totalSeconds: totalSeconds(e),
        attempts: Number(r.attempts), running: Number(r.running),
      };
    }),
  });
}));

router.get('/:id', wrap(async (req, res) => res.json(await examOut(await loadExam(req.params.id)))));

// ---------------------------------------------------------------- buat / ubah / hapus

router.post('/', wrap(async (req, res) => {
  const v = await readBody(req.body);
  const [r] = await pool.query(
    `INSERT INTO exams (title, description, kind, sections, status, start_at, end_at, access_token, max_attempts,
        max_violations, shuffle_questions, shuffle_options, result_mode, created_by, created_at)
     VALUES (?, ?, 'sekolah', ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [v.title, v.description, JSON.stringify(v.sections), v.startAt, v.endAt, v.useToken ? makeToken() : null,
      v.maxAttempts, v.maxViolations, v.shuffleQuestions, v.shuffleOptions, v.resultMode, req.user.id, Date.now()]
  );
  await setClasses(r.insertId, v.classIds);
  await audit(req, 'exam_create', String(r.insertId), v.title);
  res.status(201).json({ id: r.insertId, warnings: v.warnings });
}));

router.put('/:id', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  if (exam.kind === 'tryout') throw new HttpError('Try Out Mandiri adalah bawaan sistem dan tidak bisa diubah.', 409);
  const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM exam_attempts WHERE exam_id = ?', [exam.id]);

  const body = { ...(req.body || {}) };
  if (n > 0) delete body.sections; // soal & durasi dikunci setelah ada siswa yang mengerjakan
  const v = await readBody(body, { existing: exam });

  let token = exam.accessToken;
  if (v.useToken && !token) token = makeToken();
  if (!v.useToken) token = null;

  await pool.query(
    `UPDATE exams SET title = ?, description = ?, sections = ?, start_at = ?, end_at = ?, access_token = ?,
            max_attempts = ?, max_violations = ?, shuffle_questions = ?, shuffle_options = ?, result_mode = ?, updated_at = ?
      WHERE id = ?`,
    [v.title, v.description, JSON.stringify(v.sections), v.startAt, v.endAt, token, v.maxAttempts, v.maxViolations,
      v.shuffleQuestions, v.shuffleOptions, v.resultMode, Date.now(), exam.id]
  );
  await setClasses(exam.id, v.classIds);
  await audit(req, 'exam_update', String(exam.id), v.title);
  res.json({ message: 'Tersimpan.', warnings: v.warnings, sectionsLocked: n > 0 });
}));

router.post('/:id/status', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const status = (req.body || {}).status;
  if (!STATUSES.includes(status)) throw new HttpError('Status tidak valid.');
  if (exam.kind === 'tryout') throw new HttpError('Status Try Out Mandiri tidak bisa diubah.', 409);

  await pool.query('UPDATE exams SET status = ?, updated_at = ? WHERE id = ?', [status, Date.now(), exam.id]);

  let finished = 0;
  if (status === 'closed') {
    // Tutup ujian = semua yang masih mengerjakan dikumpulkan paksa
    const [running] = await pool.query("SELECT id FROM exam_attempts WHERE exam_id = ? AND status = 'running'", [exam.id]);
    for (const a of running) {
      await attempts.withAttempt(a.id, null, (conn, att, ex) => attempts.finishNow(conn, att, ex, 'admin'));
      finished++;
    }
  }
  await audit(req, 'exam_status', String(exam.id), `${status}${finished ? `, ${finished} dikumpulkan paksa` : ''}`);
  res.json({ message: 'Status diperbarui.', finished });
}));

router.post('/:id/token', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const token = (req.body || {}).clear ? null : makeToken();
  await pool.query('UPDATE exams SET access_token = ? WHERE id = ?', [token, exam.id]);
  await audit(req, 'exam_token', String(exam.id), token ? 'dibuat ulang' : 'dihapus');
  res.json({ accessToken: token });
}));

router.delete('/:id', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  if (exam.kind === 'tryout') throw new HttpError('Try Out Mandiri tidak bisa dihapus.', 409);
  const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM exam_attempts WHERE exam_id = ?', [exam.id]);
  if (n > 0) throw new HttpError('Ujian sudah dikerjakan siswa, tidak bisa dihapus. Tutup saja ujiannya.', 409);
  await pool.query('DELETE FROM exam_classes WHERE exam_id = ?', [exam.id]);
  await pool.query('DELETE FROM exams WHERE id = ?', [exam.id]);
  await audit(req, 'exam_delete', String(exam.id), exam.title);
  res.json({ message: 'Terhapus.' });
}));

// ---------------------------------------------------------------- pemantauan langsung

router.get('/:id/monitor', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const now = Date.now();
  const [rows] = await pool.query(
    `SELECT a.*, u.name, u.nis, c.name AS class_name
       FROM exam_attempts a JOIN users u ON u.id = a.user_id LEFT JOIN classes c ON c.id = u.class_id
      WHERE a.exam_id = ? AND COALESCE(a.end_reason,'') <> 'reset' ORDER BY a.id DESC`, [exam.id]
  );
  const seen = new Set();
  const items = [];
  for (const a of rows) {
    const answers = parseJson(a.answers, {});
    const sec = exam.sections[a.current_section];
    const answered = Object.keys(answers[a.current_section] || {}).length;
    const lastSeen = a.last_seen_at == null ? null : Number(a.last_seen_at);
    seen.add(a.user_id);
    items.push({
      attemptId: a.id, userId: a.user_id, name: a.name, nis: a.nis, className: a.class_name,
      status: a.status, endReason: a.end_reason,
      section: a.current_section + 1, sectionCount: exam.sections.length,
      answered, sectionQuestions: sec ? sec.questions : 0,
      violations: a.violations, lastSeenAt: lastSeen,
      offline: a.status === 'running' && (lastSeen == null || now - lastSeen > 60000),
      ip: a.ip, startedAt: Number(a.started_at), finishedAt: a.finished_at == null ? null : Number(a.finished_at),
    });
  }

  // Siswa target yang belum membuka ujian
  const classIds = await classIdsOf(exam.id);
  const where = ["u.role = 'siswa'", 'u.is_active = 1'];
  const args = [];
  if (classIds.length) { where.push('u.class_id IN (?)'); args.push(classIds); }
  const [students] = await pool.query(
    `SELECT u.id, u.name, u.nis, c.name AS class_name FROM users u LEFT JOIN classes c ON c.id = u.class_id
      WHERE ${where.join(' AND ')} ORDER BY u.name`, args
  );
  const notStarted = students.filter((s) => !seen.has(s.id)).map((s) => ({ userId: s.id, name: s.name, nis: s.nis, className: s.class_name }));

  res.json({
    exam: { id: exam.id, title: exam.title, status: exam.status },
    summary: {
      running: items.filter((i) => i.status === 'running').length,
      finished: items.filter((i) => i.status === 'finished').length,
      notStarted: notStarted.length,
      offline: items.filter((i) => i.offline).length,
      withViolations: items.filter((i) => i.violations > 0).length,
    },
    items, notStarted, serverNow: now,
  });
}));

const attemptOfExam = async (examId, attemptId) => {
  const [rows] = await pool.query('SELECT id, user_id FROM exam_attempts WHERE id = ? AND exam_id = ?', [toInt(attemptId, 0), toInt(examId, 0)]);
  if (!rows.length) throw new HttpError('Percobaan ujian tidak ditemukan.', 404);
  return rows[0];
};

router.post('/:id/attempts/:attemptId/force-finish', wrap(async (req, res) => {
  const a = await attemptOfExam(req.params.id, req.params.attemptId);
  await attempts.withAttempt(a.id, null, (conn, att, ex) => attempts.finishNow(conn, att, ex, 'admin'));
  await audit(req, 'attempt_force_finish', String(a.id));
  res.json({ message: 'Ujian siswa dikumpulkan paksa.' });
}));

// Izinkan siswa mengulang (percobaan lama tetap tersimpan sebagai arsip, tidak dihitung)
router.post('/:id/attempts/:attemptId/reset', wrap(async (req, res) => {
  const a = await attemptOfExam(req.params.id, req.params.attemptId);
  await attempts.withAttempt(a.id, null, async (conn, att, ex) => {
    if (att.status === 'running') await attempts.finishNow(conn, att, ex, 'admin');
    await conn.query("UPDATE exam_attempts SET end_reason = 'reset' WHERE id = ?", [a.id]);
  });
  await audit(req, 'attempt_reset', String(a.id), 'siswa boleh mengulang');
  res.json({ message: 'Siswa diizinkan mengulang ujian.' });
}));

router.post('/:id/attempts/:attemptId/extend', wrap(async (req, res) => {
  const a = await attemptOfExam(req.params.id, req.params.attemptId);
  const minutes = clampInt((req.body || {}).minutes, 1, 120, 0);
  if (!minutes) throw new HttpError('Tambahan waktu 1 sampai 120 menit.');
  await attempts.withAttempt(a.id, null, async (conn, att) => {
    if (att.status !== 'running') throw new HttpError('Ujian siswa sudah selesai.', 409);
    await conn.query('UPDATE exam_attempts SET extra_seconds = extra_seconds + ? WHERE id = ?', [minutes * 60, a.id]);
  });
  await audit(req, 'attempt_extend', String(a.id), `+${minutes} menit`);
  res.json({ message: `Waktu ditambah ${minutes} menit.` });
}));

router.get('/:id/attempts/:attemptId/violations', wrap(async (req, res) => {
  const a = await attemptOfExam(req.params.id, req.params.attemptId);
  const [rows] = await pool.query('SELECT type, counted, detail, created_at FROM violation_logs WHERE attempt_id = ? ORDER BY id', [a.id]);
  res.json({ items: rows.map((r) => ({ type: r.type, counted: !!r.counted, detail: r.detail, at: Number(r.created_at) })) });
}));

// ---------------------------------------------------------------- hasil

async function buildResults(exam) {
  const [rows] = await pool.query(
    `SELECT a.id, a.user_id, a.status, a.end_reason, a.violations, a.started_at, a.finished_at,
            u.name, u.nis, c.name AS class_name,
            COALESCE(SUM(s.correct),0) AS correct, COALESCE(SUM(s.wrong),0) AS wrong, COALESCE(SUM(s.points),0) AS points
       FROM exam_attempts a JOIN users u ON u.id = a.user_id LEFT JOIN classes c ON c.id = u.class_id
       LEFT JOIN attempt_sections s ON s.attempt_id = a.id
      WHERE a.exam_id = ? AND COALESCE(a.end_reason,'') <> 'reset'
      GROUP BY a.id, a.user_id, a.status, a.end_reason, a.violations, a.started_at, a.finished_at, u.name, u.nis, c.name`,
    [exam.id]
  );
  const total = totalQuestions(exam);
  // Satu baris per siswa: ambil percobaan dengan poin tertinggi
  const best = new Map();
  for (const r of rows) {
    const cur = best.get(r.user_id);
    if (!cur || Number(r.points) > Number(cur.points)) best.set(r.user_id, r);
  }
  const list = [...best.values()].map((r) => {
    const correct = Number(r.correct);
    const wrong = Number(r.wrong);
    return {
      attemptId: r.id, name: r.name, nis: r.nis, className: r.class_name, status: r.status, endReason: r.end_reason,
      correct, wrong, blank: total - correct - wrong, points: Number(r.points),
      score: total ? Math.round((correct / total) * 1000) / 10 : 0,
      violations: r.violations,
      durationSec: r.finished_at ? Math.round((Number(r.finished_at) - Number(r.started_at)) / 1000) : null,
    };
  });
  list.sort((a, b) => b.points - a.points || a.name.localeCompare(b.name));
  list.forEach((r, i) => { r.rank = i + 1; });
  return list;
}

router.get('/:id/results', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const items = await buildResults(exam);
  const done = items.filter((i) => i.status === 'finished');
  const avg = done.length ? Math.round((done.reduce((n, i) => n + i.score, 0) / done.length) * 10) / 10 : 0;
  res.json({
    exam: { id: exam.id, title: exam.title, totalQuestions: totalQuestions(exam) },
    stats: {
      participants: items.length, finished: done.length, average: avg,
      highest: done.length ? Math.max(...done.map((i) => i.score)) : 0,
      lowest: done.length ? Math.min(...done.map((i) => i.score)) : 0,
    },
    items,
  });
}));

const REASONS = { done: 'Selesai', timeout: 'Waktu habis', violation: 'Pelanggaran', quit: 'Keluar', abandoned: 'Ditinggalkan', admin: 'Dikumpulkan pengawas' };

router.get('/:id/results.csv', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const items = await buildResults(exam);
  const rows = [['Peringkat', 'Nama', 'NIS', 'Kelas', 'Benar', 'Salah', 'Kosong', 'Poin', 'Nilai (0-100)', 'Pelanggaran', 'Status', 'Durasi (menit)']];
  items.forEach((i) => rows.push([
    i.rank, i.name, i.nis || '', i.className || '', i.correct, i.wrong, i.blank, i.points, i.score, i.violations,
    i.status === 'running' ? 'Sedang mengerjakan' : REASONS[i.endReason] || i.endReason || '',
    i.durationSec == null ? '' : Math.round(i.durationSec / 6) / 10,
  ]));
  await audit(req, 'export_results', String(exam.id));
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="hasil-ujian-${exam.id}.csv"`);
  res.send(toCsv(rows));
}));

// Analisis butir soal: berapa persen siswa menjawab benar tiap soal (bahan evaluasi guru)
router.get('/:id/analysis', wrap(async (req, res) => {
  const exam = await loadExam(req.params.id);
  const [atts] = await pool.query(
    "SELECT plan, answers FROM exam_attempts WHERE exam_id = ? AND status = 'finished' AND COALESCE(end_reason,'') <> 'reset' LIMIT 3000", [exam.id]
  );
  const stat = new Map();
  atts.forEach((a) => {
    const plan = parseJson(a.plan, { sections: [] });
    const ans = parseJson(a.answers, {});
    plan.sections.forEach((sec, si) => sec.items.forEach((it, pos) => {
      const s = stat.get(it.q) || { section: si, shown: 0, answered: 0, chosen: {} };
      s.shown++;
      const given = (ans[si] || {})[pos];
      if (given != null) { s.answered++; s.chosen[given] = (s.chosen[given] || 0) + 1; }
      stat.set(it.q, s);
    }));
  });
  const ids = [...stat.keys()];
  const [qs] = ids.length ? await pool.query('SELECT id, text, correct_index, subtest_id FROM questions WHERE id IN (?)', [ids]) : [[]];
  const items = qs.map((q) => {
    const s = stat.get(q.id);
    const right = s.chosen[q.correct_index] || 0;
    const pct = s.shown ? Math.round((right / s.shown) * 100) : 0;
    return {
      questionId: q.id, text: q.text.slice(0, 140), subtestId: q.subtest_id, shown: s.shown, answered: s.answered,
      correctPct: pct, level: pct >= 70 ? 'mudah' : pct >= 30 ? 'sedang' : 'sulit',
    };
  }).sort((a, b) => a.correctPct - b.correctPct);
  res.json({ attempts: atts.length, items });
}));

module.exports = router;
