// Connected chosen without the LOOZ sensor kit (not in the design: the
// app's own screen, in its style): the request is saved (kit_requests),
// "we will call you to install your kit", and meanwhile the free plan.
// Once the kit is installed, the farmer pays Connected from Premium.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../onboarding/welcome_screen.dart';

class KitRequestedScreen extends StatelessWidget {
  const KitRequestedScreen({super.key, this.signUp = false});

  /// true = during the sign-up: then welcome.
  final bool signUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellPage(
      showBars: !signUp,
      children: [
        ScreenTitle(title: l10n.kitTitle, subtitle: l10n.planConnected),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              const IconBlob(icon: AppIcon.wifi, size: 90, iconSize: 48),
              const SizedBox(height: 18),
              Text(
                l10n.kitRequested,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(20, FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.kitMeanwhileFree,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(17),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: l10n.continueLabel,
          onPressed: () => signUp
              ? replaceAllWith(context, const WelcomeScreen())
              : goToTab(context, AppTab.home),
        ),
      ],
    );
  }
}
