/* AdaNando · Panel Guru & Admin. Tanpa framework & tanpa inline script (lolos CSP ketat). */
(() => {
'use strict';

// ---------------------------------------------------------------- util DOM
const h = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'style') e.style.cssText = v; // CSSOM: lolos CSP (setAttribute('style') diblokir)
    else if (k === 'value') e.value = v;
    else if (v === true) e.setAttribute(k, '');
    else e.setAttribute(k, v);
  }
  kids.flat(Infinity).forEach((c) => { if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(String(c))); });
  return e;
};
const $app = document.getElementById('app');
const clear = (el) => { while (el.firstChild) el.removeChild(el.firstChild); };

const pad = (n) => String(n).padStart(2, '0');
const fmtDate = (ms) => { if (!ms) return '—'; const d = new Date(ms); return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const toLocalInput = (ms) => { if (!ms) return ''; const d = new Date(ms); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const fromLocalInput = (v) => (v ? new Date(v).getTime() : null);
const fmtDur = (s) => { if (s == null) return '—'; const m = Math.floor(s / 60); return m >= 60 ? `${Math.floor(m / 60)}j ${m % 60}m` : `${m}m ${s % 60}d`; };
const ago = (ms, now) => { if (!ms) return 'belum pernah'; const s = Math.max(0, Math.round((now - ms) / 1000)); return s < 60 ? `${s} dtk lalu` : `${Math.round(s / 60)} mnt lalu`; };

const toast = (msg, bad = false) => {
  const t = h('div', { class: 'toast' + (bad ? ' bad' : '') }, msg);
  document.body.append(t);
  setTimeout(() => t.remove(), bad ? 6000 : 3000);
};

// ---------------------------------------------------------------- API
let token = sessionStorage.getItem('ada_token') || '';
let me = null;
let timers = [];
const stopTimers = () => { timers.forEach(clearInterval); timers = []; };

async function api(method, path, body) {
  const res = await fetch('/api/v1' + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null;
  try { data = await res.json(); } catch (_) { /* kosong */ }
  if (res.status === 401 && token) { logout(true); throw new Error('Sesi berakhir'); }
  if (!res.ok) { const e = new Error((data && data.message) || `Kesalahan ${res.status}`); e.data = data; e.status = res.status; throw e; }
  return data;
}
const guard = (fn) => async (...a) => { try { return await fn(...a); } catch (e) { if (e.message !== 'Sesi berakhir') toast(e.message, true); } };

async function download(path, filename) {
  const res = await fetch('/api/v1' + path, { headers: { Authorization: 'Bearer ' + token } });
  if (!res.ok) throw new Error('Gagal mengunduh');
  saveBlob(await res.blob(), filename);
}
const saveBlob = (blob, filename) => {
  const a = h('a', { href: URL.createObjectURL(blob), download: filename });
  document.body.append(a); a.click(); a.remove();
};
const csvEscape = (v) => { let s = v == null ? '' : String(v); if (typeof v === 'string' && /^[=+\-@]/.test(s)) s = "'" + s; return /[",\n;]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
const downloadCsv = (rows, filename) => saveBlob(new Blob(['\uFEFF' + rows.map((r) => r.map(csvEscape).join(',')).join('\r\n')], { type: 'text/csv;charset=utf-8' }), filename);

function parseCsv(text) {
  text = text.replace(/^\uFEFF/, '');
  const first = text.split(/\r?\n/)[0] || '';
  const delim = (first.match(/;/g) || []).length > (first.match(/,/g) || []).length ? ';' : ',';
  const rows = []; let row = []; let cur = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += c; }
    else if (c === '"') q = true;
    else if (c === delim) { row.push(cur); cur = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cur); rows.push(row); row = []; cur = ''; }
    else cur += c;
  }
  if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
  return rows.filter((r) => r.some((x) => x.trim() !== ''));
}
const csvToObjects = (text) => {
  const rows = parseCsv(text);
  if (rows.length < 2) return [];
  const head = rows[0].map((x) => x.trim().toLowerCase());
  return rows.slice(1).map((r) => Object.fromEntries(head.map((k, i) => [k, (r[i] || '').trim()])));
};
const readFile = (file) => new Promise((ok, no) => { const r = new FileReader(); r.onload = () => ok(r.result); r.onerror = no; r.readAsText(file); });

// ---------------------------------------------------------------- modal
function modal(title, body, { wide = false, buttons = [] } = {}) {
  const bg = h('div', { class: 'modalbg' });
  const close = () => bg.remove();
  const foot = h('div', { class: 'foot' }, ...buttons.map((b) => h('button', {
    class: b.primary ? 'primary' : b.danger ? 'danger' : '',
    onclick: async (ev) => { ev.target.disabled = true; try { const keep = await b.onclick(close); if (keep === false) ev.target.disabled = false; } catch (e) { toast(e.message, true); ev.target.disabled = false; } },
  }, b.label)));
  bg.append(h('div', { class: 'modal' + (wide ? ' wide' : '') }, h('h2', {}, title), body, foot));
  bg.addEventListener('mousedown', (e) => { if (e.target === bg) close(); });
  document.body.append(bg);
  return close;
}
const confirmBox = (msg, onYes, label = 'Ya, lanjutkan') =>
  modal('Konfirmasi', h('p', {}, msg), { buttons: [{ label: 'Batal', onclick: (c) => c() }, { label, danger: true, onclick: async (c) => { await onYes(); c(); } }] });

// ---------------------------------------------------------------- auth screens
function loginView() {
  stopTimers(); clear($app);
  const id = h('input', { placeholder: 'Email', autocomplete: 'username' });
  const pw = h('input', { type: 'password', placeholder: 'Password', autocomplete: 'current-password' });
  const err = h('div', { class: 'err' });
  const go = async () => {
    err.textContent = '';
    try {
      const r = await api('POST', '/auth/login', { identifier: id.value, password: pw.value });
      if (!['admin', 'guru'].includes(r.user.role)) { err.textContent = 'Panel ini hanya untuk guru & admin. Siswa memakai aplikasi AdaNando.'; return; }
      token = r.token; me = r.user; sessionStorage.setItem('ada_token', token);
      boot();
    } catch (e) { err.textContent = e.message; }
  };
  pw.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
  $app.append(h('div', { class: 'login' },
    h('h1', {}, 'AdaNando'), h('p', { class: 'muted' }, 'Panel Guru & Admin'),
    h('div', { class: 'card' }, h('label', {}, 'Email'), id, h('label', {}, 'Password'), pw, err,
      h('button', { class: 'primary mt', style: 'width:100%', onclick: go }, 'Masuk'))));
  id.focus();
}

function changePasswordView() {
  clear($app);
  const o = h('input', { type: 'password' }); const n = h('input', { type: 'password' }); const err = h('div', { class: 'err' });
  $app.append(h('div', { class: 'login' }, h('h1', {}, 'Ganti Password'),
    h('p', { class: 'muted' }, 'Demi keamanan, ganti password bawaanmu dulu. Minimal 8 karakter, memuat huruf dan angka.'),
    h('div', { class: 'card' }, h('label', {}, 'Password lama'), o, h('label', {}, 'Password baru'), n, err,
      h('button', { class: 'primary mt', style: 'width:100%', onclick: async () => {
        try { const r = await api('POST', '/auth/change-password', { oldPassword: o.value, newPassword: n.value }); token = r.token; sessionStorage.setItem('ada_token', token); me.mustChangePassword = false; toast('Password diganti'); boot(); }
        catch (e) { err.textContent = e.message; }
      } }, 'Simpan'))));
}

function logout(silent) {
  if (!silent && token) api('POST', '/auth/logout').catch(() => {});
  token = ''; me = null; sessionStorage.removeItem('ada_token'); loginView();
}

// ---------------------------------------------------------------- kerangka
const NAV = [
  ['dashboard', 'Beranda', ['admin', 'guru']],
  ['monitor', 'Pantau Ujian', ['admin', 'guru']],
  ['exams', 'Ujian', ['admin', 'guru']],
  ['questions', 'Bank Soal', ['admin', 'guru']],
  ['students', 'Siswa', ['admin', 'guru']],
  ['potensi', 'Potensi Siswa', ['admin', 'guru']],
  ['classes', 'Kelas', ['admin']],
  ['subjects', 'Mapel', ['admin', 'guru']],
  ['users', 'Guru & Admin', ['admin']],
  ['audit', 'Log Aktivitas', ['admin']],
];
const VIEWS = {};
let main;

function shell(route) {
  clear($app);
  main = h('div', { class: 'main' });
  $app.append(h('div', { class: 'layout' },
    h('nav', { class: 'side' }, h('div', { class: 'brand' }, 'AdaNando'),
      ...NAV.filter((n) => n[2].includes(me.role)).map(([k, label]) => h('a', { class: k === route.name ? 'on' : '', href: '#/' + k }, label)),
      h('div', { class: 'who' }, h('div', {}, me.name), h('div', {}, me.role), h('a', { href: '#', style: 'padding:6px 0;color:#93c5fd', onclick: (e) => { e.preventDefault(); logout(); } }, 'Keluar'))),
    main));
}

function parseRoute() {
  const parts = (location.hash.replace(/^#\/?/, '') || 'dashboard').split('/');
  return { name: parts[0], arg: parts[1] };
}
async function render() {
  if (!me) return;
  stopTimers();
  const route = parseRoute();
  const view = VIEWS[route.name] || VIEWS.dashboard;
  shell(VIEWS[route.name] ? route : { name: 'dashboard' });
  try { await view(route.arg); } catch (e) { if (e.message !== 'Sesi berakhir') main.append(h('div', { class: 'card err' }, e.message)); }
}
window.addEventListener('hashchange', render);

async function boot() {
  if (!token) return loginView();
  try { me = (await api('GET', '/auth/me')).user; } catch (_) { return loginView(); }
  if (!['admin', 'guru'].includes(me.role)) { toast('Akun ini bukan guru/admin', true); return logout(true); }
  if (me.mustChangePassword) return changePasswordView();
  render();
}

const pageHead = (title, sub, ...actions) => h('div', { class: 'head' }, h('div', { class: 'grow' }, h('h1', {}, title), sub ? h('div', { class: 'muted' }, sub) : null), ...actions);
const table = (heads, rows) => h('div', { class: 'tablewrap' }, h('table', {}, h('thead', {}, h('tr', {}, heads.map((x) => h('th', {}, x)))), h('tbody', {}, rows.length ? rows : h('tr', {}, h('td', { colspan: heads.length, class: 'muted' }, 'Belum ada data.')))));

// ---------------------------------------------------------------- Beranda
VIEWS.dashboard = async () => {
  const d = await api('GET', '/admin/dashboard');
  const stat = (n, l) => h('div', { class: 'stat' }, h('b', {}, n), h('span', {}, l));
  main.append(pageHead('Beranda', `Halo, ${me.name}`),
    h('div', { class: 'grid' }, stat(d.runningNow, 'Sedang ujian sekarang'), stat(d.violationsToday, 'Pelanggaran 24 jam'), stat(d.publishedExams, 'Ujian aktif'), stat(d.students, 'Siswa'), stat(d.classes, 'Kelas'), stat(d.questions, 'Butir soal')),
    h('div', { class: 'card mt' }, h('h2', {}, 'Alur cepat penyelenggaraan ujian'),
      h('ol', {}, h('li', {}, 'Siswa → impor daftar siswa (CSV), cetak kartu login.'), h('li', {}, 'Bank Soal → tambah / impor soal. Tandai soal khusus ujian sebagai "ujian".'),
        h('li', {}, 'Ujian → buat ujian, pilih kelas, jadwal, durasi, lalu terbitkan. Bagikan token ke pengawas.'),
        h('li', {}, 'Pantau Ujian → lihat siapa yang mengerjakan, offline, atau melanggar — secara langsung.'),
        h('li', {}, 'Ujian → Hasil → ekspor CSV ke Excel, lihat analisis butir soal.'))));
};

// ---------------------------------------------------------------- Kelas & Mapel
VIEWS.classes = async () => {
  const { items } = await api('GET', '/admin/classes');
  const edit = (c) => { const n = h('input', { value: c ? c.name : '' });
    modal(c ? 'Ubah Kelas' : 'Kelas Baru', h('div', {}, h('label', {}, 'Nama kelas'), n), { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Simpan', primary: true, onclick: async (x) => { await api(c ? 'PUT' : 'POST', '/admin/classes' + (c ? '/' + c.id : ''), { name: n.value }); x(); render(); } }] }); };
  main.append(pageHead('Kelas', null, h('button', { class: 'primary', onclick: () => edit() }, '+ Kelas')),
    table(['Nama', 'Siswa', ''], items.map((c) => h('tr', {}, h('td', {}, c.name), h('td', {}, c.students), h('td', { class: 'right nowrap' },
      h('button', { class: 'sm', onclick: () => edit(c) }, 'Ubah'), ' ', h('button', { class: 'sm danger', onclick: () => confirmBox(`Hapus kelas ${c.name}?`, async () => { await api('DELETE', '/admin/classes/' + c.id); render(); }) }, 'Hapus'))))));
};

VIEWS.subjects = async () => {
  const { items } = await api('GET', '/admin/subjects');
  const add = () => { const id = h('input', { placeholder: 'mis. mtk-xi' }); const code = h('input', { placeholder: 'MTK' }); const name = h('input', { placeholder: 'Matematika Kelas XI' });
    modal('Mapel Baru', h('div', {}, h('label', {}, 'ID (huruf kecil, tanpa spasi)'), id, h('label', {}, 'Singkatan'), code, h('label', {}, 'Nama'), name),
      { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Simpan', primary: true, onclick: async (x) => { await api('POST', '/admin/subjects', { id: id.value, code: code.value, name: name.value }); x(); render(); } }] }); };
  main.append(pageHead('Mata Pelajaran', 'Subtes UTBK bawaan + mapel sekolah buatanmu sendiri', h('button', { class: 'primary', onclick: add }, '+ Mapel')),
    table(['ID', 'Singkatan', 'Nama', 'Soal', 'Jenis', ''], items.map((s) => h('tr', {}, h('td', {}, s.id), h('td', {}, s.code), h('td', {}, s.name), h('td', {}, s.questions), h('td', {}, h('span', { class: 'tag ' + (s.isUtbk ? 'info' : '') }, s.isUtbk ? 'UTBK' : 'Sekolah')),
      h('td', { class: 'right' }, s.isUtbk ? null : h('button', { class: 'sm danger', onclick: () => confirmBox(`Hapus mapel ${s.name}?`, async () => { await api('DELETE', '/admin/subjects/' + s.id); render(); }) }, 'Hapus'))))));
};

// ---------------------------------------------------------------- Siswa & Pengguna
const credsTable = (created) => table(['Nama', 'NIS', 'Kelas', 'Login (email / NIS)', 'Password sementara'], created.map((c) => h('tr', {}, h('td', {}, c.nama), h('td', {}, c.nis), h('td', {}, c.kelas), h('td', {}, c.nis || c.email), h('td', {}, h('b', {}, c.password)))));

function showCreds(title, created, errors) {
  modal(title, h('div', {}, h('p', { class: 'muted' }, 'Password hanya tampil SEKALI di sini. Unduh / cetak sekarang. Siswa wajib menggantinya saat login pertama.'),
    created.length ? credsTable(created) : null,
    errors && errors.length ? h('div', {}, h('h3', {}, `${errors.length} baris gagal`), h('ul', {}, errors.map((e) => h('li', { class: 'err' }, `Baris ${e.row}: ${e.message}`)))) : null),
    { wide: true, buttons: [{ label: 'Cetak', onclick: () => { window.print(); return false; } },
      { label: 'Unduh CSV', onclick: () => { downloadCsv([['Nama', 'NIS', 'Kelas', 'Login', 'Password sementara'], ...created.map((c) => [c.nama, c.nis, c.kelas, c.nis || c.email, c.password])], 'kartu-login-siswa.csv'); return false; } },
      { label: 'Tutup', primary: true, onclick: (x) => { x(); render(); } }] });
}

VIEWS.students = async () => {
  const classes = (await api('GET', '/admin/classes')).items;
  const state = { q: '', classId: '', page: 1 };
  const box = h('div');
  const load = guard(async () => {
    const qs = new URLSearchParams({ role: 'siswa', page: state.page, limit: 50 });
    if (state.q) qs.set('q', state.q); if (state.classId) qs.set('classId', state.classId);
    const r = await api('GET', '/admin/users?' + qs);
    clear(box);
    box.append(table(['Nama', 'NIS', 'Kelas', 'Status', 'Login terakhir', ''], r.items.map((u) => h('tr', {},
      h('td', {}, u.name), h('td', {}, u.nis || '—'), h('td', {}, u.className || '—'),
      h('td', {}, u.locked ? h('span', { class: 'tag bad' }, 'Terkunci') : u.isActive ? h('span', { class: 'tag ok' }, 'Aktif') : h('span', { class: 'tag' }, 'Nonaktif')),
      h('td', {}, fmtDate(u.lastLoginAt)),
      h('td', { class: 'right nowrap' }, me.role === 'admin' ? [
        h('button', { class: 'sm', onclick: () => userForm(u, 'siswa') }, 'Ubah'), ' ',
        h('button', { class: 'sm', onclick: () => confirmBox(`Reset password ${u.name}?`, async () => { const x = await api('POST', `/admin/users/${u.id}/reset-password`); showCreds('Password Baru', [{ nama: u.name, nis: u.nis || '', kelas: u.className || '', email: u.email, password: x.password }]); }, 'Reset') }, 'Reset PW'), ' ',
        u.locked ? [h('button', { class: 'sm', onclick: guard(async () => { await api('POST', `/admin/users/${u.id}/unlock`); load(); }) }, 'Buka kunci'), ' '] : null,
        h('button', { class: 'sm danger', onclick: () => confirmBox(`Hapus ${u.name}? (akun yang punya riwayat ujian hanya bisa dinonaktifkan)`, async () => { await api('DELETE', '/admin/users/' + u.id); load(); }) }, 'Hapus')] : null)))),
      h('div', { class: 'muted mt' }, `${r.total} siswa · halaman ${r.page}`),
      h('div', { class: 'bar mt' }, h('button', { disabled: state.page <= 1, onclick: () => { state.page--; load(); } }, '‹ Sebelumnya'), h('button', { disabled: r.page * r.limit >= r.total, onclick: () => { state.page++; load(); } }, 'Berikutnya ›')));
  });
  const search = h('input', { placeholder: 'Cari nama / NIS / email', onkeydown: (e) => { if (e.key === 'Enter') { state.q = e.target.value; state.page = 1; load(); } } });
  const cls = h('select', { onchange: (e) => { state.classId = e.target.value; state.page = 1; load(); } }, h('option', { value: '' }, 'Semua kelas'), classes.map((c) => h('option', { value: c.id }, c.name)));
  const importer = () => {
    const file = h('input', { type: 'file', accept: '.csv,text/csv' });
    modal('Impor Siswa dari CSV', h('div', {}, h('p', {}, 'Kolom: ', h('b', {}, 'nama, nis, kelas'), ' (opsional: email). Kelas yang belum ada dibuat otomatis. Bisa disimpan dari Excel sebagai CSV.'),
      h('button', { onclick: () => downloadCsv([['nama', 'nis', 'kelas', 'email'], ['Budi Santoso', '1001', 'XII IPA 1', ''], ['Siti Aminah', '1002', 'XII IPA 1', '']], 'template-siswa.csv') }, 'Unduh template'), h('label', {}, 'Berkas CSV'), file),
      { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Impor', primary: true, onclick: async (x) => {
        if (!file.files[0]) { toast('Pilih berkas dulu', true); return false; }
        const rows = csvToObjects(await readFile(file.files[0]));
        if (!rows.length) { toast('Berkas kosong / tanpa header', true); return false; }
        const r = await api('POST', '/admin/users/import', { rows }); x(); showCreds(`Impor selesai: ${r.created.length} akun dibuat`, r.created, r.errors);
      } }] });
  };
  main.append(pageHead('Siswa', 'Kelola akun siswa', me.role === 'admin' ? [h('button', { onclick: importer }, 'Impor CSV'), h('button', { class: 'primary', onclick: () => userForm(null, 'siswa') }, '+ Siswa')] : null),
    h('div', { class: 'bar' }, search, cls), box);
  load();

  function userForm(u, role) {
    const f = { name: h('input', { value: u ? u.name : '' }), nis: h('input', { value: u && u.nis ? u.nis : '' }), email: h('input', { value: u && !/@siswa\.local$/.test(u.email) ? u.email : '' }),
      cls: h('select', {}, h('option', { value: '' }, '— tanpa kelas —'), classes.map((c) => h('option', { value: c.id, selected: u && u.classId === c.id }, c.name))),
      act: h('input', { type: 'checkbox', checked: u ? u.isActive : true }) };
    modal(u ? 'Ubah Siswa' : 'Siswa Baru', h('div', {}, h('label', {}, 'Nama'), f.name, h('div', { class: 'row' }, h('div', {}, h('label', {}, 'NIS'), f.nis), h('div', {}, h('label', {}, 'Email (opsional bila ada NIS)'), f.email)), h('label', {}, 'Kelas'), f.cls,
      u ? h('label', { class: 'inline' }, f.act, 'Akun aktif') : null),
      { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Simpan', primary: true, onclick: async (x) => {
        const body = { name: f.name.value, nis: f.nis.value, email: f.email.value, classId: f.cls.value || null, role };
        if (u) { body.isActive = f.act.checked; await api('PUT', '/admin/users/' + u.id, body); x(); load(); }
        else { const r = await api('POST', '/admin/users', body); x(); showCreds('Akun Dibuat', [{ nama: body.name, nis: body.nis, kelas: '', email: r.email, password: r.password }]); }
      } }] });
  }
};

VIEWS.users = async () => {
  const [a, g] = await Promise.all([api('GET', '/admin/users?role=admin&limit=200'), api('GET', '/admin/users?role=guru&limit=200')]);
  const form = (u) => {
    const name = h('input', { value: u ? u.name : '' }); const email = h('input', { value: u ? u.email : '' });
    const role = h('select', {}, ['guru', 'admin'].map((r) => h('option', { value: r, selected: u && u.role === r }, r)));
    const act = h('input', { type: 'checkbox', checked: u ? u.isActive : true });
    modal(u ? 'Ubah Akun' : 'Guru / Admin Baru', h('div', {}, h('label', {}, 'Nama'), name, h('label', {}, 'Email'), email, h('label', {}, 'Role'), role, u ? h('label', { class: 'inline' }, act, 'Akun aktif') : null),
      { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Simpan', primary: true, onclick: async (x) => {
        const body = { name: name.value, email: email.value, role: role.value };
        if (u) { body.isActive = act.checked; await api('PUT', '/admin/users/' + u.id, body); x(); render(); }
        else { const r = await api('POST', '/admin/users', body); x(); showCreds('Akun Dibuat', [{ nama: body.name, nis: '', kelas: '', email: r.email, password: r.password }]); }
      } }] });
  };
  main.append(pageHead('Guru & Admin', null, h('button', { class: 'primary', onclick: () => form() }, '+ Akun')),
    table(['Nama', 'Email', 'Role', 'Status', ''], [...a.items, ...g.items].map((u) => h('tr', {}, h('td', {}, u.name), h('td', {}, u.email), h('td', {}, h('span', { class: 'tag info' }, u.role)),
      h('td', {}, u.isActive ? h('span', { class: 'tag ok' }, 'Aktif') : h('span', { class: 'tag' }, 'Nonaktif')),
      h('td', { class: 'right nowrap' }, h('button', { class: 'sm', onclick: () => form(u) }, 'Ubah'), ' ',
        h('button', { class: 'sm', onclick: () => confirmBox(`Reset password ${u.name}?`, async () => { const x = await api('POST', `/admin/users/${u.id}/reset-password`); showCreds('Password Baru', [{ nama: u.name, nis: '', kelas: '', email: u.email, password: x.password }]); }, 'Reset') }, 'Reset PW'))))));
};

// ---------------------------------------------------------------- Bank soal
const LABEL = 'ABCDEF';
VIEWS.questions = async () => {
  const subs = (await api('GET', '/admin/subjects')).items;
  const state = { subtestId: '', usage: '', q: '', page: 1 };
  const box = h('div');
  const load = guard(async () => {
    const qs = new URLSearchParams({ page: state.page, limit: 25 });
    ['subtestId', 'usage', 'q'].forEach((k) => state[k] && qs.set(k, state[k]));
    const r = await api('GET', '/admin/questions?' + qs);
    clear(box);
    box.append(table(['#', 'Mapel', 'Soal', 'Kunci', 'Status', ''], r.items.map((q) => h('tr', {},
      h('td', {}, q.id), h('td', {}, q.subtestId.toUpperCase()), h('td', { style: 'max-width:480px' }, (q.passage ? '📖 ' : '') + q.text.slice(0, 120) + (q.text.length > 120 ? '…' : '')),
      h('td', {}, LABEL[q.correctIndex]), h('td', {}, h('span', { class: 'tag ' + (q.usage === 'ujian' ? 'warn' : q.usage === 'latihan' ? 'info' : '') }, q.usage)),
      h('td', { class: 'right nowrap' }, h('button', { class: 'sm', onclick: () => form(q) }, 'Ubah'), ' ', h('button', { class: 'sm danger', onclick: () => confirmBox('Hapus soal ini?', async () => { await api('DELETE', '/admin/questions/' + q.id); load(); }) }, 'Hapus'))))),
      h('div', { class: 'muted mt' }, `${r.total} soal · halaman ${r.page}`),
      h('div', { class: 'bar mt' }, h('button', { disabled: state.page <= 1, onclick: () => { state.page--; load(); } }, '‹'), h('button', { disabled: r.page * r.limit >= r.total, onclick: () => { state.page++; load(); } }, '›')));
  });

  function form(q) {
    const f = {
      sub: h('select', {}, subs.map((s) => h('option', { value: s.id, selected: q ? q.subtestId === s.id : s.id === state.subtestId }, `${s.code} — ${s.name}`))),
      passage: h('textarea', { placeholder: 'Teks bacaan / wacana (opsional)' }, q && q.passage ? q.passage : ''), text: h('textarea', {}, q ? q.text : ''),
      exp: h('textarea', { placeholder: 'Pembahasan (tampil ke siswa setelah ujian selesai)' }, q && q.explanation ? q.explanation : ''),
      usage: h('select', {}, [['semua', 'Semua (latihan & ujian)'], ['ujian', 'Khusus ujian (tidak muncul di latihan)'], ['latihan', 'Khusus latihan']].map(([v, l]) => h('option', { value: v, selected: (q ? q.usage : 'ujian') === v }, l))),
    };
    let count = q ? q.options.length : 5; let correct = q ? q.correctIndex : 0;
    const optBox = h('div');
    const opts = q ? [...q.options] : ['', '', '', '', ''];
    const drawOpts = () => { clear(optBox); opts.forEach((o, i) => optBox.append(h('div', { class: 'opt' }, h('input', { type: 'radio', name: 'correct', checked: i === correct, onchange: () => { correct = i; } }), h('b', {}, LABEL[i]), h('input', { type: 'text', value: o, oninput: (e) => { opts[i] = e.target.value; } })))); };
    drawOpts();
    modal(q ? `Ubah Soal #${q.id}` : 'Soal Baru', h('div', {}, h('div', { class: 'row' }, h('div', {}, h('label', {}, 'Mapel'), f.sub), h('div', {}, h('label', {}, 'Pemakaian'), f.usage)),
      h('label', {}, 'Wacana'), f.passage, h('label', {}, 'Pertanyaan'), f.text, h('label', {}, 'Pilihan jawaban (pilih bulatan untuk kunci)'), optBox, h('label', {}, 'Pembahasan'), f.exp,
      h('p', { class: 'muted' }, 'Tips: soal yang dipakai untuk ujian sebaiknya berstatus "Khusus ujian" agar kuncinya tidak terbuka lewat mode latihan siswa.')),
      { wide: true, buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Simpan', primary: true, onclick: async (x) => {
        const body = { subtestId: f.sub.value, passage: f.passage.value, text: f.text.value, options: opts.slice(0, count), correctIndex: correct, explanation: f.exp.value, usage: f.usage.value };
        await api(q ? 'PUT' : 'POST', '/admin/questions' + (q ? '/' + q.id : ''), body); x(); load();
      } }] });
  }

  const importer = () => {
    const file = h('input', { type: 'file', accept: '.csv,text/csv' });
    modal('Impor Soal dari CSV', h('div', {}, h('p', {}, 'Kolom: ', h('b', {}, 'mapel, soal, a, b, c, d, e, kunci, pembahasan, wacana, pemakaian'), '. Kunci berisi huruf A–E. Pemakaian: ujian / latihan / semua. "mapel" = ID mapel (mis. pu, mtk-xi).'),
      h('button', { onclick: () => downloadCsv([['mapel', 'soal', 'a', 'b', 'c', 'd', 'e', 'kunci', 'pembahasan', 'wacana', 'pemakaian'], ['pu', 'Contoh soal 2 + 2 = …', '3', '4', '5', '6', '7', 'B', 'Dua tambah dua sama dengan empat.', '', 'ujian']], 'template-soal.csv') }, 'Unduh template'), h('label', {}, 'Berkas CSV'), file),
      { buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Impor', primary: true, onclick: async (x) => {
        if (!file.files[0]) { toast('Pilih berkas dulu', true); return false; }
        const rows = csvToObjects(await readFile(file.files[0]));
        const questions = rows.map((r) => ({ subtestId: r.mapel, text: r.soal, options: ['a', 'b', 'c', 'd', 'e'].map((k) => r[k]).filter(Boolean), correctIndex: 'ABCDE'.indexOf((r.kunci || '').toUpperCase()), explanation: r.pembahasan, passage: r.wacana, usage: r.pemakaian || 'ujian' }));
        const res = await api('POST', '/admin/questions/import', { questions }); x();
        toast(`${res.created} soal masuk` + (res.errors.length ? `, ${res.errors.length} gagal` : ''), res.errors.length > 0);
        if (res.errors.length) modal('Baris gagal', h('ul', {}, res.errors.map((e) => h('li', {}, `Baris ${e.row}: ${e.message}`))), { buttons: [{ label: 'Tutup', primary: true, onclick: (c) => c() }] });
        load();
      } }] });
  };

  main.append(pageHead('Bank Soal', 'Kunci jawaban hanya tersimpan di server', h('button', { onclick: importer }, 'Impor CSV'), h('button', { class: 'primary', onclick: () => form() }, '+ Soal')),
    h('div', { class: 'bar' }, h('input', { placeholder: 'Cari teks soal', onkeydown: (e) => { if (e.key === 'Enter') { state.q = e.target.value; state.page = 1; load(); } } }),
      h('select', { onchange: (e) => { state.subtestId = e.target.value; state.page = 1; load(); } }, h('option', { value: '' }, 'Semua mapel'), subs.map((s) => h('option', { value: s.id }, `${s.code} (${s.questions})`))),
      h('select', { onchange: (e) => { state.usage = e.target.value; state.page = 1; load(); } }, h('option', { value: '' }, 'Semua pemakaian'), ['ujian', 'latihan', 'semua'].map((u) => h('option', { value: u }, u)))), box);
  load();
};

// ---------------------------------------------------------------- Ujian
const phaseTag = (e) => {
  const now = Date.now();
  if (e.kind === 'tryout') return h('span', { class: 'tag info' }, 'Bawaan');
  if (e.status === 'draft') return h('span', { class: 'tag' }, 'Draft');
  if (e.status === 'closed') return h('span', { class: 'tag bad' }, 'Ditutup');
  if (e.startAt && now < e.startAt) return h('span', { class: 'tag warn' }, 'Terjadwal');
  if (e.endAt && now >= e.endAt) return h('span', { class: 'tag bad' }, 'Berakhir');
  return h('span', { class: 'tag ok' }, 'Berlangsung');
};

VIEWS.exams = async (arg) => {
  if (arg === 'new') return examForm(null);
  if (arg && arg.startsWith('edit-')) return examForm(Number(arg.slice(5)));
  if (arg && arg.startsWith('results-')) return resultsView(Number(arg.slice(8)));
  const { items } = await api('GET', '/admin/exams');
  main.append(pageHead('Ujian', 'Buat, jadwalkan, dan terbitkan ujian', h('button', { class: 'primary', onclick: () => { location.hash = '#/exams/new'; } }, '+ Buat Ujian')),
    table(['Judul', 'Status', 'Jadwal', 'Soal / Durasi', 'Token', 'Peserta', ''], items.map((e) => h('tr', {},
      h('td', {}, h('b', {}, e.title)), h('td', {}, phaseTag(e)),
      h('td', { class: 'nowrap' }, e.startAt ? `${fmtDate(e.startAt)} → ${fmtDate(e.endAt)}` : 'Kapan saja'),
      h('td', {}, `${e.totalQuestions} soal · ${Math.round(e.totalSeconds / 60)} mnt`),
      h('td', {}, e.accessToken ? h('span', { class: 'token' }, e.accessToken) : '—'),
      h('td', {}, `${e.attempts}` + (e.running ? ` (${e.running} aktif)` : '')),
      h('td', { class: 'right nowrap' },
        h('button', { class: 'sm', onclick: () => { location.hash = '#/monitor/' + e.id; } }, 'Pantau'), ' ',
        h('button', { class: 'sm', onclick: () => { location.hash = '#/exams/results-' + e.id; } }, 'Hasil'), ' ',
        e.kind === 'tryout' ? null : [
          h('button', { class: 'sm', onclick: () => { location.hash = '#/exams/edit-' + e.id; } }, 'Ubah'), ' ',
          e.status === 'published' ? h('button', { class: 'sm danger', onclick: () => confirmBox('Tutup ujian? Siswa yang masih mengerjakan akan dikumpulkan paksa.', async () => { await api('POST', `/admin/exams/${e.id}/status`, { status: 'closed' }); render(); }, 'Tutup ujian') }, 'Tutup')
            : e.status === 'draft' ? h('button', { class: 'sm primary', onclick: guard(async () => { await api('POST', `/admin/exams/${e.id}/status`, { status: 'published' }); toast('Ujian diterbitkan'); render(); }) }, 'Terbitkan') : null,
          ' ', h('button', { class: 'sm danger', onclick: () => confirmBox(`Hapus ujian "${e.title}"?`, async () => { await api('DELETE', '/admin/exams/' + e.id); render(); }) }, 'Hapus')])))));
};

async function examForm(id) {
  const [classes, subs] = [(await api('GET', '/admin/classes')).items, (await api('GET', '/admin/subjects')).items];
  const ex = id ? await api('GET', '/admin/exams/' + id) : null;
  const locked = false;
  const f = {
    title: h('input', { value: ex ? ex.title : '' }), desc: h('textarea', {}, ex && ex.description ? ex.description : ''),
    start: h('input', { type: 'datetime-local', value: ex ? toLocalInput(ex.startAt) : '' }), end: h('input', { type: 'datetime-local', value: ex ? toLocalInput(ex.endAt) : '' }),
    attempts: h('input', { type: 'number', min: 0, max: 20, value: ex ? ex.maxAttempts : 1 }), viol: h('input', { type: 'number', min: 0, max: 50, value: ex ? ex.maxViolations : 3 }),
    sq: h('input', { type: 'checkbox', checked: ex ? ex.shuffleQuestions : true }), so: h('input', { type: 'checkbox', checked: ex ? ex.shuffleOptions : true }),
    tok: h('input', { type: 'checkbox', checked: ex ? !!ex.accessToken : true }),
    mode: h('select', {}, [['score', 'Nilai langsung tampil; pembahasan setelah ujian ditutup (disarankan)'], ['full', 'Nilai + pembahasan langsung tampil'], ['after_end', 'Nilai & pembahasan setelah ujian ditutup'], ['hidden', 'Tidak ditampilkan ke siswa']].map(([v, l]) => h('option', { value: v, selected: (ex ? ex.resultMode : 'score') === v }, l))),
  };
  const classSel = new Set(ex ? ex.classIds : []);
  const sections = ex ? ex.sections.map((s) => ({ ...s, minutes: Math.round(s.seconds / 60) })) : [{ subtestId: subs[0] ? subs[0].id : '', name: '', questions: 10, minutes: 30 }];
  const secBox = h('div');

  const drawSections = () => {
    clear(secBox);
    sections.forEach((s, i) => {
      const fixed = !!(s.questionIds && s.questionIds.length);
      secBox.append(h('div', { class: 'sec' }, h('div', { class: 'row' },
        h('div', {}, h('label', {}, `Bagian ${i + 1} · Mapel`), h('select', { onchange: (e) => { s.subtestId = e.target.value; s.questionIds = []; drawSections(); } }, subs.map((x) => h('option', { value: x.id, selected: x.id === s.subtestId }, `${x.code} — ${x.name}`)))),
        h('div', {}, h('label', {}, 'Durasi (menit)'), h('input', { type: 'number', min: 1, max: 240, value: s.minutes, oninput: (e) => { s.minutes = Number(e.target.value); } })),
        h('div', {}, h('label', {}, fixed ? 'Jumlah soal (dipilih manual)' : 'Jumlah soal (acak dari bank)'), h('input', { type: 'number', min: 1, max: 200, value: fixed ? s.questionIds.length : s.questions, disabled: fixed, oninput: (e) => { s.questions = Number(e.target.value); } }))),
        h('div', { class: 'bar mt' }, h('button', { onclick: () => pickQuestions(s) }, fixed ? `Ubah pilihan soal (${s.questionIds.length})` : 'Pilih soal manual'),
          fixed ? h('button', { onclick: () => { s.questionIds = []; drawSections(); } }, 'Kembali ke acak') : null,
          sections.length > 1 ? h('button', { class: 'danger', onclick: () => { sections.splice(i, 1); drawSections(); } }, 'Hapus bagian') : null)));
    });
  };
  drawSections();

  async function pickQuestions(s) {
    const r = await api('GET', `/admin/questions?subtestId=${encodeURIComponent(s.subtestId)}&limit=500`);
    const usable = r.items.filter((q) => q.usage !== 'latihan');
    const chosen = new Set(s.questionIds || []);
    const list = h('div', { style: 'max-height:55vh;overflow:auto' }, usable.length ? usable.map((q) => h('label', { class: 'inline', style: 'display:flex;border-bottom:1px solid var(--line);padding:6px 0;margin:0' },
      h('input', { type: 'checkbox', checked: chosen.has(q.id), onchange: (e) => { e.target.checked ? chosen.add(q.id) : chosen.delete(q.id); } }), `#${q.id} ${q.text.slice(0, 110)}`)) : h('p', { class: 'muted' }, 'Belum ada soal untuk ujian di mapel ini. Tambahkan di Bank Soal (pemakaian "ujian" atau "semua").'));
    modal('Pilih Soal', list, { wide: true, buttons: [{ label: 'Batal', onclick: (x) => x() }, { label: 'Pakai pilihan ini', primary: true, onclick: (x) => { s.questionIds = [...chosen]; x(); drawSections(); } }] });
  }

  const save = guard(async () => {
    const body = {
      title: f.title.value, description: f.desc.value, startAt: fromLocalInput(f.start.value), endAt: fromLocalInput(f.end.value),
      maxAttempts: Number(f.attempts.value), maxViolations: Number(f.viol.value), shuffleQuestions: f.sq.checked, shuffleOptions: f.so.checked,
      resultMode: f.mode.value, useToken: f.tok.checked, classIds: [...classSel],
      sections: sections.map((s) => ({ subtestId: s.subtestId, name: s.name, minutes: s.minutes, questions: s.questions, questionIds: s.questionIds })),
    };
    const r = await api(id ? 'PUT' : 'POST', '/admin/exams' + (id ? '/' + id : ''), body);
    if (r.warnings && r.warnings.length) modal('Perhatian', h('ul', {}, r.warnings.map((w) => h('li', {}, w))), { buttons: [{ label: 'Mengerti', primary: true, onclick: (x) => { x(); location.hash = '#/exams'; } }] });
    else { toast('Ujian tersimpan'); location.hash = '#/exams'; }
  });

  main.append(pageHead(id ? 'Ubah Ujian' : 'Buat Ujian', ex && ex.sectionsLocked ? 'Soal & durasi terkunci karena sudah ada yang mengerjakan' : null),
    h('div', { class: 'card' }, h('label', {}, 'Judul ujian'), f.title, h('label', {}, 'Petunjuk untuk siswa (opsional)'), f.desc,
      h('h3', {}, 'Peserta'), h('div', {}, classes.length ? classes.map((c) => h('label', { class: 'inline' }, h('input', { type: 'checkbox', checked: classSel.has(c.id), onchange: (e) => { e.target.checked ? classSel.add(c.id) : classSel.delete(c.id); } }), `${c.name} (${c.students})`)) : h('span', { class: 'muted' }, 'Belum ada kelas.')),
      h('div', { class: 'muted' }, 'Tidak memilih kelas = semua siswa boleh melihat ujian ini.'),
      h('h3', {}, 'Jadwal'), h('div', { class: 'row' }, h('div', {}, h('label', {}, 'Dibuka'), f.start), h('div', {}, h('label', {}, 'Ditutup'), f.end)),
      h('div', { class: 'muted' }, 'Kosongkan bila tidak dibatasi waktu. Siswa yang mulai terlambat tetap berhenti pada jam ditutup.')),
    h('div', { class: 'card' }, h('h2', {}, 'Bagian / Subtes'), secBox,
      h('button', { onclick: () => { sections.push({ subtestId: subs[0].id, name: '', questions: 10, minutes: 30 }); drawSections(); } }, '+ Tambah bagian'),
      h('p', { class: 'muted' }, 'Bagian dikerjakan berurutan; waktu tiap bagian terpisah dan tidak bisa kembali ke bagian sebelumnya.')),
    h('div', { class: 'card' }, h('h2', {}, 'Pengamanan'),
      h('label', { class: 'inline' }, f.sq, 'Acak urutan soal tiap siswa'), h('label', { class: 'inline' }, f.so, 'Acak urutan pilihan jawaban tiap siswa'), h('label', { class: 'inline' }, f.tok, 'Wajib token ujian (dibagikan pengawas)'),
      h('div', { class: 'row' }, h('div', {}, h('label', {}, 'Batas pelanggaran (pindah tab/aplikasi, keluar layar penuh). 0 = hanya dicatat'), f.viol), h('div', {}, h('label', {}, 'Maks. percobaan per siswa (0 = tak terbatas)'), f.attempts)),
      h('label', {}, 'Tampilan hasil ke siswa'), f.mode),
    h('div', { class: 'bar' }, h('button', { class: 'primary', onclick: save }, 'Simpan'), h('button', { onclick: () => { location.hash = '#/exams'; } }, 'Batal'),
      ex && ex.accessToken ? h('span', { class: 'right' }, 'Token: ', h('span', { class: 'token' }, ex.accessToken), ' ', h('button', { class: 'sm', onclick: guard(async () => { await api('POST', `/admin/exams/${id}/token`, {}); render(); }) }, 'Buat ulang')) : null));
}

// ---------------------------------------------------------------- Potensi siswa
const SOURCE = { latihan: 'Latihan', tryout: 'Try Out', ujian: 'Ujian' };
VIEWS.potensi = async () => {
  const classes = (await api('GET', '/admin/classes')).items;
  const state = { q: '', classId: '' };
  const box = h('div');
  const load = guard(async () => {
    const qs = new URLSearchParams();
    if (state.q) qs.set('q', state.q); if (state.classId) qs.set('classId', state.classId);
    const r = await api('GET', '/admin/potensi?' + qs);
    clear(box);
    box.append(table(['Siswa', 'NIS', 'Kelas', 'Sesi', 'Latihan', 'Try Out/Ujian', 'Akurasi', 'Total poin', 'Terakhir aktif', ''],
      r.items.map((s) => h('tr', {}, h('td', {}, h('b', {}, s.name)), h('td', {}, s.nis || ''), h('td', {}, s.className || '—'), h('td', {}, s.sessions), h('td', {}, s.practice), h('td', {}, s.exams),
        h('td', {}, h('div', { class: 'bar-pct' }, h('i', { style: `width:${s.accuracy}%` })), `${s.accuracy}%`), h('td', {}, h('b', {}, s.points)), h('td', {}, fmtDate(s.lastAt)),
        h('td', { class: 'right' }, h('button', { class: 'sm', onclick: () => detail(s) }, 'Detail'))))));
  });
  const detail = guard(async (s) => {
    const d = await api('GET', '/admin/potensi/' + s.userId);
    modal(`Potensi: ${d.student.name}`, h('div', {},
      h('p', { class: 'muted' }, [d.student.className, d.student.nis ? 'NIS ' + d.student.nis : ''].filter(Boolean).join(' · ') || ' '),
      h('h3', {}, 'Per subtes / mapel'),
      table(['Subtes', 'Sesi', 'Akurasi', 'Poin terbaik'], d.subtests.map((x) => h('tr', {}, h('td', {}, x.name), h('td', {}, x.sessions),
        h('td', {}, h('div', { class: 'bar-pct' }, h('i', { style: `width:${x.accuracy}%` })), `${x.accuracy}%`), h('td', {}, x.best)))),
      h('h3', {}, 'Riwayat terbaru'),
      table(['Waktu', 'Jenis', 'Subtes', 'Benar', 'Salah', 'Poin'], d.recent.map((x) => h('tr', {}, h('td', { class: 'nowrap' }, fmtDate(x.at)), h('td', {}, h('span', { class: 'tag' }, SOURCE[x.source] || x.source)), h('td', {}, x.name), h('td', {}, `${x.correct}/${x.total}`), h('td', {}, x.wrong), h('td', {}, x.points))))),
      { wide: true, buttons: [{ label: 'Tutup', primary: true, onclick: (c) => c() }] });
  });
  main.append(pageHead('Potensi Siswa', 'Perkembangan latihan, try out, dan ujian tiap siswa'),
    h('div', { class: 'bar' }, h('input', { placeholder: 'Cari nama / NIS', onkeydown: (e) => { if (e.key === 'Enter') { state.q = e.target.value; load(); } } }),
      h('select', { onchange: (e) => { state.classId = e.target.value; load(); } }, h('option', { value: '' }, 'Semua kelas'), classes.map((c) => h('option', { value: c.id }, c.name)))), box);
  load();
};

// ---------------------------------------------------------------- Pantau
const REASON = { done: 'Selesai', timeout: 'Waktu habis', violation: 'Melanggar', quit: 'Keluar sendiri', abandoned: 'Ditinggalkan', admin: 'Dikumpulkan pengawas' };
VIEWS.monitor = async (arg) => {
  if (!arg) {
    const { items } = await api('GET', '/admin/exams');
    main.append(pageHead('Pantau Ujian', 'Pilih ujian yang ingin dipantau'),
      table(['Ujian', 'Status', 'Aktif', ''], items.map((e) => h('tr', {}, h('td', {}, e.title), h('td', {}, phaseTag(e)), h('td', {}, e.running), h('td', { class: 'right' }, h('button', { class: 'primary sm', onclick: () => { location.hash = '#/monitor/' + e.id; } }, 'Buka')))))); return;
  }
  const id = Number(arg);
  const box = h('div'); main.append(box);
  const tick = async () => {
    let m; try { m = await api('GET', `/admin/exams/${id}/monitor`); } catch (_) { return; }
    clear(box);
    const s = m.summary; const pill = (n, l, cls) => h('div', { class: 'stat' }, h('b', { class: cls }, n), h('span', {}, l));
    const act = (a, label, fn, cls = '') => h('button', { class: 'sm ' + cls, onclick: fn }, label);
    box.append(pageHead(m.exam.title, 'Diperbarui otomatis tiap 5 detik', h('button', { onclick: () => { location.hash = '#/exams/results-' + id; } }, 'Lihat hasil')),
      h('div', { class: 'grid' }, pill(s.running, 'Mengerjakan'), pill(s.finished, 'Selesai'), pill(s.notStarted, 'Belum mulai'), pill(s.offline, 'Tidak terhubung > 1 mnt'), pill(s.withViolations, 'Pernah melanggar')),
      h('div', { class: 'mt' }, table(['Siswa', 'Kelas', 'Status', 'Bagian', 'Terjawab', 'Pelanggaran', 'Terakhir aktif', 'IP', ''], m.items.map((a) => h('tr', {},
        h('td', {}, h('b', {}, a.name), a.nis ? ' ' + a.nis : ''), h('td', {}, a.className || '—'),
        h('td', {}, a.status === 'running' ? (a.offline ? h('span', { class: 'tag warn' }, 'Terputus') : h('span', { class: 'tag ok' }, 'Mengerjakan')) : h('span', { class: 'tag' }, REASON[a.endReason] || 'Selesai')),
        h('td', {}, `${a.section}/${a.sectionCount}`), h('td', {}, a.status === 'running' ? `${a.answered}/${a.sectionQuestions}` : '—'),
        h('td', {}, a.violations ? h('button', { class: 'sm danger', onclick: guard(async () => { const v = await api('GET', `/admin/exams/${id}/attempts/${a.attemptId}/violations`); modal(`Pelanggaran ${a.name}`, table(['Waktu', 'Jenis', 'Dihitung'], v.items.map((x) => h('tr', {}, h('td', {}, fmtDate(x.at)), h('td', {}, x.type), h('td', {}, x.counted ? 'Ya' : 'Tidak')))), { buttons: [{ label: 'Tutup', primary: true, onclick: (c) => c() }] }); }) }, a.violations) : '0'),
        h('td', {}, a.status === 'running' ? ago(a.lastSeenAt, m.serverNow) : '—'), h('td', {}, a.ip || '—'),
        h('td', { class: 'right nowrap' }, a.status === 'running' ? [
          act('t', '+Waktu', () => { const n = h('input', { type: 'number', value: 5, min: 1, max: 120 }); modal('Tambah waktu', h('div', {}, h('label', {}, 'Menit'), n), { buttons: [{ label: 'Batal', onclick: (c) => c() }, { label: 'Tambah', primary: true, onclick: async (c) => { await api('POST', `/admin/exams/${id}/attempts/${a.attemptId}/extend`, { minutes: Number(n.value) }); c(); toast('Waktu ditambah'); tick(); } }] }); }), ' ',
          act('k', 'Kumpulkan', () => confirmBox(`Kumpulkan paksa ujian ${a.name}?`, async () => { await api('POST', `/admin/exams/${id}/attempts/${a.attemptId}/force-finish`); tick(); }))] : null,
          ' ', act('r', 'Ulang', () => confirmBox(`Izinkan ${a.name} mengulang ujian? Percobaan lama diarsipkan dan tidak dihitung.`, async () => { await api('POST', `/admin/exams/${id}/attempts/${a.attemptId}/reset`); tick(); }, 'Izinkan ulang'), 'danger')))))),
      m.notStarted.length ? h('div', { class: 'card mt' }, h('h2', {}, `Belum memulai (${m.notStarted.length})`), h('div', {}, m.notStarted.map((n) => h('span', { class: 'pill' }, `${n.name}${n.className ? ' · ' + n.className : ''}`)))) : null);
  };
  await tick(); timers.push(setInterval(tick, 5000));
};

// ---------------------------------------------------------------- Hasil
async function resultsView(id) {
  const [r, an] = await Promise.all([api('GET', `/admin/exams/${id}/results`), api('GET', `/admin/exams/${id}/analysis`)]);
  const st = r.stats; const stat = (n, l) => h('div', { class: 'stat' }, h('b', {}, n), h('span', {}, l));
  main.append(pageHead('Hasil: ' + r.exam.title, `${r.exam.totalQuestions} soal`, h('button', { class: 'primary', onclick: guard(() => download(`/admin/exams/${id}/results.csv`, `hasil-ujian-${id}.csv`)) }, 'Unduh CSV (Excel)'), h('button', { onclick: () => window.print() }, 'Cetak')),
    h('div', { class: 'grid' }, stat(st.participants, 'Peserta'), stat(st.finished, 'Selesai'), stat(st.average, 'Rata-rata nilai'), stat(st.highest, 'Tertinggi'), stat(st.lowest, 'Terendah')),
    h('h3', {}, 'Peringkat'),
    table(['#', 'Nama', 'NIS', 'Kelas', 'Benar', 'Salah', 'Kosong', 'Poin', 'Nilai', 'Pelanggaran', 'Status'], r.items.map((i) => h('tr', {}, h('td', {}, i.rank), h('td', {}, h('b', {}, i.name)), h('td', {}, i.nis || ''), h('td', {}, i.className || ''), h('td', {}, i.correct), h('td', {}, i.wrong), h('td', {}, i.blank), h('td', {}, i.points), h('td', {}, h('b', {}, i.score)),
      h('td', {}, i.violations || 0), h('td', {}, i.status === 'running' ? 'Mengerjakan' : REASON[i.endReason] || '—')))),
    h('h3', {}, `Analisis butir soal (${an.attempts} peserta selesai)`), h('p', { class: 'muted' }, 'Persentase siswa yang menjawab benar. Soal "sulit" (<30%) layak diperiksa ulang: bisa jadi kuncinya keliru atau materinya belum diajarkan.'),
    table(['Soal', 'Ditampilkan', 'Dijawab', 'Benar', 'Tingkat'], an.items.map((q) => h('tr', {},
      h('td', {}, q.text), h('td', {}, q.shown), h('td', {}, q.answered),
      h('td', {}, h('div', { class: 'bar-pct' }, h('i', { style: `width:${q.correctPct}%` })), `${q.correctPct}%`),
      h('td', {}, h('span', { class: 'tag ' + (q.level === 'mudah' ? 'ok' : q.level === 'sulit' ? 'bad' : 'warn') }, q.level))))));
}

// ---------------------------------------------------------------- Log aktivitas (admin)
VIEWS.audit = async () => {
  const { items } = await api('GET', '/admin/audit?limit=200');
  main.append(pageHead('Log Aktivitas', 'Riwayat tindakan penting (200 terakhir)'),
    table(['Waktu', 'Pelaku', 'Aksi', 'Target', 'Detail', 'IP'], items.map((r) => h('tr', {},
      h('td', { class: 'nowrap' }, fmtDate(r.at)), h('td', {}, r.actor || '—'), h('td', {}, h('span', { class: 'tag' }, r.action)),
      h('td', {}, r.target || ''), h('td', {}, r.detail || ''), h('td', {}, r.ip || '')))));
};

// ---------------------------------------------------------------- Mulai
// Login otomatis dari aplikasi AdaNando: token dibawa lewat #sso=<token>.
// Fragment langsung dihapus dari address bar supaya token tidak tertinggal di riwayat.
(function start() {
  const m = location.hash.match(/^#sso=([^&]+)/);
  if (m) {
    try {
      token = decodeURIComponent(m[1]);
      sessionStorage.setItem('ada_token', token);
    } catch (_) { /* abaikan */ }
    history.replaceState(null, '', location.pathname + location.search);
  }
  boot();
})();

})();