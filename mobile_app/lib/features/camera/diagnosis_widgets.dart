// The small pieces of the photo diagnosis screens (in the design's style):
// the "تجريبي" tag, the tips of the camera, its message card and gallery
// pill, and the photo with the sick spots marked.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_photos.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';

/// "تجريبي / Bêta": a small yellow-green pill.
class BetaTag extends StatelessWidget {
  const BetaTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.leaf,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        context.l10n.betaTag,
        style: AppTextStyles.of(14, FontWeight.w800),
      ),
    );
  }
}

/// A tip of the camera ("من قريب"): an icon and a word on a white pill.
class PhotoTip extends StatelessWidget {
  const PhotoTip({super.key, required this.icon, required this.text});

  final AppIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 14, 0),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoozIcon(icon, size: 20),
          const SizedBox(width: 6),
          Text(text, style: AppTextStyles.of(15, FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A message on the camera screen (no internet, limit of the day...): a
/// white card with the warning icon.
class CameraNote extends StatelessWidget {
  const CameraNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: CssBox(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.md),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const LoozIcon(AppIcon.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: AppTextStyles.of(16, FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "اختر من الصور" under the round button of the camera.
class GalleryPill extends StatelessWidget {
  const GalleryPill({super.key, required this.label, required this.onTap});

  final String label;

  /// null = not now (faded).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: 46,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 18, 0),
            decoration: BoxDecoration(
              color: const Color(0xD9FFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LoozIcon(AppIcon.image, size: 22),
                const SizedBox(width: 8),
                Text(label, style: AppTextStyles.of(16, FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo of the leaf, with a frame around each sick spot ([marked]:
/// fractions of the photo). The same in both languages (never mirrored).
class MarkedPhoto extends StatelessWidget {
  const MarkedPhoto({super.key, required this.photo, this.marked = const []});

  final PreparedPhoto photo;
  final List<Rect> marked;

  @override
  Widget build(BuildContext context) {
    final ratio = photo.height == 0 ? 1.0 : photo.width / photo.height;
    return Semantics(
      image: true,
      label: marked.isEmpty ? null : context.l10n.spotsMarked,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                photo.bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
              if (marked.isNotEmpty)
                CustomPaint(painter: _MarksPainter(marked)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marked);

  final List<Rect> marked;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xCCFFFFFF);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0xFFE5484D); // red: seen on green leaves
    for (final box in marked) {
      final rect = Rect.fromLTRB(
        box.left * size.width,
        box.top * size.height,
        box.right * size.width,
        box.bottom * size.height,
      ).inflate(3);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(shape, outline);
      canvas.drawRRect(shape, line);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => old.marked != marked;
}
