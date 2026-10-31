// src/config/database.js
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1', // pakai 127.0.0.1, bukan 'localhost' (hindari masalah IPv6)
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',  // Laragon default: kosong
  database: process.env.DB_NAME || 'db_utbk',
  waitForConnections: true,
  connectionLimit: 10,
  connectTimeout: 5000, // gagal cepat, jangan menggantung
});

async function testConnection() {
  try {
    const conn = await pool.getConnection();
    console.log('✅ MySQL terhubung');
    conn.release();
  } catch (err) {
    console.error('❌ Gagal konek MySQL:', err.message);
    console.error('   Pastikan MySQL di Laragon sudah Start dan nama database benar.');
  }
}

module.exports = { pool, testConnection };