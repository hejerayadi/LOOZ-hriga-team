// "اسأل سؤالًا": how to ask (speak, photo or text), then send.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../camera/camera_screen.dart';
import '../community/write_post_screen.dart';
import 'voice_screen.dart';

class AskScreen extends StatelessWidget {
  const AskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The voice chat is Premium (free plan: the "locked" screen).
    void speak() =>
        openFeature(context, Feature.assistant, const VoiceScreen());
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.askTitle, subtitle: l10n.askSubtitle),
        // "Speak" is the chosen way (the big green card).
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: speak,
            child: CssBox(
              height: 190,
              color: const Color(0xFFE5F5DD),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AssistantOrb(icon: AppIcon.mic),
                  const SizedBox(height: 16),
                  Text(
                    l10n.speak,
                    style: AppTextStyles.of(22, FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.speakHint, style: AppTextStyles.of(16)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Choice(
          icon: AppIcon.camera,
          label: l10n.photo,
          onTap: () => openFeature(
            context,
            Feature.photoDiagnosis,
            const CameraScreen(),
          ),
        ),
        const SizedBox(height: 14),
        // Writes a question for the community (the app's own screen).
        _Choice(
          icon: AppIcon.book,
          label: l10n.text,
          onTap: () => openScreen(context, const WritePostScreen()),
        ),
        const SizedBox(height: 14),
        ActionButton(label: l10n.send, onPressed: speak),
      ],
    );
  }
}

/// A white card: an icon blob and a word ("صورة", "كتابة").
class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.label, required this.onTap});

  final AppIcon icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          minHeight: 90,
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          shadows: AppShadows.card,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              IconBlob(icon: icon, iconSize: 38),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.of(22, FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
