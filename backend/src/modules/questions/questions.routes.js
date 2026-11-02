// src/modules/questions/questions.routes.js  ->  /api/v1/admin/questions  (bank soal)
const express = require('express');
const { pool } = require('../../config/database');
const { HttpError, wrap, toInt, clampInt, str, parseJson } = require('../../utils/http');
const { audit } = require('../../utils/audit');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();
router.use(requireRole('admin', 'guru'));

const USAGES = ['latihan', 'ujian', 'semua'];

const out = (q) => ({
  id: q.id, code: q.code, subtestId: q.subtest_id, passage: q.passage, text: q.text,
  options: parseJson(q.options, []), correctIndex: q.correct_index, explanation: q.explanation,
  difficulty: q.difficulty, usage: q.usage_type, isActive: !!q.is_active,
});

async function validate(body) {
  const b = body || {};
  const text = str(b.text, 5000);
  if (!text) throw new HttpError('Teks soal wajib diisi.');
  if (!Array.isArray(b.options)) throw new HttpError('Pilihan jawaban wajib diisi.');
  const options = b.options.map((o) => str(o, 600));
  if (options.length < 2 || options.length > 6) throw new HttpError('Jumlah pilihan harus 2 sampai 6.');
  if (options.some((o) => !o)) throw new HttpError('Semua pilihan jawaban harus terisi.');
  if (new Set(options).size !== options.length) throw new HttpError('Ada pilihan jawaban yang kembar.');
  const correctIndex = toInt(b.correctIndex, -1);
  if (correctIndex < 0 || correctIndex >= options.length) throw new HttpError('Kunci jawaban tidak valid.');
  const subtestId = str(b.subtestId, 20);
  const [s] = await pool.query('SELECT id FROM subtests WHERE id = ?', [subtestId]);
  if (!s.length) throw new HttpError('Mapel / subtes tidak ditemukan.');
  const usage = USAGES.includes(b.usage) ? b.usage : 'semua';
  return {
    subtestId, text, options, correctIndex, usage,
    passage: str(b.passage, 8000) || null,
    explanation: str(b.explanation, 5000) || null,
    difficulty: clampInt(b.difficulty, 1, 3, 2),
  };
}

router.get('/', wrap(async (req, res) => {
  const where = ['is_active = 1'];
  const args = [];
  if (req.query.subtestId) { where.push('subtest_id = ?'); args.push(str(req.query.subtestId, 20)); }
  if (USAGES.includes(req.query.usage)) { where.push('usage_type = ?'); args.push(req.query.usage); }
  if (req.query.q) {
    where.push('(text LIKE ? OR passage LIKE ?)');
    const like = `%${str(req.query.q, 80).replace(/[%_]/g, '')}%`;
    args.push(like, like);
  }
  const limit = clampInt(req.query.limit, 1, 500, 30);
  const page = clampInt(req.query.page, 1, 100000, 1);
  const clause = 'WHERE ' + where.join(' AND ');
  const [[{ total }]] = await pool.query(`SELECT COUNT(*) AS total FROM questions ${clause}`, args);
  const [rows] = await pool.query(
    `SELECT * FROM questions ${clause} ORDER BY id DESC LIMIT ? OFFSET ?`, [...args, limit, (page - 1) * limit]
  );
  res.json({ items: rows.map(out), total, page, limit });
}));

router.get('/:id', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM questions WHERE id = ? AND is_active = 1', [toInt(req.params.id, 0)]);
  if (!rows.length) throw new HttpError('Soal tidak ditemukan.', 404);
  res.json(out(rows[0]));
}));

router.post('/', wrap(async (req, res) => {
  const v = await validate(req.body);
  const [r] = await pool.query(
    `INSERT INTO questions (subtest_id, passage, text, options, correct_index, explanation, difficulty, usage_type, created_by, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [v.subtestId, v.passage, v.text, JSON.stringify(v.options), v.correctIndex, v.explanation, v.difficulty, v.usage, req.user.id, Date.now()]
  );
  await audit(req, 'question_create', String(r.insertId), v.subtestId);
  res.status(201).json({ id: r.insertId });
}));

router.put('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  const [rows] = await pool.query('SELECT id FROM questions WHERE id = ? AND is_active = 1', [id]);
  if (!rows.length) throw new HttpError('Soal tidak ditemukan.', 404);
  const v = await validate(req.body);
  await pool.query(
    `UPDATE questions SET subtest_id = ?, passage = ?, text = ?, options = ?, correct_index = ?, explanation = ?,
            difficulty = ?, usage_type = ?, updated_at = ? WHERE id = ?`,
    [v.subtestId, v.passage, v.text, JSON.stringify(v.options), v.correctIndex, v.explanation, v.difficulty, v.usage, Date.now(), id]
  );
  await audit(req, 'question_update', String(id));
  res.json({ message: 'Tersimpan.' });
}));

// Soal tidak dihapus permanen supaya riwayat ujian lama tetap bisa dibahas.
router.delete('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  await pool.query('UPDATE questions SET is_active = 0, updated_at = ? WHERE id = ?', [Date.now(), id]);
  await audit(req, 'question_delete', String(id));
  res.json({ message: 'Terhapus.' });
}));

// Impor massal: { questions: [{subtestId, text, options[], correctIndex, ...}] }
router.post('/import', wrap(async (req, res) => {
  const list = Array.isArray(req.body && req.body.questions) ? req.body.questions : [];
  if (!list.length) throw new HttpError('Tidak ada soal untuk diimpor.');
  if (list.length > 500) throw new HttpError('Maksimal 500 soal per impor.');
  let created = 0;
  const errors = [];
  for (let i = 0; i < list.length; i++) {
    try {
      const v = await validate(list[i]);
      await pool.query(
        `INSERT INTO questions (subtest_id, passage, text, options, correct_index, explanation, difficulty, usage_type, created_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [v.subtestId, v.passage, v.text, JSON.stringify(v.options), v.correctIndex, v.explanation, v.difficulty, v.usage, req.user.id, Date.now()]
      );
      created++;
    } catch (err) {
      errors.push({ row: i + 1, message: err.message });
    }
  }
  await audit(req, 'question_import', `${created} soal`, `${errors.length} gagal`);
  res.json({ created, errors });
}));

module.exports = router;
