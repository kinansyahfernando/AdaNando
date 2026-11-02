// src/modules/users/users.routes.js  ->  /api/v1/admin/users
const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../../config/database');
const { HttpError, wrap, toInt, clampInt, str } = require('../../utils/http');
const { generatePassword } = require('../../utils/passwords');
const { audit } = require('../../utils/audit');
const { requireRole } = require('../../middlewares/auth');

const router = express.Router();
const ROLES = ['admin', 'guru', 'siswa'];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const rowOut = (u) => ({
  id: u.id, name: u.name, email: u.email, nis: u.nis, role: u.role,
  classId: u.class_id, className: u.class_name || null,
  isActive: !!u.is_active, mustChangePassword: !!u.must_change_password,
  locked: !!(u.locked_until && Number(u.locked_until) > Date.now()),
  lastLoginAt: u.last_login_at == null ? null : Number(u.last_login_at),
});

// ---- daftar (admin & guru; guru hanya melihat siswa)
router.get('/', requireRole('admin', 'guru'), wrap(async (req, res) => {
  const where = [];
  const args = [];
  if (req.user.role === 'guru') where.push("u.role = 'siswa'");
  else if (ROLES.includes(req.query.role)) { where.push('u.role = ?'); args.push(req.query.role); }
  if (req.query.classId) { where.push('u.class_id = ?'); args.push(toInt(req.query.classId, 0)); }
  if (req.query.q) {
    where.push('(u.name LIKE ? OR u.email LIKE ? OR u.nis LIKE ?)');
    const like = `%${str(req.query.q, 60).replace(/[%_]/g, '')}%`;
    args.push(like, like, like);
  }
  const clause = where.length ? 'WHERE ' + where.join(' AND ') : '';
  const limit = clampInt(req.query.limit, 1, 200, 50);
  const page = clampInt(req.query.page, 1, 100000, 1);

  const [[{ total }]] = await pool.query(`SELECT COUNT(*) AS total FROM users u ${clause}`, args);
  const [rows] = await pool.query(
    `SELECT u.*, c.name AS class_name FROM users u LEFT JOIN classes c ON c.id = u.class_id
      ${clause} ORDER BY u.name ASC LIMIT ? OFFSET ?`,
    [...args, limit, (page - 1) * limit]
  );
  res.json({ items: rows.map(rowOut), total, page, limit });
}));

// ---- seluruh perubahan hanya untuk admin
router.use(requireRole('admin'));

async function validateUser(body, { partial = false, ignoreId = null } = {}) {
  const out = {};
  if (!partial || body.name !== undefined) {
    out.name = str(body.name, 100);
    if (!out.name) throw new HttpError('Nama wajib diisi.');
  }
  if (!partial || body.role !== undefined) {
    out.role = body.role || 'siswa';
    if (!ROLES.includes(out.role)) throw new HttpError('Role tidak valid.');
  }
  if (body.nis !== undefined) {
    out.nis = str(body.nis, 30) || null;
    if (out.nis && !/^[A-Za-z0-9._-]+$/.test(out.nis)) throw new HttpError('NIS hanya boleh huruf, angka, titik, strip.');
  }
  if (body.email !== undefined || !partial) {
    let email = str(body.email, 150).toLowerCase();
    if (!email && out.nis) email = `${out.nis.toLowerCase()}@siswa.local`;
    if (!email) throw new HttpError('Email atau NIS wajib diisi.');
    if (!EMAIL_RE.test(email)) throw new HttpError('Format email tidak valid.');
    out.email = email;
  }
  if (body.classId !== undefined) {
    out.classId = body.classId ? toInt(body.classId, null) : null;
    if (out.classId) {
      const [c] = await pool.query('SELECT id FROM classes WHERE id = ?', [out.classId]);
      if (!c.length) throw new HttpError('Kelas tidak ditemukan.');
    }
  }
  if (out.email) {
    const [dup] = await pool.query('SELECT id FROM users WHERE LOWER(email) = ? AND id <> ?', [out.email, ignoreId || 0]);
    if (dup.length) throw new HttpError(`Email ${out.email} sudah dipakai.`, 409);
  }
  if (out.nis) {
    const [dup] = await pool.query('SELECT id FROM users WHERE nis = ? AND id <> ?', [out.nis, ignoreId || 0]);
    if (dup.length) throw new HttpError(`NIS ${out.nis} sudah dipakai.`, 409);
  }
  return out;
}

router.post('/', wrap(async (req, res) => {
  const v = await validateUser(req.body || {});
  const password = str(req.body.password, 72) || generatePassword();
  if (req.body.password && password.length < 8) throw new HttpError('Password minimal 8 karakter.');
  const [r] = await pool.query(
    `INSERT INTO users (name, email, password, role, nis, class_id, must_change_password, created_ms)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?)`,
    [v.name, v.email, await bcrypt.hash(password, 10), v.role, v.nis || null, v.classId || null, Date.now()]
  );
  await audit(req, 'user_create', v.email, v.role);
  res.status(201).json({ id: r.insertId, email: v.email, password });
}));

router.put('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
  if (!rows.length) throw new HttpError('Pengguna tidak ditemukan.', 404);
  const body = req.body || {};
  const v = await validateUser(body, { partial: true, ignoreId: id });

  if (id === req.user.id && (body.isActive === false || (v.role && v.role !== 'admin'))) {
    throw new HttpError('Kamu tidak bisa menonaktifkan / menurunkan role akunmu sendiri.', 400);
  }
  const sets = [];
  const args = [];
  const push = (col, val) => { sets.push(`${col} = ?`); args.push(val); };
  if (v.name !== undefined) push('name', v.name);
  if (v.email !== undefined) push('email', v.email);
  if (v.nis !== undefined) push('nis', v.nis);
  if (v.role !== undefined) push('role', v.role);
  if (v.classId !== undefined) push('class_id', v.classId);
  if (body.isActive !== undefined) {
    push('is_active', body.isActive ? 1 : 0);
    if (!body.isActive) push('session_id', null); // langsung keluar dari semua perangkat
  }
  if (!sets.length) return res.json({ message: 'Tidak ada perubahan.' });

  await pool.query(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`, [...args, id]);
  await audit(req, 'user_update', rows[0].email, sets.map((s) => s.split(' ')[0]).join(','));
  res.json({ message: 'Tersimpan.' });
}));

router.post('/:id/reset-password', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  const [rows] = await pool.query('SELECT email FROM users WHERE id = ?', [id]);
  if (!rows.length) throw new HttpError('Pengguna tidak ditemukan.', 404);
  const password = generatePassword();
  await pool.query(
    'UPDATE users SET password = ?, must_change_password = 1, session_id = NULL, failed_logins = 0, locked_until = NULL WHERE id = ?',
    [await bcrypt.hash(password, 10), id]
  );
  await audit(req, 'user_reset_password', rows[0].email);
  res.json({ email: rows[0].email, password });
}));

router.post('/:id/unlock', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  await pool.query('UPDATE users SET failed_logins = 0, locked_until = NULL WHERE id = ?', [id]);
  await audit(req, 'user_unlock', String(id));
  res.json({ message: 'Akun dibuka kuncinya.' });
}));

router.delete('/:id', wrap(async (req, res) => {
  const id = toInt(req.params.id, 0);
  if (id === req.user.id) throw new HttpError('Kamu tidak bisa menghapus akunmu sendiri.');
  const [rows] = await pool.query('SELECT email FROM users WHERE id = ?', [id]);
  if (!rows.length) throw new HttpError('Pengguna tidak ditemukan.', 404);
  const [[{ n }]] = await pool.query('SELECT COUNT(*) AS n FROM exam_attempts WHERE user_id = ?', [id]);
  if (n > 0) {
    throw new HttpError('Pengguna ini punya riwayat ujian, jadi tidak bisa dihapus. Nonaktifkan saja akunnya.', 409);
  }
  await pool.query('DELETE FROM users WHERE id = ?', [id]);
  await audit(req, 'user_delete', rows[0].email);
  res.json({ message: 'Terhapus.' });
}));

// ---- impor massal (baris sudah di-parse dari CSV oleh panel admin)
router.post('/import', wrap(async (req, res) => {
  const rows = Array.isArray(req.body && req.body.rows) ? req.body.rows : [];
  if (!rows.length) throw new HttpError('Tidak ada baris untuk diimpor.');
  if (rows.length > 1000) throw new HttpError('Maksimal 1000 baris per impor.');

  const created = [];
  const errors = [];
  const classCache = new Map();

  const classIdOf = async (name) => {
    const key = str(name, 50);
    if (!key) return null;
    if (classCache.has(key)) return classCache.get(key);
    await pool.query('INSERT IGNORE INTO classes (name, created_at) VALUES (?, ?)', [key, Date.now()]);
    const [c] = await pool.query('SELECT id FROM classes WHERE name = ?', [key]);
    classCache.set(key, c[0].id);
    return c[0].id;
  };

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i] || {};
    try {
      const classId = await classIdOf(r.kelas || r.className);
      const v = await validateUser({ name: r.nama || r.name, nis: r.nis, email: r.email, role: 'siswa', classId });
      const password = generatePassword();
      await pool.query(
        `INSERT INTO users (name, email, password, role, nis, class_id, must_change_password, created_ms)
         VALUES (?, ?, ?, 'siswa', ?, ?, 1, ?)`,
        [v.name, v.email, await bcrypt.hash(password, 10), v.nis || null, v.classId || null, Date.now()]
      );
      created.push({ nama: v.name, nis: v.nis || '', email: v.email, kelas: str(r.kelas || r.className, 50), password });
    } catch (err) {
      errors.push({ row: i + 1, message: err.message });
    }
  }
  await audit(req, 'user_import', `${created.length} akun`, `${errors.length} gagal`);
  res.json({ created, errors });
}));

module.exports = router;
