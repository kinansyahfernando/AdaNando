// Uji integrasi end-to-end. Jalankan:  npm run migrate:demo && npm test
// (memakai database yang diisi di .env; JANGAN dijalankan di database produksi karena membuat data uji)
require('dotenv').config();
const assert = require('assert');
const http = require('http');
process.env.SINGLE_SESSION = 'true';
const app = require('../src/app');
const { pool } = require('../src/config/database');

let base = '';
let passed = 0;
const ok = (name) => { passed++; console.log('  ✓', name); };

async function call(method, path, { token, body } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) { /* csv dsb */ }
  return { status: res.status, json, text };
}
const login = async (id, password) => (await call('POST', '/api/v1/auth/login', { body: { identifier: id, password } }));

(async () => {
  const server = http.createServer(app).listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
  const stamp = Date.now();
  try {
    console.log('AUTH');
    let r = await login('guru@adanando.com', 'salah');
    assert.equal(r.status, 401); ok('password salah ditolak');
    const guru = (await login('guru@adanando.com', 'Guru12345')).json;
    assert.ok(guru.token); ok('login guru');
    const adm = await call('POST', '/api/v1/admin/users', { token: guru.token, body: { name: 'x', nis: 'zz' } });
    assert.equal(adm.status, 403); ok('guru tidak bisa membuat akun (admin only)');

    // akun admin untuk tes (buat langsung di DB)
    const bcrypt = require('bcryptjs');
    await pool.query("INSERT INTO users (name,email,password,role,created_ms) VALUES ('Admin Tes','admintes@x.id',?, 'admin', ?) ON DUPLICATE KEY UPDATE password=VALUES(password), must_change_password=0, is_active=1, locked_until=NULL, failed_logins=0",
      [await bcrypt.hash('Admin12345', 10), Date.now()]);
    const admin = (await login('admintes@x.id', 'Admin12345')).json;
    assert.ok(admin.token); ok('login admin');

    console.log('SISWA & KELAS');
    const cls = (await call('POST', '/api/v1/admin/classes', { token: admin.token, body: { name: 'TES-' + stamp } })).json;
    const other = (await call('POST', '/api/v1/admin/classes', { token: admin.token, body: { name: 'LAIN-' + stamp } })).json;
    const imp = (await call('POST', '/api/v1/admin/users/import', { token: admin.token, body: { rows: [
      { nama: 'Budi Tes', nis: 'T' + stamp + '1', kelas: 'TES-' + stamp },
      { nama: 'Sari Tes', nis: 'T' + stamp + '2', kelas: 'TES-' + stamp },
      { nama: 'Orang Lain', nis: 'T' + stamp + '3', kelas: 'LAIN-' + stamp },
      { nama: '', nis: 'bad' },
    ] } })).json;
    assert.equal(imp.created.length, 3); assert.equal(imp.errors.length, 1); ok('impor CSV: 3 sukses, 1 gagal tercatat');
    const [budi, sari, lain] = imp.created;

    r = await login(budi.nis, budi.password);
    assert.equal(r.status, 200); assert.equal(r.json.user.mustChangePassword, true); ok('login siswa pakai NIS');
    let tokB = r.json.token;
    r = await call('GET', '/api/v1/exams', { token: tokB });
    assert.equal(r.status, 403); assert.equal(r.json.code, 'MUST_CHANGE_PASSWORD'); ok('wajib ganti password dulu');
    r = await call('POST', '/api/v1/auth/change-password', { token: tokB, body: { oldPassword: budi.password, newPassword: 'abc' } });
    assert.equal(r.status, 400); ok('kebijakan password ditegakkan');
    r = await call('POST', '/api/v1/auth/change-password', { token: tokB, body: { oldPassword: budi.password, newPassword: 'Rahasia123' } });
    assert.equal(r.status, 200); tokB = r.json.token; ok('ganti password berhasil');

    // sesi tunggal
    const second = (await login(budi.nis, 'Rahasia123')).json;
    r = await call('GET', '/api/v1/exams', { token: tokB });
    assert.equal(r.status, 401); assert.equal(r.json.code, 'SESSION_REPLACED'); ok('login di perangkat lain mengeluarkan sesi lama');
    tokB = second.token;

    // kunci akun
    for (let i = 0; i < 5; i++) await login(lain.nis, 'salahsalah1');
    r = await login(lain.nis, lain.password);
    assert.equal(r.status, 423); ok('akun terkunci setelah 5 kali salah');

    // Sari
    let tokS = (await login(sari.nis, sari.password)).json.token;
    tokS = (await call('POST', '/api/v1/auth/change-password', { token: tokS, body: { oldPassword: sari.password, newPassword: 'Sari12345' } })).json.token;

    console.log('BANK SOAL');
    const subs = (await call('GET', '/api/v1/admin/questions?limit=500', { token: admin.token })).json;
    assert.ok(subs.total >= 21); ok('bank soal terbaca (' + subs.total + ')');
    const rawQ = (await call('GET', '/api/v1/admin/questions?subtestId=pu', { token: admin.token })).json.items;
    r = await call('POST', '/api/v1/admin/questions', { token: admin.token, body: { subtestId: 'pu', text: 'x', options: ['a', 'a'], correctIndex: 0 } });
    assert.equal(r.status, 400); ok('opsi kembar ditolak');
    // soal khusus ujian
    const ids = [];
    for (let i = 0; i < 4; i++) {
      r = await call('POST', '/api/v1/admin/questions', { token: admin.token, body: {
        subtestId: 'pu', text: `Soal uji ${stamp} nomor ${i}`, options: ['A' + i, 'B' + i, 'C' + i, 'D' + i], correctIndex: i % 4, usage: 'ujian', explanation: 'pembahasan ' + i } });
      assert.equal(r.status, 201); ids.push(r.json.id);
    }
    r = await call('POST', '/api/v1/admin/questions', { token: admin.token, body: { subtestId: 'pu', text: 'soal latihan saja ' + stamp, options: ['p', 'q'], correctIndex: 0, usage: 'latihan' } });
    const latihanId = r.json.id;
    ok('soal ujian & latihan dibuat');

    console.log('UJIAN SEKOLAH');
    r = await call('POST', '/api/v1/admin/exams', { token: admin.token, body: { title: 'x', sections: [{ subtestId: 'pu', minutes: 10, questionIds: [latihanId] }] } });
    assert.equal(r.status, 400); ok('soal "latihan saja" tidak boleh masuk ujian (cegah kebocoran kunci)');

    r = await call('POST', '/api/v1/admin/exams', { token: admin.token, body: {
      title: 'Ulangan Tes ' + stamp, classIds: [cls.id], maxViolations: 2, maxAttempts: 1, resultMode: 'score',
      sections: [{ subtestId: 'pu', minutes: 10, questionIds: ids }] } });
    assert.equal(r.status, 201); const examId = r.json.id; ok('ujian dibuat (draft)');
    let exam = (await call('GET', '/api/v1/admin/exams/' + examId, { token: admin.token })).json;
    const examToken = exam.accessToken; assert.ok(examToken && examToken.length === 6); ok('token ujian dibuat otomatis');

    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokB, body: { token: examToken } });
    assert.equal(r.status, 409); ok('ujian draft tidak bisa dimulai');
    await call('POST', `/api/v1/admin/exams/${examId}/status`, { token: admin.token, body: { status: 'published' } });

    r = await call('GET', '/api/v1/exams', { token: tokB });
    assert.ok(r.json.items.some((e) => e.id === examId)); ok('ujian muncul di daftar siswa kelas target');
    // siswa kelas lain
    const lainId = (await pool.query('SELECT id FROM users WHERE nis=?', [lain.nis]))[0][0].id;
    await call('POST', `/api/v1/admin/users/${lainId}/unlock`, { token: admin.token });
    let tokL = (await login(lain.nis, lain.password)).json.token;
    tokL = (await call('POST', '/api/v1/auth/change-password', { token: tokL, body: { oldPassword: lain.password, newPassword: 'Lain12345' } })).json.token;
    r = await call('GET', '/api/v1/exams', { token: tokL });
    assert.ok(!r.json.items.some((e) => e.id === examId)); ok('siswa kelas lain tidak melihat ujian');
    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokL, body: { token: examToken } });
    assert.equal(r.status, 403); ok('siswa kelas lain tidak bisa memulai');

    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokB, body: { token: 'SALAH1' } });
    assert.equal(r.status, 403); ok('token salah ditolak');
    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokB, body: { token: examToken.toLowerCase() } });
    assert.equal(r.status, 200); const attId = r.json.attempt.id;
    assert.equal(r.json.result, null); ok('ujian dimulai, hasil belum terlihat');

    r = await call('GET', `/api/v1/attempts/${attId}/section`, { token: tokB });
    assert.equal(r.status, 200);
    const sec = r.json;
    assert.equal(sec.questions.length, 4);
    const raw = JSON.stringify(sec);
    assert.ok(!/correct/i.test(raw) && !/explanation|pembahasan/i.test(raw)); ok('soal dikirim TANPA kunci & pembahasan');

    r = await call('GET', `/api/v1/attempts/${attId}/review`, { token: tokB });
    assert.equal(r.status, 403); ok('pembahasan terkunci selama ujian');
    r = await call('GET', `/api/v1/attempts/${attId}`, { token: tokS });
    assert.equal(r.status, 403); ok('siswa lain tidak bisa membuka percobaan orang lain');
    r = await call('GET', `/api/v1/attempts/${attId}/section`, { token: tokS });
    assert.equal(r.status, 403); ok('siswa lain tidak bisa mengambil soal orang lain');

    // Jawab: 3 benar (soal 0-2), 1 salah (soal 3). Kunci dicari lewat teks soal.
    const keyByText = new Map();
    for (let i = 0; i < 4; i++) keyByText.set(`Soal uji ${stamp} nomor ${i}`, `${'ABCD'[i % 4]}${i}`);
    const answers = {};
    sec.questions.forEach((q, pos) => {
      const i = Number(q.text.split('nomor ')[1]);
      const rightText = keyByText.get(q.text);
      const rightIdx = q.options.indexOf(rightText);
      answers[pos] = i === 3 ? (rightIdx + 1) % 4 : rightIdx;
    });
    r = await call('PUT', `/api/v1/attempts/${attId}/answers`, { token: tokB, body: { sectionIndex: 0, answers } });
    assert.equal(r.status, 200); assert.equal(r.json.saved, 4); ok('autosave jawaban');
    r = await call('GET', `/api/v1/attempts/${attId}/section`, { token: tokB });
    assert.deepEqual(r.json.answers, answers); ok('jawaban tersimpan di server & bisa dilanjutkan (urutan acak konsisten)');
    assert.deepEqual(r.json.questions.map((q) => q.text), sec.questions.map((q) => q.text)); ok('urutan soal tetap sama setelah dimuat ulang');

    // dua siswa mendapat urutan berbeda (acak per siswa)
    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokS, body: { token: examToken } });
    assert.equal(r.status, 200);
    const secS = (await call('GET', `/api/v1/attempts/${r.json.attempt.id}/section`, { token: tokS })).json;
    const sameOrder = JSON.stringify(secS.questions) === JSON.stringify(sec.questions);
    console.log('    (urutan sama antar siswa? ' + sameOrder + ' - kemungkinan kecil, acak)');

    // Pelanggaran: batas 2
    r = await call('POST', `/api/v1/attempts/${attId}/violation`, { token: tokB, body: { type: 'tab_hidden', sectionIndex: 0, answers } });
    assert.equal(r.json.ended, false); assert.equal(r.json.attempt.violations, 1); ok('pelanggaran #1 dicatat (peringatan)');
    r = await call('POST', `/api/v1/attempts/${attId}/violation`, { token: tokB, body: { type: 'window_blur' } });
    assert.equal(r.json.attempt.violations, 1); ok('event kembar dalam 2,5 detik tidak dihitung dua kali');
    await new Promise((res) => setTimeout(res, 2600));
    r = await call('POST', `/api/v1/attempts/${attId}/violation`, { token: tokB, body: { type: 'copy' } });
    assert.equal(r.json.attempt.violations, 1); ok('copy hanya dicatat, tidak menambah hitungan');
    r = await call('POST', `/api/v1/attempts/${attId}/violation`, { token: tokB, body: { type: 'fullscreen_exit', sectionIndex: 0, answers } });
    assert.equal(r.json.ended, true); assert.equal(r.json.attempt.endReason, 'violation'); ok('pelanggaran #2 = ujian diakhiri server');
    assert.equal(r.json.result.correct, 3); assert.equal(r.json.result.wrong, 1); assert.equal(r.json.result.points, 11); ok('nilai dihitung server: 3 benar, 1 salah, 11 poin');

    r = await call('PUT', `/api/v1/attempts/${attId}/answers`, { token: tokB, body: { sectionIndex: 0, answers: { 0: 0 } } });
    assert.equal(r.status, 409); ok('tidak bisa mengubah jawaban setelah selesai');
    r = await call('GET', `/api/v1/attempts/${attId}/review`, { token: tokB });
    assert.equal(r.status, 403); assert.equal(r.json.code, 'REVIEW_LOCKED'); ok('pembahasan (mode "score") terkunci sampai ujian ditutup');

    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokB, body: { token: examToken } });
    assert.equal(r.status, 409); ok('percobaan kedua ditolak (maxAttempts=1)');

    console.log('PEMANTAUAN & HASIL');
    r = await call('GET', `/api/v1/admin/exams/${examId}/monitor`, { token: guru.token });
    assert.equal(r.json.summary.running, 1); assert.equal(r.json.summary.finished, 1); assert.equal(r.json.summary.withViolations, 1); ok('monitor: 1 mengerjakan, 1 selesai, 1 melanggar');
    r = await call('POST', `/api/v1/admin/exams/${examId}/attempts/${secS.sectionIndex === 0 ? (await pool.query('SELECT id FROM exam_attempts WHERE exam_id=? AND user_id=(SELECT id FROM users WHERE nis=?)', [examId, sari.nis]))[0][0].id : 0}/extend`, { token: guru.token, body: { minutes: 5 } });
    assert.equal(r.status, 200); ok('guru menambah waktu siswa');
    // Sari kumpulkan semua benar
    const sariAtt = (await pool.query('SELECT id FROM exam_attempts WHERE exam_id=? AND user_id=(SELECT id FROM users WHERE nis=?)', [examId, sari.nis]))[0][0].id;
    const ansS = {};
    secS.questions.forEach((q, pos) => { ansS[pos] = q.options.indexOf(keyByText.get(q.text)); });
    r = await call('POST', `/api/v1/attempts/${sariAtt}/submit-section`, { token: tokS, body: { sectionIndex: 0, answers: ansS } });
    assert.equal(r.json.attempt.status, 'finished'); assert.equal(r.json.result.correct, 4); assert.equal(r.json.result.score, 100); ok('siswa mengumpulkan: 4/4 benar, nilai 100');
    r = await call('POST', `/api/v1/attempts/${sariAtt}/submit-section`, { token: tokS, body: { sectionIndex: 0, answers: { 0: 0 } } });
    assert.equal(r.json.result.correct, 4); ok('kirim ulang tidak mengubah nilai (idempoten)');
    const [[cnt]] = await pool.query('SELECT COUNT(*) n FROM attempt_sections WHERE attempt_id=?', [sariAtt]); assert.equal(cnt.n, 1); ok('nilai subtes hanya tersimpan sekali');

    r = await call('GET', `/api/v1/admin/exams/${examId}/results`, { token: guru.token });
    assert.equal(r.json.items[0].name, 'Sari Tes'); assert.equal(r.json.items[0].rank, 1); assert.equal(r.json.stats.finished, 2); ok('peringkat hasil benar');
    r = await call('GET', `/api/v1/admin/exams/${examId}/results.csv`, { token: guru.token });
    const bytes = new Uint8Array(await (await fetch(base + `/api/v1/admin/exams/${examId}/results.csv`, { headers: { Authorization: 'Bearer ' + guru.token } })).arrayBuffer());
    assert.deepEqual([...bytes.slice(0, 3)], [0xEF, 0xBB, 0xBF]); assert.ok(r.text.includes('Sari Tes')); ok('ekspor CSV (UTF-8 BOM, aman Excel)');
    r = await call('GET', `/api/v1/admin/exams/${examId}/analysis`, { token: guru.token });
    assert.ok(r.json.items.length === 4); ok('analisis butir soal');

    r = await call('POST', `/api/v1/admin/exams/${examId}/status`, { token: admin.token, body: { status: 'closed' } });
    r = await call('GET', `/api/v1/attempts/${attId}/review`, { token: tokB });
    assert.equal(r.status, 200); assert.equal(r.json.sections[0].items.length, 4);
    assert.ok(r.json.sections[0].items.every((i) => i.explanation.startsWith('pembahasan'))); ok('setelah ujian ditutup, pembahasan terbuka');
    const wrongOne = r.json.sections[0].items.filter((i) => i.chosen !== i.correct);
    assert.equal(wrongOne.length, 1); ok('kunci pembahasan konsisten dengan acakan opsi siswa');

    r = await call('POST', `/api/v1/admin/exams/${examId}/attempts/${attId}/reset`, { token: guru.token });
    r = await call('POST', `/api/v1/exams/${examId}/start`, { token: tokB, body: { token: examToken } });
    assert.equal(r.status, 409); ok('ujian ditutup: tidak bisa dimulai lagi');
    r = await call('DELETE', `/api/v1/admin/exams/${examId}`, { token: admin.token });
    assert.equal(r.status, 409); ok('ujian yang sudah dikerjakan tidak bisa dihapus');

    console.log('WAKTU HABIS (dikerjakan di server)');
    r = await call('POST', '/api/v1/admin/exams', { token: admin.token, body: { title: 'Cepat ' + stamp, maxAttempts: 0, useToken: false,
      sections: [{ subtestId: 'pu', minutes: 1, questionIds: ids }, { subtestId: 'pu', minutes: 1, questionIds: ids }] } });
    const ex2 = r.json.id;
    await call('POST', `/api/v1/admin/exams/${ex2}/status`, { token: admin.token, body: { status: 'published' } });
    r = await call('POST', `/api/v1/exams/${ex2}/start`, { token: tokB, body: {} });
    assert.equal(r.status, 200); const att2 = r.json.attempt.id;
    const s2 = (await call('GET', `/api/v1/attempts/${att2}/section`, { token: tokB })).json;
    const a2 = {}; s2.questions.forEach((q, pos) => { a2[pos] = q.options.indexOf(keyByText.get(q.text)); });
    await call('PUT', `/api/v1/attempts/${att2}/answers`, { token: tokB, body: { sectionIndex: 0, answers: a2 } });
    // Geser waktu mulai ke belakang 3 menit (simulasi HP mati / klien offline)
    await pool.query('UPDATE exam_attempts SET section_started_at = section_started_at - 180000 WHERE id = ?', [att2]);
    r = await call('GET', `/api/v1/attempts/${att2}`, { token: tokB });
    assert.equal(r.json.attempt.status, 'finished'); assert.equal(r.json.attempt.endReason, 'timeout');
    assert.equal(r.json.result.sections[0].correct, 4); assert.equal(r.json.result.sections[1].correct, 0); ok('waktu habis: subtes terjawab dinilai otomatis, subtes berikutnya kosong');

    console.log('LATIHAN & ROOM');
    r = await call('GET', '/api/v1/practice/questions?subtestId=pu&count=50', { token: tokB });
    assert.ok(r.json.items.length > 0); assert.ok(!/correct|explanation/i.test(JSON.stringify(r.json.items))); ok('soal latihan tanpa kunci');
    assert.ok(!r.json.items.some((q) => ids.includes(q.id))); ok('soal khusus ujian TIDAK muncul di latihan');
    r = await call('POST', '/api/v1/practice/check', { token: tokB, body: { questionId: ids[0], chosenIndex: 0 } });
    assert.equal(r.status, 404); ok('kunci soal ujian tidak bisa diambil lewat endpoint latihan');
    r = await call('POST', '/api/v1/practice/check', { token: tokB, body: { questionId: latihanId, chosenIndex: 0 } });
    assert.equal(r.json.correct, true); ok('periksa jawaban latihan oleh server');
    r = await call('POST', '/api/v1/practice/finish', { token: tokB, body: { answers: [{ questionId: latihanId, chosenIndex: 1 }, { questionId: ids[0], chosenIndex: 0 }] } });
    assert.equal(r.json.total, 1); assert.equal(r.json.wrong, 1); ok('hasil latihan dinilai server (soal ujian diabaikan)');
    r = await call('GET', '/api/v1/results/history', { token: tokB });
    assert.ok(r.json.items.length >= 2); ok('riwayat Potensi terisi');

    r = await call('POST', '/api/v1/rooms', { token: tokB, body: { subtestId: 'pu', count: 3, durationSeconds: 120 } });
    assert.equal(r.status, 200); const code = r.json.room.code;
    await call('POST', '/api/v1/rooms/join', { token: tokS, body: { code } });
    r = await call('GET', `/api/v1/rooms/${code}/questions`, { token: tokB });
    assert.equal(r.status, 409); ok('soal room tidak bisa diambil sebelum dimulai');
    await call('POST', `/api/v1/rooms/${code}/start`, { token: tokB });
    const rq = (await call('GET', `/api/v1/rooms/${code}/questions`, { token: tokB })).json.items;
    assert.ok(rq.length > 0 && !/correct/i.test(JSON.stringify(rq))); ok('soal room tanpa kunci');
    r = await call('POST', `/api/v1/rooms/${code}/submit`, { token: tokB, body: { answers: Object.fromEntries(rq.map((q) => [String(q.id), 0])), correct: 999, wrong: 0 } });
    assert.equal(r.status, 200); ok('klaim skor dari klien diabaikan');
    r = await call('GET', `/api/v1/rooms/${code}/review`, { token: tokB });
    assert.equal(r.status, 403); ok('pembahasan room terkunci sebelum semua selesai');
    await call('POST', `/api/v1/rooms/${code}/submit`, { token: tokS, body: { answers: {} } });
    r = await call('GET', `/api/v1/rooms/${code}`, { token: tokB });
    assert.equal(r.json.room.status, 'finished');
    assert.ok(r.json.players.every((p) => p.score <= rq.length * 4)); ok('skor room dihitung server');
    r = await call('GET', `/api/v1/rooms/${code}/review`, { token: tokB });
    assert.equal(r.status, 200); ok('pembahasan room terbuka setelah selesai');

    console.log('KEAMANAN UMUM');
    r = await call('GET', '/api/v1/admin/users', { token: tokB });
    assert.equal(r.status, 403); ok('siswa tidak bisa memanggil API admin');
    r = await call('GET', '/api/v1/admin/questions', { token: tokB });
    assert.equal(r.status, 403); ok('siswa tidak bisa membaca bank soal + kunci');
    r = await call('GET', '/api/v1/admin/users');
    assert.equal(r.status, 401); ok('tanpa token ditolak');
    r = await call('POST', '/api/v1/auth/register', { body: { name: 'a', email: 'a@b.co', password: 'Abcdefg1' } });
    assert.equal(r.status, 403); ok('registrasi mandiri mati secara bawaan');
    r = await call('POST', '/api/v1/auth/login', { body: { identifier: "' OR 1=1 --", password: 'x' } });
    assert.equal(r.status, 401); ok('SQL injection pada login tidak berhasil');
    const hdr = await fetch(base + '/api/v1/health');
    assert.ok(hdr.headers.get('x-content-type-options') === 'nosniff' && !hdr.headers.get('x-powered-by')); ok('header keamanan terpasang');

    console.log(`\n✅ SEMUA ${passed} PENGUJIAN LULUS`);
  } catch (err) {
    console.error('\n❌ GAGAL:', err.message);
    if (err.stack) console.error(err.stack.split('\n').slice(1, 4).join('\n'));
    process.exitCode = 1;
  } finally {
    server.close();
    await pool.end();
  }
})();
