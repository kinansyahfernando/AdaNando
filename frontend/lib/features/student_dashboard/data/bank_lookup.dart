import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'models/question.dart';
import 'models/subtest.dart';
import 'sample_question_bank.dart';
import 'subtest_catalog.dart';

const String mixSubtestId = 'mix';

/// Pilihan "Campuran": soal acak dari semua subtes.
const Subtest mixSubtest = Subtest(
  id: mixSubtestId,
  code: 'MIX',
  name: 'Campuran Semua Subtes',
  description: 'Soal acak dari seluruh subtes UTBK.',
  icon: Icons.shuffle,
  color: AppColors.bareng,
);

/// Pencarian subtes & soal dari bank soal lokal.
/// Saat soal sudah pindah ke database, cukup ganti isi file ini.
class BankLookup {
  BankLookup._();

  static List<Subtest> get allSubtests => [
    for (final c in SubtestCatalog.categories) ...c.subtests,
  ];

  /// Urutan pilihan di layar: Campuran dulu, lalu semua subtes.
  static List<Subtest> get choices => [mixSubtest, ...allSubtests];

  static Subtest subtestById(String id) {
    if (id == mixSubtestId) return mixSubtest;
    for (final s in allSubtests) {
      if (s.id == id) return s;
    }
    return mixSubtest;
  }

  static List<Question> _poolOf(String subtestId) {
    if (subtestId == mixSubtestId) {
      return [for (final list in sampleQuestionBank.values) ...list];
    }
    return List<Question>.of(sampleQuestionBank[subtestId] ?? const []);
  }

  /// Jumlah soal yang tersedia untuk subtes tertentu.
  static int availableCount(String subtestId) => _poolOf(subtestId).length;

  /// Ambil [count] soal acak dari subtes.
  static List<Question> pick(String subtestId, int count) {
    final pool = _poolOf(subtestId)..shuffle(Random());
    return pool.take(count).toList();
  }

  /// Ambil tepat [count] soal. Bila bank soal kurang, soal diulang (diacak
  /// ulang tiap putaran). Dipakai Try Out Mandiri selama bank soal masih sedikit.
  static List<Question> pickCycled(String subtestId, int count) {
    final base = _poolOf(subtestId);
    if (base.isEmpty) return const [];

    final random = Random();
    final result = <Question>[];
    while (result.length < count) {
      result.addAll(List<Question>.of(base)..shuffle(random));
    }
    return result.take(count).toList();
  }

  /// Ubah daftar id soal (dari server) menjadi soal lengkap, urutan dipertahankan.
  static List<Question> resolve(List<String> ids) {
    final byId = <String, Question>{
      for (final list in sampleQuestionBank.values)
        for (final q in list) q.id: q,
    };
    return ids.map((id) => byId[id]).whereType<Question>().toList();
  }
}
