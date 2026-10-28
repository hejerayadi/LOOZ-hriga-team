// The card of an alert (the design's "alert-card"): a face, 2 lines of text
// and an icon, with a colored bar on the side where the text starts.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'css_box.dart';
import 'mood_face.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.level,
    required this.title,
    required this.text,
    required this.icon,
    this.onTap,
  });

  final StatusLevel level;
  final String title;
  final String text;

  /// At the end of the card (an arrow, a drop...).
  final AppIcon icon;

  /// null = the card can't be opened.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = CssBox(
      minHeight: 92,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      border: BorderDirectional(
        start: BorderSide(color: AppColors.forLevel(level), width: 7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          MoodFace(level: level, small: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                Text(text, style: AppTextStyles.cardText),
              ],
            ),
          ),
          const SizedBox(width: 14),
          LoozIcon(icon),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
