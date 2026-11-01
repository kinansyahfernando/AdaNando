import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/tryout_session.dart';
import 'timed_quiz_page.dart';
import 'tryout_result_page.dart';

/// Satu subtes dalam Try Out. Mode ketat: keluar aplikasi / pindah tab
/// otomatis mengumpulkan dan mengakhiri seluruh try out.
class TryoutSectionPage extends StatefulWidget {
  const TryoutSectionPage({
    super.key,
    required this.session,
    required this.index,
  });

  final TryoutSession session;
  final int index;

  /// Route berikutnya sesuai status server: subtes yang sedang berjalan,
  /// atau halaman hasil bila try out sudah selesai.
  static Route<void> routeFor(TryoutSession session) {
    final state = session.state;
    if (state.isFinished || state.currentSection >= session.sections.length) {
      return TryoutResultPage.route(session);
    }
    return MaterialPageRoute<void>(
      builder: (_) =>
          TryoutSectionPage(session: session, index: state.currentSection),
    );
  }

  @override
  State<TryoutSectionPage> createState() => _TryoutSectionPageState();
}

class _TryoutSectionPageState extends State<TryoutSectionPage> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    // Selaraskan waktu dengan server secara berkala.
    _syncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => widget.session.sync(),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final index = widget.index;
    final subtest = session.subtestFor(index);

    return TimedQuizPage(
      title:
          'Try Out · ${subtest.code} (${index + 1}/${session.sections.length})',
      subtest: subtest,
      questions: session.questionsFor(index),
      remainingSeconds: () => session.remainingSeconds(index),
      strict: true,
      leaveWarning:
          'Keluar akan mengakhiri seluruh try out. Subtes yang belum dikerjakan dinilai kosong.',
      onFinish: (answers) async {
        final result = session.buildResult(index, answers);
        final ok = await session.submitSection(index, result);
        if (!ok) return null; // jaringan gagal -> siswa diberi pilihan coba lagi
        return TryoutSectionPage.routeFor(session);
      },
      onViolation: (answers, reason) async {
        final result = session.buildResult(index, answers);
        await session.finish(reason: reason, index: index, result: result);
        return TryoutResultPage.route(session);
      },
    );
  }
}
