// What a locked feature looks like: still visible, with a 🔒 and a big
// "Passer à Essentiel / Connecté" button that opens the plans screen.
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/plans/plans_screen.dart';
import 'plan_badge.dart';

/// Icon of each feature (also used on the plans screen).
IconData featureIcon(Feature feature) {
  switch (feature) {
    case Feature.community:
      return Icons.groups;
    case Feature.assistant:
      return Icons.smart_toy;
    case Feature.regionalAlerts:
      return Icons.campaign;
    case Feature.landSetup:
      return Icons.landscape;
    case Feature.orchardDrawing:
      return Icons.draw;
    case Feature.orchard3d:
      return Icons.view_in_ar;
    case Feature.aiLayout:
      return Icons.auto_awesome;
    case Feature.photoDiagnosis:
      return Icons.photo_camera;
    case Feature.treeAlerts:
      return Icons.notification_important;
    case Feature.liveZoneData:
      return Icons.sensors;
    case Feature.zoneAlerts:
      return Icons.notifications_active;
    case Feature.aiPredictions:
      return Icons.insights;
  }
}

/// Feature icon with a small lock on top.
class _LockedIcon extends StatelessWidget {
  const _LockedIcon({required this.feature, required this.size});

  final Feature feature;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(featureIcon(feature), size: size, color: Colors.grey),
        Positioned(
          right: -6,
          bottom: -6,
          child: CircleAvatar(
            radius: size * 0.25,
            backgroundColor: AppColors.textDark,
            child: Icon(Icons.lock, size: size * 0.28, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Big "Passer à Essentiel" / "Passer à Connecté" button.
class UpgradeButton extends StatelessWidget {
  const UpgradeButton({super.key, required this.plan});

  /// The plan to upgrade to.
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => openPlans(context),
      icon: const Icon(Icons.lock_open, size: 26),
      label: Text(
        AppStrings.upgradeTo(plan),
        style: const TextStyle(fontSize: 18),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: planColor(plan),
        minimumSize: const Size.fromHeight(56),
      ),
    );
  }
}

/// A locked feature inside a page (e.g. the 3D card on "Mon verger").
class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _LockedIcon(feature: feature, size: 48),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.feature(feature),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      PlanBadge(plan: feature.minPlan),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UpgradeButton(plan: feature.minPlan),
          ],
        ),
      ),
    );
  }
}

/// A whole locked screen (e.g. the camera button on the free plan).
class LockedFeatureScreen extends StatelessWidget {
  const LockedFeatureScreen({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.feature(feature))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LockedIcon(feature: feature, size: 120),
              const SizedBox(height: 32),
              Text(
                AppStrings.feature(feature),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              PlanBadge(plan: feature.minPlan),
              const SizedBox(height: 32),
              UpgradeButton(plan: feature.minPlan),
            ],
          ),
        ),
      ),
    );
  }
}
