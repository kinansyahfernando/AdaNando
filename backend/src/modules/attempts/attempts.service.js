// src/modules/attempts/attempts.service.js
// MESIN UJIAN. Semua hal yang menentukan nilai terjadi di server:
//  - soal & urutan pilihan diacak per siswa dan disimpan di server (plan)
//  - kunci jawaban TIDAK PERNAH dikirim ke aplikasi selama ujian berjalan
//  - jawaban disimpan di server (autosave); nilai dihitung server, bukan dikirim aplikasi
//  - waktu dihitung dari jam server; subtes yang waktunya habis otomatis dikumpulkan
//  - pelanggaran (pindah tab, keluar fullscreen, dll) dicatat; melewati batas = ujian diakhiri
const { pool, withTransaction } = require('../../config/database');
const { HttpError, parseJson, str, toInt } = require('../../utils/http');
const { ipOf } = require('../../utils/audit');
const { shuffle, parseExam, totalSeconds, hasEnded } = require('../exams/exams.shared');
const { addResult } = require('../results/results.service');

const GRACE_MS = 8000; // toleransi keterlambatan jaringan saat mengirim jawaban
const SEEN_WRITE_EVERY_MS = 10000;

// Jenis pelanggaran yang MENAMBAH hitungan, dan yang hanya dicatat
const COUNTED_TYPES = ['tab_hidden', 'window_blur', 'app_background', 'fullscreen_exit', 'screenshot', 'print_screen', 'devtools'];
const SOFT_TYPES = ['copy', 'paste', 'contextmenu', 'text_select', 'other'];
const VIOLATION_DEBOUNCE_MS = 2500; // blur + visibilitychange biasanya datang bersamaan

// ------------------------------------------------------------------ pemuat data

const loadAttemptRow = async (conn, id, userId) => {
  const [rows] = await conn.query('SELECT * FROM exam_attempts WHERE id = ? FOR UPDATE', [toInt(id, 0)]);
  if (!rows.length) throw new HttpError('Ujian tidak ditemukan.', 404);
  if (userId != null && rows[0].user_id !== userId) throw new HttpError('Ini bukan ujian milikmu.', 403);
  return rows[0];
};

const loadExamRow = async (conn, id) => {
  const [rows] = await conn.query('SELECT * FROM exams WHERE id = ?', [id]);
  if (!rows.length) throw new HttpError('Ujian sudah dihapus.', 404);
  return parseExam(rows[0]);
};

const answersOf = (attempt) => parseJson(attempt.answers, {});
const planOf = (attempt) => parseJson(attempt.plan, { sections: [] });

// ------------------------------------------------------------------ waktu

/** Batas waktu subtes aktif: durasi subtes (+ tambahan waktu dari guru), tapi tak melewati penutupan ujian. */
const deadlineOf = (attempt, exam) => {
  const sec = exam.sections[attempt.current_section];
  let d = Number(attempt.section_started_at) + (sec.seconds + (attempt.extra_seconds || 0)) * 1000;
  if (exam.endAt != null) d = Math.min(d, exam.endAt);
  return d;
};

// ------------------------------------------------------------------ penilaian

/** Hitung nilai satu subtes dari jawaban yang tersimpan di server. */
async function gradeSection(conn, attempt, exam, idx) {
  const items = (planOf(attempt).sections[idx] || { items: [] }).items;
  const given = answersOf(attempt)[idx] || {};
  const ids = [...new Set(items.map((it) => it.q))];
  const keyOf = new Map();
  if (ids.length) {
    const [rows] = await conn.query('SELECT id, correct_index FROM questions WHERE id IN (?)', [ids]);
    rows.forEach((r) => keyOf.set(r.id, r.correct_index));
  }
  let correct = 0;
  let wrong = 0;
  items.forEach((it, pos) => {
    const chosen = given[pos];
    if (chosen == null) return;
    if (chosen === keyOf.get(it.q)) correct++;
    else wrong++;
  });
  return { total: items.length, correct, wrong, points: correct * 4 - wrong };
}

/** Tutup satu subtes: nilai dihitung dan disimpan SEKALI (aman dari klik ganda / permintaan ganda). */
async function closeSection(conn, attempt, exam, idx, closedAt) {
  const g = await gradeSection(conn, attempt, exam, idx);
  const sec = exam.sections[idx];
  const [r] = await conn.query(
    `INSERT IGNORE INTO attempt_sections (attempt_id, section_idx, subtest_id, total, correct, wrong, points, closed_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [attempt.id, idx, sec.subtestId, g.total, g.correct, g.wrong, g.points, closedAt]
  );
  if (r.affectedRows) {
    // Riwayat untuk halaman "Potensi" siswa
    await addResult({
      userId: attempt.user_id, subtestId: sec.subtestId, source: exam.kind === 'tryout' ? 'tryout' : 'ujian',
      attemptId: attempt.id, total: g.total, correct: g.correct, wrong: g.wrong, conn,
    });
  }
  return g;
}

/** Akhiri seluruh ujian: subtes yang sedang berjalan tetap dinilai dari jawaban tersimpan. */
async function finishNow(conn, attempt, exam, reason, at = Date.now()) {
  if (attempt.status !== 'running') return attempt;
  await closeSection(conn, attempt, exam, attempt.current_section, at);
  await conn.query(
    "UPDATE exam_attempts SET status = 'finished', end_reason = ?, finished_at = ? WHERE id = ? AND status = 'running'",
    [reason, at, attempt.id]
  );
  return { ...attempt, status: 'finished', end_reason: reason, finished_at: at };
}

/** Majukan subtes yang waktunya sudah lewat (dijalankan setiap ada permintaan, walau HP siswa mati). */
async function advance(conn, attempt, exam) {
  if (attempt.status !== 'running') return attempt;
  const now = Date.now();
  let a = attempt;

  while (a.status === 'running' && now >= deadlineOf(a, exam) + GRACE_MS) {
    const deadline = deadlineOf(a, exam);
    const idx = a.current_section;
    await closeSection(conn, a, exam, idx, deadline);

    if (idx >= exam.sections.length - 1) {
      await conn.query(
        "UPDATE exam_attempts SET status = 'finished', end_reason = 'timeout', finished_at = ? WHERE id = ?",
        [deadline, a.id]
      );
      a = { ...a, status: 'finished', end_reason: 'timeout', finished_at: deadline };
    } else {
      await conn.query(
        'UPDATE exam_attempts SET current_section = ?, section_started_at = ?, extra_seconds = 0 WHERE id = ?',
        [idx + 1, deadline, a.id]
      );
      a = { ...a, current_section: idx + 1, section_started_at: deadline, extra_seconds: 0 };
    }
  }
  return a;
}

// ------------------------------------------------------------------ pembungkus transaksi

/**
 * Jalankan aksi pada satu percobaan ujian dengan baris terkunci (tidak ada balapan antar-permintaan).
 * userId = null untuk aksi admin / guru.
 */
const withAttempt = (id, userId, fn) =>
  withTransaction(async (conn) => {
    let attempt = await loadAttemptRow(conn, id, userId);
    const exam = await loadExamRow(conn, attempt.exam_id);
    attempt = await advance(conn, attempt, exam);
    return fn(conn, attempt, exam);
  });

// ------------------------------------------------------------------ hasil & status

const resultVisible = (exam, attempt) => {
  if (attempt.status !== 'finished') return false;
  if (exam.resultMode === 'hidden') return false;
  if (exam.resultMode === 'after_end') return hasEnded(exam);
  return true; // 'full' dan 'score'
};

const reviewVisible = (exam, attempt) => {
  if (attempt.status !== 'finished') return false;
  if (exam.resultMode === 'hidden') return false;
  if (exam.resultMode === 'full') return true;
  return hasEnded(exam); // 'score' & 'after_end': pembahasan baru dibuka setelah ujian ditutup
};

async function sectionScores(conn, attempt, exam) {
  const [rows] = await conn.query('SELECT * FROM attempt_sections WHERE attempt_id = ?', [attempt.id]);
  const byIdx = new Map(rows.map((r) => [r.section_idx, r]));
  return exam.sections.map((s, i) => {
    const r = byIdx.get(i);
    const total = s.questions;
    const correct = r ? r.correct : 0;
    const wrong = r ? r.wrong : 0;
    return {
      id: s.subtestId, name: s.name, total, correct, wrong, blank: total - correct - wrong,
      points: r ? r.points : 0, worked: !!r,
    };
  });
}

async function buildState(conn, attempt, exam) {
  const running = attempt.status === 'running';
  const state = {
    attempt: {
      id: attempt.id,
      examId: exam.id,
      status: attempt.status,
      currentSection: attempt.current_section,
      sectionEndsAt: running ? deadlineOf(attempt, exam) : null,
      serverNow: Date.now(),
      endReason: attempt.end_reason || null,
      violations: attempt.violations,
      maxViolations: exam.maxViolations,
    },
    exam: {
      id: exam.id, title: exam.title, kind: exam.kind, resultMode: exam.resultMode,
      sections: exam.sections.map((s) => ({ id: s.subtestId, name: s.name, questions: s.questions, seconds: s.seconds })),
      totalSeconds: totalSeconds(exam),
    },
    result: null,
    reviewAvailable: false,
  };
  if (attempt.status === 'finished') {
    state.reviewAvailable = reviewVisible(exam, attempt);
    if (resultVisible(exam, attempt)) {
      const sections = await sectionScores(conn, attempt, exam);
      const sum = (k) => sections.reduce((n, s) => n + s[k], 0);
      const total = sum('total');
      state.result = {
        sections,
        total, correct: sum('correct'), wrong: sum('wrong'), blank: sum('blank'), points: sum('points'),
        score: total ? Math.round((sum('correct') / total) * 1000) / 10 : 0, // skala 0-100
      };
    }
  }
  return state;
}

// ------------------------------------------------------------------ memulai ujian

async function buildPlan(conn, exam) {
  const sections = [];
  for (const sec of exam.sections) {
    let ids;
    if (sec.questionIds && sec.questionIds.length) {
      ids = [...sec.questionIds];
    } else {
      const [rows] = await conn.query(
        "SELECT id FROM questions WHERE subtest_id = ? AND is_active = 1 AND usage_type IN ('ujian','semua')", [sec.subtestId]
      );
      let pool_ = shuffle(rows.map((r) => r.id));
      if (!pool_.length) throw new HttpError(`Bank soal untuk "${sec.name}" masih kosong. Hubungi guru / admin.`, 409);
      ids = [];
      while (ids.length < sec.questions) ids.push(...(ids.length ? shuffle(pool_) : pool_));
      ids = ids.slice(0, sec.questions);
    }
    if (exam.shuffleQuestions) ids = shuffle(ids);

    const [qs] = await conn.query('SELECT id, options FROM questions WHERE id IN (?)', [[...new Set(ids)]]);
    const countOf = new Map(qs.map((q) => [q.id, parseJson(q.options, []).length]));
    sections.push({
      items: ids.map((q) => {
        const n = countOf.get(q) || 5;
        const identity = Array.from({ length: n }, (_, i) => i);
        return { q, o: exam.shuffleOptions ? shuffle(identity) : identity };
      }),
    });
  }
  return { sections };
}

async function startExam(req, user, examId, token) {
  if (user.role !== 'siswa') throw new HttpError('Hanya akun siswa yang bisa mengerjakan ujian.', 403);

  return withTransaction(async (conn) => {
    // Kunci baris siswa: dua klik "Mulai" bersamaan tidak membuat dua percobaan
    await conn.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [user.id]);

    const exam = await loadExamRow(conn, toInt(examId, 0));
    if (exam.status !== 'published') throw new HttpError('Ujian ini belum dibuka / sudah ditutup.', 409);

    // Lanjutkan percobaan yang masih berjalan (mis. HP mati lalu dibuka lagi)
    // (dibaca tanpa kunci rentang; baris siswa sudah terkunci di atas, baris percobaan dikunci lewat PK)
    const [running] = await conn.query(
      "SELECT id FROM exam_attempts WHERE exam_id = ? AND user_id = ? AND status = 'running'", [exam.id, user.id]
    );
    if (running.length) {
      const a = await advance(conn, await loadAttemptRow(conn, running[0].id, user.id), exam);
      if (a.status === 'running') return buildState(conn, a, exam);
    }

    // Target kelas
    const [targets] = await conn.query('SELECT class_id FROM exam_classes WHERE exam_id = ?', [exam.id]);
    if (targets.length && !targets.some((t) => t.class_id === user.classId)) {
      throw new HttpError('Ujian ini tidak ditujukan untuk kelasmu.', 403);
    }

    const now = Date.now();
    if (exam.startAt != null && now < exam.startAt) throw new HttpError('Ujian belum dimulai. Tunggu sesuai jadwal.', 409);
    if (exam.endAt != null && now >= exam.endAt) throw new HttpError('Waktu ujian sudah berakhir.', 409);

    if (exam.accessToken) {
      const given = str(token, 12).toUpperCase();
      if (!given || given !== exam.accessToken.toUpperCase()) throw new HttpError('Token ujian salah. Tanyakan ke pengawas / guru.', 403);
    }

    if (exam.maxAttempts > 0) {
      const [[{ n }]] = await conn.query(
        "SELECT COUNT(*) AS n FROM exam_attempts WHERE exam_id = ? AND user_id = ? AND COALESCE(end_reason, '') <> 'reset'",
        [exam.id, user.id]
      );
      if (n >= exam.maxAttempts) throw new HttpError('Kamu sudah mengerjakan ujian ini. Minta guru membuka ulang bila perlu.', 409);
    }

    // Ujian lain yang masih berjalan: Try Out lama ditutup, ujian sekolah tidak boleh ditinggalkan
    const [others] = await conn.query(
      "SELECT id FROM exam_attempts WHERE user_id = ? AND status = 'running' AND exam_id <> ?", [user.id, exam.id]
    );
    for (const row of others) {
      const o = await loadAttemptRow(conn, row.id, user.id);
      const oExam = await loadExamRow(conn, o.exam_id);
      const adv = await advance(conn, o, oExam);
      if (adv.status !== 'running') continue;
      if (oExam.kind === 'sekolah') throw new HttpError(`Selesaikan dulu ujian "${oExam.title}" yang sedang berjalan.`, 409);
      await finishNow(conn, adv, oExam, 'abandoned');
    }

    const plan = await buildPlan(conn, exam);
    const [r] = await conn.query(
      `INSERT INTO exam_attempts (exam_id, user_id, status, current_section, section_started_at, started_at, last_seen_at, ip, user_agent, plan, answers)
       VALUES (?, ?, 'running', 0, ?, ?, ?, ?, ?, ?, '{}')`,
      [exam.id, user.id, now, now, now, str(ipOf(req), 64), str(req.headers['user-agent'], 255), JSON.stringify(plan)]
    );
    const [rows] = await conn.query('SELECT * FROM exam_attempts WHERE id = ?', [r.insertId]);
    return buildState(conn, rows[0], exam);
  });
}

// ------------------------------------------------------------------ aksi siswa

const touchSeen = async (conn, attempt) => {
  const now = Date.now();
  if (!attempt.last_seen_at || now - Number(attempt.last_seen_at) > SEEN_WRITE_EVERY_MS) {
    await conn.query('UPDATE exam_attempts SET last_seen_at = ? WHERE id = ?', [now, attempt.id]);
  }
};

const getState = (user, id) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    await touchSeen(conn, attempt);
    return buildState(conn, attempt, exam);
  });

/** Soal subtes yang SEDANG berjalan (tanpa kunci jawaban). Subtes lain belum dikirim sama sekali. */
const getSection = (user, id) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    if (attempt.status !== 'running') throw new HttpError('Ujian sudah selesai.', 409);
    await touchSeen(conn, attempt);

    const idx = attempt.current_section;
    const items = (planOf(attempt).sections[idx] || { items: [] }).items;
    const [qs] = await conn.query(
      'SELECT id, passage, text, options FROM questions WHERE id IN (?)', [[...new Set(items.map((it) => it.q))]]
    );
    const byId = new Map(qs.map((q) => [q.id, q]));

    const questions = items.map((it) => {
      const q = byId.get(it.q);
      const opts = parseJson(q.options, []);
      return { passage: q.passage, text: q.text, options: it.o.map((orig) => opts[orig]) };
    });

    // Jawaban tersimpan dikembalikan sebagai indeks tampilan (untuk melanjutkan setelah HP mati)
    const saved = answersOf(attempt)[idx] || {};
    const answers = {};
    items.forEach((it, pos) => {
      if (saved[pos] != null) answers[pos] = it.o.indexOf(saved[pos]);
    });

    const sec = exam.sections[idx];
    return {
      sectionIndex: idx,
      subtest: { id: sec.subtestId, name: sec.name },
      questions,
      answers,
      endsAt: deadlineOf(attempt, exam),
      serverNow: Date.now(),
    };
  });

/** Ubah { posisi: indeksTampilan } menjadi { posisi: indeksAsli } sesuai acakan siswa ini. */
function toOriginal(plan, idx, displayAnswers) {
  const items = (plan.sections[idx] || { items: [] }).items;
  const out = {};
  if (!displayAnswers || typeof displayAnswers !== 'object' || Array.isArray(displayAnswers)) return out;
  for (const [k, v] of Object.entries(displayAnswers)) {
    const pos = toInt(k, -1);
    const d = toInt(v, -1);
    if (pos < 0 || pos >= items.length || v == null) continue;
    if (d < 0 || d >= items[pos].o.length) continue;
    out[pos] = items[pos].o[d];
  }
  return out;
}

async function saveAnswers(conn, attempt, idx, displayAnswers) {
  const all = answersOf(attempt);
  all[idx] = toOriginal(planOf(attempt), idx, displayAnswers);
  const json = JSON.stringify(all);
  await conn.query('UPDATE exam_attempts SET answers = ?, last_seen_at = ? WHERE id = ?', [json, Date.now(), attempt.id]);
  return { ...attempt, answers: json };
}

const autosave = (user, id, body) =>
  withAttempt(id, user.id, async (conn, attempt) => {
    if (attempt.status !== 'running') throw new HttpError('Ujian sudah selesai.', 409);
    const idx = toInt((body || {}).sectionIndex, -1);
    if (idx !== attempt.current_section) throw new HttpError('Subtes ini sudah tidak aktif.', 409);
    const saved = await saveAnswers(conn, attempt, idx, (body || {}).answers);
    return { saved: Object.keys(answersOf(saved)[idx] || {}).length, serverNow: Date.now() };
  });

const submitSection = (user, id, body) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    const idx = toInt((body || {}).sectionIndex, -1);
    if (idx < 0 || idx >= exam.sections.length) throw new HttpError('Nomor subtes tidak valid.');
    // Sudah lewat / sudah selesai: kirim ulang tidak mengubah apa pun (idempoten)
    if (attempt.status !== 'running' || idx < attempt.current_section) return buildState(conn, attempt, exam);
    if (idx > attempt.current_section) throw new HttpError('Subtes ini belum dimulai.', 409);

    let a = attempt;
    if ((body || {}).answers) a = await saveAnswers(conn, a, idx, body.answers); // jawaban terakhir ikut disimpan
    const now = Date.now();
    const at = Math.min(now, deadlineOf(a, exam));
    await closeSection(conn, a, exam, idx, at);

    if (idx >= exam.sections.length - 1) {
      await conn.query("UPDATE exam_attempts SET status = 'finished', end_reason = 'done', finished_at = ? WHERE id = ?", [at, a.id]);
      a = { ...a, status: 'finished', end_reason: 'done', finished_at: at };
    } else {
      await conn.query('UPDATE exam_attempts SET current_section = ?, section_started_at = ?, extra_seconds = 0 WHERE id = ?', [idx + 1, at, a.id]);
      a = { ...a, current_section: idx + 1, section_started_at: at, extra_seconds: 0 };
    }
    return buildState(conn, a, exam);
  });

/** Siswa memilih keluar. Jawaban yang sudah tersimpan tetap dinilai. */
const finish = (user, id, body) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    if (attempt.status !== 'running') return buildState(conn, attempt, exam);
    let a = attempt;
    const idx = toInt((body || {}).sectionIndex, -1);
    if (idx === a.current_section && (body || {}).answers) a = await saveAnswers(conn, a, idx, body.answers);
    a = await finishNow(conn, a, exam, 'quit');
    return buildState(conn, a, exam);
  });

/** Catat pelanggaran dari aplikasi siswa. Server yang memutuskan kapan ujian diakhiri. */
const violation = (user, id, body) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    if (attempt.status !== 'running') return { ...(await buildState(conn, attempt, exam)), ended: true };

    const type = str((body || {}).type, 20) || 'other';
    const known = COUNTED_TYPES.includes(type) || SOFT_TYPES.includes(type);
    const kind = known ? type : 'other';
    const now = Date.now();
    let counted = COUNTED_TYPES.includes(kind) && exam.maxViolations > 0;

    // Beberapa event dari satu kejadian yang sama dihitung satu kali
    if (counted && attempt.last_violation_at && now - Number(attempt.last_violation_at) < VIOLATION_DEBOUNCE_MS) counted = false;

    await conn.query(
      'INSERT INTO violation_logs (attempt_id, user_id, type, counted, detail, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [attempt.id, user.id, kind, counted ? 1 : 0, str((body || {}).detail, 200) || null, now]
    );

    let a = attempt;
    if (counted) {
      const n = attempt.violations + 1;
      await conn.query('UPDATE exam_attempts SET violations = ?, last_violation_at = ? WHERE id = ?', [n, now, attempt.id]);
      a = { ...a, violations: n, last_violation_at: now };
      if (n >= exam.maxViolations) {
        const idx = toInt((body || {}).sectionIndex, -1);
        if (idx === a.current_section && (body || {}).answers) a = await saveAnswers(conn, a, idx, body.answers);
        a = await finishNow(conn, a, exam, 'violation');
      }
    }
    const state = await buildState(conn, a, exam);
    return { ...state, ended: a.status !== 'running', counted };
  });

// ------------------------------------------------------------------ pembahasan

/** Kunci & pembahasan: HANYA setelah ujian selesai DAN kebijakan hasil ujian mengizinkan. */
const review = (user, id) =>
  withAttempt(id, user.id, async (conn, attempt, exam) => {
    if (attempt.status !== 'finished') throw new HttpError('Pembahasan baru tersedia setelah ujian selesai.', 403);
    if (!reviewVisible(exam, attempt)) {
      const msg = exam.resultMode === 'hidden'
        ? 'Pembahasan untuk ujian ini tidak ditampilkan.'
        : 'Pembahasan dibuka setelah waktu ujian ditutup, supaya teman yang belum selesai tidak terbantu.';
      throw new HttpError(msg, 403, { code: 'REVIEW_LOCKED' });
    }
    const plan = planOf(attempt);
    const all = answersOf(attempt);
    const ids = [...new Set(plan.sections.flatMap((s) => s.items.map((it) => it.q)))];
    const [qs] = ids.length ? await conn.query('SELECT * FROM questions WHERE id IN (?)', [ids]) : [[]];
    const byId = new Map(qs.map((q) => [q.id, q]));

    const sections = exam.sections.map((sec, i) => {
      const given = all[i] || {};
      return {
        id: sec.subtestId, name: sec.name,
        items: (plan.sections[i] || { items: [] }).items.map((it, pos) => {
          const q = byId.get(it.q);
          const opts = parseJson(q.options, []);
          return {
            passage: q.passage, text: q.text, options: it.o.map((orig) => opts[orig]),
            chosen: given[pos] == null ? null : it.o.indexOf(given[pos]),
            correct: it.o.indexOf(q.correct_index),
            explanation: q.explanation || '',
          };
        }),
      };
    });
    return { sections };
  });

module.exports = {
  GRACE_MS, withAttempt, buildState, advance, finishNow, closeSection, deadlineOf, loadExamRow, planOf, answersOf,
  startExam, getState, getSection, autosave, submitSection, finish, violation, review,
};
