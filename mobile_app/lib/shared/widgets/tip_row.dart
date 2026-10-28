// A white row of the design ("tip-card", "tip-row"): an icon blob, a bold
// text and the round speaker button.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'blob.dart';
import 'css_box.dart';
import 'speaker_button.dart';

class TipRow extends StatelessWidget {
  const TipRow({
    super.key,
    required this.icon,
    required this.text,
    this.onSpeaker,
  });

  final AppIcon icon;
  final String text;

  /// The speaker button (null = no sound yet, demo).
  final VoidCallback? onSpeaker;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      minHeight: 82,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(26),
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconBlob(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.of(17, FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          SpeakerButton(onPressed: onSpeaker),
        ],
      ),
    );
  }
}
