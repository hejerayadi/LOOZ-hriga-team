// Badge showing a plan: "Gratuit" (mint), "Essentiel" (bright green),
// "Connecté" (premium green).
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'badge_label.dart';

/// Color of each plan. All 3 are light: put dark green text or icons on them.
Color planColor(Plan plan) {
  switch (plan) {
    case Plan.free:
      return AppColors.mint;
    case Plan.essential:
      return AppColors.leaf;
    case Plan.connected:
      return AppColors.midGreen;
  }
}

/// Icon of each plan.
IconData planIcon(Plan plan) {
  switch (plan) {
    case Plan.free:
      return Icons.eco;
    case Plan.essential:
      return Icons.park;
    case Plan.connected:
      return Icons.sensors;
  }
}

class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return BadgeLabel(
      text: AppStrings.plan(plan),
      color: planColor(plan),
      icon: planIcon(plan),
    );
  }
}
