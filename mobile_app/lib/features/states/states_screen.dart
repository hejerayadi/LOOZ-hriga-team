// "حالات التطبيق": the 4 special states of the app (sent later, no
// internet, try again, nothing yet), as shown in the design.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';

class StatesScreen extends StatelessWidget {
  const StatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final states = [
      (AppIcon.clock, l10n.sendLater, AppColors.yellow),
      (AppIcon.wifi, l10n.noInternet, AppColors.sky),
      (AppIcon.bug, l10n.tryAgain, AppColors.peach),
      (AppIcon.book, l10n.askFirstQuestion, AppColors.mint),
    ];
    Widget card(int i) => Expanded(
      child: CssBox(
        height: 180,
        color: states[i].$3,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        shadows: AppShadows.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBlob(icon: states[i].$1),
            const SizedBox(height: 16),
            Text(
              states[i].$2,
              textAlign: TextAlign.center,
              style: AppTextStyles.of(17, FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.appStates),
        Row(children: [card(0), const SizedBox(width: 12), card(1)]),
        const SizedBox(height: 12),
        Row(children: [card(2), const SizedBox(width: 12), card(3)]),
      ],
    );
  }
}
