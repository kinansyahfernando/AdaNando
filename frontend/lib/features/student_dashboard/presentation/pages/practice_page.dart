import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/question.dart';
import '../../data/models/subtest.dart';
import '../../data/results_repository.dart';
import '../providers/practice_provider.dart';
import '../widgets/option_tile.dart';
import 'practice_result_page.dart';

/// Halaman latihan satu subtes.
/// Alur: pilih jawaban → Periksa Jawaban (muncul kunci + pembahasan) → Soal Berikutnya.
class PracticePage extends StatelessWidget {
  const PracticePage({super.key, required this.subtest});

  final Subtest subtest;

  static Route<void> route(Subtest subtest) {
    return MaterialPageRoute<void>(
      builder: (_) => PracticePage(subtest: subtest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PracticeProvider>(
      create: (_) => PracticeProvider(subtest: subtest)..load(),
      child: const _PracticeView(),
    );
  }
}

class _PracticeView extends StatefulWidget {
  const _PracticeView();

  @override
  State<_PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<_PracticeView> {
  final GlobalKey _feedbackKey = GlobalKey();

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari latihan?'),
        content: const Text('Progres latihan ini tidak akan disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut Latihan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onPrimaryPressed(PracticeProvider p) {
    if (!p.isChecked) {
      p.check();
      // Setelah kunci & pembahasan muncul, gulir agar terlihat.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final feedbackContext = _feedbackKey.currentContext;
        if (feedbackContext != null && feedbackContext.mounted) {
          Scrollable.ensureVisible(
            feedbackContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
      });
    } else if (p.isLast) {
      final result = p.buildResult();
      // Simpan hasil untuk halaman Potensi (gagal simpan tidak mengganggu siswa)
      ResultsRepository().savePractice(
        subtestId: result.subtest.id,
        total: result.total,
        correct: result.correct,
        wrong: result.wrong,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PracticeResultPage(result: result),
        ),
      );
    } else {
      p.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeProvider>();

    return PopScope(
      canPop: !p.hasProgress,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Keluar',
            onPressed: () {
              if (p.hasProgress) {
                _confirmExit();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            p.subtest.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: p.progress,
              minHeight: 4,
              backgroundColor: AppColors.border,
              color: p.subtest.color,
            ),
          ),
        ),
        body: _buildBody(p),
      ),
    );
  }

  Widget _buildBody(PracticeProvider p) {
    if (p.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.errorMessage != null) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        title: p.errorMessage!,
        actionLabel: 'Coba Lagi',
        onAction: p.load,
      );
    }
    if (!p.hasQuestions) {
      return _MessageState(
        icon: Icons.inbox_outlined,
        title: 'Belum ada soal untuk subtes ini.',
        actionLabel: 'Kembali',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    final hPad = horizontalPagePadding(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // Key per soal: posisi scroll kembali ke atas saat pindah soal.
            key: ValueKey<int>(p.currentIndex),
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
            child: ContentWidth(
              maxWidth: 1000,
              child: _QuestionSection(p: p, feedbackKey: _feedbackKey),
            ),
          ),
        ),
        _BottomBar(p: p, onPressed: () => _onPrimaryPressed(p)),
      ],
    );
  }
}

// ───────────────────────── Bagian soal ─────────────────────────

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({required this.p, required this.feedbackKey});

  final PracticeProvider p;
  final GlobalKey feedbackKey;

  @override
  Widget build(BuildContext context) {
    final question = p.current;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final passage = question.passage;
    final hasPassage = passage != null && passage.isNotEmpty;

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuestionCard(p: p),
        if (p.isChecked) ...[
          const SizedBox(height: 16),
          _FeedbackCard(
            key: feedbackKey,
            question: question,
            selectedIndex: p.selectedIndex!,
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(p: p),
        const SizedBox(height: 14),
        if (wide && hasPassage)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PassageCard(text: passage!)),
              const SizedBox(width: 16),
              Expanded(child: rightColumn),
            ],
          )
        else ...[
          if (hasPassage) ...[
            _PassageCard(text: passage!),
            const SizedBox(height: 16),
          ],
          rightColumn,
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.p});

  final PracticeProvider p;

  @override
  Widget build(BuildContext context) {
    final color = p.subtest.color;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Soal ${p.currentIndex + 1} dari ${p.questions.length}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          p.subtest.code,
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.article_outlined, size: 18, color: AppColors.muted),
              SizedBox(width: 8),
              Text(
                'BACAAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.p});

  final PracticeProvider p;

  OptionState _stateFor(int index) {
    if (!p.isChecked) {
      return p.selectedIndex == index ? OptionState.selected : OptionState.idle;
    }
    if (index == p.current.correctIndex) return OptionState.correct;
    if (index == p.selectedIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final question = p.current;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == question.options.length - 1 ? 0 : 10,
              ),
              child: OptionTile(
                label: Question.labelOf(i),
                text: question.options[i],
                state: _stateFor(i),
                onTap: p.isChecked ? null : () => p.select(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    super.key,
    required this.question,
    required this.selectedIndex,
  });

  final Question question;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final correct = selectedIndex == question.correctIndex;
    final accent = correct ? AppColors.success : AppColors.danger;

    return _CardShell(
      borderColor: accent,
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? 'Jawabanmu benar!' : 'Jawabanmu kurang tepat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!correct) ...[
            Text(
              'Jawabanmu: ${Question.labelOf(selectedIndex)}. ${question.options[selectedIndex]}',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Jawaban benar: ${question.correctLabel}. ${question.options[question.correctIndex]}',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const Text(
            'PEMBAHASAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question.explanation,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bar bawah ─────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.p, required this.onPressed});

  final PracticeProvider p;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.compact;
    final enabled = p.isChecked || p.selectedIndex != null;
    final label = !p.isChecked
        ? 'Periksa Jawaban'
        : (p.isLast ? 'Lihat Hasil' : 'Soal Berikutnya');

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: p.subtest.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (p.isChecked) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ],
      ),
    );

    final hint = !p.isChecked
        ? 'Pilih satu jawaban, lalu periksa.'
        : 'Baca pembahasan sebelum lanjut.';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPagePadding(context),
            vertical: 12,
          ),
          child: ContentWidth(
            maxWidth: 1000,
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      button,
                    ],
                  )
                : Row(children: [Expanded(child: button)]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── State kosong / error ─────────────────────────

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
