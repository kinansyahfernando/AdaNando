// server.js
require('dotenv').config();

const app = require('./src/app');
const { testConnection } = require('./src/config/database');

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0'; // IPv4, bisa diakses dari 127.0.0.1 & jaringan lokal

const server = app.listen(PORT, HOST, () => {
  console.log('==============================================');
  console.log(`✅ AdaNando API berjalan di http://127.0.0.1:${PORT}`);
  console.log(`   Health check : http://127.0.0.1:${PORT}/api/v1/health`);
  console.log('==============================================');

  // Cek database SETELAH server hidup, tidak memblokir listen
  testConnection();
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} sudah dipakai proses lain. Ganti PORT di .env atau matikan prosesnya.`);
  } else if (err.code === 'EACCES') {
    console.error(`❌ Tidak punya izin memakai port ${PORT}. Coba port lain (mis. 5000 / 4000).`);
  } else {
    console.error('❌ Server error:', err);
  }
  process.exit(1);
});

// Supaya error tak terduga tidak mematikan server tanpa jejak
process.on('unhandledRejection', (reason) => {
  console.error('⚠️ Unhandled Rejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('⚠️ Uncaught Exception:', err);
});