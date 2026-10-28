// "Les offres": the 3 plans side by side, with icons.
// No real payment for now: the button says "Contactez-nous".
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/locked_feature.dart';
import '../../shared/widgets/plan_badge.dart';

/// Opens the plans screen.
void openPlans(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PlansScreen()));
}

/// What each plan ADDS to the plan before it (shown on its card).
const Map<Plan, List<Feature>> planAdds = {
  Plan.free: [Feature.community, Feature.assistant, Feature.regionalAlerts],
  Plan.essential: [
    Feature.landSetup,
    Feature.orchardDrawing,
    Feature.orchard3d,
    Feature.aiLayout,
    Feature.photoDiagnosis,
  ],
  Plan.connected: [
    Feature.liveZoneData,
    Feature.zoneAlerts,
    Feature.aiPredictions,
  ],
};

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.plans)),
      body: ValueListenableBuilder<Plan>(
        valueListenable: currentPlan,
        builder: (context, plan, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in Plan.values) _PlanCard(plan: p, current: plan),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.current});

  final Plan plan;
  final Plan current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = planColor(plan);
    final isCurrent = plan == current;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        // The current plan has a thick colored border.
        side: isCurrent ? BorderSide(color: color, width: 4) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Icon(planIcon(plan), size: 32, color: AppColors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    AppStrings.plan(plan),
                    style: textTheme.titleLarge,
                  ),
                ),
                if (isCurrent)
                  const Icon(
                    Icons.check_circle,
                    size: 36,
                    color: AppColors.good,
                  ),
              ],
            ),
            if (isCurrent) ...[
              const SizedBox(height: 4),
              Text(
                AppStrings.yourPlan,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.good),
              ),
            ],
            const SizedBox(height: 12),
            // "Tout de l'offre Gratuit +" on the bigger plans.
            if (plan.index > 0)
              _FeatureLine(
                icon: planIcon(Plan.values[plan.index - 1]),
                text:
                    '${AppStrings.everythingIn} '
                    '${AppStrings.plan(Plan.values[plan.index - 1])} +',
              ),
            for (final feature in planAdds[plan]!)
              _FeatureLine(
                icon: featureIcon(feature),
                text: feature == Feature.assistant && plan == Plan.free
                    ? '${AppStrings.feature(feature)} · '
                          '$freeAssistantQuestionsPerDay ${AppStrings.perDay}'
                    : AppStrings.feature(feature),
              ),
            // Only bigger plans get the button.
            if (plan.index > current.index) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _contactUs(context),
                icon: const Icon(Icons.call, size: 26),
                label: const Text(
                  AppStrings.contactUs,
                  style: TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _contactUs(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.call, size: 48),
        title: const Text(AppStrings.contactUs),
        content: const Text(
          AppStrings.contactUsText,
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.ok, style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

/// One line on a plan card: icon + short text.
class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppColors.olive),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
