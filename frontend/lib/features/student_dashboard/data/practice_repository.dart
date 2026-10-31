import 'models/question.dart';
import 'sample_question_bank.dart';

/// Sumber soal latihan. Saat ini memakai soal contoh lokal.
/// Nanti cukup buat `ApiPracticeRepository` (panggil backend lewat DioClient)
/// dan ganti implementasi yang dipakai di PracticeProvider.
abstract class PracticeRepository {
  Future<List<Question>> getQuestions(String subtestId);
}

class SamplePracticeRepository implements PracticeRepository {
  @override
  Future<List<Question>> getQuestions(String subtestId) async {
    // Simulasi jeda jaringan singkat
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final questions = sampleQuestionBank[subtestId] ?? const <Question>[];
    return List<Question>.of(questions);
  }
}
