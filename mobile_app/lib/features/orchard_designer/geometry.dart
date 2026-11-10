// The geometry of the orchard designer: polygons in METRES, x = east,
// z = south (the same frame as the database and the 3D scene). Only plain
// maths here, no screen: test/geometry_test.dart checks every function.
//
//   - area, size, crossing edges (the same rules as polygon_ok() of the
//     database, migration 011);
//   - cleanUpStroke: the finger's line → a few straight sides, closed;
//   - splitByTrees: the automatic zones, their areas proportional to the
//     trees of each zone;
//   - cutZones: the farmer's dividing lines;
//   - layoutTrees: the rows of trees of a zone (like orchard_layout_zone()).
import 'dart:math' as math;

import '../../data/orchard_service.dart' show OrchardPoint;

typedef Polygon = List<OrchardPoint>;

/// The limits of the database (polygon_ok() in migration 011).
const maxCorners = 200;
const maxCoordinate = 5000.0;
const minPolygonArea = 10.0; // m²

/// The corners a cleaned drawing keeps at most (a farmer's orchard has a
/// few sides; the database allows 200).
const maxDrawnCorners = 60;

double _cross(double ux, double uz, double vx, double vz) => ux * vz - uz * vx;

double distance(OrchardPoint a, OrchardPoint b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z));

/// Area with a sign (shoelace formula): the sign says the direction.
double signedArea(Polygon p) {
  var sum = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i];
    final b = p[(i + 1) % p.length];
    sum += a.x * b.z - b.x * a.z;
  }
  return sum / 2;
}

/// Area in m².
double polygonArea(Polygon p) => p.length < 3 ? 0 : signedArea(p).abs();

/// Area in hectares (1 ha = 10 000 m²).
double hectares(Polygon p) => polygonArea(p) / 10000;

/// The box around a polygon.
class Bounds {
  const Bounds(this.minX, this.minZ, this.maxX, this.maxZ);

  final double minX;
  final double minZ;
  final double maxX;
  final double maxZ;

  /// West to east (m).
  double get width => maxX - minX;

  /// North to south (m).
  double get length => maxZ - minZ;
  OrchardPoint get center => OrchardPoint((minX + maxX) / 2, (minZ + maxZ) / 2);
}

Bounds boundsOf(Polygon p) {
  var minX = double.infinity, minZ = double.infinity;
  var maxX = -double.infinity, maxZ = -double.infinity;
  for (final q in p) {
    minX = math.min(minX, q.x);
    maxX = math.max(maxX, q.x);
    minZ = math.min(minZ, q.z);
    maxZ = math.max(maxZ, q.z);
  }
  return Bounds(minX, minZ, maxX, maxZ);
}

/// true = segments ab and cd cross (touching at a point is not crossing),
/// like the database.
bool segmentsCross(
  OrchardPoint a,
  OrchardPoint b,
  OrchardPoint c,
  OrchardPoint d,
) {
  final d1 = _cross(d.x - c.x, d.z - c.z, a.x - c.x, a.z - c.z);
  final d2 = _cross(d.x - c.x, d.z - c.z, b.x - c.x, b.z - c.z);
  final d3 = _cross(b.x - a.x, b.z - a.z, c.x - a.x, c.z - a.z);
  final d4 = _cross(b.x - a.x, b.z - a.z, d.x - a.x, d.z - a.z);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// true = two sides of the polygon cross each other (sides next to each
/// other share a corner: not checked), like the database.
bool edgesCross(Polygon p) {
  final n = p.length;
  for (var i = 0; i < n; i++) {
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      if (segmentsCross(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n])) {
        return true;
      }
    }
  }
  return false;
}

/// The database accepts it (polygon_ok): 3 to 200 corners, inside ±5 km,
/// at least 10 m², no crossing sides.
bool polygonOk(Polygon p) {
  if (p.length < 3 || p.length > maxCorners) return false;
  for (final q in p) {
    if (!q.x.isFinite || !q.z.isFinite) return false;
    if (q.x.abs() > maxCoordinate || q.z.abs() > maxCoordinate) return false;
  }
  return polygonArea(p) >= minPolygonArea && !edgesCross(p);
}

/// The polygon moved so that the middle of its box is at (0, 0).
Polygon centered(Polygon p) {
  final c = boundsOf(p).center;
  return [for (final q in p) OrchardPoint(q.x - c.x, q.z - c.z)];
}

/// The polygon stretched to [width] x [length] metres (its box), centred
/// at (0, 0). The farmer types the approximate size of his orchard.
Polygon scaleToSize(Polygon p, double width, double length) {
  final b = boundsOf(p);
  final sx = b.width > 0 ? width / b.width : 1.0;
  final sz = b.length > 0 ? length / b.length : 1.0;
  final c = b.center;
  return [for (final q in p) OrchardPoint((q.x - c.x) * sx, (q.z - c.z) * sz)];
}

/// Corners rounded to the centimetre (what is saved).
Polygon rounded(Polygon p) => [
  for (final q in p)
    OrchardPoint(
      (q.x * 100).roundToDouble() / 100,
      (q.z * 100).roundToDouble() / 100,
    ),
];

/// true = [p] is inside [polygon] (even-odd rule, like the database).
bool pointInPolygon(OrchardPoint p, Polygon polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.z > p.z) != (b.z > p.z) &&
        p.x < (b.x - a.x) * (p.z - a.z) / (b.z - a.z) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

// ---------------------------------------------------------------------
// The finger's line → a clean shape
// ---------------------------------------------------------------------

double _distanceToSegment(OrchardPoint p, OrchardPoint a, OrchardPoint b) {
  final dx = b.x - a.x;
  final dz = b.z - a.z;
  final length2 = dx * dx + dz * dz;
  if (length2 == 0) return distance(p, a);
  final t = (((p.x - a.x) * dx + (p.z - a.z) * dz) / length2).clamp(0.0, 1.0);
  return distance(p, OrchardPoint(a.x + t * dx, a.z + t * dz));
}

/// Ramer-Douglas-Peucker: keeps only the points that are more than
/// [tolerance] away from the straight line between their neighbours.
List<OrchardPoint> simplifyLine(List<OrchardPoint> line, double tolerance) {
  if (line.length < 3) return List.of(line);
  var worst = 0.0;
  var index = 0;
  for (var i = 1; i < line.length - 1; i++) {
    final d = _distanceToSegment(line[i], line.first, line.last);
    if (d > worst) {
      worst = d;
      index = i;
    }
  }
  if (worst <= tolerance) return [line.first, line.last];
  final left = simplifyLine(line.sublist(0, index + 1), tolerance);
  final right = simplifyLine(line.sublist(index), tolerance);
  return [...left.sublist(0, left.length - 1), ...right];
}

/// Removes the corners that are almost straight (turn < [maxTurnDegrees])
/// and the very short sides (< [minSide] metres) of a closed shape.
Polygon removeStraightCorners(
  Polygon p, {
  double maxTurnDegrees = 15,
  double minSide = 0,
}) {
  final ring = List.of(p);
  var changed = true;
  while (changed && ring.length > 3) {
    changed = false;
    for (var i = 0; i < ring.length && ring.length > 3; i++) {
      final prev = ring[(i - 1 + ring.length) % ring.length];
      final here = ring[i];
      final next = ring[(i + 1) % ring.length];
      final ux = here.x - prev.x, uz = here.z - prev.z;
      final vx = next.x - here.x, vz = next.z - here.z;
      final lu = math.sqrt(ux * ux + uz * uz);
      final lv = math.sqrt(vx * vx + vz * vz);
      var remove = lu < minSide || lu == 0 || lv == 0;
      if (!remove) {
        final cos = ((ux * vx + uz * vz) / (lu * lv)).clamp(-1.0, 1.0);
        final turn = math.acos(cos) * 180 / math.pi;
        remove = turn < maxTurnDegrees;
      }
      if (remove) {
        ring.removeAt(i);
        changed = true;
        i--;
      }
    }
  }
  return ring;
}

/// The finger's line (many points) → a closed shape with straight sides.
/// [tolerance] = how far (metres) the finger may wobble around a straight
/// side. null = not a shape (too few points, too small).
Polygon? cleanUpStroke(List<OrchardPoint> stroke, {required double tolerance}) {
  // 1. Without the points that nearly touch the previous one.
  final points = <OrchardPoint>[];
  for (final p in stroke) {
    if (points.isEmpty || distance(points.last, p) >= tolerance / 4) {
      points.add(p);
    }
  }
  if (points.length < 3) return null;
  // 2. Straight sides (the wobbles of the finger go away).
  var shape = simplifyLine(points, tolerance);
  // 3. Closed: the end joins the start (if the finger came back near it,
  //    the last point is the first corner again).
  if (shape.length > 3 && distance(shape.first, shape.last) < tolerance * 2) {
    shape.removeLast();
  }
  // 4. No almost-straight corner, no tiny side.
  shape = removeStraightCorners(shape, minSide: tolerance);
  // 5. A drawing with too many corners: a bit straighter.
  var t = tolerance;
  while (shape.length > maxDrawnCorners) {
    t *= 1.5;
    shape = removeStraightCorners(simplifyLine(points, t), minSide: t);
  }
  if (shape.length < 3 || polygonArea(shape) < minPolygonArea) return null;
  return shape;
}

// ---------------------------------------------------------------------
// Cutting polygons
// ---------------------------------------------------------------------

/// Which side of the line a→b the point is on (> 0 one side, < 0 the other).
double _side(OrchardPoint a, OrchardPoint b, OrchardPoint p) =>
    _cross(b.x - a.x, b.z - a.z, p.x - a.x, p.z - a.z);

/// The part of [p] on one side of the (endless) line through a and b
/// (Sutherland-Hodgman). [positive] = the side where _side() >= 0.
Polygon clipHalfPlane(
  Polygon p,
  OrchardPoint a,
  OrchardPoint b, {
  required bool positive,
}) {
  final out = <OrchardPoint>[];
  bool inside(double s) => positive ? s >= 0 : s <= 0;
  for (var i = 0; i < p.length; i++) {
    final prev = p[(i - 1 + p.length) % p.length];
    final here = p[i];
    final sp = _side(a, b, prev);
    final sh = _side(a, b, here);
    if (inside(sh)) {
      if (!inside(sp)) out.add(_crossing(prev, here, sp, sh));
      out.add(here);
    } else if (inside(sp)) {
      out.add(_crossing(prev, here, sp, sh));
    }
  }
  return cleanPolygon(out);
}

OrchardPoint _crossing(OrchardPoint p, OrchardPoint q, double sp, double sq) {
  final t = sp / (sp - sq);
  return OrchardPoint(p.x + (q.x - p.x) * t, p.z + (q.z - p.z) * t);
}

/// Without corners on top of each other and without corners in the middle
/// of a straight side.
Polygon cleanPolygon(Polygon p) {
  final ring = <OrchardPoint>[];
  for (final q in p) {
    if (ring.isEmpty || distance(ring.last, q) > 1e-6) ring.add(q);
  }
  while (ring.length > 1 && distance(ring.first, ring.last) <= 1e-6) {
    ring.removeLast();
  }
  var changed = true;
  while (changed && ring.length > 3) {
    changed = false;
    for (var i = 0; i < ring.length && ring.length > 3; i++) {
      final prev = ring[(i - 1 + ring.length) % ring.length];
      final here = ring[i];
      final next = ring[(i + 1) % ring.length];
      final cross = _cross(
        here.x - prev.x,
        here.z - prev.z,
        next.x - here.x,
        next.z - here.z,
      );
      final dot =
          (here.x - prev.x) * (next.x - here.x) +
          (here.z - prev.z) * (next.z - here.z);
      final scale = distance(prev, here) * distance(here, next);
      // Straight on (same direction): the middle corner is not needed.
      if (cross.abs() <= 1e-9 * (scale + 1) && dot > 0) {
        ring.removeAt(i);
        changed = true;
        i--;
      }
    }
  }
  return ring;
}

/// The two parts of [p] on both sides of the line through a and b.
/// null = the line does not cut it.
(Polygon, Polygon)? cutByLine(Polygon p, OrchardPoint a, OrchardPoint b) {
  if (distance(a, b) == 0) return null;
  final one = clipHalfPlane(p, a, b, positive: true);
  final two = clipHalfPlane(p, a, b, positive: false);
  if (one.length < 3 || two.length < 3) return null;
  if (polygonArea(one) < 1e-6 || polygonArea(two) < 1e-6) return null;
  return (one, two);
}

/// true = the segment a-b goes over [p] (crosses a side, or starts or ends
/// inside it).
bool segmentTouches(Polygon p, OrchardPoint a, OrchardPoint b) {
  if (pointInPolygon(a, p) || pointInPolygon(b, p)) return true;
  for (var i = 0; i < p.length; i++) {
    if (segmentsCross(a, b, p[i], p[(i + 1) % p.length])) return true;
  }
  return false;
}

/// The farmer's dividing line a-b: every zone it goes over is cut in two
/// (along the whole straight line through a and b). A part smaller than
/// [minArea] m² is not made (that zone stays whole). null = nothing cut.
List<Polygon>? cutZones(
  List<Polygon> zones,
  OrchardPoint a,
  OrchardPoint b, {
  double minArea = minPolygonArea,
}) {
  var cut = false;
  final out = <Polygon>[];
  for (final zone in zones) {
    final parts = segmentTouches(zone, a, b) ? cutByLine(zone, a, b) : null;
    if (parts == null ||
        polygonArea(parts.$1) < minArea ||
        polygonArea(parts.$2) < minArea) {
      out.add(zone);
      continue;
    }
    // West (or north) part first, like the reading of a map.
    final c1 = labelPoint(parts.$1);
    final c2 = labelPoint(parts.$2);
    final mostlyAcross = (b.x - a.x).abs() >= (b.z - a.z).abs();
    final firstIsOne = mostlyAcross ? c1.z <= c2.z : c1.x <= c2.x;
    out
      ..add(firstIsOne ? parts.$1 : parts.$2)
      ..add(firstIsOne ? parts.$2 : parts.$1);
    cut = true;
  }
  return cut ? out : null;
}

/// The automatic zones: [outline] cut in straight strips (across its longer
/// side), each strip's area proportional to its number of trees. The first
/// zone is in the west (or the north).
List<Polygon> splitByTrees(Polygon outline, List<int> trees) {
  if (trees.length <= 1) return [cleanPolygon(outline)];
  final weights = [for (final t in trees) math.max(1, t).toDouble()];
  final total = weights.reduce((a, b) => a + b);
  final area = polygonArea(outline);
  final b = boundsOf(outline);
  final alongX = b.width >= b.length;

  // The part of the outline before the position c (x or z). (The line
  // (c,0)→(c,1) has x <= c on its positive side; (0,c)→(1,c) has z >= c.)
  Polygon before(Polygon p, double c) => alongX
      ? clipHalfPlane(p, OrchardPoint(c, 0), OrchardPoint(c, 1), positive: true)
      : clipHalfPlane(
          p,
          OrchardPoint(0, c),
          OrchardPoint(1, c),
          positive: false,
        );
  Polygon after(Polygon p, double c) => alongX
      ? clipHalfPlane(
          p,
          OrchardPoint(c, 0),
          OrchardPoint(c, 1),
          positive: false,
        )
      : clipHalfPlane(
          p,
          OrchardPoint(0, c),
          OrchardPoint(1, c),
          positive: true,
        );

  // Where to cut: the position where the area before it is the share of
  // the trees so far (found by halving the interval).
  final cuts = <double>[];
  var share = 0.0;
  for (var k = 0; k < weights.length - 1; k++) {
    share += weights[k];
    final target = area * share / total;
    var lo = alongX ? b.minX : b.minZ;
    var hi = alongX ? b.maxX : b.maxZ;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (polygonArea(before(outline, mid)) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    cuts.add((lo + hi) / 2);
  }

  return [
    for (var i = 0; i < weights.length; i++)
      () {
        var part = List.of(outline);
        if (i > 0) part = after(part, cuts[i - 1]);
        if (i < cuts.length) part = before(part, cuts[i]);
        return part;
      }(),
  ];
}

// ---------------------------------------------------------------------
// Inside a zone
// ---------------------------------------------------------------------

/// Where to write the letter of a zone: its middle, or (an L-shaped zone)
/// the middle of its widest part across that line.
OrchardPoint labelPoint(Polygon p) {
  if (p.isEmpty) return const OrchardPoint(0, 0);
  final a = signedArea(p);
  var cx = 0.0, cz = 0.0;
  if (a.abs() > 1e-9) {
    for (var i = 0; i < p.length; i++) {
      final q = p[i];
      final r = p[(i + 1) % p.length];
      final f = q.x * r.z - r.x * q.z;
      cx += (q.x + r.x) * f;
      cz += (q.z + r.z) * f;
    }
    cx /= 6 * a;
    cz /= 6 * a;
  } else {
    cx = p.map((q) => q.x).reduce((s, v) => s + v) / p.length;
    cz = p.map((q) => q.z).reduce((s, v) => s + v) / p.length;
  }
  final middle = OrchardPoint(cx, cz);
  if (pointInPolygon(middle, p)) return middle;
  // Across the polygon at that height: the widest inside part.
  final xs = <double>[];
  for (var i = 0; i < p.length; i++) {
    final q = p[i];
    final r = p[(i + 1) % p.length];
    if ((q.z > cz) != (r.z > cz)) {
      xs.add(q.x + (cz - q.z) * (r.x - q.x) / (r.z - q.z));
    }
  }
  xs.sort();
  var best = middle;
  var widest = -1.0;
  for (var i = 0; i + 1 < xs.length; i += 2) {
    if (xs[i + 1] - xs[i] > widest) {
      widest = xs[i + 1] - xs[i];
      best = OrchardPoint((xs[i] + xs[i + 1]) / 2, cz);
    }
  }
  return best;
}

/// About how many trees fit on [areaM2] with [spacing] metres between
/// them (at least 1).
int estimateTrees(double areaM2, {double spacing = 7}) =>
    math.max(1, (areaM2 / (spacing * spacing)).round());

/// [total] trees shared in proportion to [areas] (each at least 1, the
/// sum is [total] when total >= the number of parts).
List<int> shareTrees(int total, List<double> areas) {
  if (areas.isEmpty) return const [];
  final sum = areas.fold(0.0, (s, a) => s + a);
  final shares = [
    for (final a in areas)
      math.max(1, (sum > 0 ? total * a / sum : total / areas.length).floor()),
  ];
  // The trees left over go to the biggest parts.
  var left = total - shares.fold(0, (s, v) => s + v);
  final order = List.generate(areas.length, (i) => i)
    ..sort((i, j) => areas[j].compareTo(areas[i]));
  for (var k = 0; left > 0; k = (k + 1) % order.length, left--) {
    shares[order[k]]++;
  }
  return shares;
}

/// The trees of a zone in rows, like the database (orchard_layout_zone):
/// spacing = √(area / trees) between 3 and 15 m (or [spacing] when no
/// number of trees), rows from the corner, half a spacing from the edge.
List<OrchardPoint> layoutTrees(
  Polygon boundary,
  int? treeCount, {
  double spacing = 7,
}) {
  final area = polygonArea(boundary);
  final s = (treeCount ?? 0) > 0
      ? math.sqrt(area / treeCount!).clamp(3.0, 15.0)
      : spacing;
  final b = boundsOf(boundary);
  final trees = <OrchardPoint>[];
  for (var z = b.minZ + s / 2; z < b.maxZ; z += s) {
    for (var x = b.minX + s / 2; x < b.maxX; x += s) {
      final p = OrchardPoint(x, z);
      if (pointInPolygon(p, boundary)) trees.add(p);
    }
  }
  return trees;
}
