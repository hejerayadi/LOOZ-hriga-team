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
    this.barColor,
    this.tag,
    this.semanticLabel,
  });

  final StatusLevel level;
  final String title;
  final String text;

  /// At the end of the card (an arrow, a drop...).
  final AppIcon icon;

  /// null = the card can't be opened.
  final VoidCallback? onTap;

  /// The side bar (null = the color of [level]).
  final Color? barColor;

  /// A small pill next to the title (e.g. "جديد"), null = none.
  final String? tag;

  /// Read by screen readers before the texts (e.g. "خطر").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    final card = CssBox(
      minHeight: 92,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      border: BorderDirectional(
        start: BorderSide(
          color: barColor ?? AppColors.forLevel(level),
          width: 7,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          MoodFace(level: level, small: true, semanticLabel: semanticLabel),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null) ...[_Tag(tag), const SizedBox(height: 4)],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle,
                ),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardText,
                ),
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

/// "جديد": a small light-green pill.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.leaf,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppTextStyles.of(13, FontWeight.w800)),
    );
  }
}
