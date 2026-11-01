// backend/scripts/create-tryout-tables.js
// Membuat tabel tryout_attempts & practice_results. Aman dijalankan berulang kali.
// Pakai:  node scripts/create-tryout-tables.js
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/database');

(async () => {
  try {
    const sql = fs.readFileSync(path.join(__dirname, '..', 'sql', 'tryout.sql'), 'utf8');
    const statements = sql
      .split(';')
      .map((s) => s.replace(/--.*$/gm, '').trim())
      .filter(Boolean);

    for (const stmt of statements) {
      await pool.query(stmt);
    }
    console.log('✅ Tabel tryout_attempts & practice_results siap dipakai.');
  } catch (err) {
    console.error('❌ Gagal membuat tabel:', err.message);
  } finally {
    await pool.end();
  }
})();
