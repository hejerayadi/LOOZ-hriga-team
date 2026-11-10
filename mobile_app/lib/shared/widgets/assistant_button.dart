// The "اسأل المساعد" pill of the assistant bar (the design's "ask-pill"):
// the orb, the text and a microphone. It opens the voice assistant.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../features/ask/voice_screen.dart';
import 'app_icon.dart';
import 'assistant_orb.dart';

class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, this.compact = false});

  /// true = only the orb, in a round button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        // Premium (free plan: the "locked" screen of "بستاني ★").
        onTap: () =>
            openFeature(context, Feature.assistant, const VoiceScreen()),
        child: Container(
          width: compact ? AppSizes.roundButton : null,
          height: AppSizes.assistantBarHeight,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.assistantBar,
          ),
          child: compact
              ? const Center(child: AssistantOrb(size: OrbSize.tiny))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const AssistantOrb(size: OrbSize.tiny),
                    Flexible(
                      child: Text(
                        context.l10n.askAssistant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.assistantBar,
                      ),
                    ),
                    const LoozIcon(AppIcon.mic, size: 25),
                  ],
                ),
        ),
      ),
    );
  }
}
