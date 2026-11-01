# Update 2: Try Out Mandiri 160 soal + halaman Potensi

Extract zip ini lalu timpa/tambahkan ke folder `AdaNando` (pilih "Replace" kalau ditanya).
Zip ini berisi SEMUA file dari update 1 + update 2, jadi aman ditimpa langsung.

## 1. Backend (folder `backend`)

BARU:
- sql/tryout.sql
- scripts/create-tryout-tables.js
- src/modules/tryout/ (tryout.config.js, tryout.service.js, tryout.controller.js, tryout.routes.js)
- src/modules/results/ (results.service.js, results.controller.js, results.routes.js)

GANTI:
- src/app.js  (menambah route /api/v1/tryout dan /api/v1/results)

Langkah:
1. Di folder backend jalankan:  node scripts/create-tryout-tables.js
2. Restart server (ketik `rs` di terminal nodemon, atau jalankan ulang npm run dev).

## 2. Android (blokir screenshot & rekam layar)

GANTI:
- frontend/android/app/src/main/kotlin/com/example/frontend/MainActivity.kt

Setelah file ini diganti, aplikasi harus di-build ulang penuh (stop lalu `flutter run`,
hot reload tidak cukup). Tidak ada package baru.

## 3. Frontend (folder `frontend/lib`)

BARU:
- core/utils/secure_screen.dart
- features/student_dashboard/data/models/tryout.dart
- features/student_dashboard/data/models/result_entry.dart
- features/student_dashboard/data/tryout_repository.dart
- features/student_dashboard/data/tryout_session.dart
- features/student_dashboard/data/results_repository.dart
- features/student_dashboard/presentation/pages/tryout_start_page.dart
- features/student_dashboard/presentation/pages/tryout_section_page.dart
- features/student_dashboard/presentation/pages/tryout_result_page.dart
- features/student_dashboard/presentation/pages/potensi_page.dart

GANTI:
- features/student_dashboard/data/bank_lookup.dart
- features/student_dashboard/presentation/pages/timed_quiz_page.dart
- features/student_dashboard/presentation/pages/belajar_bareng_page.dart
- features/student_dashboard/presentation/pages/student_dashboard_page.dart
- features/student_dashboard/presentation/pages/practice_page.dart

(File update 1 lain ikut disertakan; isinya tidak berubah.)

## Catatan
- Soal Try Out masih memakai bank soal contoh (3 soal per subtes, diulang sampai 30/20 soal).
- Tes keluar aplikasi di Chrome: pindah tab akan memicu pelanggaran, tapi screenshot tidak bisa
  diblokir di web. Blokir screenshot hanya aktif di APK Android.
- Untuk HP asli, isi frontend/.env:  API_BASE_URL=http://IP_LAPTOP:3000/api/v1
