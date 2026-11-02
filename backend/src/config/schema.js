// src/config/schema.js
// Pembuat / pemulih skema database AdaNando. AMAN dijalankan berulang kali.
//
// Dipakai di tiga tempat:
//   1) server.js              -> otomatis setiap server menyala (tabel yang hilang dibuat sendiri)
//   2) scripts/migrate.js     -> manual:  npm run migrate  /  npm run migrate:demo
//   3) practice.routes.js     -> bila ada query gagal karena tabel hilang, diperbaiki lalu diulang
//
// Beda dengan versi lama: bila satu langkah gagal, langkah lain TETAP dilanjutkan dan
// penyebab gagalnya dicetak jelas (nama langkah + pesan MySQL), tidak berhenti diam-diam.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');
const { pool } = require('./database');

const dbName = () => process.env.DB_NAME || 'db_utbk';

// Tabel yang wajib ada agar aplikasi berjalan penuh
const REQUIRED_TABLES = [
  'users', 'classes', 'subtests', 'questions', 'exams', 'exam_classes', 'exam_attempts',
  'attempt_sections', 'violation_logs', 'audit_logs', 'rooms', 'room_players',
  'tryout_attempts', 'practice_results',
];

// Kesempatan keluar layar / pindah tab saat Try Out Mandiri. Ke-2 kalinya ujian otomatis diakhiri.
const TRYOUT_MAX_VIOLATIONS = 2;

const MANDIRI_SECTIONS = [
  { subtestId: 'pu',  name: 'Penalaran Umum',                 questions: 30, seconds: 30 * 60 },
  { subtestId: 'ppu', name: 'Pengetahuan dan Pemahaman Umum', questions: 20, seconds: 15 * 60 },
  { subtestId: 'pbm', name: 'Pemahaman Bacaan dan Menulis',   questions: 20, seconds: 25 * 60 },
  { subtestId: 'pk',  name: 'Pengetahuan Kuantitatif',        questions: 20, seconds: 20 * 60 },
  { subtestId: 'lbi', name: 'Literasi Bahasa Indonesia',      questions: 30, seconds: 2550 },
  { subtestId: 'lbe', name: 'Literasi Bahasa Inggris',        questions: 20, seconds: 20 * 60 },
  { subtestId: 'pm',  name: 'Penalaran Matematika',           questions: 20, seconds: 2550 },
];

const SUBTESTS = [
  ['pu', 'PU', 'Penalaran Umum'], ['ppu', 'PPU', 'Pengetahuan dan Pemahaman Umum'],
  ['pbm', 'PBM', 'Pemahaman Bacaan dan Menulis'], ['pk', 'PK', 'Pengetahuan Kuantitatif'],
  ['lbi', 'LBI', 'Literasi Bahasa Indonesia'], ['lbe', 'LBE', 'Literasi Bahasa Inggris'],
  ['pm', 'PM', 'Penalaran Matematika'],
];

// Tabel dengan nama sama tapi struktur lama / berbeda (mis. sisa percobaan sebelumnya) tidak boleh
// merusak migrasi: ganti namanya menjadi old_<nama>, lalu buat tabel baru yang benar.
const EXPECTED = {
  classes: 'created_at', subtests: 'is_utbk', questions: 'usage_type', exams: 'sections',
  exam_classes: 'class_id', exam_attempts: 'plan', attempt_sections: 'section_idx',
  violation_logs: 'counted', audit_logs: 'actor_id',
};

const randomPassword = () => crypto.randomBytes(9).toString('base64').replace(/[+/=]/g, 'x').slice(0, 12);

// ───────────────────────── Database ─────────────────────────

/** Buat database bila belum ada (penyebab umum "tabel tidak terbentuk"). */
async function ensureDatabase(log = console.log) {
  const name = dbName().replace(/`/g, '');
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    connectTimeout: 5000,
  });
  try {
    await conn.query(`CREATE DATABASE IF NOT EXISTS \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  } finally {
    await conn.end();
  }
  log(`   database "${name}" siap`);
}

const columnInfo = async (table, column) => {
  const [rows] = await pool.query(
    'SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?',
    [dbName(), table, column]
  );
  return rows[0] || null;
};

const indexExists = async (table, name) => {
  const [rows] = await pool.query(
    'SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND INDEX_NAME = ? LIMIT 1',
    [dbName(), table, name]
  );
  return rows.length > 0;
};

const tableExists = async (name) => {
  const [rows] = await pool.query(
    'SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?', [dbName(), name]
  );
  return rows.length > 0;
};

/** Pecah file .sql menjadi perintah. Komentar dibuang DULU, baru dipecah di tanda titik-koma. */
const readStatements = (file) => {
  const sql = fs.readFileSync(path.join(__dirname, '..', '..', 'sql', file), 'utf8');
  return sql
    .replace(/\r/g, '')
    .replace(/^\s*--.*$/gm, '')
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);
};

// ───────────────────────── Migrasi ─────────────────────────

/**
 * Buat / perbarui semua tabel + data awal.
 * @param {{demo?: boolean, quiet?: boolean}} opts
 * @returns {Promise<{ok: boolean, problems: string[]}>}
 */
async function migrate({ demo = false, quiet = false } = {}) {
  const log = quiet ? () => {} : (...a) => console.log(...a);
  const problems = [];

  // Jalankan satu langkah; bila gagal catat penyebabnya lalu lanjut ke langkah berikutnya.
  const step = async (label, fn) => {
    try {
      await fn();
      return true;
    } catch (err) {
      const msg = `${label}: ${err.code ? `[${err.code}] ` : ''}${err.message}`;
      problems.push(msg);
      console.error(`   ❌ ${msg}`);
      return false;
    }
  };

  const addColumn = async (table, column, ddl) => {
    if (await columnInfo(table, column)) return;
    await pool.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${ddl}`);
    log(`   + kolom ${table}.${column}`);
  };

  log('➡️  Menyiapkan database...');
  const dbOk = await step('Membuat database', () => ensureDatabase(log));
  if (!dbOk) {
    console.error('   Periksa: MySQL/MariaDB sudah menyala? DB_HOST, DB_USER, DB_PASSWORD di backend/.env benar?');
    return { ok: false, problems };
  }

  log('➡️  Membuat tabel...');
  await step('Mengecek tabel lama', async () => {
    for (const [table, marker] of Object.entries(EXPECTED)) {
      if (!(await tableExists(table))) continue;
      if (await columnInfo(table, marker)) continue;
      let target = `old_${table}`;
      if (await tableExists(target)) target = `old_${table}_${Date.now()}`;
      await pool.query(`RENAME TABLE \`${table}\` TO \`${target}\``);
      log(`   ~ tabel lama "${table}" punya struktur berbeda, diganti nama menjadi "${target}" (datanya aman)`);
    }
  });

  // Setiap perintah CREATE TABLE dijalankan sendiri-sendiri agar satu kegagalan tidak menggagalkan semuanya
  for (const file of ['rooms.sql', 'tryout.sql', 'schema.sql']) {
    let statements = [];
    if (!(await step(`Membaca sql/${file}`, async () => { statements = readStatements(file); }))) continue;
    for (const stmt of statements) {
      const m = stmt.match(/CREATE TABLE IF NOT EXISTS\s+`?(\w+)`?/i);
      await step(`Membuat tabel ${m ? m[1] : `(${file})`}`, () => pool.query(stmt));
    }
  }

  log('➡️  Menyesuaikan tabel users...');
  await step('Menyesuaikan tabel users', async () => {
    const role = await columnInfo('users', 'role');
    if (role && /^enum/i.test(role.COLUMN_TYPE)) {
      await pool.query("ALTER TABLE users MODIFY role VARCHAR(10) NOT NULL DEFAULT 'siswa'");
      log('   ~ users.role diubah dari ENUM menjadi VARCHAR (agar role "guru" bisa dipakai)');
    }
    await addColumn('users', 'nis', 'VARCHAR(30) NULL');
    await addColumn('users', 'class_id', 'INT NULL');
    await addColumn('users', 'is_active', 'TINYINT(1) NOT NULL DEFAULT 1');
    await addColumn('users', 'must_change_password', 'TINYINT(1) NOT NULL DEFAULT 0');
    await addColumn('users', 'failed_logins', 'INT NOT NULL DEFAULT 0');
    await addColumn('users', 'locked_until', 'BIGINT NULL');
    await addColumn('users', 'session_id', 'VARCHAR(64) NULL');
    await addColumn('users', 'last_login_at', 'BIGINT NULL');
    await addColumn('users', 'created_ms', 'BIGINT NULL');
    if (!(await indexExists('users', 'uq_users_nis'))) {
      await pool.query('ALTER TABLE users ADD UNIQUE KEY uq_users_nis (nis)');
    }
    if (!(await indexExists('users', 'idx_users_class'))) {
      await pool.query('ALTER TABLE users ADD KEY idx_users_class (class_id)');
    }
  });

  log('➡️  Mengisi data awal...');
  await step('Mengisi daftar subtes', async () => {
    for (const [id, code, name] of SUBTESTS) {
      await pool.query(
        'INSERT INTO subtests (id, code, name, is_utbk) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE code = VALUES(code), name = VALUES(name), is_utbk = 1',
        [id, code, name]
      );
    }
  });

  // INSERT IGNORE per kode soal: soal contoh yang belum ada ditambahkan, yang sudah ada dibiarkan.
  // Jadi bank soal yang terisi sebagian (migrasi lama gagal di tengah jalan) ikut dilengkapi.
  await step('Mengisi bank soal contoh', async () => {
    const bank = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'sample-questions.json'), 'utf8'));
    let added = 0;
    for (const q of bank) {
      const [r] = await pool.query(
        `INSERT IGNORE INTO questions (code, subtest_id, passage, text, options, correct_index, explanation, usage_type, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'semua', ?)`,
        [q.code, q.subtestId, q.passage, q.text, JSON.stringify(q.options), q.correctIndex, q.explanation, Date.now()]
      );
      added += r.affectedRows || 0;
    }
    if (added) log(`   + ${added} soal contoh dimasukkan ke bank soal`);
  });

  await step('Membuat Try Out Mandiri', async () => {
    const [mandiri] = await pool.query("SELECT id FROM exams WHERE kind = 'tryout' LIMIT 1");
    if (mandiri.length === 0) {
      await pool.query(
        `INSERT INTO exams (title, description, kind, sections, status, max_attempts, max_violations, result_mode, created_at)
         VALUES (?, ?, 'tryout', ?, 'published', 0, ?, 'full', ?)`,
        ['Try Out Mandiri UTBK', 'Simulasi UTBK: 7 subtes, 160 soal, 195 menit. Bisa diulang kapan saja.',
          JSON.stringify(MANDIRI_SECTIONS), TRYOUT_MAX_VIOLATIONS, Date.now()]
      );
      log('   + Try Out Mandiri UTBK dibuat');
    }
    // Database lama: Try Out Mandiri yang masih 3 kesempatan diturunkan menjadi 2
    const [upd] = await pool.query(
      "UPDATE exams SET max_violations = ? WHERE kind = 'tryout' AND max_violations <> ?",
      [TRYOUT_MAX_VIOLATIONS, TRYOUT_MAX_VIOLATIONS]
    );
    if (upd.affectedRows) log(`   ~ batas pelanggaran Try Out Mandiri diset ${TRYOUT_MAX_VIOLATIONS}x`);
  });

  await step('Membuat akun admin', async () => {
    const [admins] = await pool.query("SELECT id FROM users WHERE role = 'admin' LIMIT 1");
    if (admins.length === 0) {
      const email = process.env.ADMIN_EMAIL || 'admin@adanando.com';
      const password = process.env.ADMIN_PASSWORD || randomPassword();
      await pool.query(
        `INSERT INTO users (name, email, password, role, must_change_password, created_ms)
         VALUES (?, ?, ?, 'admin', 1, ?)
         ON DUPLICATE KEY UPDATE role = 'admin', password = VALUES(password), must_change_password = 1`,
        ['Administrator', email, await bcrypt.hash(password, 10), Date.now()]
      );
      // Password acak harus terlihat sekali oleh pemilik, jadi selalu dicetak (juga saat mode quiet)
      console.log('\n   ╔══════════════════════════════════════════════╗');
      console.log('   ║  AKUN ADMIN DIBUAT (catat, hanya tampil sekali) ║');
      console.log(`   ║  Email   : ${email}`);
      console.log(`   ║  Password: ${password}`);
      console.log('   ╚══════════════════════════════════════════════╝\n');
    }
  });

  await step('Mengecek password bawaan lama', async () => {
    const weak = [['admin@adanando.com', 'admin123'], ['siswa@adanando.com', 'siswa123']];
    for (const [email, pass] of weak) {
      const [rows] = await pool.query('SELECT id, password FROM users WHERE email = ?', [email]);
      if (rows[0] && (await bcrypt.compare(pass, rows[0].password))) {
        await pool.query('UPDATE users SET must_change_password = 1 WHERE id = ?', [rows[0].id]);
        console.log(`⚠️  ${email} masih memakai password bawaan "${pass}". Akun ini WAJIB ganti password saat login berikutnya.`);
      }
    }
  });

  if (demo) {
    await step('Membuat akun demo', async () => {
      await pool.query("INSERT IGNORE INTO classes (name, created_at) VALUES ('XII IPA 1', ?)", [Date.now()]);
      const [[cls]] = await pool.query("SELECT id FROM classes WHERE name = 'XII IPA 1'");
      const accounts = [
        ['Guru Demo', 'guru@adanando.com', 'Guru12345', 'guru', null, null],
        ['Siswa Demo', 'siswa@adanando.com', 'Siswa12345', 'siswa', '1001', cls.id],
      ];
      for (const [name, email, pass, r, nis, classId] of accounts) {
        await pool.query(
          `INSERT INTO users (name, email, password, role, nis, class_id, created_ms) VALUES (?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE password = VALUES(password), role = VALUES(role), class_id = VALUES(class_id),
             must_change_password = 0, failed_logins = 0, locked_until = NULL`,
          [name, email, await bcrypt.hash(pass, 10), r, nis, classId, Date.now()]
        );
        console.log(`   + akun demo ${r}: ${email} / ${pass}`);
      }
    });
  }

  // Pemeriksaan akhir: pastikan semua tabel benar-benar ada dan soal latihan tersedia
  await step('Pemeriksaan akhir', async () => {
    const missing = [];
    for (const t of REQUIRED_TABLES) if (!(await tableExists(t))) missing.push(t);
    if (missing.length) throw new Error(`tabel belum terbentuk: ${missing.join(', ')}`);

    const [[{ n }]] = await pool.query(
      "SELECT COUNT(*) AS n FROM questions WHERE is_active = 1 AND usage_type IN ('latihan','semua')"
    );
    log(`   ✓ ${REQUIRED_TABLES.length} tabel lengkap, ${n} soal tersedia untuk latihan`);
  });

  return { ok: problems.length === 0, problems };
}

// ───────────────────────── Dipakai saat server berjalan ─────────────────────────

let inflight = null;
let lastOk = false;

/**
 * Pastikan skema siap. Pemanggilan serentak berbagi satu proses yang sama.
 * force=true -> jalankan ulang walau sebelumnya sukses (dipakai saat tabel mendadak hilang).
 */
function ensureReady({ force = false } = {}) {
  if (inflight) return inflight;
  if (lastOk && !force) return Promise.resolve({ ok: true, problems: [] });
  inflight = migrate({ quiet: true })
    .then((r) => { lastOk = r.ok; return r; })
    .catch((err) => { lastOk = false; return { ok: false, problems: [err.message] }; })
    .finally(() => { inflight = null; });
  return inflight;
}

// Kode error MySQL yang berarti "tabel / kolom / database belum ada"
const SCHEMA_ERRORS = new Set(['ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR', 'ER_BAD_DB_ERROR']);

/** pool.query yang otomatis memperbaiki skema satu kali bila tabel hilang, lalu mengulang. */
async function queryHealing(sql, args) {
  try {
    return await pool.query(sql, args);
  } catch (err) {
    if (!SCHEMA_ERRORS.has(err.code)) throw err;
    console.warn(`⚠️ ${err.code}: ${err.message} — memperbaiki skema database...`);
    const r = await ensureReady({ force: true });
    if (!r.ok) console.error('❌ Perbaikan skema belum tuntas:', r.problems.join(' | '));
    return pool.query(sql, args);
  }
}

module.exports = { migrate, ensureReady, ensureDatabase, queryHealing, REQUIRED_TABLES };
