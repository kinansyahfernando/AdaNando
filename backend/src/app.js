// src/app.js
const path = require('path');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');

const env = require('./config/env');
const { apiLimiter } = require('./middlewares/limits');
const { authenticate, requirePasswordChanged, requireRole } = require('./middlewares/auth');
const { notFound, errorHandler } = require('./middlewares/errors');

const app = express();
if (env.trustProxy) app.set('trust proxy', /^\d+$/.test(env.trustProxy) ? Number(env.trustProxy) : env.trustProxy);
app.disable('x-powered-by');

// ---------- Header keamanan ----------
// CSP dimatikan global karena Flutter Web memakai WebAssembly/CanvasKit; panel admin punya CSP sendiri (di bawah).
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false, crossOriginResourcePolicy: { policy: 'same-site' } }));
app.use(compression());

// ---------- CORS ----------
// Aplikasi & API satu alamat (same-origin) tidak butuh CORS. Origin lain harus didaftarkan di CORS_ORIGINS.
// Saat development, localhost / 127.0.0.1 diizinkan.
const corsOptions = {
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    const dev = !env.isProd && (/^https?:\/\/localhost(:\d+)?$/.test(origin) || /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin));
    if (dev || env.corsOrigins.includes(origin)) return cb(null, true);
    return cb(null, false);
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  optionsSuccessStatus: 204,
};
app.use('/api', cors(corsOptions));
app.use(express.json({ limit: '2mb' }));

// ---------- Log ringkas (tanpa isi body / token) ----------
app.use('/api', (req, res, next) => {
  const t = Date.now();
  res.on('finish', () => {
    if (req.originalUrl.includes('/health')) return;
    console.log(`[${new Date().toISOString()}] ${req.ip} ${req.method} ${req.originalUrl.split('?')[0]} ${res.statusCode} ${Date.now() - t}ms`);
  });
  next();
});

// ---------- API ----------
const api = express.Router();
api.use(apiLimiter);
api.get('/health', (req, res) => res.json({ success: true, message: 'AdaNando API hidup', time: new Date().toISOString() }));
// Waktu server: dipakai aplikasi untuk menyelaraskan timer
api.get('/time', (req, res) => res.json({ now: Date.now() }));

api.use('/auth', require('./modules/auth/auth.routes'));
api.use('/rooms', require('./modules/rooms/rooms.routes'));
api.use('/results', require('./modules/results/results.routes'));
api.use('/practice', require('./modules/practice/practice.routes'));
const { examsRouter, attemptsRouter } = require('./modules/attempts/attempts.routes');
api.use('/exams', examsRouter);
api.use('/attempts', attemptsRouter);

// Panel guru / admin
const staff = express.Router();
staff.use(authenticate, requirePasswordChanged, requireRole('admin', 'guru'));
staff.use('/users', require('./modules/users/users.routes'));
staff.use('/classes', require('./modules/classes/classes.routes'));
staff.use('/subjects', require('./modules/subjects/subjects.routes'));
staff.use('/questions', require('./modules/questions/questions.routes'));
staff.use('/exams', require('./modules/exams/exams.routes'));
staff.use('/potensi', require('./modules/reports/potensi.routes'));
staff.use('/', require('./modules/reports/dashboard.routes'));
api.use('/admin', staff);

app.use('/api/v1', api);
app.use('/api', (req, res) => notFound(req, res));

// ---------- Panel admin (web) di /admin ----------
const adminDir = path.join(__dirname, '..', 'public', 'admin');
app.use('/admin', (req, res, next) => {
  res.setHeader('Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
  res.setHeader('Cache-Control', 'no-cache');
  next();
}, express.static(adminDir));

// ---------- Aplikasi siswa (Flutter Web / PWA) di "/" ----------
if (env.webDir) {
  const webDir = path.resolve(env.webDir);
  if (fs.existsSync(path.join(webDir, 'index.html'))) {
    app.use(express.static(webDir, {
      setHeaders: (res, file) => {
        // File kunci Flutter jangan di-cache lama supaya update langsung terpakai
        if (/(index\.html|flutter_service_worker\.js|flutter_bootstrap\.js|version\.json|manifest\.json)$/.test(file)) {
          res.setHeader('Cache-Control', 'no-cache');
        }
      },
    }));
    app.get(/^\/(?!api|admin).*/, (req, res) => res.sendFile(path.join(webDir, 'index.html')));
    console.log(`🌐 Aplikasi web disajikan dari ${webDir}`);
  } else {
    console.warn(`⚠️ WEB_DIR=${webDir} tidak berisi index.html. Jalankan "flutter build web" dulu.`);
  }
}

// Tanpa aplikasi web yang disajikan, alamat utama langsung mengarah ke panel guru/admin
if (!env.webDir) app.get('/', (req, res) => res.redirect('/admin/'));

app.use(notFound);
app.use(errorHandler);

module.exports = app;