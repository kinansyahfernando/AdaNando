// src/config/env.js
// Semua pengaturan dibaca dari .env di satu tempat, lengkap dengan nilai bawaan yang aman.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const bool = (v, def) => (v == null || v === '' ? def : ['1', 'true', 'yes', 'ya'].includes(String(v).toLowerCase()));
const list = (v) => String(v || '').split(',').map((s) => s.trim()).filter(Boolean);

const nodeEnv = process.env.NODE_ENV || 'development';
const isProd = nodeEnv === 'production';

/**
 * Mode development: JWT_SECRET kosong dibuatkan otomatis lalu disimpan ke backend/.env,
 * supaya server tidak langsung mati hanya karena lupa mengisi (login tetap berlaku antar restart).
 * Mode production TIDAK melakukan ini: wajib diisi manual.
 */
function ensureDevJwtSecret() {
  if (process.env.JWT_SECRET || isProd) return process.env.JWT_SECRET || '';
  const secret = crypto.randomBytes(48).toString('hex');
  process.env.JWT_SECRET = secret;
  const envFile = path.join(__dirname, '..', '..', '.env');
  try {
    let text = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : '';
    if (/^JWT_SECRET=.*$/m.test(text)) text = text.replace(/^JWT_SECRET=.*$/m, `JWT_SECRET=${secret}`);
    else text += `${text && !text.endsWith('\n') ? '\n' : ''}JWT_SECRET=${secret}\n`;
    fs.writeFileSync(envFile, text);
    console.log('🔑 JWT_SECRET kosong, dibuatkan otomatis dan disimpan ke backend/.env (mode development).');
  } catch (err) {
    console.warn(`🔑 JWT_SECRET dibuat sementara (gagal menyimpan ke .env: ${err.message}). Login hilang saat restart.`);
  }
  return secret;
}

const env = {
  nodeEnv,
  isProd,
  port: Number(process.env.PORT) || 3000,
  host: process.env.HOST || '0.0.0.0',

  jwtSecret: ensureDevJwtSecret(),
  jwtExpires: process.env.JWT_EXPIRES || '12h',

  // Pendaftaran mandiri siswa. Untuk sekolah sebaiknya false (akun dibuat admin / impor CSV).
  allowRegister: bool(process.env.ALLOW_REGISTER, false),

  // Satu akun siswa hanya boleh aktif di satu perangkat (cegah berbagi akun / joki).
  singleSession: bool(process.env.SINGLE_SESSION, true),

  // Daftar origin tambahan yang boleh memanggil API (pisahkan koma). Same-origin selalu boleh.
  corsOrigins: list(process.env.CORS_ORIGINS),

  // Isi 1 bila di belakang reverse proxy (Nginx / Caddy / Cloudflare) agar IP asli terbaca.
  trustProxy: process.env.TRUST_PROXY || '',

  // Folder hasil build Flutter Web (flutter build web) yang ingin disajikan di "/"
  webDir: process.env.WEB_DIR || '',

  // Batas percobaan login salah sebelum akun dikunci sementara
  maxFailedLogins: Number(process.env.MAX_FAILED_LOGINS) || 5,
  lockMinutes: Number(process.env.LOCK_MINUTES) || 10,
};

env.validate = () => {
  const problems = [];
  if (!env.jwtSecret) problems.push('JWT_SECRET belum diisi di .env');
  else if (isProd && env.jwtSecret.length < 32) problems.push('JWT_SECRET minimal 32 karakter di mode production');
  return problems;
};

module.exports = env;
