import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/tryout.dart';
import '../../data/tryout_session.dart';
import 'timed_quiz_page.dart';
import 'tryout_result_page.dart';

/// Satu bagian dalam ujian. Soal diambil dari server hanya saat bagian ini
/// dimulai (tanpa kunci), jawaban disimpan otomatis, dan pelanggaran dilaporkan
/// ke server yang memutuskan kapan ujian diakhiri.
class TryoutSectionPage extends StatefulWidget {
  const TryoutSectionPage({
    super.key,
    required this.session,
    required this.index,
  });

  final TryoutSession session;
  final int index;

  /// Route berikutnya sesuai status server: bagian yang sedang berjalan,
  /// atau halaman hasil bila ujian sudah selesai.
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
  SectionData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // "Detak jantung": selaraskan waktu & beri tahu pengawas siswa masih terhubung.
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sync());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.session.loadSection(widget.index);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      // Bila ujian sudah selesai di server (waktu habis / dikumpulkan pengawas)
      await widget.session.sync();
      if (!mounted) return;
      if (widget.session.state.isFinished) {
        _goNext();
        return;
      }
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sync() async {
    final session = widget.session;
    await session.sync();
    if (!mounted) return;
    // Server mengakhiri ujian (pengawas / waktu habis) atau sudah pindah bagian.
    if (session.state.isFinished ||
        session.state.currentSection != widget.index) {
      _goNext();
    }
  }

  void _goNext() {
    final navigator = Navigator.of(context);
    final self = ModalRoute.of(context);
    if (self != null) navigator.popUntil((r) => r == self);
    navigator.pushReplacement(TryoutSectionPage.routeFor(widget.session));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final index = widget.index;
    final data = _data;

    if (data == null) {
      return Scaffold(
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
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final auth = context.read<AuthProvider>();
    final subtest = session.subtestFor(index);
    final who = [
      auth.userName ?? '',
      if ((auth.userNis ?? '').isNotEmpty) auth.userNis!,
    ].where((e) => e.isNotEmpty).join(' · ');

    return TimedQuizPage(
      title:
          '${session.state.examTitle} · ${subtest.code} (${index + 1}/${session.sections.length})',
      subtest: subtest,
      questions: data.questions,
      initialAnswers: data.answers,
      watermark: who.isEmpty ? null : who,
      remainingSeconds: () => session.remainingSeconds(index),
      strict: true,
      leaveWarning:
          'Keluar akan mengakhiri seluruh ujian. Bagian yang belum dikerjakan dinilai kosong dan kamu tidak bisa masuk lagi.',
      onAnswersChanged: (answers) => session.autosave(index, answers),
      onFinish: (answers) async {
        final ok = await session.submitSection(index, answers);
        if (!ok) return null; // jaringan gagal -> siswa diberi pilihan coba lagi
        return TryoutSectionPage.routeFor(session);
      },
      onViolation: (answers, reason) async {
        await session.finish(index: index, answers: answers);
        return TryoutResultPage.route(session);
      },
      onViolationEvent: (type, answers) async {
        final s = await session.reportViolation(
          type: type,
          index: index,
          answers: answers,
        );
        if (s == null) return null;
        return ViolationOutcome(
          counted: s.counted,
          count: s.violations,
          max: s.maxViolations,
          ended: s.ended,
          route: s.ended ? TryoutResultPage.route(session) : null,
        );
      },
    );
  }
}
