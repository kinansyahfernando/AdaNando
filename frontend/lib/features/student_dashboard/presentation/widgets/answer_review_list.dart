import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/question.dart';
import '../../data/models/session_result.dart';
import 'section_card.dart';

/// Tinjauan semua soal: jawaban siswa, kunci, dan pembahasan.
class AnswerReviewList extends StatelessWidget {
  const AnswerReviewList({super.key, required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tinjauan Jawaban',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pelajari pembahasan tiap soal, terutama yang masih salah.',
          style: TextStyle(fontSize: 13.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < result.questions.length; i++) ...[
          _ReviewItem(
            number: i + 1,
            question: result.questions[i],
            selectedIndex: result.answers[i],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.number,
    required this.question,
    required this.selectedIndex,
  });

  final int number;
  final Question question;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final answered = selectedIndex != null;
    final correct = answered && selectedIndex == question.correctIndex;

    final Color accent;
    final String statusLabel;
    final IconData statusIcon;
    if (!answered) {
      accent = AppColors.muted;
      statusLabel = 'Tidak dijawab';
      statusIcon = Icons.remove_circle_outline;
    } else if (correct) {
      accent = AppColors.success;
      statusLabel = 'Benar';
      statusIcon = Icons.check_circle;
    } else {
      accent = AppColors.danger;
      statusLabel = 'Salah';
      statusIcon = Icons.cancel;
    }

    final passage = question.passage;

    return SectionCard(
      borderColor: answered ? accent : AppColors.border,
      borderWidth: answered ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Soal $number',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Icon(statusIcon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (passage != null && passage.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 10),
                title: const Text(
                  'Lihat bacaan',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                children: [
                  Text(
                    passage,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (!answered)
            const Text(
              'Kamu tidak menjawab soal ini.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            )
          else if (!correct)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Jawabanmu: ${Question.labelOf(selectedIndex!)}. ${question.options[selectedIndex!]}',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.danger,
                ),
              ),
            ),
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
