// The face of the design: a green blob with 2 eyes and a mouth.
// Light green + smile = fine, medium green = watch, dark green = act now.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import 'blob.dart';
import 'css_box.dart';

class MoodFace extends StatelessWidget {
  const MoodFace({
    super.key,
    required this.level,
    this.small = false,
    this.ring = false,
    this.semanticLabel,
  });

  final StatusLevel level;

  /// true = the small face of the cards (62 x 58), else 92 x 82.
  final bool small;

  /// true = with a white ring and a darker shadow (the trees on the map).
  final bool ring;

  /// Read aloud by screen readers (e.g. the health level).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final outer = small ? const Size(62, 58) : const Size(92, 82);
    // Like CSS: the eyes and the mouth are placed inside the ring.
    final size = ring ? Size(outer.width - 6, outer.height - 6) : outer;
    final eye = small ? const Size(5, 7) : const Size(8, 11);
    final ok = level == StatusLevel.good;

    // The mouth is the edge of a small oval: its bottom edge = a smile,
    // its top edge = a worried mouth. (The small faces show more of the oval.)
    const line = BorderSide(color: AppColors.green, width: 3);
    final Border mouthBorder;
    if (!small) {
      final side = line.copyWith(width: 4);
      mouthBorder = ok ? Border(bottom: side) : Border(top: side);
    } else {
      mouthBorder = ok
          ? Border.all(color: AppColors.green, width: 3)
          : const Border(top: line, left: line, right: line);
    }
    final mouth = Size(size.width * 0.27, size.height * 0.13);

    return Semantics(
      label: semanticLabel,
      child: CssBox(
        width: outer.width,
        height: outer.height,
        color: AppColors.forLevel(level),
        borderRadius: blobRadius(
          outer,
          BlobShapes.faceAcross,
          BlobShapes.faceUpDown,
        ),
        border: ring ? Border.all(color: AppColors.white, width: 3) : null,
        shadows: ring ? AppShadows.mapTree : AppShadows.face,
        highlight: ring ? null : AppHighlights.face,
        highlightColor: AppHighlights.faceColor,
        child: Stack(
          children: [
            for (final left in [true, false])
              Positioned(
                top: size.height * 0.29,
                left: left ? size.width * 0.29 : null,
                right: left ? null : size.width * 0.29,
                width: eye.width,
                height: eye.height,
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.green,
                    shape: OvalBorder(),
                  ),
                ),
              ),
            Positioned(
              left: size.width * 0.36,
              bottom: size.height * (ok ? 0.25 : 0.18),
              width: mouth.width,
              height: mouth.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: mouthBorder,
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(mouth.width / 2, mouth.height / 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
