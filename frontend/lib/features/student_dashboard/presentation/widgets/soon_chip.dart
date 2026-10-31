import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Label kecil "Segera hadir" untuk fitur yang belum tersedia.
class SoonChip extends StatelessWidget {
  const SoonChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bareng.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Segera hadir',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.bareng,
        ),
      ),
    );
  }
}
