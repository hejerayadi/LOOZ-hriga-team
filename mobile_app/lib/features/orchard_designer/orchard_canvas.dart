// The drawing of the orchard designer: a grid seen from above (north at
// the top), the outline, the zones with their letters, the corners, and
// the line the finger is drawing. Positions are in METRES (x = east,
// z = south); the canvas turns them into points of the screen and back.
// Works with a finger and with a mouse (Chrome). "من صورة": the photo of
// the sketch can be shown faded under the grid.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/orchard_service.dart';
import 'geometry.dart';

/// metres <-> screen: [frame] (metres) fits in [size], same scale both ways.
class CanvasView {
  factory CanvasView(Size size, Bounds frame, {double padding = 22}) {
    final w = math.max(frame.width, 1.0);
    final l = math.max(frame.length, 1.0);
    final scale = math.max(
      0.0001,
      math.min((size.width - 2 * padding) / w, (size.height - 2 * padding) / l),
    );
    final c = frame.center;
    return CanvasView._(
      Offset(size.width / 2 - c.x * scale, size.height / 2 - c.z * scale),
      scale,
    );
  }

  const CanvasView._(this.origin, this.scale);

  /// Where (0, 0) is on the screen.
  final Offset origin;

  /// Screen points per metre.
  final double scale;

  Offset toScreen(OrchardPoint p) => origin + Offset(p.x * scale, p.z * scale);

  OrchardPoint toMetres(Offset o) =>
      OrchardPoint((o.dx - origin.dx) / scale, (o.dy - origin.dy) / scale);

  /// A distance on the screen, in metres.
  double metres(double screenPoints) => screenPoints / scale;
}

/// The box to show around [p]: a little margin on each side.
Bounds frameAround(Polygon p, {double margin = 0.12}) {
  if (p.length < 2) return const Bounds(-100, -100, 100, 100);
  final b = boundsOf(p);
  final mx = math.max(b.width, 10.0) * margin;
  final mz = math.max(b.length, 10.0) * margin;
  return Bounds(b.minX - mx, b.minZ - mz, b.maxX + mx, b.maxZ + mz);
}

/// A square frame of [side] metres around (0, 0) (a new drawing).
Bounds squareFrame(double side) =>
    Bounds(-side / 2, -side / 2, side / 2, side / 2);

/// The metres of one grid square, so that a square is at least [minPoints]
/// on the screen (1, 2, 5, 10, 20, 25, 50... m).
double gridStep(double scale, {double minPoints = 34}) {
  const steps = [1.0, 2.0, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 250.0];
  for (final s in steps) {
    if (s * scale >= minPoints) return s;
  }
  var s = 500.0;
  while (s * scale < minPoints) {
    s *= 2;
  }
  return s;
}

/// "20" / "2.5": a whole number when it is one.
String metresText(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// A zone as the canvas draws it.
class CanvasZone {
  const CanvasZone({
    required this.letter,
    required this.boundary,
    required this.color,
  });

  final String letter;
  final Polygon boundary;

  /// "#8BC34A".
  final String color;
}

Color colorOf(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x8BC34A;
  return Color(0xFF000000 | v);
}

class OrchardCanvas extends StatelessWidget {
  const OrchardCanvas({
    super.key,
    required this.frame,
    required this.semanticLabel,
    this.outline = const [],
    this.closed = true,
    this.zones = const [],
    this.stroke = const [],
    this.cutLine,
    this.showCorners = false,
    this.highlightFirst = false,
    this.gridLabel,
    this.northLabel,
    this.onTap,
    this.onDragStart,
    this.onDrag,
    this.onDragEnd,
    this.photo,
    this.photoPlace,
  });

  /// The photo of a sketch, faded under the grid ("من صورة"), at
  /// [photoPlace] (metres). null = none.
  final ui.Image? photo;
  final Bounds? photoPlace;

  /// The metres shown.
  final Bounds frame;
  final String semanticLabel;
  final Polygon outline;

  /// false = the outline is still open (corners being placed).
  final bool closed;
  final List<CanvasZone> zones;

  /// The line the finger is drawing (metres).
  final List<OrchardPoint> stroke;

  /// The dividing line being drawn.
  final (OrchardPoint, OrchardPoint)? cutLine;

  /// true = the corners can be moved: show them as round handles.
  final bool showCorners;

  /// true = the first corner is bigger (tap it to close the shape).
  final bool highlightFirst;

  /// "المربّع = 20 م" (from the grid step, in metres).
  final String Function(String metres)? gridLabel;
  final String? northLabel;

  /// Gestures, in metres (+ the view, for distances on the screen).
  final void Function(OrchardPoint p, CanvasView view)? onTap;
  final void Function(OrchardPoint p, CanvasView view)? onDragStart;
  final void Function(OrchardPoint p, CanvasView view)? onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final view = CanvasView(size, frame);
        final step = gridStep(view.scale);
        final label = gridLabel?.call(metresText(step));
        Widget canvas = CustomPaint(
          size: size,
          painter: _OrchardPainter(
            view: view,
            gridMetres: step,
            outline: outline,
            closed: closed,
            zones: zones,
            stroke: stroke,
            cutLine: cutLine,
            showCorners: showCorners,
            highlightFirst: highlightFirst,
            gridLabel: label,
            northLabel: northLabel,
            direction: direction,
            photo: photo,
            photoPlace: photoPlace,
          ),
        );
        if (onTap != null || onDragStart != null) {
          canvas = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null
                ? null
                : (d) => onTap!(view.toMetres(d.localPosition), view),
            onPanStart: onDragStart == null
                ? null
                : (d) => onDragStart!(view.toMetres(d.localPosition), view),
            onPanUpdate: onDrag == null
                ? null
                : (d) => onDrag!(view.toMetres(d.localPosition), view),
            onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
            child: canvas,
          );
        }
        return Semantics(label: semanticLabel, image: true, child: canvas);
      },
    );
  }
}

class _OrchardPainter extends CustomPainter {
  _OrchardPainter({
    required this.view,
    required this.gridMetres,
    required this.outline,
    required this.closed,
    required this.zones,
    required this.stroke,
    required this.cutLine,
    required this.showCorners,
    required this.highlightFirst,
    required this.gridLabel,
    required this.northLabel,
    required this.direction,
    required this.photo,
    required this.photoPlace,
  });

  final CanvasView view;
  final ui.Image? photo;
  final Bounds? photoPlace;
  final double gridMetres;
  final Polygon outline;
  final bool closed;
  final List<CanvasZone> zones;
  final List<OrchardPoint> stroke;
  final (OrchardPoint, OrchardPoint)? cutLine;
  final bool showCorners;
  final bool highlightFirst;
  final String? gridLabel;
  final String? northLabel;
  final TextDirection direction;

  Path _path(Polygon p, {bool close = true}) {
    final path = Path();
    for (final (i, q) in p.indexed) {
      final o = view.toScreen(q);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    if (close) path.close();
    return path;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    Alignment align = Alignment.center,
    TextDirection? textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection ?? direction,
    )..layout();
    final offset = Offset(
      at.dx - painter.width * (align.x + 1) / 2,
      at.dy - painter.height * (align.y + 1) / 2,
    );
    painter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    // 0. The photo of the sketch, faded.
    final picture = photo, place = photoPlace;
    if (picture != null && place != null) {
      canvas.drawImageRect(
        picture,
        Rect.fromLTWH(
          0,
          0,
          picture.width.toDouble(),
          picture.height.toDouble(),
        ),
        Rect.fromPoints(
          view.toScreen(OrchardPoint(place.minX, place.minZ)),
          view.toScreen(OrchardPoint(place.maxX, place.maxZ)),
        ),
        Paint()
          ..color =
              const Color(0x8C000000) // 55 %
          ..filterQuality = FilterQuality.medium,
      );
    }

    // 1. The grid: light lines every gridMetres.
    final grid = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 1;
    final topLeft = view.toMetres(Offset.zero);
    final bottomRight = view.toMetres(Offset(size.width, size.height));
    for (
      var x = (topLeft.x / gridMetres).floor() * gridMetres;
      x <= bottomRight.x;
      x += gridMetres
    ) {
      final sx = view.toScreen(OrchardPoint(x, 0)).dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), grid);
    }
    for (
      var z = (topLeft.z / gridMetres).floor() * gridMetres;
      z <= bottomRight.z;
      z += gridMetres
    ) {
      final sz = view.toScreen(OrchardPoint(0, z)).dy;
      canvas.drawLine(Offset(0, sz), Offset(size.width, sz), grid);
    }

    // 2. The zones (or the outline alone).
    if (zones.isNotEmpty) {
      for (final zone in zones) {
        final path = _path(zone.boundary);
        canvas.drawPath(
          path,
          Paint()..color = colorOf(zone.color).withValues(alpha: 0.55),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = AppColors.white
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round,
        );
      }
    } else if (outline.length >= 3 && closed) {
      canvas.drawPath(
        _path(outline),
        Paint()
          ..color = AppColors.lightGreen.withValues(
            alpha: photo == null ? 0.55 : 0.3,
          ),
      );
    }
    if (outline.length >= 2) {
      canvas.drawPath(
        _path(outline, close: closed),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.green
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // 3. The letters of the zones.
    for (final zone in zones) {
      final at = view.toScreen(labelPoint(zone.boundary));
      canvas.drawCircle(at, 14, Paint()..color = AppColors.white);
      canvas.drawCircle(
        at,
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colorOf(zone.color),
      );
      _text(
        canvas,
        zone.letter,
        at,
        AppTextStyles.of(15, FontWeight.w800),
        textDirection: TextDirection.ltr,
      );
    }

    // 4. The corners (handles to move them).
    if (showCorners || !closed) {
      for (final (i, p) in outline.indexed) {
        final at = view.toScreen(p);
        final big = i == 0 && highlightFirst;
        canvas.drawCircle(at, big ? 15 : 10, Paint()..color = AppColors.white);
        canvas.drawCircle(
          at,
          big ? 15 : 10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = big ? 4 : 3
            ..color = big ? AppColors.leaf : AppColors.green,
        );
      }
    }

    // 5. The finger's line, the dividing line.
    if (stroke.length >= 2) {
      canvas.drawPath(
        _path(stroke, close: false),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.green
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final cut = cutLine;
    if (cut != null) {
      final a = view.toScreen(cut.$1);
      final b = view.toScreen(cut.$2);
      final dash = Paint()
        ..color = AppColors.green
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final length = (b - a).distance;
      if (length > 0) {
        final unit = (b - a) / length;
        for (var d = 0.0; d < length; d += 14) {
          canvas.drawLine(
            a + unit * d,
            a + unit * math.min(d + 8, length),
            dash,
          );
        }
      }
      canvas.drawCircle(a, 7, Paint()..color = AppColors.green);
      canvas.drawCircle(b, 7, Paint()..color = AppColors.green);
    }

    // 6. North at the top, the size of a square.
    final small = AppTextStyles.of(
      13,
      FontWeight.w700,
    ).copyWith(color: AppColors.textMuted);
    final north = northLabel;
    if (north != null) {
      // A small arrow pointing up (drawn: the glyph is not in the font).
      final arrow = Path()
        ..moveTo(16, 7)
        ..lineTo(22, 17)
        ..lineTo(10, 17)
        ..close();
      canvas.drawPath(arrow, Paint()..color = AppColors.textMuted);
      canvas.drawLine(
        const Offset(16, 16),
        const Offset(16, 24),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 2.5,
      );
      _text(
        canvas,
        north,
        const Offset(27, 8),
        small,
        align: Alignment.topLeft,
        textDirection: direction,
      );
    }
    final label = gridLabel;
    if (label != null) {
      _text(
        canvas,
        label,
        Offset(size.width - 10, size.height - 8),
        small,
        align: Alignment.bottomRight,
      );
    }
  }

  @override
  bool shouldRepaint(_OrchardPainter old) => true;
}
