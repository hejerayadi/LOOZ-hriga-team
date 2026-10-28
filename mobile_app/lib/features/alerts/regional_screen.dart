// "تنبيه في منطقتك": aphids are near (34 farmers reported them).
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';

class RegionalScreen extends StatefulWidget {
  const RegionalScreen({super.key});

  @override
  State<RegionalScreen> createState() => _RegionalScreenState();
}

class _RegionalScreenState extends State<RegionalScreen> {
  // DEMO: "أنا أراه أيضًا" adds the farmer to the count (once).
  bool _seenToo = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final farmers = fakeFarmersReported + (_seenToo ? 1 : 0);
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.regionalTitle),
        CssBox(
          height: 320,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          gradient: const CssLinearGradient(
            angle: 145,
            colors: [AppColors.yellow, AppColors.peach],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconBlob(icon: AppIcon.bug, size: 90, iconSize: 60),
              const SizedBox(height: 12),
              const MoodFace(level: StatusLevel.warning, small: true),
              const SizedBox(height: 12),
              Text(
                l10n.aphidsNearby,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(24, FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.checkYourLeaves,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoozIcon(AppIcon.people),
            const SizedBox(width: 8),
            Text('$farmers', style: AppTextStyles.of(18, FontWeight.w700)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(l10n.farmersReported, style: AppTextStyles.of(18)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ActionButton(
          label: l10n.meToo,
          onPressed: _seenToo ? null : () => setState(() => _seenToo = true),
        ),
      ],
    );
  }
}
