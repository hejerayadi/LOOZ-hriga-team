// Badge showing a plan: "Gratuit" (brown), "Essentiel" (olive), "Connecté" (gold).
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'badge_label.dart';

/// Color of each plan.
Color planColor(Plan plan) {
  switch (plan) {
    case Plan.free:
      return AppColors.brown;
    case Plan.essential:
      return AppColors.olive;
    case Plan.connected:
      return AppColors.premium;
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
