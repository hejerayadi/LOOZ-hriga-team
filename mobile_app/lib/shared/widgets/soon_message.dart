// "قريبًا" / "Bientôt": the short message of a button that does not work
// yet (e.g. ▶ of the voice answers), instead of doing nothing.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';

void showSoon(BuildContext context) {
  // Above the assistant bar and the tab bar, so it is not hidden by them.
  final bottom =
      MediaQuery.paddingOf(context).bottom +
      AppSizes.assistantBarBottom +
      AppSizes.assistantBarHeight +
      12;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.soon,
          textAlign: TextAlign.center,
          style: AppTextStyles.of(
            17,
            FontWeight.w800,
          ).copyWith(color: AppColors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green,
        shape: const StadiumBorder(),
        elevation: 0,
        margin: EdgeInsets.fromLTRB(90, 0, 90, bottom),
        duration: const Duration(seconds: 2),
      ),
    );
}
