// Tab 4 — "Profil": name, role and subscription plan.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/looz_page.dart';
import '../../shared/widgets/plan_badge.dart';
import '../../shared/widgets/role_badge.dart';
import '../plans/plans_screen.dart';
import 'profile_data.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const user = fakeUser;
    // Rebuilds as soon as the plan changes.
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) => LoozPage(
        title: AppStrings.tabProfile,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.almond,
                    child: Icon(Icons.person, size: 72, color: AppColors.brown),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  RoleBadge(role: user.role),
                  const SizedBox(height: 12),
                  // Current plan: "Gratuit", "Essentiel" or "Connecté".
                  PlanBadge(plan: plan),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openPlans(context),
            icon: const Icon(Icons.workspace_premium),
            label: const Text(
              AppStrings.seePlans,
              style: TextStyle(fontSize: 18),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Logout: AuthGate sees it and goes back to the Login screen.
          OutlinedButton.icon(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text(
              AppStrings.logout,
              style: TextStyle(fontSize: 18),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          // Only while developing (flutter run), never in the real app.
          if (kDebugMode) _DevPlanSwitch(plan: plan),
        ],
      ),
    );
  }
}

/// Developer tool: switch the fake user's plan to test all 3 plans.
class _DevPlanSwitch extends StatelessWidget {
  const _DevPlanSwitch({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.build, color: AppColors.brown),
                SizedBox(width: 8),
                Text(AppStrings.devPlan),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<Plan>(
              segments: [
                for (final p in Plan.values)
                  ButtonSegment(value: p, label: Text(AppStrings.plan(p))),
              ],
              selected: {plan},
              onSelectionChanged: (selection) =>
                  currentPlan.value = selection.first,
            ),
          ],
        ),
      ),
    );
  }
}
