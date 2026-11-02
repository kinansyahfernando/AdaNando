// src/utils/csv.js
// Penulis CSV yang aman untuk Excel (BOM UTF-8, kutip ganda, dan proteksi formula injection).
const cell = (v) => {
  if (v == null) return '';
  let s = String(v);
  // Cegah "CSV injection": sel yang diawali = + - @ dianggap formula oleh Excel
  if (typeof v === 'string' && /^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return /[",\n\r;]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
};

const toCsv = (rows) => '\uFEFF' + rows.map((r) => r.map(cell).join(',')).join('\r\n');

module.exports = { toCsv };
