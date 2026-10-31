import 'package:flutter/material.dart';

/// Warna terpusat supaya tampilan konsisten di seluruh aplikasi.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE8F7EE);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFDECEC);

  // Warna per kategori subtes
  static const Color tps = Color(0xFF2563EB);
  static const Color literasi = Color(0xFF0D9488);
  static const Color penalaran = Color(0xFFEA580C);
  static const Color bareng = Color(0xFF7C3AED);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
