import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum OptionState { idle, selected, correct, wrong, dimmed }

/// Satu pilihan jawaban (A-E) dengan beberapa keadaan visual.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String label;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Color background = AppColors.surface;
    Color borderColor = AppColors.border;
    Color badgeBackground = const Color(0xFFF1F5F9);
    Color badgeForeground = AppColors.muted;
    Color textColor = AppColors.ink;
    double borderWidth = 1;
    IconData? trailingIcon;
    Color trailingColor = AppColors.muted;

    switch (state) {
      case OptionState.idle:
        break;
      case OptionState.selected:
        background = primary.withAlpha(20);
        borderColor = primary;
        borderWidth = 2;
        badgeBackground = primary;
        badgeForeground = Colors.white;
        break;
      case OptionState.correct:
        background = AppColors.successSoft;
        borderColor = AppColors.success;
        borderWidth = 2;
        badgeBackground = AppColors.success;
        badgeForeground = Colors.white;
        trailingIcon = Icons.check_circle;
        trailingColor = AppColors.success;
        break;
      case OptionState.wrong:
        background = AppColors.dangerSoft;
        borderColor = AppColors.danger;
        borderWidth = 2;
        badgeBackground = AppColors.danger;
        badgeForeground = Colors.white;
        trailingIcon = Icons.cancel;
        trailingColor = AppColors.danger;
        break;
      case OptionState.dimmed:
        textColor = AppColors.muted;
        break;
    }

    return Semantics(
      button: true,
      selected: state == OptionState.selected,
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: badgeForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, color: trailingColor, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
