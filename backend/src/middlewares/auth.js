// src/middlewares/auth.js
// Memeriksa token JWT, lalu MEMVERIFIKASI ULANG ke database (akun aktif, sesi masih berlaku).
// Dengan begitu akun yang dinonaktifkan atau login di perangkat lain langsung tertolak,
// tidak menunggu token kedaluwarsa.
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { pool } = require('../config/database');
const { HttpError, wrap } = require('../utils/http');

const authenticate = wrap(async (req, res, next) => {
  const [scheme, token] = (req.headers.authorization || '').split(' ');
  if (scheme !== 'Bearer' || !token) throw new HttpError('Silakan login terlebih dahulu.', 401, { code: 'NO_TOKEN' });

  let payload;
  try {
    payload = jwt.verify(token, env.jwtSecret);
  } catch (_) {
    throw new HttpError('Sesi berakhir. Silakan login ulang.', 401, { code: 'TOKEN_EXPIRED' });
  }

  const [rows] = await pool.query(
    'SELECT id, name, email, role, nis, class_id, is_active, must_change_password, session_id FROM users WHERE id = ?',
    [payload.id]
  );
  const user = rows[0];
  if (!user) throw new HttpError('Akun tidak ditemukan.', 401, { code: 'NO_USER' });
  if (!user.is_active) throw new HttpError('Akun dinonaktifkan. Hubungi admin sekolah.', 403, { code: 'DISABLED' });

  if (env.singleSession && user.role === 'siswa' && user.session_id !== payload.sid) {
    throw new HttpError('Akunmu sedang dipakai di perangkat lain. Silakan login ulang.', 401, { code: 'SESSION_REPLACED' });
  }

  req.user = {
    id: user.id, name: user.name, email: user.email, role: user.role,
    nis: user.nis, classId: user.class_id, mustChangePassword: !!user.must_change_password,
  };
  next();
});

/** Hanya role tertentu yang boleh lewat. Contoh: requireRole('admin', 'guru') */
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return next(new HttpError('Kamu tidak punya akses ke fitur ini.', 403, { code: 'FORBIDDEN' }));
  }
  next();
};

/** Akun yang wajib ganti password tidak boleh memakai fitur lain dulu. */
const requirePasswordChanged = (req, res, next) => {
  if (req.user && req.user.mustChangePassword) {
    return next(new HttpError('Kamu harus mengganti password terlebih dahulu.', 403, { code: 'MUST_CHANGE_PASSWORD' }));
  }
  next();
};

module.exports = { authenticate, requireRole, requirePasswordChanged };
