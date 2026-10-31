const { pool } = require('../../config/database'); // <-- perbaikan utama: destructuring
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

class AuthError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const login = async (email, password) => {
  if (!email || !password) {
    throw new AuthError('Email dan password wajib diisi', 400);
  }
  if (!process.env.JWT_SECRET) {
    throw new AuthError('JWT_SECRET belum diisi di file .env backend', 500);
  }

  const [rows] = await pool.query(
    'SELECT id, name, email, password, role FROM users WHERE email = ?',
    [email]
  );
  if (rows.length === 0) {
    throw new AuthError('Email atau password salah', 401);
  }

  const user = rows[0];
  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) {
    throw new AuthError('Email atau password salah', 401);
  }

  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '1d' }
  );

  return {
    message: 'Login berhasil',
    token,
    user: { id: user.id, name: user.name, email: user.email, role: user.role },
  };
};

const register = async (name, email, password) => {
  const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
  if (existing.length > 0) {
    throw new AuthError('Email sudah terdaftar', 409);
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  // Pendaftaran publik SELALU menjadi siswa. Admin dibuat lewat seed / panel admin.
  await pool.query(
    'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
    [name, email, hashedPassword, 'siswa']
  );

  return { message: 'Registrasi berhasil' };
};

module.exports = { login, register, AuthError };