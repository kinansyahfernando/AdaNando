import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../widgets/soon_chip.dart';

/// Placeholder fitur Belajar Bareng (room multipemain). Dibangun di tahap berikutnya.
class BelajarBarengPage extends StatelessWidget {
  const BelajarBarengPage({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.add_circle_outline,
      title: 'Buat Room',
      text: 'Buat ruang belajar dan bagikan kodenya ke teman-temanmu.',
    ),
    _Feature(
      icon: Icons.login,
      title: 'Gabung Room',
      text: 'Masukkan kode room untuk bergabung dengan teman.',
    ),
    _Feature(
      icon: Icons.timer_outlined,
      title: 'Mulai & Selesai Bersamaan',
      text: 'Setelah semua siap, tekan Mulai. Waktu berjalan sama untuk semua dan selesai bersamaan.',
    ),
    _Feature(
      icon: Icons.emoji_events_outlined,
      title: 'Skor & Peringkat',
      text: 'Skor dan peringkat semua peserta muncul di HP masing-masing setelah selesai.',
    ),
    _Feature(
      icon: Icons.person_outline,
      title: 'Try Out Mandiri',
      text: 'Mau latihan sendiri? Kamu juga bisa try out sendiri untuk mengasah kemampuan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.bareng.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups,
                    size: 44,
                    color: AppColors.bareng,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Belajar Bareng',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SoonChip(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kerjakan soal bersama teman secara realtime. Fitur ini sedang kami siapkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              for (final feature in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeatureTile(feature: feature),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.add),
                      label: const Text('Buat Room'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.login),
                      label: const Text('Gabung Room'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bareng.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: AppColors.bareng, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
