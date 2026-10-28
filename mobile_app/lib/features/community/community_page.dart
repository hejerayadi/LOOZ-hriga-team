// Tab 2 — Community ("المجتمع"): a question from a farmer with its photo,
// the tip of the day, and a button to ask a question.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/tip_row.dart';
import '../ask/ask_screen.dart';
import 'tips_screen.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellContent(
      children: [
        ScreenTitle(
          title: l10n.communityTitle,
          subtitle: l10n.communitySubtitle,
        ),
        const _FeedCard(),
        const SizedBox(height: 14),
        TipRow(
          icon: AppIcon.drop,
          text: l10n.tipOfTheDay,
          onSpeaker: () => openScreen(context, const TipsScreen()),
        ),
        const SizedBox(height: 14),
        ActionButton(
          label: l10n.askAQuestion,
          onPressed: () => openScreen(context, const AskScreen()),
        ),
      ],
    );
  }
}

/// A farmer's question: photo, text, answers and the expert badge.
class _FeedCard extends StatelessWidget {
  const _FeedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.asset(
              'assets/images/almond_blossoms.jpg',
              height: 220,
              fit: BoxFit.cover,
              semanticLabel: l10n.almondBlossoms,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isThisFlowerHealthy,
                  style: AppTextStyles.of(20, FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // DEMO: the voice answers can't be played yet.
                    Semantics(
                      button: true,
                      label: l10n.a11yPlay,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: SymbolText('▶', style: AppTextStyles.of(16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.answers('$fakeAnswers'),
                      style: AppTextStyles.of(16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: SymbolText(
                    '◆ ${l10n.verifiedExpert}',
                    style: AppTextStyles.of(16, FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
