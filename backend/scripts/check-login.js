require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('../src/config/database');

const TEST_EMAIL = 'admin@adanando.com';
const TEST_PASSWORD = 'admin123';

(async () => {
  try {
    console.log('Database :', process.env.DB_NAME || '(default db_utbk)');
    console.log('Host:port:', process.env.DB_HOST || '127.0.0.1', process.env.DB_PORT || 3306);

    const [rows] = await pool.query('SELECT id, name, email, role, password FROM users');
    console.log(`\nJumlah user di tabel users: ${rows.length}\n`);

    for (const u of rows) {
      const isHash = /^\$2[aby]\$/.test(u.password);
      const cocok = isHash ? await bcrypt.compare(TEST_PASSWORD, u.password) : false;
      console.log(`- [${u.id}] ${u.email} | role=${u.role} | bcrypt=${isHash ? 'ya' : 'TIDAK (teks biasa)'} | cocok "${TEST_PASSWORD}"=${cocok}`);
    }

    if (!rows.some((u) => u.email === TEST_EMAIL)) {
      console.log(`\n⚠️ Email ${TEST_EMAIL} TIDAK ADA. Jalankan: node scripts/seed-users.js`);
    }
  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    await pool.end();
  }
})();
