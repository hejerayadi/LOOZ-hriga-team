// Tab 4 — Alerts ("التنبيهات"): a thirsty tree, an insect nearby, and the
// rest of the orchard (fine).
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import 'alert_screen.dart';
import 'regional_screen.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellContent(
      children: [
        ScreenTitle(
          title: l10n.alertsTitle,
          subtitle: l10n.alertsSubtitle('$fakeAlertCount'),
        ),
        AlertCard(
          level: StatusLevel.danger,
          title: l10n.treeThirsty('$fakeThirstyTree'),
          text: l10n.actNow,
          icon: AppIcon.drop,
          onTap: () => openScreen(context, const AlertScreen()),
        ),
        const SizedBox(height: 16),
        AlertCard(
          level: StatusLevel.warning,
          title: l10n.insectNearby,
          text: l10n.watchLeaves,
          icon: AppIcon.bug,
          onTap: () => openScreen(context, const RegionalScreen()),
        ),
        const SizedBox(height: 16),
        AlertCard(
          level: StatusLevel.good,
          title: l10n.restIsFine,
          text: l10n.allGood,
          icon: AppIcon.check,
        ),
      ],
    );
  }
}
