// "وجدت شيئًا": what the assistant found (DEMO: always aphids), why, and
// what to do. A button asks an expert in the community.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../shared/widgets/symbol_text.dart';
import 'thinking_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocks = [
      (AppIcon.bug, l10n.whatIsIt, l10n.smallInsect),
      (AppIcon.sun, l10n.why, l10n.warmWeather),
      (AppIcon.drop, l10n.whatToDo, l10n.rinseLeaf),
    ];
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.resultTitle),
        CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          shadows: AppShadows.card,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const MoodFace(level: StatusLevel.warning),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.maybeAphids, style: AppTextStyles.cardTitle),
                    SymbolText(
                      confidenceDots(),
                      style: AppTextStyles.of(12.8)
                          .copyWith(color: AppColors.leaf, letterSpacing: 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const SpeakerButton(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, (icon, question, answer)) in blocks.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          CssBox(
            minHeight: 82,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(25),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBlob(icon: icon),
                const SizedBox(width: 12),
                // The question takes the free space: the answer is at the end.
                Expanded(
                  child: Text(
                    question,
                    style: AppTextStyles.of(18, FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(answer, style: AppTextStyles.of(16)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        ActionButton(
          label: l10n.askAnExpert,
          secondary: true,
          onPressed: () => goToTab(context, AppTab.community),
        ),
      ],
    );
  }
}
