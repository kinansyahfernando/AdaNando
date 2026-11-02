// src/modules/auth/auth.service.js
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const { pool } = require('../../config/database');
const { HttpError, str } = require('../../utils/http');
const { audit } = require('../../utils/audit');

// Hash tiruan: dipakai agar waktu respons sama baik akun ada maupun tidak (cegah user enumeration)
const DUMMY_HASH = bcrypt.hashSync('tidak-ada-akun', 10);

const checkPasswordPolicy = (password) => {
  const p = String(password || '');
  if (p.length < 8) throw new HttpError('Password minimal 8 karakter.');
  if (p.length > 72) throw new HttpError('Password maksimal 72 karakter.');
  if (!/[A-Za-z]/.test(p) || !/\d/.test(p)) throw new HttpError('Password harus memuat huruf dan angka.');
};

const publicUser = (u, className = null) => ({
  id: u.id, name: u.name, email: u.email, role: u.role, nis: u.nis || null,
  classId: u.class_id || null, className, mustChangePassword: !!u.must_change_password,
});

const classNameOf = async (classId) => {
  if (!classId) return null;
  const [rows] = await pool.query('SELECT name FROM classes WHERE id = ?', [classId]);
  return rows[0] ? rows[0].name : null;
};

const issueToken = (user, sid) =>
  jwt.sign({ id: user.id, role: user.role, sid }, env.jwtSecret, { expiresIn: env.jwtExpires });

const login = async (req, identifier, password) => {
  const id = str(identifier, 150).toLowerCase();
  if (!id || !password) throw new HttpError('Email/NIS dan password wajib diisi.');
  if (!env.jwtSecret) throw new HttpError('Server belum dikonfigurasi (JWT_SECRET kosong).', 500);

  const [rows] = await pool.query(
    'SELECT * FROM users WHERE LOWER(email) = ? OR nis = ? LIMIT 1',
    [id, str(identifier, 30)]
  );
  const user = rows[0];
  const now = Date.now();

  if (user && user.locked_until && Number(user.locked_until) > now) {
    const minutes = Math.ceil((Number(user.locked_until) - now) / 60000);
    throw new HttpError(`Akun dikunci sementara karena terlalu banyak salah password. Coba lagi dalam ${minutes} menit.`, 423);
  }

  const ok = await bcrypt.compare(String(password), user ? user.password : DUMMY_HASH);
  if (!user || !ok) {
    if (user) {
      const fails = (user.failed_logins || 0) + 1;
      if (fails >= env.maxFailedLogins) {
        await pool.query('UPDATE users SET failed_logins = 0, locked_until = ? WHERE id = ?',
          [now + env.lockMinutes * 60000, user.id]);
        await audit(req, 'login_locked', user.email, `Dikunci ${env.lockMinutes} menit`, user.id);
      } else {
        await pool.query('UPDATE users SET failed_logins = ? WHERE id = ?', [fails, user.id]);
      }
    }
    await audit(req, 'login_failed', id, null, user ? user.id : null);
    throw new HttpError('Email/NIS atau password salah.', 401);
  }

  if (!user.is_active) throw new HttpError('Akun dinonaktifkan. Hubungi admin sekolah.', 403);

  const sid = crypto.randomBytes(16).toString('hex');
  await pool.query(
    'UPDATE users SET failed_logins = 0, locked_until = NULL, session_id = ?, last_login_at = ? WHERE id = ?',
    [sid, now, user.id]
  );
  await audit(req, 'login', user.email, null, user.id);

  return {
    message: 'Login berhasil',
    token: issueToken(user, sid),
    user: publicUser(user, await classNameOf(user.class_id)),
  };
};

const register = async (req, name, email, password) => {
  if (!env.allowRegister) {
    throw new HttpError('Pendaftaran mandiri dinonaktifkan. Minta akun ke admin / wali kelas sekolahmu.', 403);
  }
  const cleanName = str(name, 100);
  const cleanEmail = str(email, 150).toLowerCase();
  if (!cleanName || !cleanEmail) throw new HttpError('Nama dan email wajib diisi.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) throw new HttpError('Format email tidak valid.');
  checkPasswordPolicy(password);

  const [existing] = await pool.query('SELECT id FROM users WHERE LOWER(email) = ?', [cleanEmail]);
  if (existing.length > 0) throw new HttpError('Email sudah terdaftar.', 409);

  // Pendaftaran publik SELALU menjadi siswa; role dari klien diabaikan.
  const [result] = await pool.query(
    "INSERT INTO users (name, email, password, role, created_ms) VALUES (?, ?, ?, 'siswa', ?)",
    [cleanName, cleanEmail, await bcrypt.hash(String(password), 10), Date.now()]
  );
  await audit(req, 'register', cleanEmail, null, result.insertId);
  return { message: 'Registrasi berhasil' };
};

const me = async (user) => {
  const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [user.id]);
  return { user: publicUser(rows[0], await classNameOf(rows[0].class_id)) };
};

const changePassword = async (req, user, oldPassword, newPassword) => {
  const [rows] = await pool.query('SELECT password FROM users WHERE id = ?', [user.id]);
  if (!rows[0] || !(await bcrypt.compare(String(oldPassword || ''), rows[0].password))) {
    throw new HttpError('Password lama salah.', 400);
  }
  checkPasswordPolicy(newPassword);
  if (oldPassword === newPassword) throw new HttpError('Password baru harus berbeda dari password lama.');

  const sid = crypto.randomBytes(16).toString('hex'); // sesi lain otomatis keluar
  await pool.query('UPDATE users SET password = ?, must_change_password = 0, session_id = ? WHERE id = ?',
    [await bcrypt.hash(String(newPassword), 10), sid, user.id]);
  await audit(req, 'change_password', user.email);
  return { message: 'Password berhasil diganti.', token: issueToken(user, sid) };
};

const logout = async (req, user) => {
  await pool.query('UPDATE users SET session_id = NULL WHERE id = ?', [user.id]);
  await audit(req, 'logout', user.email);
  return { message: 'OK' };
};

module.exports = { login, register, me, changePassword, logout, checkPasswordPolicy, publicUser };
