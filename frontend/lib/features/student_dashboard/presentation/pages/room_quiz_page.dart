import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/bank_lookup.dart';
import '../../data/models/question.dart';
import '../../data/models/session_result.dart';
import '../providers/room_provider.dart';
import 'session_result_page.dart';
import 'timed_quiz_page.dart';

/// Ujian Belajar Bareng. Soal diambil dari server (tanpa kunci), waktu dihitung
/// dari jam server sehingga semua peserta selesai bersamaan, dan nilai dihitung server.
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
  late final String _code;
  late final String _subtestId;
  List<Question>? _questions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = context.read<RoomProvider>();
    final room = _provider.room;
    _code = room?.code ?? '';
    _subtestId = room?.subtestId ?? utbkSubtestId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _provider.loadQuestions();
      if (!mounted) return;
      setState(() => _questions = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtest = BankLookup.subtestById(_subtestId);
    final questions = _questions;

    if (questions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Belajar Bareng')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 56, color: AppColors.muted),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                ),
        ),
      );
    }

    return TimedQuizPage(
      title: 'Belajar Bareng · ${subtest.code}',
      subtest: subtest,
      questions: questions,
      remainingSeconds: () => _provider.remainingSeconds,
      onLeave: _provider.reset,
      onFinish: (answers) async {
        final draft = SessionResult(
          subtest: subtest,
          questions: questions,
          answers: answers,
        );

        // Server menilai dari jawaban mentah; angka dari aplikasi tidak dipakai.
        final ok = await _provider.submitAnswers(answers: draft.answersById);
        if (!ok) return null;

        final me = _provider.room?.me;
        final result = SessionResult(
          subtest: subtest,
          questions: questions,
          answers: answers,
          fixedTotal: questions.length,
          fixedCorrect: me?.correct,
          fixedWrong: me?.wrong,
        );

        return MaterialPageRoute<void>(
          builder: (_) => SessionResultPage(result: result, roomCode: _code),
        );
      },
    );
  }
}
