// Small helpers to draw exactly like the design's CSS, which Flutter does a
// bit differently: gradient angles, round gradients and shadow blur.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A CSS shadow: `box-shadow: x y blur color`.
/// (CSS and Flutter measure the blur differently: this converts it.)
BoxShadow cssShadow(double x, double y, double blur, Color color) {
  return BoxShadow(
    color: color,
    offset: Offset(x, y),
    blurRadius: blur <= 1 ? 0 : (blur / 2 - 0.5) / 0.57735,
  );
}

/// CSS `linear-gradient(<angle>deg, ...)`: 0 = upwards, 90 = to the right.
/// Unlike Flutter's LinearGradient, the angle stays the same on any shape.
class CssLinearGradient extends Gradient {
  const CssLinearGradient({
    required this.angle,
    required super.colors,
    super.stops,
  });

  /// In degrees, like in CSS.
  final double angle;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final a = angle * math.pi / 180;
    final direction = Offset(math.sin(a), -math.cos(a));
    final length =
        (rect.width * math.sin(a)).abs() + (rect.height * math.cos(a)).abs();
    final half = direction * (length / 2);
    return ui.Gradient.linear(
      rect.center - half,
      rect.center + half,
      colors,
      _stops(),
    );
  }

  List<double>? _stops() => stops ?? _evenStops(colors.length);

  @override
  CssLinearGradient scale(double factor) => CssLinearGradient(
    angle: angle,
    colors: [for (final c in colors) Color.lerp(null, c, factor)!],
    stops: stops,
  );

  @override
  CssLinearGradient withOpacity(double opacity) => CssLinearGradient(
    angle: angle,
    colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
    stops: stops,
  );
}

/// CSS `radial-gradient(circle at x% y%, ...)`: a circle that reaches the
/// farthest corner of the box. [center] is in fractions (0.1, 0.08 = 10% 8%).
class CssRadialGradient extends Gradient {
  const CssRadialGradient({
    required this.center,
    required super.colors,
    super.stops,
  });

  final Offset center;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final c =
        rect.topLeft + Offset(rect.width * center.dx, rect.height * center.dy);
    final radius = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((corner) => (corner - c).distance).reduce(math.max);
    return ui.Gradient.radial(
      c,
      radius,
      colors,
      stops ?? _evenStops(colors.length),
    );
  }

  @override
  CssRadialGradient scale(double factor) => CssRadialGradient(
    center: center,
    colors: [for (final c in colors) Color.lerp(null, c, factor)!],
    stops: stops,
  );

  @override
  CssRadialGradient withOpacity(double opacity) => CssRadialGradient(
    center: center,
    colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
    stops: stops,
  );
}

List<double> _evenStops(int count) => [
  for (var i = 0; i < count; i++) count == 1 ? 0 : i / (count - 1),
];

/// CSS `repeating-linear-gradient(<angle>deg, ...)`: the [stops] are in
/// pixels along the gradient line and repeat every [period] pixels.
class CssRepeatingLinearGradient extends Gradient {
  const CssRepeatingLinearGradient({
    required this.angle,
    required this.period,
    required super.colors,
    required List<double> super.stops,
  });

  final double angle;
  final double period;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final a = angle * math.pi / 180;
    final direction = Offset(math.sin(a), -math.cos(a));
    final length =
        (rect.width * math.sin(a)).abs() + (rect.height * math.cos(a)).abs();
    final start = rect.center - direction * (length / 2);
    return ui.Gradient.linear(start, start + direction * period, colors, [
      for (final s in stops!) s / period,
    ], TileMode.repeated);
  }

  @override
  CssRepeatingLinearGradient scale(double factor) => CssRepeatingLinearGradient(
    angle: angle,
    period: period,
    colors: [for (final c in colors) Color.lerp(null, c, factor)!],
    stops: stops!,
  );

  @override
  CssRepeatingLinearGradient withOpacity(double opacity) =>
      CssRepeatingLinearGradient(
        angle: angle,
        period: period,
        colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
        stops: stops!,
      );
}
