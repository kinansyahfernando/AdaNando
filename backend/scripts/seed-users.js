// backend/scripts/seed-users.js
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('../src/config/database');

const users = [
  { name: 'Admin AdaNando', email: 'admin@adanando.com', password: 'admin123', role: 'admin' },
  { name: 'Siswa Contoh',   email: 'siswa@adanando.com', password: 'siswa123', role: 'siswa' },
];

(async () => {
  try {
    for (const u of users) {
      const hash = await bcrypt.hash(u.password, 10);
      await pool.query(
        `INSERT INTO users (name, email, password, role)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE name = VALUES(name), password = VALUES(password), role = VALUES(role)`,
        [u.name, u.email, hash, u.role]
      );
      console.log(`✅ ${u.role}: ${u.email} / ${u.password}`);
    }
  } catch (err) {
    console.error('❌ Seed gagal:', err.message);
  } finally {
    await pool.end();
  }
})();