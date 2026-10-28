// The round "read aloud" button of the design (a speaker on mint).
// DEMO: it does not speak yet (that needs a text-to-speech package).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

class SpeakerButton extends StatelessWidget {
  const SpeakerButton({super.key, this.onPressed, this.iconSize = 28});

  /// null = nothing happens yet (demo).
  final VoidCallback? onPressed;

  /// 28, or 24 on the weather card.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.a11yReadAloud,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: LoozIcon(AppIcon.speaker, size: iconSize),
        ),
      ),
    );
  }
}
