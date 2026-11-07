// Sign-up, after the code: "من أنت؟" — one question on its own screen, two
// big buttons with an icon (many farmers read with difficulty):
//   "فلاح" (farmer) or "مهندس فلاحي أو مرشد" (agronomist / adviser).
// One tap opens "معلوماتك" with only the boxes of that person (the role is
// saved there, with the name).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/user_profile.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import 'sign_up_info_screen.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  void _choose(BuildContext context, UserRole role) =>
      openScreen(context, SignUpInfoScreen(role: role));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LoozBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageSide(context, shrink: false),
            system.top + 28,
            AppSpacing.pageSide(context, shrink: false),
            system.bottom + 30,
          ),
          children: [
            const LoozHeader(),
            ScreenTitle(
              title: l10n.roleTitle,
              subtitle: l10n.roleSubtitle,
              top: 64,
            ),
            _RoleButton(
              icon: AppIcon.tree,
              label: l10n.roleFarmer,
              hint: l10n.roleFarmerHint,
              onTap: () => _choose(context, UserRole.farmer),
            ),
            const SizedBox(height: 16),
            _RoleButton(
              icon: AppIcon.book,
              label: l10n.roleExpert,
              hint: l10n.roleExpertHint,
              onTap: () => _choose(context, UserRole.expert),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big white button: a big icon blob, the word, a short line under it,
/// and the arrow of the design's buttons.
class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          minHeight: 112,
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              IconBlob(icon: icon, size: 72, iconSize: 38),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppTextStyles.of(22, FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: AppTextStyles.of(16)
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // The design's arrow points right in both languages.
              const LoozIcon(AppIcon.arrow, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
