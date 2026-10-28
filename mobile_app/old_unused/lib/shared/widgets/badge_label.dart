// A small colored "pill" with text, e.g. "Expert" or "Premium".
// The text is dark green on light colors, white on dark colors.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BadgeLabel extends StatelessWidget {
  const BadgeLabel({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;

  /// Optional small icon before the text.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? AppColors.white
        : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
