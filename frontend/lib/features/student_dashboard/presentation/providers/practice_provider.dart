import 'package:flutter/foundation.dart';

import '../../data/models/question.dart';
import '../../data/models/subtest.dart';
import '../../data/practice_repository.dart';

/// Satu soal beserta jawaban yang dipilih siswa (untuk halaman hasil).
class AnswerReview {
  const AnswerReview({required this.question, required this.selectedIndex});

  final Question question;
  final int selectedIndex;

  bool get isCorrect => selectedIndex == question.correctIndex;
}

/// Ringkasan hasil satu sesi latihan.
class PracticeResult {
  const PracticeResult({required this.subtest, required this.reviews});

  final Subtest subtest;
  final List<AnswerReview> reviews;

  int get total => reviews.length;
  int get correct => reviews.where((r) => r.isCorrect).length;
  int get wrong => total - correct;
  double get accuracy => total == 0 ? 0 : correct / total;

  /// Poin dengan aturan: benar +4, salah −1.
  int get points => correct * 4 - wrong;
}

/// State satu sesi latihan. Dibuat baru setiap siswa membuka sebuah subtes.
class PracticeProvider extends ChangeNotifier {
  PracticeProvider({required this.subtest, PracticeRepository? repository})
    : _repository = repository ?? SamplePracticeRepository();

  final Subtest subtest;
  final PracticeRepository _repository;

  bool isLoading = true;
  String? errorMessage;
  List<Question> questions = const [];
  int currentIndex = 0;

  final Map<int, int> _selected = {}; // indeks soal -> indeks opsi
  final Set<int> _checked = {}; // soal yang sudah diperiksa
  bool _disposed = false;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    _notify();

    try {
      questions = await _repository.getQuestions(subtest.id);
      currentIndex = 0;
      _selected.clear();
      _checked.clear();
    } catch (_) {
      errorMessage = 'Gagal memuat soal. Coba lagi.';
    }

    isLoading = false;
    _notify();
  }

  bool get hasQuestions => questions.isNotEmpty;
  Question get current => questions[currentIndex];
  int? get selectedIndex => _selected[currentIndex];
  bool get isChecked => _checked.contains(currentIndex);
  bool get isLast => currentIndex >= questions.length - 1;

  /// True jika siswa sudah memeriksa minimal satu soal.
  bool get hasProgress => _checked.isNotEmpty;

  double get progress =>
      questions.isEmpty ? 0 : _checked.length / questions.length;

  void select(int optionIndex) {
    if (!hasQuestions || isChecked) return;
    _selected[currentIndex] = optionIndex;
    _notify();
  }

  void check() {
    if (!hasQuestions || isChecked || selectedIndex == null) return;
    _checked.add(currentIndex);
    _notify();
  }

  void next() {
    if (!isChecked || isLast) return;
    currentIndex++;
    _notify();
  }

  PracticeResult buildResult() {
    final reviews = <AnswerReview>[];
    for (var i = 0; i < questions.length; i++) {
      final selected = _selected[i];
      if (_checked.contains(i) && selected != null) {
        reviews.add(
          AnswerReview(question: questions[i], selectedIndex: selected),
        );
      }
    }
    return PracticeResult(subtest: subtest, reviews: reviews);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
