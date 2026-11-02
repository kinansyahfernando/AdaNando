// server.js
const env = require('./src/config/env');
const app = require('./src/app');
const { testConnection } = require('./src/config/database');

// Pemeriksaan skema bersifat tambahan: bila filenya belum tersalin, server tetap menyala.
let checkSchema = async () => true;
try {
  ({ checkSchema } = require('./src/config/schemaCheck'));
} catch (err) {
  console.warn('⚠️ src/config/schemaCheck.js tidak ditemukan, pemeriksaan skema dilewati.');
}

const problems = env.validate();
if (problems.length) {
  console.error('❌ Konfigurasi belum benar:');
  problems.forEach((p) => console.error('   - ' + p));
  process.exit(1);
}

const server = app.listen(env.port, env.host, () => {
  console.log('==============================================');
  console.log(`✅ AdaNando API berjalan di http://127.0.0.1:${env.port}  (${env.nodeEnv})`);
  console.log(`   Panel guru/admin : http://127.0.0.1:${env.port}/admin`);
  console.log(`   Health check     : http://127.0.0.1:${env.port}/api/v1/health`);
  console.log('==============================================');
  testConnection().then((ok) => { if (ok) checkSchema(); });
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') console.error(`❌ Port ${env.port} sudah dipakai proses lain. Ganti PORT di .env.`);
  else if (err.code === 'EACCES') console.error(`❌ Tidak punya izin memakai port ${env.port}.`);
  else console.error('❌ Server error:', err);
  process.exit(1);
});

const shutdown = (sig) => {
  console.log(`\n${sig}: menutup server...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (r) => console.error('⚠️ Unhandled Rejection:', r));
process.on('uncaughtException', (e) => console.error('⚠️ Uncaught Exception:', e));