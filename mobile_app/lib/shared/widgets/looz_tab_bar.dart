// The dark green tab bar floating at the bottom, with the 5 tabs of the
// design. Like in the design, it stays right-to-left in French too
// (Home is always on the right).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'symbol_text.dart';

class LoozTabBar extends StatelessWidget {
  const LoozTabBar({super.key, required this.selected});

  /// The tab shown as selected (null on screens opened on top of the tabs).
  final AppTab? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = [
      (AppTab.home, AppIcon.home, l10n.tabHome),
      (AppTab.community, AppIcon.people, l10n.tabCommunity),
      (AppTab.orchard, AppIcon.tree, l10n.tabOrchard),
      (AppTab.alerts, AppIcon.bell, l10n.tabAlerts),
      (AppTab.profile, AppIcon.user, l10n.tabProfile),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: AppSizes.tabBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.tabBar,
        ),
        child: Row(
          children: [
            for (final (tab, icon, label) in tabs)
              Expanded(
                child: _TabButton(
                  icon: icon,
                  label: label,
                  selected: tab == selected,
                  onTap: () => goToTab(context, tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? AppTextStyles.tabLabelSelected
        : AppSpacing.isSmallPhone(context)
        ? AppTextStyles.tabLabelSmallPhone
        : AppTextStyles.tabLabel;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: selected ? 1 : 0.68,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: selected ? AppColors.leaf : null,
                    shape: const OvalBorder(),
                  ),
                  child: LoozIcon(
                    icon,
                    size: 27,
                    color: selected ? AppColors.green : AppColors.white,
                  ),
                ),
                const SizedBox(height: 1),
                // One line, never cut (like the design).
                SymbolText(label, style: style, softWrap: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
