import 'package:flutter/widgets.dart';

/// Titik patah (breakpoint) lebar layar.
class Breakpoints {
  Breakpoints._();

  /// HP
  static const double compact = 600;

  /// Tablet
  static const double medium = 900;

  /// Desktop / web lebar
  static const double expanded = 1200;
}

/// Padding horizontal halaman yang menyesuaikan lebar layar.
double horizontalPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.medium) return 32;
  if (width >= Breakpoints.compact) return 24;
  return 16;
}

/// Membatasi lebar konten agar tetap nyaman dibaca di layar lebar,
/// dan memusatkannya secara horizontal.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
