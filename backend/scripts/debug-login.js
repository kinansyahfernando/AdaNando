require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('../src/config/database');

(async () => {
  try {
    console.log('DB_NAME    :', process.env.DB_NAME);
    console.log('JWT_SECRET :', process.env.JWT_SECRET ? 'ada' : 'KOSONG');

    const [[db]] = await pool.query('SELECT DATABASE() AS nama');
    console.log('Database aktif:', db.nama);

    // Buat / reset akun admin
    const hash = await bcrypt.hash('admin123', 10);
    await pool.query(
      `INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, 'admin')
       ON DUPLICATE KEY UPDATE password = VALUES(password), role = 'admin'`,
      ['Admin AdaNando', 'admin@adanando.com', hash]
    );

    const [rows] = await pool.query('SELECT id, email, role, password FROM users');
    console.log('\nIsi tabel users:');
    for (const u of rows) {
      console.log(`- [${u.id}] ${u.email} | ${u.role} | cocok admin123 = ${await bcrypt.compare('admin123', u.password)}`);
    }

    // Tes ke server yang sedang berjalan
    const res = await fetch('http://127.0.0.1:3000/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@adanando.com', password: 'admin123' }),
    });
    console.log('\nTes login ke server -> status', res.status);
    console.log((await res.text()).slice(0, 200));
  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    await pool.end();
  }
})();
