// "دفتر البستان": what the farmer did today (watering, treatment,
// pruning, harvest), by voice or with the 4 buttons.
//
// DEMO: nothing is saved yet. The buttons do nothing in the design;
// "حفظ" goes back.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activities = [
      (AppIcon.drop, l10n.watering),
      (AppIcon.bug, l10n.treatment),
      (AppIcon.leaf, l10n.pruning),
      (AppIcon.tree, l10n.harvest),
    ];
    Widget tile(int i) => Expanded(
      child: CssBox(
        height: 120,
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        shadows: AppShadows.card,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBlob(icon: activities[i].$1, iconSize: 34),
            const SizedBox(height: 8),
            Text(
              activities[i].$2,
              style: AppTextStyles.of(18, FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.journalTitle, subtitle: l10n.journalSubtitle),
        CssBox(
          height: 120,
          color: const Color(0xFFE0F3D7),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AssistantOrb(icon: AppIcon.mic, iconSize: 38),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  l10n.dictateNote,
                  style: AppTextStyles.of(21, FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [tile(0), const SizedBox(width: 12), tile(1)]),
        const SizedBox(height: 12),
        Row(children: [tile(2), const SizedBox(width: 12), tile(3)]),
        const SizedBox(height: 16),
        ActionButton(
          label: l10n.save,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
