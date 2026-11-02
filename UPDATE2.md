# Update 2: Room mode UTBK + kesempatan pelanggaran 2x

## 1. Buat Room: "Campuran" diganti "UTBK"
- Chip "Campuran" dihapus; diganti chip **UTBK** (dipilih secara bawaan).
- Saat UTBK dipilih, kartu "Jumlah soal" dan "Durasi" diganti kartu terkunci:
  **160 soal, 195 menit**, urutan 7 subtes seperti UTBK. Host tidak bisa mengatur soal/waktunya.
- Server yang menetapkan nilainya (angka dari aplikasi diabaikan), jadi tidak bisa diakali.
- Soal diambil per subtes sesuai susunan UTBK (30/20/20/20/30/20/20) dan tetap berurutan.
  Bila bank soal lebih sedikit, jumlahnya menyesuaikan.
- Room lama yang dibuat dengan "Campuran" tetap bisa dibuka.

## 2. Kesempatan keluar saat Try Out: 3x -> 2x
- Try Out Mandiri: pelanggaran ke-2 langsung mengakhiri dan mengumpulkan ujian.
- Database lama otomatis diperbarui saat backend dijalankan ulang (Try Out Mandiri jadi 2).
- Ujian buatan guru: bawaan batas pelanggaran untuk ujian BARU kini 2 (masih bisa diubah guru di panel admin).
- Dialog aturan sebelum mulai ujian kini menampilkan jumlah kesempatan dari server.

## File (semua LENGKAP)
Backend: src/modules/rooms/rooms.service.js, src/modules/attempts/attempts.routes.js,
         src/modules/exams/exams.routes.js, src/config/schema.js, sql/schema.sql, public/admin/app.js
Frontend (lib/features/student_dashboard): data/bank_lookup.dart, data/models/tryout.dart,
         presentation/pages/room_setup_page.dart, room_quiz_page.dart, tryout_start_page.dart

## Cara pasang
1. Timpa file ke folder AdaNando (Replace). File schema.js di sini menggantikan versi update sebelumnya.
2. Restart backend (npm run dev). Cari baris: "~ batas pelanggaran Try Out Mandiri diset 2x".
3. Frontend: stop lalu flutter run -d chrome lagi.
