import 'models/question.dart';

/// Soal contoh (sementara) agar alur latihan bisa dicoba tanpa backend.
/// Nanti diganti dengan soal dari database lewat ApiPracticeRepository.
final Map<String, List<Question>> sampleQuestionBank = {
  // ───────────────────────── Penalaran Umum ─────────────────────────
  'pu': [
    const Question(
      id: 'pu-1',
      subtestId: 'pu',
      text: 'Semua pelajar yang rajin lulus ujian. Sebagian pelajar di kelas X rajin. Kesimpulan yang pasti benar adalah …',
      options: [
        'Semua pelajar di kelas X lulus ujian.',
        'Sebagian pelajar di kelas X lulus ujian.',
        'Tidak ada pelajar di kelas X yang lulus ujian.',
        'Semua pelajar yang lulus ujian adalah pelajar rajin.',
        'Sebagian pelajar di kelas X tidak rajin.',
      ],
      correctIndex: 1,
      explanation: 'Sebagian pelajar kelas X rajin, dan setiap pelajar rajin pasti lulus ujian. Jadi sebagian pelajar kelas X pasti lulus ujian. Pilihan D membalik premis (kekeliruan konversi), sedangkan A dan E tidak dapat dipastikan dari premis yang ada.',
    ),
    const Question(
      id: 'pu-2',
      subtestId: 'pu',
      text: 'Perhatikan pola bilangan berikut: 2, 6, 12, 20, 30, … Bilangan berikutnya adalah …',
      options: ['38', '40', '41', '42', '44'],
      correctIndex: 3,
      explanation: 'Selisih antarsuku: 4, 6, 8, 10, sehingga selisih berikutnya 12. Suku berikutnya 30 + 12 = 42. Pola ini juga dapat ditulis n × (n + 1): 1×2, 2×3, 3×4, 4×5, 5×6, lalu 6×7 = 42.',
    ),
    const Question(
      id: 'pu-3',
      subtestId: 'pu',
      text: 'Dalam sebuah lomba lari, Andi finis sebelum Budi, Citra finis setelah Budi, dan Dedi finis sebelum Andi. Siapa yang finis paling akhir?',
      options: ['Andi', 'Budi', 'Citra', 'Dedi', 'Tidak dapat ditentukan'],
      correctIndex: 2,
      explanation: 'Urutan dari yang tercepat: Dedi → Andi → Budi → Citra. Jadi Citra finis paling akhir.',
    ),
  ],

  // ─────────────── Pengetahuan dan Pemahaman Umum ───────────────
  'ppu': [
    const Question(
      id: 'ppu-1',
      subtestId: 'ppu',
      text: 'Kata baku yang penulisannya tepat adalah …',
      options: ['aktifitas', 'analisa', 'apotik', 'risiko', 'kwitansi'],
      correctIndex: 3,
      explanation: 'Bentuk bakunya: aktivitas, analisis, apotek, risiko, dan kuitansi. Dari pilihan yang ada, hanya “risiko” yang sudah baku.',
    ),
    const Question(
      id: 'ppu-2',
      subtestId: 'ppu',
      text: 'Makna kata “mitigasi” dalam konteks kebencanaan adalah …',
      options: [
        'peringatan dini sebelum bencana terjadi',
        'upaya mengurangi risiko dan dampak bencana',
        'penanganan korban saat bencana terjadi',
        'pemulihan kondisi setelah bencana',
        'penelitian tentang penyebab bencana',
      ],
      correctIndex: 1,
      explanation: 'Mitigasi berarti tindakan mengurangi risiko atau dampak bencana, baik melalui pembangunan fisik maupun penyadaran dan peningkatan kemampuan menghadapi bencana.',
    ),
    const Question(
      id: 'ppu-3',
      subtestId: 'ppu',
      text: 'Bentuk kata yang tepat dari kata dasar “sukses” dengan imbuhan me-kan adalah …',
      options: [
        'mensukseskan',
        'menyukseskan',
        'memsukseskan',
        'menyuksesi',
        'mensuksesi',
      ],
      correctIndex: 1,
      explanation: 'Huruf awal s pada kata dasar luluh ketika mendapat awalan me-, sehingga menjadi “menyukseskan”. Bentuk “mensukseskan” tidak baku.',
    ),
  ],

  // ─────────────── Pemahaman Bacaan dan Menulis ───────────────
  'pbm': [
    const Question(
      id: 'pbm-1',
      subtestId: 'pbm',
      text: 'Kalimat berikut yang efektif adalah …',
      options: [
        'Para peserta-peserta seminar telah hadir di ruangan.',
        'Banyak para siswa yang mengikuti lomba itu.',
        'Pemerintah menaikkan anggaran pendidikan tahun ini.',
        'Daripada itu, kami memutuskan untuk berangkat lebih awal.',
        'Adalah merupakan kewajiban kita menjaga lingkungan.',
      ],
      correctIndex: 2,
      explanation: 'Pilihan A dan B boros makna: “para” sudah menyatakan jamak, jadi tidak perlu “peserta-peserta” atau “banyak para”. D salah memakai “daripada itu”, seharusnya “oleh karena itu”. E memakai “adalah merupakan” yang berlebihan. Hanya C yang singkat, jelas, dan tidak berlebihan.',
    ),
    const Question(
      id: 'pbm-2',
      subtestId: 'pbm',
      text: 'Penulisan kalimat yang sesuai kaidah ejaan adalah …',
      options: [
        'Buku itu diletakkan di atas meja.',
        'Buku itu di letakkan di atas meja.',
        'Buku itu diletakkan diatas meja.',
        'Buku itu di letakkan diatas meja.',
        'Buku itu diletakan di atas meja.',
      ],
      correctIndex: 0,
      explanation: '“diletakkan” adalah kata kerja pasif sehingga di- ditulis serangkai. “di atas” menunjukkan tempat sehingga “di” ditulis terpisah. Kata dasarnya “letak”, dan bentuk dengan me-kan yang benar memakai dua huruf k: “diletakkan” (bukan “diletakan”).',
    ),
    const Question(
      id: 'pbm-3',
      subtestId: 'pbm',
      passage: 'Rendahnya minat baca masyarakat Indonesia bukan semata-mata disebabkan oleh kurangnya buku. Akses terhadap buku memang masih timpang, tetapi kebiasaan membaca juga tidak ditanamkan sejak dini di rumah maupun di sekolah. Anak-anak lebih sering melihat orang dewasa menatap layar gawai daripada membuka buku. Tanpa teladan, perpustakaan yang lengkap sekalipun akan sepi pengunjung.',
      text: 'Gagasan utama paragraf tersebut adalah …',
      options: [
        'Buku di Indonesia masih sangat mahal.',
        'Rendahnya minat baca disebabkan kurangnya teladan dan pembiasaan, bukan hanya minimnya buku.',
        'Perpustakaan di Indonesia selalu sepi pengunjung.',
        'Anak-anak tidak boleh menggunakan gawai.',
        'Orang dewasa tidak suka membaca buku.',
      ],
      correctIndex: 1,
      explanation: 'Kalimat pertama menyatakan inti paragraf: rendahnya minat baca tidak semata-mata karena kurangnya buku. Kalimat-kalimat berikutnya menjelaskan penyebab lain, yaitu kurangnya pembiasaan dan teladan. Pilihan lain hanya mengambil detail atau menarik kesimpulan yang berlebihan.',
    ),
  ],

  // ─────────────── Pengetahuan Kuantitatif ───────────────
  'pk': [
    const Question(
      id: 'pk-1',
      subtestId: 'pk',
      text: 'Jika 3x − 7 = 14, maka nilai 2x + 1 adalah …',
      options: ['11', '13', '15', '17', '19'],
      correctIndex: 2,
      explanation:
          '3x − 7 = 14 → 3x = 21 → x = 7. Maka 2x + 1 = 2(7) + 1 = 15.',
    ),
    const Question(
      id: 'pk-2',
      subtestId: 'pk',
      text: 'Rata-rata lima bilangan adalah 12. Jika salah satu bilangan, yaitu 20, dihapus, maka rata-rata empat bilangan yang tersisa adalah …',
      options: ['9', '10', '11', '12', '14'],
      correctIndex: 1,
      explanation: 'Jumlah lima bilangan = 5 × 12 = 60. Setelah 20 dihapus, jumlahnya 40. Rata-rata baru = 40 ÷ 4 = 10.',
    ),
    const Question(
      id: 'pk-3',
      subtestId: 'pk',
      text: 'Dua dadu dilempar bersamaan. Peluang munculnya jumlah mata dadu 7 adalah …',
      options: ['1/12', '1/9', '1/8', '1/6', '1/4'],
      correctIndex: 3,
      explanation: 'Ruang sampel = 6 × 6 = 36. Pasangan yang berjumlah 7: (1,6), (2,5), (3,4), (4,3), (5,2), (6,1) = 6 kejadian. Peluang = 6/36 = 1/6.',
    ),
  ],

  // ─────────────── Literasi Bahasa Indonesia ───────────────
  'lbi': [
    const Question(
      id: 'lbi-1',
      subtestId: 'lbi',
      passage: 'Pasar tradisional kerap dianggap kumuh dan kalah bersaing dengan minimarket. Padahal, pasar tradisional menyerap jutaan pedagang kecil dan menjadi tempat berputarnya ekonomi lokal. Sejumlah kota mulai merevitalisasi pasar dengan menata lorong, memperbaiki drainase, dan menyediakan pembayaran nontunai tanpa menghilangkan tawar-menawar yang menjadi ciri khasnya.',
      text: 'Simpulan yang paling tepat dari teks tersebut adalah …',
      options: [
        'Pasar tradisional sebaiknya digantikan oleh minimarket.',
        'Revitalisasi dapat memperbaiki pasar tradisional tanpa menghilangkan ciri khasnya.',
        'Pembayaran nontunai menghapus tradisi tawar-menawar.',
        'Pedagang kecil lebih memilih bekerja di minimarket.',
        'Kota-kota besar mulai menutup pasar tradisional.',
      ],
      correctIndex: 1,
      explanation: 'Teks menyebut pasar ditata dan dimodernisasi, tetapi tawar-menawar sebagai ciri khasnya tetap dipertahankan. Itulah inti simpulannya. Pilihan lain bertentangan dengan teks atau tidak disebutkan.',
    ),
    const Question(
      id: 'lbi-2',
      subtestId: 'lbi',
      passage: 'Pasar tradisional kerap dianggap kumuh dan kalah bersaing dengan minimarket. Padahal, pasar tradisional menyerap jutaan pedagang kecil dan menjadi tempat berputarnya ekonomi lokal. Sejumlah kota mulai merevitalisasi pasar dengan menata lorong, memperbaiki drainase, dan menyediakan pembayaran nontunai tanpa menghilangkan tawar-menawar yang menjadi ciri khasnya.',
      text: 'Menurut teks, apa yang tetap dipertahankan dalam revitalisasi pasar tradisional?',
      options: [
        'Lorong yang sempit',
        'Drainase lama',
        'Pembayaran tunai saja',
        'Tradisi tawar-menawar',
        'Sistem harga pas',
      ],
      correctIndex: 3,
      explanation: 'Kalimat terakhir menyatakan revitalisasi dilakukan “tanpa menghilangkan tawar-menawar”, artinya tawar-menawar tetap dipertahankan.',
    ),
    const Question(
      id: 'lbi-3',
      subtestId: 'lbi',
      passage: 'Remaja membutuhkan tidur delapan hingga sepuluh jam setiap malam. Namun, survei menunjukkan banyak remaja tidur kurang dari tujuh jam karena tugas sekolah dan penggunaan gawai hingga larut malam. Kurang tidur terbukti menurunkan konsentrasi, memicu perubahan suasana hati, dan melemahkan daya ingat.',
      text: 'Pernyataan yang sesuai dengan isi teks adalah …',
      options: [
        'Remaja cukup tidur selama enam jam setiap malam.',
        'Kurang tidur dapat melemahkan daya ingat.',
        'Gawai tidak memengaruhi waktu tidur remaja.',
        'Tugas sekolah tidak berhubungan dengan jam tidur.',
        'Konsentrasi meningkat ketika remaja kurang tidur.',
      ],
      correctIndex: 1,
      explanation: 'Kalimat terakhir menyebut kurang tidur melemahkan daya ingat. Pilihan lain bertentangan dengan isi teks.',
    ),
  ],

  // ─────────────── Literasi Bahasa Inggris ───────────────
  'lbe': [
    const Question(
      id: 'lbe-1',
      subtestId: 'lbe',
      passage: 'Coral reefs cover less than one percent of the ocean floor, yet they support about a quarter of all marine species. Rising sea temperatures cause corals to expel the algae living in their tissues, turning them white in a process called bleaching. Without these algae, corals lose their main source of food and become more vulnerable to disease.',
      text: 'What is the main idea of the passage?',
      options: [
        'Coral reefs are the largest habitats in the ocean.',
        'Warming seas threaten coral reefs, which are vital for marine life.',
        'Algae are harmful to corals.',
        'Bleaching is a natural process that helps corals grow.',
        'Marine species do not depend on coral reefs.',
      ],
      correctIndex: 1,
      explanation: 'The passage explains that reefs support many marine species and that rising temperatures cause bleaching, which harms corals. Option B combines both points.',
    ),
    const Question(
      id: 'lbe-2',
      subtestId: 'lbe',
      passage: 'Coral reefs cover less than one percent of the ocean floor, yet they support about a quarter of all marine species. Rising sea temperatures cause corals to expel the algae living in their tissues, turning them white in a process called bleaching. Without these algae, corals lose their main source of food and become more vulnerable to disease.',
      text: 'According to the passage, why do bleached corals become more vulnerable to disease?',
      options: [
        'They absorb too much algae.',
        'They lose their main source of food.',
        'They grow too quickly.',
        'The ocean floor becomes less stable.',
        'Their white color attracts predators.',
      ],
      correctIndex: 1,
      explanation: 'The last sentence says that without the algae, corals lose their main source of food and become more vulnerable to disease.',
    ),
    const Question(
      id: 'lbe-3',
      subtestId: 'lbe',
      passage: 'Coral reefs cover less than one percent of the ocean floor, yet they support about a quarter of all marine species. Rising sea temperatures cause corals to expel the algae living in their tissues, turning them white in a process called bleaching. Without these algae, corals lose their main source of food and become more vulnerable to disease.',
      text: 'The word “vulnerable” in the passage is closest in meaning to …',
      options: [
        'strong',
        'exposed to harm',
        'colorful',
        'unknown',
        'resistant',
      ],
      correctIndex: 1,
      explanation: '“Vulnerable” means easily harmed or at risk, so “exposed to harm” is the closest meaning. “Strong” and “resistant” are its opposites.',
    ),
  ],

  // ─────────────── Penalaran Matematika ───────────────
  'pm': [
    const Question(
      id: 'pm-1',
      subtestId: 'pm',
      text: 'Sebuah toko memberi diskon 20% untuk sepatu yang harga awalnya Rp250.000. Karena membayar dengan kartu tertentu, pembeli mendapat potongan tambahan Rp15.000. Berapa rupiah yang harus dibayar pembeli?',
      options: [
        'Rp165.000',
        'Rp175.000',
        'Rp180.000',
        'Rp185.000',
        'Rp195.000',
      ],
      correctIndex: 3,
      explanation: 'Diskon 20% dari Rp250.000 = Rp50.000, sehingga harga menjadi Rp200.000. Dikurangi potongan tambahan Rp15.000 → Rp185.000.',
    ),
    const Question(
      id: 'pm-2',
      subtestId: 'pm',
      text: 'Budi bersepeda ke sekolah dengan kecepatan rata-rata 12 km/jam dan tiba dalam 30 menit. Agar tiba dalam 20 menit, kecepatan rata-rata yang diperlukan adalah …',
      options: [
        '12 km/jam',
        '15 km/jam',
        '16 km/jam',
        '18 km/jam',
        '20 km/jam',
      ],
      correctIndex: 3,
      explanation: 'Jarak = 12 × 0,5 jam = 6 km. Waktu baru = 20 menit = 1/3 jam. Kecepatan = 6 ÷ (1/3) = 18 km/jam.',
    ),
    const Question(
      id: 'pm-3',
      subtestId: 'pm',
      text: 'Nilai lima siswa adalah 70, 75, 80, 85, dan 90. Jika setiap siswa mendapat tambahan nilai 5, pernyataan yang benar adalah …',
      options: [
        'Rata-rata dan jangkauan sama-sama naik 5.',
        'Rata-rata naik 5, sedangkan jangkauan tetap 20.',
        'Rata-rata tetap 80, sedangkan jangkauan naik 5.',
        'Rata-rata dan jangkauan sama-sama tetap.',
        'Rata-rata naik 10, sedangkan jangkauan tetap 20.',
      ],
      correctIndex: 1,
      explanation: 'Rata-rata awal 80 dan jangkauan 90 − 70 = 20. Setelah semua nilai ditambah 5, rata-rata menjadi 85 (naik 5), sedangkan jangkauan tetap 95 − 75 = 20 karena selisih antarnilai tidak berubah.',
    ),
  ],
};
