// Tab 4 — Alerts ("التنبيهات"): the REAL regional alerts of the farmer's
// governorate (frost, heat...), written by the Looz team in the dashboard.
// The most serious first, the done ones at the end; "جديد" on the ones not
// opened yet. Pull down to refresh (it also refreshes every minute and when
// the tab is opened, see alerts_store.dart).
// Premium: the alerts of the orchard's sensors come later ("قريبًا").
import 'package:flutter/material.dart';

import '../../core/governorates.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/alerts_service.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../community/community_widgets.dart' show LoadingCard, StateCard;
import 'alert_widgets.dart';
import 'alerts_store.dart';
import 'regional_screen.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  @override
  void initState() {
    super.initState();
    currentTab.addListener(_onTabChanged);
    // The tab is built the first time it is opened: load now.
    refreshAlerts();
  }

  @override
  void dispose() {
    currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (currentTab.value == AppTab.alerts) refreshAlerts();
  }

  void _open(RegionalAlert alert) =>
      openScreen(context, RegionalScreen(alert: alert));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<AlertsState>(
      valueListenable: regionalAlerts,
      builder: (context, state, _) {
        final alerts = state.alerts;
        final failure = state.failure;
        final region = governorateName(l10n, currentUser.value?.governorate);
        final open = state.openCount;
        return RefreshIndicator(
          color: AppColors.green,
          onRefresh: refreshAlerts,
          child: ShellContent(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ScreenTitle(
                title: l10n.alertsTitle,
                subtitle: alerts == null
                    ? null
                    : open > 0
                    ? l10n.alertsSubtitle('$open')
                    : l10n.alertsNoneSubtitle,
              ),
              AlertsSectionTitle(
                region == null
                    ? l10n.alertsInRegionPlain
                    : l10n.alertsInRegion(region),
              ),
              if (alerts == null && failure != null)
                AlertsFailureCard(failure: failure, onRetry: refreshAlerts)
              else if (alerts == null)
                const LoadingCard(photo: false)
              else if (alerts.isEmpty)
                StateCard(
                  icon: AppIcon.check,
                  text: l10n.noAlertsInRegion,
                  color: AppColors.mint,
                  height: 150,
                )
              else
                for (final (i, alert) in alerts.indexed) ...[
                  if (i > 0) const SizedBox(height: 16),
                  RegionalAlertCard(alert: alert, onTap: () => _open(alert)),
                ],
              // Premium: the sensors of the orchard (Phase 2).
              ValueListenableBuilder<Plan>(
                valueListenable: currentPlan,
                builder: (context, plan, _) {
                  // (Experts never have the paid pack.)
                  if (!canUse(Feature.zoneAlerts, plan)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AlertsSectionTitle(l10n.myOrchard),
                        SoonRow(
                          icon: AppIcon.tree,
                          text: l10n.sensorAlertsSoon,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              SoonRow(icon: AppIcon.bell, text: l10n.phoneNotificationsSoon),
            ],
          ),
        );
      },
    );
  }
}
