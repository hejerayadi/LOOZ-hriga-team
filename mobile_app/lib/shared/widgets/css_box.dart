// CssBox: a box drawn like the boxes of the design's CSS: a background,
// round corners (any shape), shadows, a border, and the light band at the
// top of buttons and faces (CSS "inset" shadow).
import 'package:flutter/material.dart';

class CssBox extends StatelessWidget {
  const CssBox({
    super.key,
    this.width,
    this.height,
    this.minHeight = 0,
    this.color,
    this.gradient,
    this.image,
    this.borderRadius = BorderRadius.zero,
    this.shadows,
    this.border,
    this.highlight,
    this.highlightColor = const Color(0x00000000),
    this.padding = EdgeInsets.zero,
    this.alignment,
    this.clip = false,
    this.child,
  });

  final double? width;
  final double? height;
  final double minHeight;
  final Color? color;
  final Gradient? gradient;
  final DecorationImage? image;
  final BorderRadius borderRadius;
  final List<BoxShadow>? shadows;

  /// A border inside the box (like CSS: the padding starts after it).
  final BoxBorder? border;

  /// The light band at the top: how far the box shape is moved (e.g. 0, 2).
  final Offset? highlight;
  final Color highlightColor;

  final EdgeInsetsGeometry padding;
  final AlignmentGeometry? alignment;

  /// true = cut what goes out of the round corners (CSS overflow: hidden).
  final bool clip;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget content = child ?? const SizedBox.shrink();
    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }
    // Like CSS "border-box": the content starts inside the border.
    content = Padding(
      padding: padding.add(border?.dimensions ?? EdgeInsets.zero),
      child: content,
    );
    if (highlight != null) {
      content = CustomPaint(
        painter: _HighlightPainter(borderRadius, highlight!, highlightColor),
        child: content,
      );
    }
    if (clip) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }
    content = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        image: image,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: border,
      ),
      child: content,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight)
          .tighten(width: width, height: height),
      child: content,
    );
  }
}

/// Paints the inside of the shape minus the same shape moved by [offset]:
/// a thin light band along the top edge.
class _HighlightPainter extends CustomPainter {
  _HighlightPainter(this.radius, this.offset, this.color);

  final BorderRadius radius;
  final Offset offset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()..addRRect(radius.toRRect(Offset.zero & size));
    final band = Path.combine(
      PathOperation.difference,
      shape,
      shape.shift(offset),
    );
    canvas.drawPath(band, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.radius != radius || old.offset != offset || old.color != color;
}
