// src/app.js
const express = require('express');
const cors = require('cors');

const authRoutes = require('./modules/auth/auth.routes'); // sesuaikan nama file
const roomRoutes = require('./modules/rooms/rooms.routes'); // Belajar Bareng
const tryoutRoutes = require('./modules/tryout/tryout.routes'); // Try Out Mandiri
const resultRoutes = require('./modules/results/results.routes'); // Riwayat hasil (Potensi)

const app = express();

// ---------- CORS ----------
// Flutter Web memakai port acak (mis. localhost:54321), jadi izinkan semua localhost/127.0.0.1
const corsOptions = {
  origin: (origin, callback) => {
    // origin kosong = Postman/cURL/mobile app, selalu diizinkan
    if (!origin) return callback(null, true);

    const allowed =
      /^https?:\/\/localhost(:\d+)?$/.test(origin) ||
      /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);

    return allowed ? callback(null, true) : callback(new Error(`CORS ditolak untuk origin: ${origin}`));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  credentials: true,
  optionsSuccessStatus: 204,
};

app.use(cors(corsOptions)); // sudah menangani preflight OPTIONS otomatis
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ---------- Logger sederhana (untuk debugging) ----------
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} | origin: ${req.headers.origin || '-'}`);
  next();
});

// ---------- Routes ----------
app.get('/api/v1/health', (req, res) => {
  res.json({ success: true, message: 'AdaNando API hidup', time: new Date().toISOString() });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/rooms', roomRoutes);
app.use('/api/v1/tryout', tryoutRoutes);
app.use('/api/v1/results', resultRoutes);

// ---------- 404 ----------
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.originalUrl} tidak ditemukan` });
});

// ---------- Error handler ----------
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('❌ Error:', err.message);
  res.status(err.status || 500).json({ success: false, message: err.message || 'Terjadi kesalahan server' });
});

module.exports = app;