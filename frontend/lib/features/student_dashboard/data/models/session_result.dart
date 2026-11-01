import 'question.dart';
import 'subtest.dart';

/// Hasil satu sesi try out (mandiri maupun Belajar Bareng).
/// Soal yang tidak dijawab tidak mendapat poin (tidak dihitung salah).
class SessionResult {
  const SessionResult({
    required this.subtest,
    required this.questions,
    required this.answers,
  });

  final Subtest subtest;
  final List<Question> questions;

  /// indeks soal -> indeks opsi yang dipilih
  final Map<int, int> answers;

  int get total => questions.length;

  int get correct {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] == questions[i].correctIndex) n++;
    }
    return n;
  }

  int get wrong {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      final picked = answers[i];
      if (picked != null && picked != questions[i].correctIndex) n++;
    }
    return n;
  }

  int get blank => total - correct - wrong;

  /// Benar +4, salah −1, kosong 0 (sama seperti halaman latihan).
  int get points => correct * 4 - wrong;

  double get accuracy => total == 0 ? 0 : correct / total;

  /// Dikirim ke server: id soal -> indeks opsi.
  Map<String, int> get answersById {
    final map = <String, int>{};
    answers.forEach((index, picked) {
      if (index >= 0 && index < questions.length) {
        map[questions[index].id] = picked;
      }
    });
    return map;
  }
}
