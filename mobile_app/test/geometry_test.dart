// The maths of the orchard designer (lib/features/orchard_designer/
// geometry.dart): area, clean-up of the finger's line, crossing sides,
// the automatic zones (areas proportional to the trees) and the dividing
// lines. Run it with: flutter test
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';

Polygon poly(List<List<double>> xz) => [
  for (final p in xz) OrchardPoint(p[0], p[1]),
];

/// 200 m (west-east) x 100 m (north-south).
final rectangle = poly([
  [0, 0],
  [200, 0],
  [200, 100],
  [0, 100],
]);

/// An L: 100 x 100 without its south-east quarter (7500 m²).
final lShape = poly([
  [0, 0],
  [100, 0],
  [100, 50],
  [50, 50],
  [50, 100],
  [0, 100],
]);

/// The outline of the demo seed (supabase/seed/orchard_demo.sql).
final demoOutline = poly([
  [-90, -60],
  [85, -70],
  [100, 40],
  [20, 75],
  [-95, 55],
]);

/// A wobbly hand-drawn line around a rectangle, coming back near the start.
List<OrchardPoint> wobblyRectangle() {
  final points = <OrchardPoint>[];
  final random = math.Random(7);
  double wobble() => (random.nextDouble() - 0.5) * 2; // ±1 m
  void side(double x1, double z1, double x2, double z2) {
    for (var i = 0; i < 40; i++) {
      final t = i / 40;
      points.add(
        OrchardPoint(
          x1 + (x2 - x1) * t + wobble(),
          z1 + (z2 - z1) * t + wobble(),
        ),
      );
    }
  }

  side(0, 0, 120, 0);
  side(120, 0, 120, 80);
  side(120, 80, 0, 80);
  side(0, 80, 0, 3); // the finger stops just before the start
  return points;
}

void main() {
  group('area and size', () {
    test('Area in m² and in hectares, whatever the direction', () {
      expect(polygonArea(rectangle), 20000);
      expect(hectares(rectangle), 2);
      expect(polygonArea(rectangle.reversed.toList()), 20000);
      expect(polygonArea(lShape), 7500);
      expect(
        polygonArea(
          poly([
            [0, 0],
            [10, 0],
            [0, 10],
          ]),
        ),
        50,
      );
      // The demo orchard: 2.3688 ha, like the database computed it.
      expect(hectares(demoOutline), closeTo(2.3688, 0.0001));
      expect(
        polygonArea(
          poly([
            [0, 0],
            [1, 1],
          ]),
        ),
        0,
      ); // not a shape
    });

    test('The box: width (west-east) and length (north-south)', () {
      final b = boundsOf(demoOutline);
      expect(b.width, 195);
      expect(b.length, 145);
      expect(b.center.x, 2.5);
      expect(b.center.z, 2.5);
    });

    test('The size typed by the farmer stretches the drawing, centred', () {
      final scaled = scaleToSize(rectangle, 300, 50);
      final b = boundsOf(scaled);
      expect(b.width, closeTo(300, 1e-9));
      expect(b.length, closeTo(50, 1e-9));
      expect(b.center.x, closeTo(0, 1e-9));
      expect(b.center.z, closeTo(0, 1e-9));
      expect(polygonArea(scaled), closeTo(15000, 1e-6));
      final same = centered(lShape);
      expect(polygonArea(same), 7500);
      expect(boundsOf(same).center.x, 0);
    });

    test('Saved to the centimetre', () {
      final p = rounded(
        poly([
          [1.23456, -7.891],
          [3, 4],
          [0, 9],
        ]),
      );
      expect(p.first.x, 1.23);
      expect(p.first.z, -7.89);
    });
  });

  group('crossing sides (the same rule as the database)', () {
    test('A normal shape has no crossing sides', () {
      expect(edgesCross(rectangle), isFalse);
      expect(edgesCross(lShape), isFalse);
      expect(edgesCross(demoOutline), isFalse);
    });

    test('A bow-tie (two sides cross) is refused', () {
      final bowTie = poly([
        [0, 0],
        [100, 100],
        [100, 0],
        [0, 100],
      ]);
      expect(edgesCross(bowTie), isTrue);
      expect(polygonOk(bowTie), isFalse);
    });

    test('Touching at a corner is not crossing', () {
      // Two triangles meeting at (50, 50): the sides only touch.
      final touching = poly([
        [0, 0],
        [50, 50],
        [100, 0],
        [100, 100],
        [50, 50],
        [0, 100],
      ]);
      expect(edgesCross(touching), isFalse);
      expect(
        segmentsCross(
          const OrchardPoint(0, 0),
          const OrchardPoint(10, 0),
          const OrchardPoint(10, 0),
          const OrchardPoint(10, 10),
        ),
        isFalse,
      );
    });

    test('polygonOk: 3 to 200 corners, ±5 km, at least 10 m²', () {
      expect(polygonOk(rectangle), isTrue);
      expect(
        polygonOk(
          poly([
            [0, 0],
            [10, 0],
          ]),
        ),
        isFalse,
      );
      expect(
        polygonOk(
          poly([
            [0, 0],
            [3, 0],
            [0, 3],
          ]),
        ),
        isFalse, // 4.5 m²
      );
      expect(
        polygonOk(
          poly([
            [0, 0],
            [6000, 0],
            [0, 100],
          ]),
        ),
        isFalse,
      );
      final circle = [
        for (var i = 0; i < 201; i++)
          OrchardPoint(
            100 * math.cos(i * 2 * math.pi / 201),
            100 * math.sin(i * 2 * math.pi / 201),
          ),
      ];
      expect(polygonOk(circle), isFalse); // 201 corners
      expect(polygonOk(circle.sublist(0, 200)), isTrue);
    });
  });

  group('clean-up of the finger\'s line', () {
    test('A wobbly rectangle → 4 straight sides, closed', () {
      final shape = cleanUpStroke(wobblyRectangle(), tolerance: 4)!;
      expect(shape, hasLength(4));
      expect(polygonOk(shape), isTrue);
      // Its corners are near the drawn corners.
      for (final corner in [
        const OrchardPoint(0, 0),
        const OrchardPoint(120, 0),
        const OrchardPoint(120, 80),
        const OrchardPoint(0, 80),
      ]) {
        final nearest = shape.map((p) => distance(p, corner)).reduce(math.min);
        expect(nearest, lessThan(4), reason: '$corner');
      }
      expect(polygonArea(shape), closeTo(9600, 600));
    });

    test('A line that does not come back is closed by a straight side', () {
      final open = [
        for (var i = 0; i <= 20; i++) OrchardPoint(i * 5.0, 0),
        for (var i = 1; i <= 20; i++) OrchardPoint(100, i * 4.0),
      ];
      final shape = cleanUpStroke(open, tolerance: 3)!;
      expect(shape, hasLength(3)); // the corner (100, 0) and both ends
      expect(polygonArea(shape), closeTo(4000, 1));
    });

    test('Almost-straight corners and tiny sides go away', () {
      final square = poly([
        [0, 0],
        [50, 0.5], // almost straight
        [100, 0],
        [100, 100],
        [0.3, 100],
        [0, 100], // a side of 30 cm
      ]);
      final clean = removeStraightCorners(square, minSide: 1);
      expect(clean, hasLength(4));
    });

    test('Too small or too few points: not a shape', () {
      expect(
        cleanUpStroke([
          const OrchardPoint(0, 0),
          const OrchardPoint(1, 1),
        ], tolerance: 1),
        isNull,
      );
      final tiny = [
        for (var i = 0; i < 30; i++)
          OrchardPoint(math.cos(i / 5), math.sin(i / 5)),
      ];
      expect(cleanUpStroke(tiny, tolerance: 0.2), isNull); // ~3 m²
    });

    test('A circle keeps at most 60 corners', () {
      final circle = [
        for (var i = 0; i < 2000; i++)
          OrchardPoint(
            300 * math.cos(i * 2 * math.pi / 2000),
            300 * math.sin(i * 2 * math.pi / 2000),
          ),
      ];
      final shape = cleanUpStroke(circle, tolerance: 0.05)!;
      expect(shape.length, lessThanOrEqualTo(maxDrawnCorners));
      expect(polygonOk(shape), isTrue);
      expect(polygonArea(shape), closeTo(math.pi * 300 * 300, 15000));
    });

    test('Straight-line simplification (Ramer-Douglas-Peucker)', () {
      final line = [
        for (var i = 0; i <= 10; i++) OrchardPoint(i * 10.0, i == 5 ? 0.2 : 0),
      ];
      expect(simplifyLine(line, 1), hasLength(2));
      // (40, 0) and (60, 0) are 0.16 m from the line to (50, 0.2).
      expect(simplifyLine(line, 0.17), hasLength(3));
      expect(simplifyLine(line, 0.1).length, greaterThan(3));
    });
  });

  group('dividing lines', () {
    test('A line across the rectangle cuts it in two', () {
      final parts = cutByLine(
        rectangle,
        const OrchardPoint(100, -10),
        const OrchardPoint(100, 110),
      )!;
      expect(polygonArea(parts.$1) + polygonArea(parts.$2), 20000);
      expect(polygonArea(parts.$1), closeTo(10000, 1e-6));
      expect(polygonOk(parts.$1) && polygonOk(parts.$2), isTrue);
    });

    test('A line outside does not cut', () {
      expect(
        cutByLine(
          rectangle,
          const OrchardPoint(300, 0),
          const OrchardPoint(300, 100),
        ),
        isNull,
      );
    });

    test('Two lines: 2 then 4 zones, west and north first', () {
      final two = cutZones(
        [rectangle],
        const OrchardPoint(80, -5),
        const OrchardPoint(80, 105),
      )!;
      expect(two, hasLength(2));
      expect(polygonArea(two[0]), closeTo(8000, 1e-6)); // the west part
      expect(polygonArea(two[1]), closeTo(12000, 1e-6));

      final four = cutZones(
        two,
        const OrchardPoint(-5, 40),
        const OrchardPoint(205, 40),
      )!;
      expect(four, hasLength(4));
      expect(
        four.map(polygonArea).reduce((a, b) => a + b),
        closeTo(20000, 1e-6),
      );
      // West zone cut: its north part first (40 m deep = 3200 m²).
      expect(polygonArea(four[0]), closeTo(3200, 1e-6));
      for (final zone in four) {
        expect(polygonOk(zone), isTrue);
      }
    });

    test('A short line inside one zone cuts only that zone', () {
      final two = cutZones(
        [rectangle],
        const OrchardPoint(100, -5),
        const OrchardPoint(100, 105),
      )!;
      // Only in the east zone (x > 100), not reaching its sides.
      final three = cutZones(
        two,
        const OrchardPoint(140, 50),
        const OrchardPoint(160, 50),
      )!;
      expect(three, hasLength(3));
      expect(polygonArea(three[0]), closeTo(10000, 1e-6)); // west: whole
    });

    test('A line that misses the orchard, or makes a tiny part: nothing', () {
      expect(
        cutZones(
          [rectangle],
          const OrchardPoint(-50, -50),
          const OrchardPoint(-40, -60),
        ),
        isNull,
      );
      // 2 cm from the west edge: a part of 2 m² (< 10 m²) is not made.
      expect(
        cutZones(
          [rectangle],
          const OrchardPoint(0.02, -5),
          const OrchardPoint(0.02, 105),
        ),
        isNull,
      );
    });

    test('A line across an L cuts both of its arms', () {
      final parts = cutZones(
        [lShape],
        const OrchardPoint(25, -10),
        const OrchardPoint(25, 110),
      )!;
      expect(parts, hasLength(2));
      expect(polygonArea(parts[0]), closeTo(2500, 1e-6));
      expect(polygonArea(parts[1]), closeTo(5000, 1e-6));
    });
  });

  group('automatic zones (proportional to the trees)', () {
    test('2 zones: 100 and 300 trees → 25 % and 75 % of the area', () {
      final zones = splitByTrees(rectangle, [100, 300]);
      expect(zones, hasLength(2));
      expect(polygonArea(zones[0]), closeTo(5000, 0.01));
      expect(polygonArea(zones[1]), closeTo(15000, 0.01));
      // Cut across the longer side (west → east): zone A in the west.
      expect(boundsOf(zones[0]).maxX, closeTo(50, 0.01));
      expect(boundsOf(zones[0]).length, 100);
    });

    test('4 zones on the demo outline: shares, total and each zone ok', () {
      const trees = [160, 210, 120, 190];
      final zones = splitByTrees(demoOutline, trees);
      final total = polygonArea(demoOutline);
      expect(
        zones.map(polygonArea).reduce((a, b) => a + b),
        closeTo(total, 0.01),
      );
      for (var i = 0; i < 4; i++) {
        expect(polygonArea(zones[i]), closeTo(total * trees[i] / 680, 0.05));
        expect(polygonOk(zones[i]), isTrue, reason: 'zone $i');
      }
    });

    test('A tall orchard is cut from north to south', () {
      final tall = scaleToSize(rectangle, 100, 400);
      final zones = splitByTrees(tall, [1, 1, 2]);
      expect(boundsOf(zones[0]).minZ, closeTo(-200, 1e-6)); // the north
      expect(polygonArea(zones[0]), closeTo(10000, 0.01));
      expect(polygonArea(zones[2]), closeTo(20000, 0.01));
    });

    test('An L (not convex) is shared right too', () {
      final zones = splitByTrees(lShape, [1, 2]);
      expect(polygonArea(zones[0]), closeTo(2500, 0.01));
      expect(polygonArea(zones[1]), closeTo(5000, 0.01));
    });

    test('One zone = the whole outline; 0 trees count as 1', () {
      expect(splitByTrees(rectangle, [500]).single, hasLength(4));
      final zones = splitByTrees(rectangle, [0, 0]);
      expect(polygonArea(zones[0]), closeTo(10000, 0.01));
    });
  });

  group('inside a zone', () {
    test('The letter of an L-shaped zone is inside it', () {
      final u = poly([
        [0, 0],
        [30, 0],
        [30, 100],
        [70, 100],
        [70, 0],
        [100, 0],
        [100, 110],
        [0, 110],
      ]);
      expect(pointInPolygon(labelPoint(u), u), isTrue);
      expect(pointInPolygon(labelPoint(rectangle), rectangle), isTrue);
    });

    test('Trees shared by area: the total is kept, each zone has 1+', () {
      final shares = shareTrees(670, [100, 300, 600]);
      expect(shares.reduce((a, b) => a + b), 670);
      expect(shares[2], greaterThan(shares[1]));
      expect(shareTrees(2, [1, 1000, 1]), everyElement(greaterThan(0)));
      expect(estimateTrees(20000), 408); // 7 m between trees
    });

    test('Rows of trees like the database: about the trees said, inside', () {
      final trees = layoutTrees(rectangle, 400);
      // spacing = √(20000 / 400) ≈ 7.07 m: 28 x 14 = 392 trees.
      expect(trees.length, inInclusiveRange(380, 400));
      expect(trees.every((t) => pointInPolygon(t, rectangle)), isTrue);
      // No number of trees: 7 m (the orchard's spacing).
      expect(layoutTrees(rectangle, null).length, 29 * 14);
    });
  });
}
