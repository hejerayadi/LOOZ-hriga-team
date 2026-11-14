// "قريبًا" / "Bientôt": the short message of a button that does not work
// yet (e.g. ▶ of the voice answers), instead of doing nothing.
// showMessage: the same green pill with another short text (e.g. "شكرًا").
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';

void showSoon(BuildContext context) => showMessage(context, context.l10n.soon);

/// A short message in a green pill above the bottom bars (2 s, or 4 s for
/// a longer text).
void showMessage(BuildContext context, String text) {
  // Above the assistant bar and the tab bar, so it is not hidden by them.
  final bottom =
      MediaQuery.paddingOf(context).bottom +
      AppSizes.assistantBarBottom +
      AppSizes.assistantBarHeight +
      12;
  final short = text.length <= 12;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.of(
            17,
            FontWeight.w800,
          ).copyWith(color: AppColors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green,
        shape: short
            ? const StadiumBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
        elevation: 0,
        margin: short
            ? EdgeInsets.fromLTRB(90, 0, 90, bottom)
            : EdgeInsets.fromLTRB(24, 0, 24, bottom),
        duration: Duration(seconds: short ? 2 : 4),
      ),
    );
}
