// Badge showing the user role: "Agriculteur" (pale green) or "Expert" (mint).
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'badge_label.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isExpert = role == UserRole.expert;
    return BadgeLabel(
      text: AppStrings.role(role),
      color: isExpert ? AppColors.mint : AppColors.yellow,
      icon: isExpert ? Icons.verified : Icons.agriculture,
    );
  }
}
