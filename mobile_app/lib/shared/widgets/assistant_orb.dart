// The assistant "orb" of the design: a shiny green blob with a smile
// (or an icon, like the microphone).
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'blob.dart';
import 'css_box.dart';
import 'symbol_text.dart';

/// The 3 sizes of the design.
enum OrbSize {
  tiny(Size(43, 41), 18),
  normal(Size(76, 70), 16),
  giant(Size(145, 135), 40);

  const OrbSize(this.size, this.smileSize);

  final Size size;

  /// Font size of the smile "⌣".
  final double smileSize;
}

class AssistantOrb extends StatelessWidget {
  const AssistantOrb({
    super.key,
    this.size = OrbSize.normal,
    this.icon,
    this.iconSize = 42,
    this.glow,
  });

  final OrbSize size;

  /// null = the smile.
  final AppIcon? icon;
  final double iconSize;

  /// Another glow (the orb "breathes" while listening).
  final List<BoxShadow>? glow;

  @override
  Widget build(BuildContext context) {
    final box = size.size;
    final tiny = size == OrbSize.tiny;
    final icon = this.icon;
    return CssBox(
      width: box.width,
      height: box.height,
      gradient: AppGradients.orb,
      borderRadius: blobRadius(box, BlobShapes.orb),
      shadows: glow ?? (tiny ? AppShadows.orbTiny : AppShadows.orb),
      // The tiny orb has no light band in the design.
      highlight: tiny ? null : AppHighlights.orb,
      highlightColor: AppHighlights.orbColor,
      alignment: Alignment.center,
      child: icon != null
          ? LoozIcon(icon, size: iconSize, color: AppColors.orbIcon)
          : SymbolText(
              '⌣',
              style: AppTextStyles.of(size.smileSize)
                  .copyWith(color: AppColors.orbIcon),
            ),
    );
  }
}
