import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/question.dart';
import '../providers/practice_provider.dart';
import 'practice_page.dart';

/// Ringkasan hasil latihan + tinjauan semua soal.
class PracticeResultPage extends StatelessWidget {
  const PracticeResultPage({super.key, required this.result});

  final PracticeResult result;

  String get _message {
    final pct = result.accuracy * 100;
    if (pct >= 80) return 'Luar biasa! Pertahankan ya.';
    if (pct >= 60) return 'Bagus! Sedikit lagi untuk hasil maksimal.';
    return 'Tetap semangat! Pelajari pembahasannya lalu coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final hPad = horizontalPagePadding(context);

    final summary = _SummaryCard(result: result, message: _message);
    final actions = _Actions(result: result);
    final review = _ReviewList(result: result);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Hasil ${result.subtest.code}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          child: ContentWidth(
            maxWidth: 1000,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 340,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 16),
                            actions,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: review),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 16),
                      actions,
                      const SizedBox(height: 24),
                      review,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result, required this.message});

  final PracticeResult result;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = result.subtest.color;
    final percent = (result.accuracy * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            result.subtest.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
                    value: result.accuracy,
                    strokeWidth: 10,
                    backgroundColor: AppColors.border,
                    color: color,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const Text(
                      'akurasi',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Benar',
                  value: '${result.correct}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Salah',
                  value: '${result.wrong}',
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Poin',
                  value: '${result.points}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Poin: benar +4, salah −1',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _Actions extends StatelessWidget {
  const _Actions({required this.result});

  final PracticeResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .pushReplacement(PracticePage.route(result.subtest)),
          icon: const Icon(Icons.replay),
          label: const Text('Ulangi Latihan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: result.subtest.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Kembali ke Beranda'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.result});

  final PracticeResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tinjau Jawabanmu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ketuk soal untuk melihat jawaban dan pembahasan.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < result.reviews.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewTile(number: i + 1, review: result.reviews[i]),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.number, required this.review});

  final int number;
  final AnswerReview review;

  @override
  Widget build(BuildContext context) {
    final question = review.question;
    final accent = review.isCorrect ? AppColors.success : AppColors.danger;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Icon(
          review.isCorrect ? Icons.check_circle : Icons.cancel,
          color: accent,
        ),
        title: Text(
          'Soal $number',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          question.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        children: [
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Jawabanmu: ${Question.labelOf(review.selectedIndex)}. ${question.options[review.selectedIndex]}',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          if (!review.isCorrect) ...[
            const SizedBox(height: 4),
            Text(
              'Jawaban benar: ${question.correctLabel}. ${question.options[question.correctIndex]}',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'PEMBAHASAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.explanation,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
