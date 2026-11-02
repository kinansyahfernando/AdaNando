// src/config/database.js
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1', // 127.0.0.1, bukan 'localhost' (hindari masalah IPv6)
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'db_utbk',
  waitForConnections: true,
  connectionLimit: Number(process.env.DB_POOL) || 20,
  connectTimeout: 5000,
  charset: 'utf8mb4',
  // BIGINT (waktu epoch ms) dikembalikan sebagai angka, bukan string
  supportBigNumbers: true,
  bigNumberStrings: false,
});

async function testConnection() {
  try {
    const conn = await pool.getConnection();
    console.log('✅ MySQL terhubung');
    conn.release();
    return true;
  } catch (err) {
    console.error('❌ Gagal konek MySQL:', err.message);
    console.error('   Pastikan MySQL menyala dan DB_* di file .env benar.');
    return false;
  }
}

const RETRYABLE = new Set(['ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT']);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Jalankan fn(conn) di dalam satu transaksi. Commit bila sukses, rollback bila error.
 * Bila terjadi deadlock (wajar saat ratusan siswa menekan "Mulai" bersamaan) transaksi
 * diulang otomatis, sehingga siswa tidak melihat error. fn harus aman diulang.
 */
async function withTransaction(fn) {
  for (let attempt = 1; ; attempt++) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const result = await fn(conn);
      await conn.commit();
      return result;
    } catch (err) {
      try { await conn.rollback(); } catch (_) { /* abaikan */ }
      if (RETRYABLE.has(err.code) && attempt < 5) {
        conn.release();
        await sleep(20 * attempt + Math.floor(Math.random() * 60));
        continue;
      }
      throw err;
    } finally {
      try { conn.release(); } catch (_) { /* sudah dilepas */ }
    }
  }
}

module.exports = { pool, testConnection, withTransaction };
