import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Kartu putih berbingkai yang dipakai di banyak halaman siswa.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}
