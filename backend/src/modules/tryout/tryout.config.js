// src/modules/tryout/tryout.config.js
// Susunan Try Out Mandiri: 7 subtes berurutan, 160 soal, 195 menit.
// Durasi dalam detik (42,5 menit = 2550 detik).
const SECTIONS = [
  { id: 'pu',  name: 'Penalaran Umum',                  questions: 30, seconds: 30 * 60 },
  { id: 'ppu', name: 'Pengetahuan dan Pemahaman Umum',  questions: 20, seconds: 15 * 60 },
  { id: 'pbm', name: 'Pemahaman Bacaan dan Menulis',    questions: 20, seconds: 25 * 60 },
  { id: 'pk',  name: 'Pengetahuan Kuantitatif',         questions: 20, seconds: 20 * 60 },
  { id: 'lbi', name: 'Literasi Bahasa Indonesia',       questions: 30, seconds: 2550 },
  { id: 'lbe', name: 'Literasi Bahasa Inggris',         questions: 20, seconds: 20 * 60 },
  { id: 'pm',  name: 'Penalaran Matematika',            questions: 20, seconds: 2550 },
];

const TOTAL_SECONDS = SECTIONS.reduce((sum, s) => sum + s.seconds, 0); // 11700 = 195 menit
const TOTAL_QUESTIONS = SECTIONS.reduce((sum, s) => sum + s.questions, 0); // 160

// Toleransi keterlambatan jaringan saat mengirim jawaban setelah waktu habis (ms)
const GRACE_MS = 8000;

module.exports = { SECTIONS, TOTAL_SECONDS, TOTAL_QUESTIONS, GRACE_MS };
