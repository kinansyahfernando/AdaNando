// src/middlewares/limits.js
// PENTING untuk sekolah: ratusan siswa sering memakai SATU alamat IP publik (Wi-Fi sekolah / NAT).
// Karena itu batas laju TIDAK boleh per-IP saja. Kita membatasi per akun / per token;
// batas per-IP dibuat sangat longgar hanya sebagai pengaman dari banjir permintaan.
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');

const make = (windowMs, max, message, keyGenerator) =>
  rateLimit({
    windowMs, max, keyGenerator, standardHeaders: true, legacyHeaders: false,
    handler: (req, res) => res.status(429).json({ message }),
  });

const tokenKey = (req) => {
  const h = req.headers.authorization || '';
  if (h.startsWith('Bearer ') && h.length > 20) {
    return 't:' + crypto.createHash('sha1').update(h.slice(7)).digest('hex').slice(0, 16);
  }
  return 'ip:' + req.ip;
};

// Seluruh API: tiap token (siswa) maks. 600/menit (10 per detik). Tanpa token: 600/menit per IP.
const apiLimiter = make(60 * 1000, 600, 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.', tokenKey);

const identifierOf = (req) =>
  String((req.body && (req.body.identifier || req.body.email)) || '').toLowerCase().trim().slice(0, 100);

// Login: tebak-tebak password ke SATU akun dari satu IP dibatasi 20x / 15 menit
// (ditambah kunci akun otomatis di auth.service). Seluruh IP sekolah: 5000 / 15 menit.
const loginLimiter = [
  make(15 * 60 * 1000, 20, 'Terlalu banyak percobaan login untuk akun ini. Coba lagi dalam 15 menit.',
    (req) => `${req.ip}|${identifierOf(req)}`),
  make(15 * 60 * 1000, 5000, 'Terlalu banyak percobaan login dari jaringan ini. Coba lagi nanti.', (req) => 'ip:' + req.ip),
];

module.exports = { apiLimiter, loginLimiter };
