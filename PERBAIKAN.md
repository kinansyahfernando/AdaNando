# Perbaikan: "Gagal memuat soal" (tabel database tidak terbentuk)

## Penyebab
1. Tabel (terutama `questions`) hanya dibuat bila `npm run migrate` dijalankan manual dan sukses sampai akhir.
   Satu error di tengah jalan menghentikan semuanya -> tabel soal tidak ada -> API latihan error 500
   -> aplikasi hanya menampilkan "Gagal memuat soal".
2. Migrasi tidak membuat database `db_utbk` bila belum ada.
3. `backend/.env` masih berupa template: `JWT_SECRET` kosong membuat server langsung berhenti.
4. Aplikasi menyembunyikan penyebab asli error.

## Yang diubah (semua file diberikan LENGKAP)
Backend
- `backend/src/config/schema.js`      BARU  - pembuat/pemulih skema (buat database, tabel, soal contoh, Try Out, admin)
- `backend/server.js`                 GANTI - menyiapkan database otomatis setiap server menyala
- `backend/scripts/migrate.js`        GANTI - kini memakai schema.js, error dilaporkan per langkah
- `backend/src/config/env.js`         GANTI - mode development: JWT_SECRET kosong dibuat otomatis
- `backend/src/modules/practice/practice.routes.js` GANTI - bila tabel hilang, diperbaiki otomatis lalu diulang
- `backend/src/app.js`                GANTI - `/api/v1/health` kini menampilkan status database & jumlah soal
- `backend/Dockerfile`                GANTI - server sudah migrasi sendiri

Frontend
- `frontend/lib/features/student_dashboard/data/practice_repository.dart`
- `frontend/lib/features/student_dashboard/presentation/providers/practice_provider.dart`
- `frontend/lib/features/student_dashboard/presentation/pages/practice_page.dart`
  -> pesan error kini menyebut penyebab sebenarnya (server mati / kode error / data tidak sesuai).

## Cara memasang
1. Extract zip ini, timpa ke folder `AdaNando` (pilih Replace).
2. Pastikan MySQL/MariaDB (Laragon) menyala.
3. Restart backend:
   ```
   cd backend
   npm run dev        (atau npm start)
   ```
   Di terminal harus muncul:  `✅ Database & tabel siap.`
   dan baris `✓ 14 tabel lengkap, 21 soal tersedia untuk latihan`.
   Bila ada kegagalan, terminal mencetak langkah dan pesan MySQL-nya.
4. Cek di browser: http://127.0.0.1:3000/api/v1/health  ->  `"db":{"ok":true,"questions":21}`
5. Frontend: stop lalu `flutter run -d chrome` lagi (bukan hot reload), lalu buka Penalaran Umum.

Catatan: `.env` tidak ikut ditimpa supaya pengaturan DB Anda aman. Bila `JWT_SECRET` kosong,
server membuatkannya sendiri dan menyimpannya ke `backend/.env`.
