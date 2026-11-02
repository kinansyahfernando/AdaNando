# AdaNando v3 — Panduan Pemasangan & Pemakaian untuk Sekolah

Sistem ujian online + Try Out UTBK. Satu server melayani tiga hal sekaligus:

| Alamat | Untuk siapa | Isi |
|---|---|---|
| `https://ujian.sekolahmu.sch.id/` | **Siswa** | Aplikasi ujian (web/PWA) — jalan di laptop, Chromebook, Android, **iPhone** |
| `https://ujian.sekolahmu.sch.id/admin` | **Guru & Admin** | Panel: siswa, bank soal, ujian, pantau langsung, hasil |
| `…/api/v1` | Aplikasi | API (nilai & kunci jawaban hanya ada di sini) |

Android juga bisa memakai APK (`flutter build apk`), tapi **versi web/PWA adalah jalur utama** karena satu-satunya
yang bisa dipakai di iPhone, laptop Windows, dan Chromebook tanpa instal apa pun.

---

## 1. Apa yang sudah dibenahi (ringkas)

**Anti-curang (inti perubahan)**
- **Nilai dihitung server.** Dulu aplikasi mengirim "benar 30, salah 0" dan server percaya. Sekarang aplikasi hanya mengirim jawaban mentah.
- **Kunci jawaban tidak ada di aplikasi.** Dulu seluruh bank soal + kunci ikut terpasang di APK/web. Sekarang soal dikirim server **per bagian** dan **tanpa kunci**.
- **Acak per siswa:** urutan soal dan urutan pilihan A–E berbeda tiap siswa (menyontek ke sebelah jadi tidak berguna).
- **Waktu dari jam server**, bagian yang waktunya habis otomatis dinilai walau HP siswa mati.
- **Jawaban tersimpan otomatis** ke server (HP mati/ browser tertutup → lanjut dari titik terakhir).
- **Deteksi pelanggaran**: pindah tab/aplikasi, jendela kehilangan fokus, keluar layar penuh, copy-paste, klik kanan, PrintScreen, F12. Dihitung & dicatat di server; melewati batas → ujian otomatis dikumpulkan.
- **Layar ditutup (blur) saat jendela kehilangan fokus** (menyulitkan alat screenshot/Snipping Tool), **tanda air nama + NIS** di atas soal (foto layar bisa dilacak), layar HP tidak mati selama ujian, Android memblokir screenshot (FLAG_SECURE).
- **Satu akun = satu perangkat aktif.** Login di perangkat lain mengeluarkan yang lama (cegah joki/berbagi akun).
- **Token ujian + jadwal buka/tutup + target kelas.** Siswa kelas lain tidak melihat ujiannya. Ujian ditutup tepat waktu.
- **Pembahasan terkunci** sampai ujian ditutup (mode bawaan), supaya siswa yang selesai duluan tidak membocorkan jawaban.
- **Soal "khusus ujian"** tidak pernah muncul di mode Latihan, jadi kuncinya tidak bisa "dipanen" lewat latihan.
- Kunci akun setelah 5× salah password, batas laju (rate limit) yang dihitung per akun/token — bukan per IP — supaya satu Wi-Fi sekolah dengan ratusan siswa tidak saling memblokir, header keamanan (helmet), CORS terbatas, password bcrypt, wajib ganti password awal, log aktivitas (audit).

**Fitur sekolah yang dulu belum ada**
- Panel web guru/admin: kelola siswa & kelas, **impor siswa dari CSV** (password acak + kartu login siap cetak), bank soal (**impor CSV**), mapel sekolah sendiri (bukan hanya UTBK), buat ujian terjadwal, **pantau ujian langsung** (siapa mengerjakan / terputus / melanggar), tambah waktu, kumpulkan paksa, izinkan ulang, **hasil + peringkat + ekspor Excel/CSV + analisis butir soal**, log aktivitas.
- Sesi login tersimpan (tidak login ulang tiap buka), ganti password, login memakai NIS.

---

## 2. Pasang di komputer sendiri (uji coba / Windows + Laragon)

Syarat: Node.js 20+, MySQL/MariaDB (Laragon sudah termasuk).

```bash
cd backend
npm install
copy .env.example .env        # lalu isi DB_* dan JWT_SECRET (lihat petunjuk di dalam file)
npm run migrate:demo          # membuat tabel + akun demo (guru & siswa)
npm start
```

- Panel guru: <http://127.0.0.1:3000/admin> — login `guru@adanando.com` / `Guru12345` (akun demo).
- Admin pertama dibuat otomatis; **password-nya tampil sekali di layar migrasi**. Bila Anda memakai database lama, akun `admin@adanando.com / admin123` otomatis ditandai **wajib ganti password**.
- Uji otomatis (membuat data uji, jangan di database produksi): `npm test`.

Aplikasi siswa (development): `cd frontend && flutter pub get && flutter run -d chrome`
(isi `frontend/.env` dengan `API_BASE_URL=http://127.0.0.1:3000/api/v1`).

> Database lama otomatis ditingkatkan oleh `npm run migrate` (kolom baru ditambah, data lama aman).

---

## 3. Pasang untuk sekolah (server sungguhan, HTTPS)

**Disarankan:** VPS kecil (2 vCPU / 2 GB RAM; pada uji beban saya, 150 siswa mulai ujian bersamaan + menyimpan jawaban terus-menerus berjalan tanpa error di satu mesin — hasil di server Anda bisa berbeda, uji dulu dengan jumlah siswa sebenarnya) + domain. HTTPS **wajib** agar bisa dipasang di iPhone dan agar kata sandi tidak terbaca di Wi-Fi.

```bash
# di laptop developer: bangun aplikasi web siswa (sekali tiap ada pembaruan)
cd frontend
flutter pub get
flutter build web --release --no-web-resources-cdn   # tanpa CDN Google: jalan juga di jaringan sekolah yang terbatas

# di server
cp .env.docker.example .env      # isi DOMAIN, password DB, JWT_SECRET
docker compose up -d --build
```

Caddy mengurus sertifikat HTTPS (Let's Encrypt) otomatis. Arahkan DNS domain ke IP server, buka `https://domain/admin`.
Tanpa Docker: jalankan `backend` dengan `NODE_ENV=production`, isi `WEB_DIR=../frontend/build/web`, dan taruh Nginx/Caddy/Cloudflare Tunnel di depannya.

**Cadangan (backup)** — jalankan harian lewat cron:
`docker compose exec db sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" db_utbk' > backup-$(date +%F).sql`

---

## 4. Cara siswa memakai

| Perangkat | Cara |
|---|---|
| **Laptop / PC Windows, Chromebook, Mac** | Buka alamat di Chrome/Edge → ⋮ → *Instal AdaNando* (opsional). Ujian otomatis minta layar penuh. |
| **iPhone / iPad** | Buka alamat di **Safari** → tombol Bagikan → **Tambah ke Layar Utama**. Muncul seperti aplikasi biasa. |
| **Android** | Buka di Chrome → *Instal aplikasi*, atau pasang APK (`flutter build apk --release`). APK memblokir screenshot. |

Catatan iPhone: ikon & ujian jalan penuh sebagai PWA. Aplikasi iOS asli (App Store/TestFlight) butuh Mac + akun Apple Developer (US$99/tahun) — tidak diperlukan untuk memakai sistem ini.
Siswa tanpa perangkat → sekolah menyediakan laptop lab; cukup buka alamat web yang sama.

---

## 5. Alur hari-H ujian

1. **H-7:** Siswa → *Impor CSV* → unduh/cetak kartu login (NIS + password sementara). Siswa login sekali & ganti password.
2. **H-3:** Bank Soal → tambah/impor soal, set pemakaian **ujian**. Ujian → *Buat Ujian* → pilih kelas, jadwal, durasi, jumlah soal, batas pelanggaran (disarankan 3). Cek peringatan bank soal. Klik *Terbitkan*.
3. **H-1:** Uji coba dengan 2–3 siswa pada perangkat yang berbeda (laptop, iPhone, Android).
4. **Hari-H:** Buka *Pantau Ujian*. Bagikan **token** (6 karakter, tertera di daftar ujian) di ruangan. Siswa terputus → otomatis lanjut saat tersambung; bila perlu **+Waktu**.
5. **Selesai:** *Tutup* ujian (yang belum selesai dikumpulkan paksa, pembahasan terbuka). *Hasil* → **Unduh CSV (Excel)**; periksa *analisis butir soal* untuk soal yang kuncinya mungkin keliru.

---

## 6. Batasan yang jujur (harap dibaca)

Tidak ada sistem ujian online yang **100% tahan curang**. Yang dilakukan sistem ini: membuat curang **jauh lebih sulit dan tercatat**:

- **Screenshot/foto layar.** Android APK memblokirnya. Di web/iPhone browser **tidak bisa memblokir**; yang ada hanya blur saat fokus hilang, tanda air nama+NIS, dan pelanggaran tercatat. Foto dari HP lain tidak terdeteksi — itu sebabnya soal diacak per siswa dan tanda air dipasang.
- **Bantuan orang lain / HP kedua / AI.** Tidak terdeteksi perangkat lunak. Pengawas ruangan tetap perlu. Gunakan jadwal ketat, soal acak, dan batas waktu.
- **Pelanggaran di iPhone:** iOS menidurkan Safari saat pindah aplikasi; kejadian terlapor begitu siswa kembali (dan tercatat saat itu).
- **Kode klien bisa dibuka orang yang ahli**, tetapi karena kunci & nilai ada di server, hal terburuk yang bisa dilakukannya adalah mematikan deteksi pelanggaran — bukan mengubah nilai atau mengambil kunci.
- Soal yang **ikut diberi status "latihan/semua"** terlihat kuncinya di mode Latihan. Soal ujian sungguhan → status **ujian**.

## 7. Yang belum bisa saya uji di sini (jujur)

Saya menguji **backend & panel web** secara otomatis (69 pengujian + uji tampilan panel). Kode **Flutter** ditulis dengan teliti dan diperiksa kesesuaian sintaksnya,
tetapi **belum saya kompilasi** karena SDK Flutter tidak tersedia di lingkungan saya. Jalankan di komputer Anda:
`flutter pub get && flutter analyze && flutter test` — bila ada pesan error/peringatan, kirimkan ke saya untuk diperbaiki.
Uji juga langsung di iPhone dan Android sebelum hari-H.
