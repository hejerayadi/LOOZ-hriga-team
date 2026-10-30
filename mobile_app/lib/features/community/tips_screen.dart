// The tips library ("مكتبة النصائح"), opened from the tip of the day.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/tip_row.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tips = [
      (AppIcon.sun, l10n.tipWaterBeforeSun),
      (AppIcon.leaf, l10n.tipCheckLeaves),
      (AppIcon.bug, l10n.tipPhotoInsects),
    ];
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.tipsTitle),
        for (final (i, (icon, text)) in tips.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          // Reading aloud does not work yet: "قريبًا".
          TipRow(icon: icon, text: text, onSpeaker: () => showSoon(context)),
        ],
      ],
    );
  }
}
