// Tab 3 — "Alertes": list of alerts, colored by urgency.
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/looz_page.dart';
import 'alerts_data.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoozPage(
      title: AppStrings.tabAlerts,
      children: fakeAlerts.map((alert) => _AlertCard(alert: alert)).toList(),
    );
  }
}

/// One alert: big colored icon + title + short detail.
/// A colored bar on the left also shows the urgency.
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLevel(alert.urgency);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 10, color: color), // urgency bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(alert.icon, size: 34, color: color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alert.title, style: textTheme.titleMedium),
                          Text(alert.detail, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
