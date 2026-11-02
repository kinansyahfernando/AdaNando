// src/modules/rooms/rooms.service.js
// Logika fitur Belajar Bareng: buat room, gabung, mulai, kumpulkan jawaban, peringkat.
const crypto = require('crypto');
const { pool } = require('../../config/database');
const { shuffle } = require('../exams/exams.shared');
const { SECTIONS: UTBK_SECTIONS, TOTAL_SECONDS: UTBK_SECONDS } = require('../tryout/tryout.config');

// Pilihan "UTBK" di Buat Room: susunan soal + waktu dikunci server sama seperti UTBK
// (7 subtes berurutan, 160 soal, 195 menit). Host tidak bisa mengubah jumlah soal / waktunya.
const UTBK_ID = 'utbk';

class RoomError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

// Tanpa huruf/angka yang mirip (0/O, 1/I) supaya kode mudah diketik
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;

// Toleransi pengiriman jawaban setelah waktu habis (ms), untuk keterlambatan jaringan
const GRACE_MS = 8000;
const MAX_PLAYERS = 30;

const generateCode = () => {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_CHARS[crypto.randomInt(0, CODE_CHARS.length)];
  }
  return code;
};

const normalizeCode = (code) => String(code || '').trim().toUpperCase();

const parseIds = (text) => {
  try {
    const list = JSON.parse(text);
    return Array.isArray(list) ? list.map(String) : [];
  } catch (_) {
    return [];
  }
};

// ---------------------------------------------------------------- loader

const loadRoom = async (code) => {
  const [rows] = await pool.query('SELECT * FROM rooms WHERE code = ?', [normalizeCode(code)]);
  if (rows.length === 0) throw new RoomError('Room tidak ditemukan. Periksa kembali kodenya.', 404);
  return rows[0];
};

const loadPlayers = async (roomId) => {
  const [rows] = await pool.query(
    `SELECT rp.user_id, rp.score, rp.correct, rp.wrong, rp.submitted_at, rp.joined_at, rp.answers, u.name
       FROM room_players rp
       JOIN users u ON u.id = rp.user_id
      WHERE rp.room_id = ?
      ORDER BY rp.joined_at ASC, rp.id ASC`,
    [roomId]
  );
  return rows;
};

const endsAtOf = (room) =>
  room.started_at == null ? null : Number(room.started_at) + Number(room.duration_seconds) * 1000;

// Room "running" otomatis menjadi "finished" bila semua sudah mengumpulkan
// atau waktu + toleransi sudah lewat.
const refreshStatus = async (room, players) => {
  if (room.status !== 'running') return room;

  const endsAt = endsAtOf(room);
  const allSubmitted = players.length > 0 && players.every((p) => p.submitted_at != null);
  const expired = endsAt != null && Date.now() >= endsAt + GRACE_MS;

  if (allSubmitted || expired) {
    await pool.query("UPDATE rooms SET status = 'finished' WHERE id = ? AND status = 'running'", [room.id]);
    return { ...room, status: 'finished' };
  }
  return room;
};

// ---------------------------------------------------------------- bentuk respons

const rankPlayers = (players) =>
  [...players].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (b.correct !== a.correct) return b.correct - a.correct;
    const ta = a.submitted_at == null ? Infinity : Number(a.submitted_at);
    const tb = b.submitted_at == null ? Infinity : Number(b.submitted_at);
    if (ta !== tb) return ta - tb;
    return Number(a.joined_at) - Number(b.joined_at);
  });

const buildState = (room, players, userId) => {
  const finished = room.status === 'finished';
  const ordered = finished ? rankPlayers(players) : players;

  return {
    room: {
      code: room.code,
      subtestId: room.subtest_id,
      questionCount: parseIds(room.question_ids).length,
      durationSeconds: Number(room.duration_seconds),
      status: room.status,
      hostId: room.host_id,
      startedAt: room.started_at == null ? null : Number(room.started_at),
      endsAt: endsAtOf(room),
      serverNow: Date.now(),
    },
    players: ordered.map((p, i) => ({
      userId: p.user_id,
      name: p.name,
      isHost: p.user_id === room.host_id,
      isMe: p.user_id === userId,
      submitted: p.submitted_at != null,
      // Skor baru dibuka setelah room selesai supaya tidak saling mengintip
      score: finished ? p.score : null,
      correct: finished ? p.correct : null,
      wrong: finished ? p.wrong : null,
      rank: finished ? i + 1 : null,
    })),
  };
};

const stateFor = async (room, userId) => {
  let players = await loadPlayers(room.id);
  const isMember = players.some((p) => p.user_id === userId);
  if (!isMember) throw new RoomError('Kamu bukan peserta room ini.', 403);

  const fresh = await refreshStatus(room, players);
  if (fresh.status !== room.status) players = await loadPlayers(room.id);
  return buildState(fresh, players, userId);
};

// ---------------------------------------------------------------- aksi

const ACTIVE_PRACTICE = "is_active = 1 AND usage_type IN ('latihan','semua')";

const createRoom = async (user, body) => {
  const { subtestId, count, durationSeconds } = body || {};

  if (typeof subtestId !== 'string' || !subtestId.trim() || subtestId.length > 20) {
    throw new RoomError('Subtes tidak valid.');
  }
  const sid = subtestId.trim();

  let ids = [];
  let duration;

  if (sid === UTBK_ID) {
    // Mode UTBK: abaikan count / durationSeconds dari aplikasi. Soal diambil per subtes
    // sesuai susunan UTBK dan tetap berurutan (PU, PPU, PBM, PK, LBI, LBE, PM).
    duration = UTBK_SECONDS;
    for (const sec of UTBK_SECTIONS) {
      const [rows] = await pool.query(
        `SELECT id FROM questions WHERE ${ACTIVE_PRACTICE} AND subtest_id = ?`, [sec.id]
      );
      ids.push(...shuffle(rows.map((r) => String(r.id))).slice(0, sec.questions));
    }
    if (!ids.length) throw new RoomError('Belum ada soal latihan untuk UTBK.', 409);
  } else {
    const n = Number(count);
    if (!Number.isInteger(n) || n < 1 || n > 50) throw new RoomError('Jumlah soal harus antara 1 sampai 50.');
    duration = Number(durationSeconds);
    if (!Number.isInteger(duration) || duration < 60 || duration > 7200) {
      throw new RoomError('Durasi harus antara 1 sampai 120 menit.');
    }

    // Soal dipilih SERVER dari bank soal (hanya yang berstatus latihan/semua)
    const where = ["is_active = 1", "usage_type IN ('latihan','semua')"];
    const args = [];
    if (sid !== 'mix') { where.push('subtest_id = ?'); args.push(sid); }
    const [pool_] = await pool.query(`SELECT id FROM questions WHERE ${where.join(' AND ')}`, args);
    if (!pool_.length) throw new RoomError('Belum ada soal latihan untuk subtes ini.', 409);
    ids = shuffle(pool_.map((r) => String(r.id))).slice(0, n);
  }

  const now = Date.now();
  let code = null;
  let roomId = null;

  for (let attempt = 0; attempt < 8 && roomId == null; attempt++) {
    const candidate = generateCode();
    try {
      const [result] = await pool.query(
        `INSERT INTO rooms (code, host_id, subtest_id, question_ids, duration_seconds, status, created_at)
         VALUES (?, ?, ?, ?, ?, 'waiting', ?)`,
        [candidate, user.id, sid, JSON.stringify(ids), duration, now]
      );
      code = candidate;
      roomId = result.insertId;
    } catch (err) {
      if (err.code !== 'ER_DUP_ENTRY') throw err; // kode bentrok -> coba kode lain
    }
  }
  if (roomId == null) throw new RoomError('Gagal membuat kode room. Coba lagi.', 500);

  await pool.query('INSERT INTO room_players (room_id, user_id, joined_at) VALUES (?, ?, ?)', [
    roomId,
    user.id,
    now,
  ]);

  return stateFor(await loadRoom(code), user.id);
};

const joinRoom = async (user, rawCode) => {
  const code = normalizeCode(rawCode);
  if (!code) throw new RoomError('Kode room wajib diisi.');

  const room = await loadRoom(code);
  if (room.status === 'closed') throw new RoomError('Room ini sudah ditutup oleh host.', 410);

  const players = await loadPlayers(room.id);
  const alreadyIn = players.some((p) => p.user_id === user.id);

  if (!alreadyIn) {
    if (room.status !== 'waiting') {
      throw new RoomError('Room sudah dimulai, tidak bisa bergabung lagi.', 409);
    }
    if (players.length >= MAX_PLAYERS) throw new RoomError('Room sudah penuh.', 409);

    try {
      await pool.query('INSERT INTO room_players (room_id, user_id, joined_at) VALUES (?, ?, ?)', [
        room.id,
        user.id,
        Date.now(),
      ]);
    } catch (err) {
      if (err.code !== 'ER_DUP_ENTRY') throw err; // sudah masuk (klik ganda), abaikan
    }
  }

  return stateFor(room, user.id);
};

const getRoom = async (user, code) => {
  const room = await loadRoom(code);
  return stateFor(room, user.id);
};

const startRoom = async (user, code) => {
  const room = await loadRoom(code);
  if (room.host_id !== user.id) throw new RoomError('Hanya host yang bisa memulai room.', 403);
  if (room.status !== 'waiting') throw new RoomError('Room ini sudah dimulai atau ditutup.', 409);

  const [result] = await pool.query(
    "UPDATE rooms SET status = 'running', started_at = ? WHERE id = ? AND status = 'waiting'",
    [Date.now(), room.id]
  );
  if (!result.affectedRows) throw new RoomError('Room ini sudah dimulai atau ditutup.', 409);

  return stateFor(await loadRoom(code), user.id);
};

const submitAnswers = async (user, code, body) => {
  const room = await loadRoom(code);
  const players = await loadPlayers(room.id);
  const me = players.find((p) => p.user_id === user.id);
  if (!me) throw new RoomError('Kamu bukan peserta room ini.', 403);

  // Kirim ulang tidak mengubah apa pun (idempoten)
  if (me.submitted_at != null) return stateFor(room, user.id);

  if (room.status !== 'running') {
    throw new RoomError('Room belum dimulai atau sudah selesai.', 409);
  }
  const endsAt = endsAtOf(room);
  if (endsAt != null && Date.now() > endsAt + GRACE_MS) {
    throw new RoomError('Waktu pengumpulan jawaban sudah lewat.', 409);
  }

  const given = (body || {}).answers;
  if (given == null || typeof given !== 'object' || Array.isArray(given)) throw new RoomError('Data jawaban tidak valid.');

  // Nilai dihitung SERVER dari kunci di database
  const ids = parseIds(room.question_ids).map(Number);
  const [qs] = await pool.query('SELECT id, correct_index FROM questions WHERE id IN (?)', [ids]);
  const key = new Map(qs.map((q) => [String(q.id), q.correct_index]));
  const clean = {};
  let c = 0;
  let w = 0;
  for (const id of ids) {
    const v = given[String(id)];
    if (!Number.isInteger(v) || v < 0 || v > 5) continue;
    clean[String(id)] = v;
    if (v === key.get(String(id))) c++; else w++;
  }
  const score = c * 4 - w;

  await pool.query(
    `UPDATE room_players
        SET score = ?, correct = ?, wrong = ?, answers = ?, submitted_at = ?
      WHERE room_id = ? AND user_id = ? AND submitted_at IS NULL`,
    [score, c, w, JSON.stringify(clean), Date.now(), room.id, user.id]
  );

  return stateFor(room, user.id);
};

// Soal untuk peserta (tanpa kunci), hanya saat ujian room berjalan
const roomQuestions = async (user, code) => {
  const room = await loadRoom(code);
  const players = await loadPlayers(room.id);
  if (!players.some((p) => p.user_id === user.id)) throw new RoomError('Kamu bukan peserta room ini.', 403);
  if (room.status !== 'running' && room.status !== 'finished') throw new RoomError('Room belum dimulai.', 409);
  const ids = parseIds(room.question_ids).map(Number);
  const [qs] = await pool.query('SELECT id, subtest_id, passage, text, options FROM questions WHERE id IN (?)', [ids]);
  const byId = new Map(qs.map((q) => [q.id, q]));
  return {
    items: ids.map((id) => byId.get(id)).filter(Boolean).map((q) => ({
      id: q.id, subtestId: q.subtest_id, passage: q.passage, text: q.text, options: JSON.parse(q.options),
    })),
  };
};

// Kunci + pembahasan: hanya setelah room selesai
const roomReview = async (user, code) => {
  const room = await loadRoom(code);
  const players = await loadPlayers(room.id);
  const me = players.find((p) => p.user_id === user.id);
  if (!me) throw new RoomError('Kamu bukan peserta room ini.', 403);
  const fresh = await refreshStatus(room, players);
  if (fresh.status !== 'finished') throw new RoomError('Pembahasan dibuka setelah semua peserta selesai / waktu habis.', 403);
  const ids = parseIds(room.question_ids).map(Number);
  const [qs] = await pool.query('SELECT * FROM questions WHERE id IN (?)', [ids]);
  const byId = new Map(qs.map((q) => [q.id, q]));
  let mine = {};
  try { mine = JSON.parse(me.answers || '{}'); } catch (_) { mine = {}; }
  return {
    items: ids.map((id) => byId.get(id)).filter(Boolean).map((q) => ({
      id: q.id, subtestId: q.subtest_id, passage: q.passage, text: q.text, options: JSON.parse(q.options),
      correctIndex: q.correct_index, explanation: q.explanation || '',
      chosen: mine[String(q.id)] == null ? null : mine[String(q.id)],
    })),
  };
};

const leaveRoom = async (user, code) => {
  const room = await loadRoom(code);

  if (room.status === 'waiting') {
    if (room.host_id === user.id) {
      await pool.query("UPDATE rooms SET status = 'closed' WHERE id = ? AND status = 'waiting'", [room.id]);
    } else {
      await pool.query('DELETE FROM room_players WHERE room_id = ? AND user_id = ?', [room.id, user.id]);
    }
  }
  // Saat ujian berjalan / selesai, keluar tidak mengubah data peserta.
  return { message: 'OK' };
};

module.exports = {
  RoomError,
  createRoom,
  joinRoom,
  getRoom,
  startRoom,
  submitAnswers,
  leaveRoom,
  roomQuestions,
  roomReview,
};
