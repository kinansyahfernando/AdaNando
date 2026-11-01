import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/secure_screen.dart';
import '../../data/models/session_result.dart';
import '../../data/tryout_session.dart';
import '../widgets/answer_review_list.dart';
import '../widgets/section_card.dart';

/// Hasil Try Out: ringkasan total dan rincian tiap subtes.
class TryoutResultPage extends StatefulWidget {
  const TryoutResultPage({super.key, required this.session});

  final TryoutSession session;

  static Route<void> route(TryoutSession session) {
    return MaterialPageRoute<void>(
      builder: (_) => TryoutResultPage(session: session),
    );
  }

  @override
  State<TryoutResultPage> createState() => _TryoutResultPageState();
}

class _TryoutResultPageState extends State<TryoutResultPage> {
  @override
  void initState() {
    super.initState();
    SecureScreen.disable(); // ujian selesai, screenshot boleh lagi
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openReview(int index) {
    final result = widget.session.results[index];
    if (result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ReviewPage(result: result)),
    );
  }

  ({String text, Color color, IconData icon})? _banner() {
    switch (widget.session.endReason) {
      case 'violation':
        return (
          text:
              'Try out dihentikan otomatis karena kamu meninggalkan aplikasi atau pindah tab. Jawaban subtes yang sedang berjalan tetap dinilai.',
          color: AppColors.danger,
          icon: Icons.warning_amber_rounded,
        );
      case 'quit':
        return (
          text:
              'Kamu mengakhiri try out lebih awal. Subtes yang belum dikerjakan dinilai kosong.',
          color: AppColors.penalaran,
          icon: Icons.exit_to_app,
        );
      case 'timeout':
        return (
          text: 'Waktu try out habis.',
          color: AppColors.muted,
          icon: Icons.timer_off_outlined,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final hPad = horizontalPagePadding(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    var correct = 0;
    var wrong = 0;
    var points = 0;
    for (final r in session.results.values) {
      correct += r.correct;
      wrong += r.wrong;
      points += r.points;
    }
    final totalQuestions = session.state.totalQuestions;
    final blank = totalQuestions - correct - wrong;
    final accuracy = totalQuestions == 0 ? 0.0 : correct / totalQuestions;

    final banner = _banner();

    final summary = _TotalCard(
      points: points,
      correct: correct,
      wrong: wrong,
      blank: blank,
      accuracy: accuracy,
      totalQuestions: totalQuestions,
    );

    final sectionList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Rincian per Subtes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Hasil tiap subtes tersimpan dan bisa dipantau di halaman Potensi.',
          style: TextStyle(fontSize: 13.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < session.sections.length; i++) ...[
          _SectionResultTile(
            code: session.subtestFor(i).code,
            name: session.sections[i].name,
            color: session.subtestFor(i).color,
            result: session.results[i],
            onReview: () => _openReview(i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

    final doneButton = FilledButton.icon(
      onPressed: _finish,
      icon: const Icon(Icons.home_rounded),
      label: const Text('Selesai'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: AppColors.penalaran,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'Hasil Try Out',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
            child: ContentWidth(
              maxWidth: 1000,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (banner != null) ...[
                    _Banner(
                      text: banner.text,
                      color: banner.color,
                      icon: banner.icon,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              const SizedBox(height: 16),
                              doneButton,
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: sectionList),
                      ],
                    )
                  else ...[
                    summary,
                    const SizedBox(height: 16),
                    doneButton,
                    const SizedBox(height: 24),
                    sectionList,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.points,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.accuracy,
    required this.totalQuestions,
  });

  final int points;
  final int correct;
  final int wrong;
  final int blank;
  final double accuracy;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final percent = (accuracy * 100).round();

    return SectionCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Total Try Out',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: accuracy,
                    strokeWidth: 10,
                    backgroundColor: AppColors.border,
                    color: AppColors.penalaran,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.penalaran,
                      ),
                    ),
                    Text(
                      '$correct/$totalQuestions benar',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Benar',
                  value: '$correct',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Salah',
                  value: '$wrong',
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Kosong',
                  value: '$blank',
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stat(label: 'Poin', value: '$points', color: AppColors.primary),
          const SizedBox(height: 10),
          const Text(
            'Poin: benar +4, salah −1, kosong 0',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SectionResultTile extends StatelessWidget {
  const _SectionResultTile({
    required this.code,
    required this.name,
    required this.color,
    required this.result,
    required this.onReview,
  });

  final String code;
  final String name;
  final Color color;
  final SessionResult? result;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final r = result;

    return SectionCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (r == null)
            const Text(
              'Tidak dikerjakan',
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.correct} benar · ${r.wrong} salah · ${r.blank} kosong',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(r.accuracy * 100).round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          if (r != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Lihat pembahasan'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pembahasan ${result.subtest.code}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          child: ContentWidth(
            maxWidth: 820,
            child: AnswerReviewList(result: result),
          ),
        ),
      ),
    );
  }
}
