import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'models/subtest.dart';
import 'subtest_catalog.dart';

/// ID pilihan "UTBK" di Buat Room: soal + waktu dikunci sama seperti UTBK
/// (7 subtes berurutan, 160 soal, 195 menit). Harus sama dengan di backend.
const String utbkSubtestId = 'utbk';

/// Jumlah soal & waktu UTBK (sesuai backend/src/modules/tryout/tryout.config.js).
const int utbkTotalQuestions = 160;
const int utbkTotalSeconds = 195 * 60;

/// Pilihan "UTBK": semua subtes dalam satu sesi, soal dan waktu mengikuti UTBK.
const Subtest utbkSubtest = Subtest(
  id: utbkSubtestId,
  code: 'UTBK',
  name: 'UTBK Lengkap',
  description:
      '7 subtes berurutan, 160 soal, 195 menit. Soal dan waktu sama seperti UTBK.',
  icon: Icons.school_rounded,
  color: AppColors.bareng,
);

/// Hanya untuk menampilkan room lama yang dibuat dengan pilihan "Campuran"
/// (tidak lagi tersedia di pilihan Buat Room).
const Subtest _legacyMixSubtest = Subtest(
  id: 'mix',
  code: 'MIX',
  name: 'Campuran Semua Subtes',
  description: 'Soal acak dari seluruh subtes UTBK.',
  icon: Icons.shuffle,
  color: AppColors.bareng,
);

/// Katalog tampilan subtes. Soal TIDAK disimpan di aplikasi: semua soal dan kunci
/// jawaban berada di server (lihat repository latihan / ujian / room).
class BankLookup {
  BankLookup._();

  static List<Subtest> get allSubtests => [
    for (final c in SubtestCatalog.categories) ...c.subtests,
  ];

  /// Urutan pilihan di layar: UTBK dulu, lalu semua subtes.
  static List<Subtest> get choices => [utbkSubtest, ...allSubtests];

  static Subtest subtestById(String id) {
    if (id == utbkSubtestId) return utbkSubtest;
    if (id == 'mix') return _legacyMixSubtest;
    for (final s in allSubtests) {
      if (s.id == id) return s;
    }
    return utbkSubtest;
  }

  /// Subtes untuk tampilan ujian. Mapel buatan sekolah (bukan UTBK) tidak ada di
  /// katalog, jadi dibuatkan tampilan umum dari nama yang dikirim server.
  static Subtest forSection(String id, String name) {
    for (final s in allSubtests) {
      if (s.id == id) return s;
    }
    final code = name.trim().isEmpty
        ? id.toUpperCase()
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .map((w) => w.isEmpty ? '' : w[0])
              .take(4)
              .join()
              .toUpperCase();
    return Subtest(
      id: id,
      code: code,
      name: name,
      description: name,
      icon: Icons.school_outlined,
      color: AppColors.primary,
    );
  }
}
