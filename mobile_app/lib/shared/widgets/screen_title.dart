// The big title at the top of a page, with an optional line under it.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'symbol_text.dart';

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.top = 26,
    this.color = AppColors.green,
    this.symbolColor,
  });

  /// The title (may contain ★).
  final String title;

  /// The line under the title, at 70% opacity (null = none).
  final String? subtitle;

  /// Space above the title (64 on the login screens).
  final double top;

  /// White on the photo of the first screen.
  final Color color;

  /// The color of ★ in the title (gold on "بستاني ★").
  final Color? symbolColor;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final headline = AppSpacing.isSmallPhone(context)
        ? AppTextStyles.headlineSmallPhone
        : AppTextStyles.headline;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: SymbolText(
              title,
              style: headline.copyWith(color: color),
              symbolColor: symbolColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Opacity(
              opacity: 0.7,
              child: Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
