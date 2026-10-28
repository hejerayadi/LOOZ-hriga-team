// Tab 3 — My orchard ("بستاني ★"):
//  - with the right plan: the 3D orchard, in a card under the title,
//  - without it: the design's "locked" screen (what Premium gives).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/orchard_scene.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import '../premium/premium_screen.dart';
import 'orchard_3d_data.dart';
import 'orchard_3d_view.dart';

/// true while a panel of the 3D page covers the bottom of the screen:
/// the assistant bar is hidden then (see MainShell in app.dart).
final ValueNotifier<bool> orchardPanelOpen = ValueNotifier(false);

class OrchardTab extends StatelessWidget {
  const OrchardTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds as soon as the plan changes.
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) => canUse(Feature.orchard3d)
          ? const _Orchard3d()
          : const _LockedOrchard(),
    );
  }
}

/// The title "بستاني ★" (with a gold star).
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return ScreenTitle(
      title: '${context.l10n.myOrchard} ★',
      symbolColor: AppColors.midGreen,
    );
  }
}

/// The 3D orchard planner (assets/orchard_3d/), in a big white card.
class _Orchard3d extends StatefulWidget {
  const _Orchard3d();

  @override
  State<_Orchard3d> createState() => _Orchard3dState();
}

class _Orchard3dState extends State<_Orchard3d> {
  // The orchard (zones, nodes, trees) sent to the 3D page. Fake for now.
  // Live zone data (nodes, readings) only with the "Connecté" plan.
  // (Made once: a language change only switches the page's texts.)
  late final String _orchardJson = orchard3dJson(
    liveData: canUse(Feature.liveZoneData),
    language: Localizations.localeOf(context).languageCode,
  );

  /// Messages sent by the 3D page (assets/orchard_3d/index.html).
  void _onMessage(String message) {
    switch (message) {
      case 'looz:upgrade': // "ابدأ بريميوم" tapped in the zone panel
        openScreen(context, const PremiumScreen());
      case 'looz:buttons:hide':
        orchardPanelOpen.value = true;
      case 'looz:buttons:show':
        orchardPanelOpen.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final side = AppSpacing.pageSide(context);
    // The card ends 12 px above the assistant bar.
    const bottom =
        AppSizes.assistantBarBottom + AppSizes.assistantBarHeight + 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        system.top + AppSpacing.pageTop,
        side,
        system.bottom + bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(),
          Expanded(
            child: CssBox(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(34),
              shadows: AppShadows.card,
              clip: true,
              child: Orchard3dView(
                data: _orchardJson,
                language: Localizations.localeOf(context).languageCode,
                onMessage: _onMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's "locked" screen: the drawing with a gold star, what Premium
/// gives, and the button to start it.
class _LockedOrchard extends StatelessWidget {
  const _LockedOrchard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final benefits = [
      (AppIcon.map, l10n.benefitTreeMap),
      (AppIcon.drop, l10n.benefitSmartWatering),
      (AppIcon.bell, l10n.benefitEarlyAlert),
    ];
    return ShellContent(
      children: [
        const _Title(),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(34),
          shadows: AppShadows.card,
          clip: true,
          padding: const EdgeInsets.only(bottom: 18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OrchardScene(radius: 0),
                  Text(
                    l10n.orchardInPocket,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(23, FontWeight.w700),
                  ),
                ],
              ),
              // Like in the design, the star covers the middle of the text.
              Positioned(
                top: 135,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.midGreen,
                      shape: BoxShape.circle,
                    ),
                    child: SymbolText(
                      '★',
                      style: AppTextStyles.of(28)
                          .copyWith(color: AppColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (icon, label)) in benefits.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    IconBlob(icon: icon),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(14, FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: '★ ${l10n.startPremium}',
          onPressed: () => openScreen(context, const PremiumScreen()),
        ),
        TextLink(
          label: l10n.notNow,
          onTap: () => goToTab(context, AppTab.home),
        ),
      ],
    );
  }
}
