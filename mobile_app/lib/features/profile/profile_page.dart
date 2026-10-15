// Tab 4 — "Profil": name, role and subscription.
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/badge_label.dart';
import '../../shared/widgets/looz_page.dart';
import '../../shared/widgets/role_badge.dart';
import 'profile_data.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const user = fakeUser;
    return LoozPage(
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
                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                RoleBadge(role: user.role),
                const SizedBox(height: 12),
                // Subscription badge: gold "Premium" or brown "Gratuit".
                BadgeLabel(
                  text: user.isPremium ? AppStrings.premium : AppStrings.free,
                  color: user.isPremium ? AppColors.premium : AppColors.brown,
                  icon: user.isPremium ? Icons.star : Icons.eco,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
