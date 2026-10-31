import 'package:flutter/material.dart';

/// Satu subtes UTBK (mis. Penalaran Umum).
class Subtest {
  const Subtest({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  /// ID unik, juga dipakai untuk mengambil soal (mis. 'pu', 'pm').
  final String id;

  /// Singkatan yang tampil di kartu (mis. 'PU').
  final String code;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
}

/// Kelompok subtes (TPS, Tes Literasi, Penalaran Matematika).
class SubtestCategory {
  const SubtestCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.subtests,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<Subtest> subtests;
}
