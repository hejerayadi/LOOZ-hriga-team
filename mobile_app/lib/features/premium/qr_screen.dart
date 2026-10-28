// "امسح الرمز": welcome to Premium, scan the code on the orchard's device.
// DEMO: there is no scanner yet; the button opens the orchard map.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../map/map_screen.dart';

class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.scanTitle, subtitle: l10n.scanSubtitle),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              SymbolText('▦', style: AppTextStyles.of(170).copyWith(height: 1)),
              const SizedBox(height: 20),
              Text(
                l10n.onOrchardDevice,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(16, FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: l10n.openMap,
          onPressed: () =>
              openFeature(context, Feature.orchard3d, const MapScreen()),
        ),
      ],
    );
  }
}
