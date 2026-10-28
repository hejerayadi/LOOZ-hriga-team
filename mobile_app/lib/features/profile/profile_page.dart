// Tab 5 — Profile ("حسابي"): the farmer, the plan, become an expert, and
// the states of the app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../premium/premium_screen.dart';
import '../states/states_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const avatar = Size.square(86);
    return ShellContent(
      children: [
        const LoozHeader(),
        const SizedBox(height: 42),
        Row(
          children: [
            Container(
              width: avatar.width,
              height: avatar.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.leaf,
                borderRadius: blobRadius(avatar, BlobShapes.avatar),
              ),
              child: Text(
                l10n.demoInitial,
                style: AppTextStyles.of(34, FontWeight.w800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.demoFullName,
                    style: AppTextStyles.headline.copyWith(fontSize: 26),
                  ),
                  Text(l10n.demoCity, style: AppTextStyles.of(16)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _ProfileRow(
          icon: AppIcon.tree,
          label: l10n.myPlan,
          end: SymbolText(
            '★',
            style: AppTextStyles.of(19).copyWith(color: AppColors.midGreen),
          ),
          onTap: () => openScreen(context, const PremiumScreen()),
        ),
        _ProfileRow(
          icon: AppIcon.people,
          label: l10n.becomeExpert,
          // DEMO: there is no "become an expert" screen in the design yet.
          onTap: null,
        ),
        _ProfileRow(
          icon: AppIcon.wifi,
          label: l10n.appStates,
          onTap: () => openScreen(context, const StatesScreen()),
        ),
        // Only for developers (debug builds): change the fake plan.
        if (kDebugMode) const _DevPlanSwitch(),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.end,
  });

  final AppIcon icon;
  final String label;
  final VoidCallback? onTap;

  /// At the end of the row (default: an arrow).
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: CssBox(
            height: 86,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            shadows: AppShadows.card,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBlob(icon: icon),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: AppTextStyles.cardTitle)),
                const SizedBox(width: 14),
                end ?? const LoozIcon(AppIcon.arrow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Debug builds only: the 3 plans, to see the locked screens.
class _DevPlanSwitch extends StatelessWidget {
  const _DevPlanSwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = {
      Plan.free: l10n.free,
      Plan.essential: l10n.planEssential,
      Plan.connected: l10n.planConnected,
    };
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) => CssBox(
        color: AppColors.white70,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.devPlanSwitch,
              style: AppTextStyles.of(15, FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final p in Plan.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: p == plan,
                      child: GestureDetector(
                        onTap: () => currentPlan.value = p,
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p == plan
                                ? AppColors.green
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            names[p]!,
                            style: AppTextStyles.langPill.copyWith(
                              color: p == plan
                                  ? AppColors.white
                                  : AppColors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
