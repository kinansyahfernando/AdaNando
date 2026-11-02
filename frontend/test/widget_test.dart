import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/student_dashboard/data/models/question.dart';
import 'package:frontend/features/student_dashboard/data/models/session_result.dart';
import 'package:frontend/features/student_dashboard/data/models/tryout.dart';
import 'package:frontend/features/student_dashboard/data/bank_lookup.dart';

/// Uji model murni (tanpa platform). Jalankan: flutter test
void main() {
  group('Soal selama ujian', () {
    test('tidak membawa kunci jawaban', () {
      final q = Question.fromJson({
        'id': 7,
        'text': 'Contoh?',
        'options': ['a', 'b', 'c', 'd'],
      }, subtestId: 'pu');

      expect(q.hasKey, isFalse);
      expect(q.correctIndex, -1);
      expect(q.explanation, isEmpty);
      expect(q.correctLabel, '-');
    });

    test('kunci baru terisi lewat withKey', () {
      final q = const Question(
        id: '1',
        subtestId: 'pu',
        text: 'x',
        options: ['a', 'b'],
      ).withKey(correctIndex: 1, explanation: 'karena b');

      expect(q.hasKey, isTrue);
      expect(q.correctLabel, 'B');
      expect(q.explanation, 'karena b');
    });
  });

  group('Respons server', () {
    test('SectionData: urutan soal dan jawaban tersimpan', () {
      final data = SectionData.fromJson({
        'sectionIndex': 1,
        'subtest': {'id': 'pu', 'name': 'Penalaran Umum'},
        'questions': [
          {'text': 'S1', 'options': ['a', 'b']},
          {'text': 'S2', 'options': ['c', 'd']},
        ],
        'answers': {'1': 0},
        'endsAt': 1000,
        'serverNow': 500,
      });

      expect(data.sectionIndex, 1);
      expect(data.questions.length, 2);
      expect(data.questions.first.hasKey, isFalse);
      expect(data.answers, {1: 0});
    });

    test('TryoutState: nilai tersembunyi bila server tidak mengirim', () {
      final s = TryoutState.fromJson({
        'attempt': {
          'id': 3,
          'status': 'finished',
          'currentSection': 0,
          'endReason': 'violation',
          'violations': 3,
          'maxViolations': 3,
        },
        'exam': {
          'id': 9,
          'title': 'Ulangan',
          'kind': 'sekolah',
          'sections': [
            {'id': 'pu', 'name': 'PU', 'questions': 10, 'seconds': 600},
          ],
        },
        'result': null,
        'reviewAvailable': false,
      });

      expect(s.isFinished, isTrue);
      expect(s.endReason, 'violation');
      expect(s.result, isNull);
      expect(s.totalQuestions, 10);
    });

    test('ExamScore dibaca apa adanya dari server', () {
      final score = ExamScore.fromJson({
        'total': 4,
        'correct': 3,
        'wrong': 1,
        'points': 11,
        'score': 75,
        'sections': [
          {'id': 'pu', 'name': 'PU', 'total': 4, 'correct': 3, 'wrong': 1, 'points': 11, 'worked': true},
        ],
      });

      expect(score.points, 11);
      expect(score.blank, 0);
      expect(score.sections.single.worked, isTrue);
    });
  });

  group('SessionResult', () {
    test('memakai angka server bila pembahasan belum dibuka', () {
      final r = SessionResult(
        subtest: BankLookup.forSection('pu', 'Penalaran Umum'),
        questions: const [],
        answers: const {},
        fixedTotal: 10,
        fixedCorrect: 7,
        fixedWrong: 2,
      );

      expect(r.hasReview, isFalse);
      expect(r.correct, 7);
      expect(r.wrong, 2);
      expect(r.blank, 1);
      expect(r.points, 26);
    });

    test('mapel buatan sekolah mendapat tampilan umum', () {
      final s = BankLookup.forSection('mtk-xi', 'Matematika Kelas XI');
      expect(s.id, 'mtk-xi');
      expect(s.code, 'MKX');
    });
  });
}
