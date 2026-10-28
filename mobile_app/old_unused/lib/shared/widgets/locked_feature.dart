// What a locked feature looks like: still visible, with a 🔒 and a big
// "Passer à Essentiel / Connecté" button that opens the plans screen.
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/plans/plans_screen.dart';
import 'action_button.dart';
import 'blob.dart';
import 'looz_card.dart';
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

/// Feature icon on a blob, with a small round lock on its corner.
class _LockedIcon extends StatelessWidget {
  const _LockedIcon({required this.feature, required this.size});

  final Feature feature;

  /// Size of the blob.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Old look, until this screen is redesigned (step 3).
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: blobRadius(Size.square(size), BlobShapes.icon),
          ),
          child: Icon(featureIcon(feature), size: size * 0.48),
        ),
        Positioned(
          right: -size * 0.1,
          bottom: -size * 0.1,
          child: Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              color: AppColors.midGreen,
              shape: BoxShape.circle,
              boxShadow: AppShadows.small,
            ),
            child: Icon(Icons.lock, size: size * 0.25, color: AppColors.white),
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
    return ActionButton(
      label: AppStrings.upgradeTo(plan),
      onPressed: () => openPlans(context),
    );
  }
}

/// A locked feature inside a page (e.g. the 3D card on "Mon verger").
class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    return LoozCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              _LockedIcon(feature: feature, size: 58),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.feature(feature),
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 6),
                    PlanBadge(plan: feature.minPlan),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          UpgradeButton(plan: feature.minPlan),
        ],
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
