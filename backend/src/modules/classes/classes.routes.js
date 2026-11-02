// src/modules/classes/classes.routes.js  ->  /api/v1/admin/classes
const express = require('express');
const { pool } = require('../../config/database');
const { HttpError, wrap, toInt, str } = require('../../utils/http');
const { audit } = require('../../utils/audit');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();

router.get('/', requireRole('admin', 'guru'), wrap(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT c.id, c.name, COUNT(u.id) AS students
       FROM classes c LEFT JOIN users u ON u.class_id = c.id AND u.role = 'siswa'
      GROUP BY c.id, c.name ORDER BY c.name ASC`
  );
  res.json({ items: rows.map((r) => ({ id: r.id, name: r.name, students: Number(r.students) })) });
}));

router.use(requireRole('admin'));

router.post('/', wrap(async (req, res) => {
  const name = str(req.body && req.body.name, 50);
  if (!name) throw new HttpError('Nama kelas wajib diisi.');
  const [dup] = await pool.query('SELECT id FROM classes WHERE name = ?', [name]);
  if (dup.length) throw new HttpError('Nama kelas sudah ada.', 409);
  const [r] = await pool.query('INSERT INTO classes (name, created_at) VALUES (?, ?)', [name, Date.now()]);
  await audit(req, 'class_create', name);
  res.status(201).json({ id: r.insertId, name });
}));

router.put('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  const name = str(req.body && req.body.name, 50);
  if (!name) throw new HttpError('Nama kelas wajib diisi.');
  const [dup] = await pool.query('SELECT id FROM classes WHERE name = ? AND id <> ?', [name, id]);
  if (dup.length) throw new HttpError('Nama kelas sudah ada.', 409);
  await pool.query('UPDATE classes SET name = ? WHERE id = ?', [name, id]);
  await audit(req, 'class_update', name);
  res.json({ message: 'Tersimpan.' });
}));

router.delete('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM users WHERE class_id = ?', [id]);
  if (n > 0) throw new HttpError('Kelas masih memiliki siswa. Pindahkan siswanya terlebih dahulu.', 409);
  await pool.query('DELETE FROM exam_classes WHERE class_id = ?', [id]);
  await pool.query('DELETE FROM classes WHERE id = ?', [id]);
  await audit(req, 'class_delete', String(id));
  res.json({ message: 'Terhapus.' });
}));

module.exports = router;
