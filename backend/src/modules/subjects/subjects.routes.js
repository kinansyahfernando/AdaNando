// src/modules/subjects/subjects.routes.js  ->  /api/v1/admin/subjects  (mata pelajaran / subtes)
const express = require('express');
const { pool } = require('../../config/database');
const { HttpError, wrap, str } = require('../../utils/http');
const { audit } = require('../../utils/audit');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();
router.use(requireRole('admin', 'guru'));

router.get('/', wrap(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT s.id, s.code, s.name, s.is_utbk, COUNT(q.id) AS questions
       FROM subtests s LEFT JOIN questions q ON q.subtest_id = s.id AND q.is_active = 1
      GROUP BY s.id, s.code, s.name, s.is_utbk ORDER BY s.is_utbk DESC, s.name ASC`
  );
  res.json({ items: rows.map((r) => ({ id: r.id, code: r.code, name: r.name, isUtbk: !!r.is_utbk, questions: Number(r.questions) })) });
}));

router.post('/', wrap(async (req, res) => {
  const id = str(req.body && req.body.id, 20).toLowerCase();
  const name = str(req.body && req.body.name, 100);
  const code = str(req.body && req.body.code, 10).toUpperCase() || id.toUpperCase().slice(0, 6);
  if (!/^[a-z0-9_-]{2,20}$/.test(id)) throw new HttpError('Kode ID mapel 2-20 karakter: huruf kecil, angka, _ atau -.');
  if (!name) throw new HttpError('Nama mapel wajib diisi.');
  const [dup] = await pool.query('SELECT id FROM subtests WHERE id = ?', [id]);
  if (dup.length) throw new HttpError('ID mapel sudah ada.', 409);
  await pool.query('INSERT INTO subtests (id, code, name, is_utbk) VALUES (?, ?, ?, 0)', [id, code, name]);
  await audit(req, 'subject_create', id, name);
  res.status(201).json({ id, code, name });
}));

router.put('/:id', wrap(async (req, res) => {
  const name = str(req.body && req.body.name, 100);
  const code = str(req.body && req.body.code, 10).toUpperCase();
  if (!name) throw new HttpError('Nama mapel wajib diisi.');
  await pool.query('UPDATE subtests SET name = ?, code = COALESCE(NULLIF(?, \'\'), code) WHERE id = ?', [name, code, req.params.id]);
  await audit(req, 'subject_update', req.params.id, name);
  res.json({ message: 'Tersimpan.' });
}));

router.delete('/:id', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT is_utbk FROM subtests WHERE id = ?', [req.params.id]);
  if (!rows.length) throw new HttpError('Mapel tidak ditemukan.', 404);
  if (rows[0].is_utbk) throw new HttpError('Subtes UTBK bawaan tidak bisa dihapus.', 409);
  const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM questions WHERE subtest_id = ?', [req.params.id]);
  if (n > 0) throw new HttpError('Mapel ini masih punya soal. Hapus / pindahkan soalnya dulu.', 409);
  await pool.query('DELETE FROM subtests WHERE id = ?', [req.params.id]);
  await audit(req, 'subject_delete', req.params.id);
  res.json({ message: 'Terhapus.' });
}));

module.exports = router;
