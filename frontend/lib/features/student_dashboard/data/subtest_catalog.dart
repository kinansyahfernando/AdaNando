import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'models/subtest.dart';

/// Daftar kategori dan subtes UTBK yang tampil di beranda siswa.
class SubtestCatalog {
  SubtestCatalog._();

  static const List<SubtestCategory> categories = [
    SubtestCategory(
      id: 'tps',
      title: 'Tes Potensi Skolastik (TPS)',
      description: 'Mengukur kemampuan kognitif, logika, dan penalaran.',
      icon: Icons.lightbulb_outline,
      color: AppColors.tps,
      subtests: [
        Subtest(
          id: 'pu',
          code: 'PU',
          name: 'Penalaran Umum',
          description: 'Penalaran induktif, deduktif, dan kuantitatif untuk memecahkan masalah secara logis.',
          icon: Icons.psychology_outlined,
          color: AppColors.tps,
        ),
        Subtest(
          id: 'ppu',
          code: 'PPU',
          name: 'Pengetahuan dan Pemahaman Umum',
          description: 'Memahami bahasa, kosakata, bentuk kata, dan makna dalam konteks Indonesia.',
          icon: Icons.menu_book_outlined,
          color: AppColors.tps,
        ),
        Subtest(
          id: 'pbm',
          code: 'PBM',
          name: 'Pemahaman Bacaan dan Menulis',
          description: 'Memahami wacana tertulis, tata tulis, ejaan, dan kalimat efektif.',
          icon: Icons.edit_note_outlined,
          color: AppColors.tps,
        ),
        Subtest(
          id: 'pk',
          code: 'PK',
          name: 'Pengetahuan Kuantitatif',
          description: 'Konsep matematika dasar: bilangan, aljabar, geometri, statistika, dan peluang.',
          icon: Icons.calculate_outlined,
          color: AppColors.tps,
        ),
      ],
    ),
    SubtestCategory(
      id: 'literasi',
      title: 'Tes Literasi',
      description: 'Menguji kemampuan menganalisis, mengevaluasi, dan memahami isi teks.',
      icon: Icons.auto_stories_outlined,
      color: AppColors.literasi,
      subtests: [
        Subtest(
          id: 'lbi',
          code: 'LBI',
          name: 'Literasi Bahasa Indonesia',
          description:
              'Membaca, memahami, dan menyimpulkan teks berbahasa Indonesia.',
          icon: Icons.auto_stories_outlined,
          color: AppColors.literasi,
        ),
        Subtest(
          id: 'lbe',
          code: 'LBE',
          name: 'Literasi Bahasa Inggris',
          description: 'Memahami bacaan, kosakata, serta informasi tersurat dan tersirat dalam bahasa Inggris.',
          icon: Icons.translate,
          color: AppColors.literasi,
        ),
      ],
    ),
    SubtestCategory(
      id: 'penalaran',
      title: 'Penalaran Matematika',
      description:
          'Menerapkan konsep matematika untuk memecahkan masalah sehari-hari.',
      icon: Icons.functions,
      color: AppColors.penalaran,
      subtests: [
        Subtest(
          id: 'pm',
          code: 'PM',
          name: 'Penalaran Matematika',
          description: 'Penerapan bilangan, aljabar, geometri, data, dan ketidakpastian dalam kehidupan sehari-hari.',
          icon: Icons.functions,
          color: AppColors.penalaran,
        ),
      ],
    ),
  ];

  static int get totalSubtests =>
      categories.fold<int>(0, (sum, c) => sum + c.subtests.length);
}
