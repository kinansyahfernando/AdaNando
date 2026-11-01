import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/bank_lookup.dart';
import '../../data/models/question.dart';
import '../../data/models/session_result.dart';
import '../providers/room_provider.dart';
import 'session_result_page.dart';
import 'timed_quiz_page.dart';

/// Ujian Belajar Bareng. Waktu dihitung dari jam server sehingga
/// semua peserta selesai bersamaan.
class RoomQuizPage extends StatefulWidget {
  const RoomQuizPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const RoomQuizPage());
  }

  @override
  State<RoomQuizPage> createState() => _RoomQuizPageState();
}

class _RoomQuizPageState extends State<RoomQuizPage> {
  late final RoomProvider _provider;
  late final List<Question> _questions;
  late final String _code;
  late final String _subtestId;

  @override
  void initState() {
    super.initState();
    _provider = context.read<RoomProvider>();
    final room = _provider.room;
    _code = room?.code ?? '';
    _subtestId = room?.subtestId ?? mixSubtestId;
    _questions = BankLookup.resolve(room?.questionIds ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    final subtest = BankLookup.subtestById(_subtestId);

    return TimedQuizPage(
      title: 'Belajar Bareng · ${subtest.code}',
      subtest: subtest,
      questions: _questions,
      remainingSeconds: () => _provider.remainingSeconds,
      onLeave: _provider.reset,
      onFinish: (answers) async {
        final result = SessionResult(
          subtest: subtest,
          questions: _questions,
          answers: answers,
        );

        final ok = await _provider.submitAnswers(
          answers: result.answersById,
          correct: result.correct,
          wrong: result.wrong,
        );
        if (!ok) return null;

        return MaterialPageRoute<void>(
          builder: (_) => SessionResultPage(result: result, roomCode: _code),
        );
      },
    );
  }
}
