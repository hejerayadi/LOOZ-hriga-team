// "من صورة": finds the outline of the orchard on a PHOTO of a sketch drawn
// on paper. Classic image processing, no AI, nothing sent anywhere: plain
// Dart maths on the pixels, so it runs the same in Chrome and on Android
// (and in test/sketch_detect_test.dart).
//
//   1. The photo, at most 800 px.
//   2. The sheet of paper = the big bright areas (slightly blurred: thin
//      squares of the paper melt into it), grown into the grey paper of a
//      shadow (a wooden table is coloured: it stays out). When the sheet's 4
//      corners are in the photo, it is straightened (as if taken from above).
//   3. The ink = clearly darker than the paper around it (a local
//      threshold: shadows don't matter). Brightness = the brightest colour
//      channel, so light blue or pink squares of the paper are not ink.
//   4. Small gaps of the pen line are closed (a few pixels).
//   5. Everything the paper's edge can't reach without crossing ink is
//      "inside a closed line"; the biggest such shape with mostly empty
//      paper inside is the orchard. Numbers, words, trees and lines drawn
//      inside it are inside it: they don't count. Small marks outside are
//      too small.
//   6. Its border, traced pixel by pixel. When the sheet's corners were not
//      seen, a small tilt (< 15°) shared by its long sides is straightened
//      (the photo too).
// placeSketch() then puts it on the designer's grid and cleans it with the
// SAME code as a line drawn with the finger (cleanUpStroke).
import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/orchard_service.dart' show OrchardPoint;
import 'geometry.dart';
import 'outline_editor.dart' show minOrchardArea;

/// "Very far" (no bit shift: on the web `-1 << 30` is a big POSITIVE number).
const _far = 1000000000;

/// The longest side of the picture worked on (pixels).
const sketchMaxSide = 800;

/// A small tilt of the drawing is straightened below this (degrees).
const sketchMaxTilt = 15.0;

/// How much the pen line may wobble around a straight side, as a part of
/// the picture's longest side.
const sketchWobble = 0.015;

/// Pixels in RGBA order (4 bytes each), row by row.
class SketchImage {
  const SketchImage(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;
}

class SketchResult {
  const SketchResult({
    required this.sheet,
    required this.contour,
    this.straightened = false,
    this.tiltDegrees = 0,
  });

  /// The picture the outline is on (straightened when the sheet was found):
  /// the app shows it faded behind the grid.
  final SketchImage sheet;

  /// The border of the orchard, in pixels of [sheet], in order. Empty = no
  /// closed shape found.
  final List<(double, double)> contour;

  /// true = the sheet's 4 corners were found and the photo straightened.
  final bool straightened;

  /// The tilt that was straightened (degrees, 0 = none).
  final double tiltDegrees;

  bool get found => contour.length >= 3;
}

/// The outline on the grid (metres) and where the photo goes.
class SketchPlacement {
  const SketchPlacement({required this.photo, this.outline});

  /// The photo's place on the grid (metres).
  final Bounds photo;

  /// The outline, cleaned like a finger's line; null = none found (the
  /// farmer taps the corners on the photo).
  final Polygon? outline;
}

/// The sketch on the grid: the photo's longest side is [side] metres
/// (the size of an empty grid), centred at (0, 0).
SketchPlacement placeSketch(SketchResult result, double side) {
  final w = result.sheet.width, h = result.sheet.height;
  final m = side / math.max(w, h);
  final photo = Bounds(-w / 2 * m, -h / 2 * m, w / 2 * m, h / 2 * m);
  if (!result.found) return SketchPlacement(photo: photo);
  final points = [
    for (final (x, y) in result.contour)
      OrchardPoint((x - w / 2) * m, (y - h / 2) * m),
  ];
  final shape = cleanUpStroke(
    points,
    tolerance: sketchWobble * math.max(w, h) * m,
  );
  final ok =
      shape != null &&
      polygonArea(shape) >= minOrchardArea &&
      !edgesCross(shape);
  return SketchPlacement(photo: photo, outline: ok ? shape : null);
}

/// Finds the orchard's outline on [photo] (see the top of this file).
SketchResult findSketch(SketchImage photo) {
  var img = _fit(photo, sketchMaxSide);
  var v = _brightness(img);

  // 2. The sheet of paper: the biggest bright area (slightly blurred: thin
  // lines of squared paper melt into it), grown into the grey paper of a
  // shadow (a wooden table is coloured: it stays out).
  final soft = _blur(
    v,
    img.width,
    img.height,
    math.max(2, sketchMaxSide ~/ 160),
  );
  // (When the sheet fills the photo, light has one level only: the split
  // stays well under the paper's light.)
  final split = math.min(_otsu(soft), (0.75 * _percentile(soft, 0.9)).round());
  // Every big bright part (the drawn line cuts the sheet in two: its inside
  // and the ring around it).
  final seed = _bigParts(_threshold(soft, split), img.width, img.height, 0.05);
  final grown = _growGrey(seed, v, img);
  var paper = _fillHoles(grown, img.width, img.height);
  var straightened = false;
  final quad = _sheetCorners(paper, img.width, img.height);
  if (quad != null) {
    img = _straighten(img, quad);
    v = _brightness(img);
    paper = Uint8List(img.width * img.height)
      ..fillRange(0, img.width * img.height, 1);
    straightened = true;
  } else if (_count(paper) < 0.3 * img.width * img.height) {
    // No clear sheet: the whole photo is the paper.
    paper = Uint8List(img.width * img.height)
      ..fillRange(0, img.width * img.height, 1);
  }
  final w = img.width, h = img.height;
  // A thin band along the sheet's edge (and the photo's) is not paper.
  final band = math.max(2, (0.015 * math.max(w, h)).round());
  final inside = _shrink(paper, w, h, band);

  // 3. The ink.
  final ink = _ink(v, inside, w, h);

  // 4-5. The biggest closed shape (the pen line closed a little more if
  // needed).
  Uint8List? biggestShape(Uint8List region) {
    final area = _count(region);
    for (final r in const [1, 2, 4, 6]) {
      final s = _closedShape(_grow(ink, w, h, r), region, w, h, area);
      if (s != null) return s;
    }
    return null;
  }

  var shape = biggestShape(inside);
  // Almost all the paper: that is the sheet's own edge (a grey or white
  // table): the outline is inside it.
  if (shape != null && _count(shape) > 0.85 * _count(inside)) {
    final inner = biggestShape(_shrink(shape, w, h, 2 * band));
    if (inner != null) shape = inner;
  }
  if (shape == null) {
    return SketchResult(
      sheet: img,
      contour: const [],
      straightened: straightened,
    );
  }

  // 6. Its border. A small tilt is straightened only when the sheet's
  // corners were NOT seen (then the photo may be turned); with the sheet
  // straightened, the drawing's angle is what the farmer drew.
  var contour = _trace(shape, w, h);
  var tilt = 0.0;
  final rough = straightened
      ? null
      : cleanUpStroke([
          for (final (x, y) in contour) OrchardPoint(x, y),
        ], tolerance: sketchWobble * math.max(w, h));
  if (rough != null) {
    final a = _commonTilt(rough);
    if (a != null && a.abs() > 0.5 && a.abs() < sketchMaxTilt) {
      tilt = a;
      img = _rotate(img, -a);
      contour = _rotatePoints(contour, -a, w / 2, h / 2);
    }
  }
  return SketchResult(
    sheet: img,
    contour: contour,
    straightened: straightened,
    tiltDegrees: tilt,
  );
}

// ---------------------------------------------------------------------
// Pixels
// ---------------------------------------------------------------------

/// The picture made smaller (average of the pixels), at most [maxSide].
SketchImage _fit(SketchImage src, int maxSide) {
  final side = math.max(src.width, src.height);
  if (side <= maxSide) return src;
  final f = side / maxSide;
  final w = (src.width / f).round(), h = (src.height / f).round();
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    final y0 = (y * f).floor(), y1 = math.min(src.height, ((y + 1) * f).ceil());
    for (var x = 0; x < w; x++) {
      final x0 = (x * f).floor(),
          x1 = math.min(src.width, ((x + 1) * f).ceil());
      var r = 0, g = 0, b = 0, n = 0;
      for (var yy = y0; yy < y1; yy++) {
        var i = (yy * src.width + x0) * 4;
        for (var xx = x0; xx < x1; xx++, i += 4) {
          r += src.rgba[i];
          g += src.rgba[i + 1];
          b += src.rgba[i + 2];
          n++;
        }
      }
      final o = (y * w + x) * 4;
      out[o] = r ~/ n;
      out[o + 1] = g ~/ n;
      out[o + 2] = b ~/ n;
      out[o + 3] = 255;
    }
  }
  return SketchImage(w, h, out);
}

/// Brightness = the brightest channel (coloured squares look like paper).
Uint8List _brightness(SketchImage img) {
  final n = img.width * img.height;
  final v = Uint8List(n);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    v[i] = math.max(img.rgba[j], math.max(img.rgba[j + 1], img.rgba[j + 2]));
  }
  return v;
}

/// Otsu: the threshold that best splits dark from bright.
int _otsu(Uint8List v) {
  final hist = List<int>.filled(256, 0);
  for (final x in v) {
    hist[x]++;
  }
  final total = v.length;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0.0, wB = 0, best = 0.0, t = 128;
  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB, mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      t = i;
    }
  }
  return t;
}

/// The average over a square of radius [r] (integral image).
Uint8List _blur(Uint8List v, int w, int h, int r) {
  final sums = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      row += v[y * w + x];
      sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row;
    }
  }
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
      final s =
          sums[y1 * (w + 1) + x1] -
          sums[y0 * (w + 1) + x1] -
          sums[y1 * (w + 1) + x0] +
          sums[y0 * (w + 1) + x0];
      out[y * w + x] = (s / ((x1 - x0) * (y1 - y0))).round();
    }
  }
  return out;
}

/// [seed] (the bright paper) grown into the touching pixels that look like
/// paper in a shadow: grey (not coloured like a wooden table) and not dark
/// (more than a third of the sheet's light).
Uint8List _growGrey(Uint8List seed, Uint8List v, SketchImage img) {
  final w = img.width, h = img.height;
  var sum = 0.0, n = 0;
  for (var i = 0; i < seed.length; i++) {
    if (seed[i] == 1) {
      sum += v[i];
      n++;
    }
  }
  if (n == 0) return seed;
  final floor = sum / n / 3;
  final grey = Uint8List(w * h);
  for (var i = 0, j = 0; i < grey.length; i++, j += 4) {
    final r = img.rgba[j], g = img.rgba[j + 1], b = img.rgba[j + 2];
    final hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
    grey[i] = v[i] > floor && hi > 0 && (hi - lo) / hi < 0.18 ? 1 : 0;
  }
  for (var i = 0; i < seed.length; i++) {
    if (seed[i] == 1) grey[i] = 1;
  }
  return _flood(grey, w, h, [
    for (var i = 0; i < seed.length; i++)
      if (seed[i] == 1) i,
  ]);
}

/// The light under which [part] of the pixels are (0.9 = 90 %).
int _percentile(Uint8List v, double part) {
  final hist = List<int>.filled(256, 0);
  for (final x in v) {
    hist[x]++;
  }
  var seen = 0;
  for (var i = 0; i < 256; i++) {
    seen += hist[i];
    if (seen >= part * v.length) return i;
  }
  return 255;
}

Uint8List _threshold(Uint8List v, int t) {
  final out = Uint8List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] > t ? 1 : 0;
  }
  return out;
}

int _count(Uint8List mask) {
  var n = 0;
  for (final x in mask) {
    n += x;
  }
  return n;
}

/// Flood fill (4 neighbours) from [seeds] over the pixels where
/// [passable] is 1. Returns the pixels reached.
Uint8List _flood(Uint8List passable, int w, int h, Iterable<int> seeds) {
  final reached = Uint8List(w * h);
  final stack = Int32List(w * h);
  var top = 0;
  for (final s in seeds) {
    if (passable[s] == 1 && reached[s] == 0) {
      reached[s] = 1;
      stack[top++] = s;
    }
  }
  while (top > 0) {
    final i = stack[--top];
    final x = i % w;
    if (x > 0 && passable[i - 1] == 1 && reached[i - 1] == 0) {
      reached[i - 1] = 1;
      stack[top++] = i - 1;
    }
    if (x < w - 1 && passable[i + 1] == 1 && reached[i + 1] == 0) {
      reached[i + 1] = 1;
      stack[top++] = i + 1;
    }
    if (i >= w && passable[i - w] == 1 && reached[i - w] == 0) {
      reached[i - w] = 1;
      stack[top++] = i - w;
    }
    if (i < w * (h - 1) && passable[i + w] == 1 && reached[i + w] == 0) {
      reached[i + w] = 1;
      stack[top++] = i + w;
    }
  }
  return reached;
}

Iterable<int> _border(int w, int h) sync* {
  for (var x = 0; x < w; x++) {
    yield x;
    yield (h - 1) * w + x;
  }
  for (var y = 1; y < h - 1; y++) {
    yield y * w;
    yield y * w + w - 1;
  }
}

/// The groups of touching pixels of [mask] holding at least [minPart] of
/// the picture each (at least the biggest one).
Uint8List _bigParts(Uint8List mask, int w, int h, double minPart) {
  final label = Int32List(w * h);
  final stack = Int32List(w * h);
  final sizes = <int>[0];
  var bestLabel = 0, bestSize = 0, next = 0;
  for (var s = 0; s < mask.length; s++) {
    if (mask[s] == 0 || label[s] != 0) continue;
    next++;
    var size = 0, top = 0;
    label[s] = next;
    stack[top++] = s;
    while (top > 0) {
      final i = stack[--top];
      size++;
      final x = i % w;
      if (x > 0 && mask[i - 1] == 1 && label[i - 1] == 0) {
        label[i - 1] = next;
        stack[top++] = i - 1;
      }
      if (x < w - 1 && mask[i + 1] == 1 && label[i + 1] == 0) {
        label[i + 1] = next;
        stack[top++] = i + 1;
      }
      if (i >= w && mask[i - w] == 1 && label[i - w] == 0) {
        label[i - w] = next;
        stack[top++] = i - w;
      }
      if (i < w * (h - 1) && mask[i + w] == 1 && label[i + w] == 0) {
        label[i + w] = next;
        stack[top++] = i + w;
      }
    }
    sizes.add(size);
    if (size > bestSize) {
      bestSize = size;
      bestLabel = next;
    }
  }
  final keep = [for (final s in sizes) s >= minPart * w * h];
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    final l = label[i];
    out[i] = l != 0 && (keep[l] || l == bestLabel) ? 1 : 0;
  }
  return out;
}

/// The mask with its holes filled (what the outside can't reach).
Uint8List _fillHoles(Uint8List mask, int w, int h) {
  final free = Uint8List(w * h);
  for (var i = 0; i < free.length; i++) {
    free[i] = 1 - mask[i];
  }
  final outside = _flood(free, w, h, _border(w, h));
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = 1 - outside[i];
  }
  return out;
}

/// Max over a square of radius [r] (separable).
Uint8List _grow(Uint8List mask, int w, int h, int r) {
  if (r <= 0) return Uint8List.fromList(mask);
  final tmp = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var run = -_far; // last 1 seen
    for (var x = 0; x < w; x++) {
      if (mask[row + x] == 1) run = x;
      if (x - run <= r) tmp[row + x] = 1;
    }
    run = _far;
    for (var x = w - 1; x >= 0; x--) {
      if (mask[row + x] == 1) run = x;
      if (run - x <= r) tmp[row + x] = 1;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    var run = -_far;
    for (var y = 0; y < h; y++) {
      if (tmp[y * w + x] == 1) run = y;
      if (y - run <= r) out[y * w + x] = 1;
    }
    run = _far;
    for (var y = h - 1; y >= 0; y--) {
      if (tmp[y * w + x] == 1) run = y;
      if (run - y <= r) out[y * w + x] = 1;
    }
  }
  return out;
}

/// The mask without a band of [r] pixels along its edge and the photo's.
Uint8List _shrink(Uint8List mask, int w, int h, int r) {
  final notMask = Uint8List(w * h);
  for (var i = 0; i < notMask.length; i++) {
    notMask[i] = 1 - mask[i];
  }
  for (final i in _border(w, h)) {
    notMask[i] = 1;
  }
  final grown = _grow(notMask, w, h, r);
  for (var i = 0; i < grown.length; i++) {
    grown[i] = 1 - grown[i];
  }
  return grown;
}

/// The ink: clearly darker than the paper around it.
Uint8List _ink(Uint8List v, Uint8List inside, int w, int h) {
  // Sums of the brightness (and of the paper pixels) over any rectangle.
  final sums = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      row += v[y * w + x];
      sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row;
    }
  }
  final r = math.max(7, math.max(w, h) ~/ 24);
  final ink = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (inside[i] == 0) continue;
      final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
      final s =
          sums[y1 * (w + 1) + x1] -
          sums[y0 * (w + 1) + x1] -
          sums[y1 * (w + 1) + x0] +
          sums[y0 * (w + 1) + x0];
      final mean = s / ((x1 - x0) * (y1 - y0));
      final p = v[i];
      if (p < mean * 0.78 && p < mean - 18) ink[i] = 1;
    }
  }
  return ink;
}

/// The biggest closed shape: what the paper's edge can't reach without
/// crossing [ink], with mostly empty paper inside. null = none.
Uint8List? _closedShape(
  Uint8List ink,
  Uint8List inside,
  int w,
  int h,
  int paperArea,
) {
  final free = Uint8List(w * h);
  final seeds = <int>[];
  for (var i = 0; i < free.length; i++) {
    free[i] = 1 - ink[i];
    if (inside[i] == 0 && free[i] == 1) seeds.add(i);
  }
  final outside = _flood(free, w, h, [...seeds, ..._border(w, h)]);
  final enclosed = Uint8List(w * h);
  for (var i = 0; i < enclosed.length; i++) {
    enclosed[i] = outside[i] == 0 && inside[i] == 1 ? 1 : 0;
  }
  // Each group of enclosed pixels: its size and its empty paper.
  final label = Int32List(w * h);
  final stack = Int32List(w * h);
  var next = 0, bestLabel = 0, bestEmpty = 0;
  for (var s = 0; s < enclosed.length; s++) {
    if (enclosed[s] == 0 || label[s] != 0) continue;
    next++;
    var size = 0, empty = 0, top = 0;
    label[s] = next;
    stack[top++] = s;
    while (top > 0) {
      final i = stack[--top];
      size++;
      if (ink[i] == 0) empty++;
      final x = i % w;
      if (x > 0 && enclosed[i - 1] == 1 && label[i - 1] == 0) {
        label[i - 1] = next;
        stack[top++] = i - 1;
      }
      if (x < w - 1 && enclosed[i + 1] == 1 && label[i + 1] == 0) {
        label[i + 1] = next;
        stack[top++] = i + 1;
      }
      if (i >= w && enclosed[i - w] == 1 && label[i - w] == 0) {
        label[i - w] = next;
        stack[top++] = i - w;
      }
      if (i < w * (h - 1) && enclosed[i + w] == 1 && label[i + w] == 0) {
        label[i + w] = next;
        stack[top++] = i + w;
      }
    }
    if (empty >= 0.02 * paperArea && empty >= 0.5 * size && empty > bestEmpty) {
      bestEmpty = empty;
      bestLabel = next;
    }
  }
  if (bestLabel == 0) return null;
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = label[i] == bestLabel ? 1 : 0;
  }
  return out;
}

/// The outer border of [mask] (one group), pixel by pixel, in order
/// (Moore neighbours).
List<(double, double)> _trace(Uint8List mask, int w, int h) {
  const dx = [1, 1, 0, -1, -1, -1, 0, 1];
  const dy = [0, 1, 1, 1, 0, -1, -1, -1];
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && mask[y * w + x] == 1;
  int dirOf(int x, int y) {
    for (var d = 0; d < 8; d++) {
      if (dx[d] == x && dy[d] == y) return d;
    }
    return 4;
  }

  var start = -1;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 1) {
      start = i;
      break;
    }
  }
  if (start < 0) return const [];
  final sx = start % w, sy = start ~/ w;
  final out = <(double, double)>[(sx.toDouble(), sy.toDouble())];
  var cx = sx, cy = sy, back = 4; // the pixel on the left is outside
  final limit = 8 * (w + h) * 4;
  for (var step = 0; step < limit; step++) {
    var moved = false;
    for (var k = 1; k <= 8; k++) {
      final d = (back + k) % 8;
      final nx = cx + dx[d], ny = cy + dy[d];
      if (on(nx, ny)) {
        final pd = (back + k - 1) % 8;
        final bx = cx + dx[pd], by = cy + dy[pd];
        cx = nx;
        cy = ny;
        back = dirOf(bx - cx, by - cy);
        moved = true;
        break;
      }
    }
    if (!moved || (cx == sx && cy == sy)) break;
    out.add((cx.toDouble(), cy.toDouble()));
  }
  // At most ~1500 points (enough for straight sides).
  final every = math.max(1, out.length ~/ 1500);
  return [for (var i = 0; i < out.length; i += every) out[i]];
}

// ---------------------------------------------------------------------
// Straightening
// ---------------------------------------------------------------------

/// The 4 corners of the sheet (top-left, top-right, bottom-right,
/// bottom-left) when the whole sheet is in the photo; null otherwise.
List<(double, double)>? _sheetCorners(Uint8List paper, int w, int h) {
  final area = _count(paper);
  if (area < 0.15 * w * h || area > 0.97 * w * h) return null;
  var touching = 0;
  for (final i in _border(w, h)) {
    touching += paper[i];
  }
  if (touching > 0.02 * 2 * (w + h)) return null;
  var tl = (0.0, 0.0), tr = (0.0, 0.0), br = (0.0, 0.0), bl = (0.0, 0.0);
  var minS = _far, maxS = -_far, minD = _far, maxD = -_far;
  for (var i = 0; i < paper.length; i++) {
    if (paper[i] == 0) continue;
    final x = i % w, y = i ~/ w;
    final s = x + y, d = x - y;
    if (s < minS) {
      minS = s;
      tl = (x.toDouble(), y.toDouble());
    }
    if (s > maxS) {
      maxS = s;
      br = (x.toDouble(), y.toDouble());
    }
    if (d > maxD) {
      maxD = d;
      tr = (x.toDouble(), y.toDouble());
    }
    if (d < minD) {
      minD = d;
      bl = (x.toDouble(), y.toDouble());
    }
  }
  final quad = [tl, tr, br, bl];
  // A real sheet: the 4 corners hold (almost) all of it, every angle
  // between 50° and 130°.
  final poly = [for (final (x, y) in quad) OrchardPoint(x, y)];
  final quadArea = polygonArea(poly);
  if (quadArea < 0.9 * area || quadArea > 1.12 * area || edgesCross(poly)) {
    return null;
  }
  for (var i = 0; i < 4; i++) {
    final a = quad[(i + 3) % 4], b = quad[i], c = quad[(i + 1) % 4];
    final ux = a.$1 - b.$1,
        uy = a.$2 - b.$2,
        vx = c.$1 - b.$1,
        vy = c.$2 - b.$2;
    final cos =
        (ux * vx + uy * vy) /
        (math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy));
    final deg = math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
    if (deg < 50 || deg > 130) return null;
  }
  return quad;
}

double _dist((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

/// The sheet seen from above: [quad] becomes a rectangle (A4 when it is
/// close to it).
SketchImage _straighten(SketchImage src, List<(double, double)> quad) {
  final top = _dist(quad[0], quad[1]), bottom = _dist(quad[3], quad[2]);
  final left = _dist(quad[0], quad[3]), right = _dist(quad[1], quad[2]);
  var ratio = ((left + right) / 2) / ((top + bottom) / 2); // height / width
  const a4 = 1.4142;
  if ((ratio - a4).abs() / a4 < 0.2) ratio = a4;
  if ((ratio - 1 / a4).abs() * a4 < 0.2) ratio = 1 / a4;
  final w = ratio >= 1 ? (sketchMaxSide / ratio).round() : sketchMaxSide;
  final h = ratio >= 1 ? sketchMaxSide : (sketchMaxSide * ratio).round();
  final hm = _homography([
    (0.0, 0.0),
    (w - 1.0, 0.0),
    (w - 1.0, h - 1.0),
    (0.0, h - 1.0),
  ], quad);
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = hm[6] * x + hm[7] * y + 1;
      final sx = (hm[0] * x + hm[1] * y + hm[2]) / d;
      final sy = (hm[3] * x + hm[4] * y + hm[5]) / d;
      _sample(src, sx, sy, out, (y * w + x) * 4);
    }
  }
  return SketchImage(w, h, out);
}

/// The 8 numbers of the projection taking [from] to [to] (4 points each).
List<double> _homography(
  List<(double, double)> from,
  List<(double, double)> to,
) {
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final (u, v) = from[i];
    final (x, y) = to[i];
    a[2 * i] = [u, v, 1, 0, 0, 0, -u * x, -v * x, x];
    a[2 * i + 1] = [0, 0, 0, u, v, 1, -u * y, -v * y, y];
  }
  // Gaussian elimination with the biggest pivot.
  for (var c = 0; c < 8; c++) {
    var p = c;
    for (var r = c + 1; r < 8; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    final t = a[c];
    a[c] = a[p];
    a[p] = t;
    for (var r = 0; r < 8; r++) {
      if (r == c || a[c][c] == 0) continue;
      final f = a[r][c] / a[c][c];
      for (var k = c; k < 9; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [for (var i = 0; i < 8; i++) a[i][8] / a[i][i]];
}

/// The colour at (x, y) of [src] (between pixels: mixed), or white outside.
void _sample(SketchImage src, double x, double y, Uint8List out, int o) {
  if (x < 0 || y < 0 || x > src.width - 1 || y > src.height - 1) {
    out[o] = out[o + 1] = out[o + 2] = 255;
    out[o + 3] = 255;
    return;
  }
  final x0 = x.floor(), y0 = y.floor();
  final x1 = math.min(x0 + 1, src.width - 1),
      y1 = math.min(y0 + 1, src.height - 1);
  final fx = x - x0, fy = y - y0;
  for (var c = 0; c < 3; c++) {
    final p00 = src.rgba[(y0 * src.width + x0) * 4 + c];
    final p10 = src.rgba[(y0 * src.width + x1) * 4 + c];
    final p01 = src.rgba[(y1 * src.width + x0) * 4 + c];
    final p11 = src.rgba[(y1 * src.width + x1) * 4 + c];
    out[o + c] =
        (p00 * (1 - fx) * (1 - fy) +
                p10 * fx * (1 - fy) +
                p01 * (1 - fx) * fy +
                p11 * fx * fy)
            .round();
  }
  out[o + 3] = 255;
}

/// A side's angle, brought to -45..45 degrees (0 = along the photo's edges).
double _sideAngle(OrchardPoint a, OrchardPoint b) {
  var angle = math.atan2(b.z - a.z, b.x - a.x) * 180 / math.pi;
  while (angle > 45) {
    angle -= 90;
  }
  while (angle <= -45) {
    angle += 90;
  }
  return angle;
}

/// The tilt of the drawing: the angle of its longest side, when sides making
/// at least half of the border agree with it (±3°); null = no common tilt
/// (a shape with slanted sides on purpose).
double? _commonTilt(Polygon p) {
  var best = 0.0, angle = 0.0, perimeter = 0.0;
  for (var i = 0; i < p.length; i++) {
    final d = distance(p[i], p[(i + 1) % p.length]);
    perimeter += d;
    if (d > best) {
      best = d;
      angle = _sideAngle(p[i], p[(i + 1) % p.length]);
    }
  }
  var agree = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    if ((_sideAngle(a, b) - angle).abs() <= 3) agree += distance(a, b);
  }
  return agree >= 0.5 * perimeter ? angle : null;
}

/// [src] turned by [degrees] around its middle (white where nothing is).
SketchImage _rotate(SketchImage src, double degrees) {
  final w = src.width, h = src.height;
  final t = degrees * math.pi / 180;
  final c = math.cos(t), s = math.sin(t);
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Where this pixel comes from (turned back).
      final px = x - w / 2, py = y - h / 2;
      final sx = c * px + s * py + w / 2;
      final sy = -s * px + c * py + h / 2;
      _sample(src, sx, sy, out, (y * w + x) * 4);
    }
  }
  return SketchImage(w, h, out);
}

List<(double, double)> _rotatePoints(
  List<(double, double)> points,
  double degrees,
  double cx,
  double cy,
) {
  final t = degrees * math.pi / 180;
  final c = math.cos(t), s = math.sin(t);
  return [
    for (final (x, y) in points)
      (c * (x - cx) - s * (y - cy) + cx, s * (x - cx) + c * (y - cy) + cy),
  ];
}
