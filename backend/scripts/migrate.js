// backend/scripts/migrate.js
// Membuat / memperbarui seluruh tabel AdaNando v3. AMAN dijalankan berulang kali.
//   npm run migrate            -> skema + data awal (mapel, bank soal contoh, Try Out Mandiri, admin)
//   npm run migrate -- --demo  -> tambah juga akun demo (guru & siswa) untuk uji coba
//
// Catatan: server (npm start / npm run dev) sekarang juga menjalankan langkah yang sama
// otomatis setiap menyala, jadi script ini hanya perlu dipakai bila ingin melihat laporannya.
require('dotenv').config();
const { pool } = require('../src/config/database');
const { migrate } = require('../src/config/schema');

const demo = process.argv.includes('--demo');

(async () => {
  try {
    const result = await migrate({ demo });
    if (result.ok) {
      console.log('✅ Migrasi selesai.');
    } else {
      console.error('\n❌ Migrasi selesai dengan masalah:');
      result.problems.forEach((p) => console.error('   - ' + p));
      process.exitCode = 1;
    }
  } catch (err) {
    console.error('❌ Migrasi gagal:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
