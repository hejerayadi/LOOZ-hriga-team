// "من صورة": the outline found on photos of sketches (test/sketches/).
//   - the 5 test photos (made by tool/make_sketch_photos.py): clean, shadow,
//     numbers + words + trees + a zone line inside, turned + taken at an
//     angle, squared paper; + a drawing turned 9° on the sheet; + a photo
//     with NO closed shape;
//   - every photo of test/sketches/real/ (real phone photos: put yours
//     there, any name, .jpg / .jpeg / .png): a closed shape must be found.
// "Works" = found, 3 to 12 corners, and the shape matches the true one
// (overlap >= 90 % once both are scaled to the same box).
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';
import 'package:looz_mobile/features/orchard_designer/sketch_detect.dart';

/// A photo file as the app gets it: pixels, upright.
SketchImage readPhoto(String path) {
  final decoded = img.bakeOrientation(
    img.decodeImage(File(path).readAsBytesSync())!,
  );
  final rgba = decoded
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
  return SketchImage(decoded.width, decoded.height, Uint8List.fromList(rgba));
}

/// [p] scaled to the box 0..1 x 0..1.
Polygon unitBox(Polygon p) {
  final b = boundsOf(p);
  return [
    for (final q in p)
      OrchardPoint((q.x - b.minX) / b.width, (q.z - b.minZ) / b.length),
  ];
}

/// How much two shapes cover each other (0..1), both in the box 0..1.
double overlap(Polygon a, Polygon b) {
  var both = 0, either = 0;
  for (var i = 0; i < 120; i++) {
    for (var j = 0; j < 120; j++) {
      final p = OrchardPoint((i + 0.5) / 120, (j + 0.5) / 120);
      final inA = pointInPolygon(p, a), inB = pointInPolygon(p, b);
      if (inA && inB) both++;
      if (inA || inB) either++;
    }
  }
  return either == 0 ? 0 : both / either;
}

void main() {
  final truth = jsonDecode(
    File('test/sketches/truth.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('the 5 test sketches (+ a turned drawing)', () {
    for (final name in [
      'clean',
      'shadow',
      'numbers',
      'angle',
      'squared',
      'tilted',
    ]) {
      test(name, () {
        final watch = Stopwatch()..start();
        final result = findSketch(readPhoto('test/sketches/$name.jpg'));
        final ms = watch.elapsedMilliseconds;
        final placed = placeSketch(result, 200);
        final outline = placed.outline;
        final expected = [
          for (final p in (truth[name]['outline'] as List))
            OrchardPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ];
        final score = outline == null
            ? 0.0
            : overlap(unitBox(outline), unitBox(expected));
        // ignore: avoid_print
        print(
          '$name: found ${result.found}, ${outline?.length ?? 0} corners '
          '(true ${expected.length}), overlap ${(score * 100).round()} %, '
          'sheet straightened ${result.straightened}, '
          'tilt ${result.tiltDegrees.toStringAsFixed(1)}°, $ms ms',
        );
        expect(result.found, isTrue);
        expect(outline, isNotNull);
        expect(outline!.length, inInclusiveRange(3, 12));
        expect(outline.length, expected.length);
        expect(score, greaterThan(0.9));
        expect(polygonOk(outline), isTrue);
      });
    }

    test(
      'angle: the sheet is straightened (its 4 corners are in the photo)',
      () {
        expect(
          findSketch(readPhoto('test/sketches/angle.jpg')).straightened,
          isTrue,
        );
      },
    );

    test('tilted: the 9° turn of the drawing is straightened', () {
      final result = findSketch(readPhoto('test/sketches/tilted.jpg'));
      expect(result.tiltDegrees.abs(), closeTo(9, 1.5));
    });
  });

  test('no closed shape: nothing found, the photo is still given', () {
    final result = findSketch(readPhoto('test/sketches/no_shape.jpg'));
    expect(result.found, isFalse);
    expect(result.sheet.width, greaterThan(100));
    final placed = placeSketch(result, 200);
    expect(placed.outline, isNull);
    expect(placed.photo.width, greaterThan(0));
  });

  test(
    'placeSketch: the photo is [side] metres, centred; the outline inside it',
    () {
      final result = findSketch(readPhoto('test/sketches/clean.jpg'));
      final placed = placeSketch(result, 300);
      expect(
        [
          placed.photo.width,
          placed.photo.length,
        ].reduce((a, b) => a > b ? a : b),
        closeTo(300, 0.01),
      );
      expect(placed.photo.center.x, closeTo(0, 0.01));
      for (final p in placed.outline!) {
        expect(p.x, inInclusiveRange(placed.photo.minX, placed.photo.maxX));
        expect(p.z, inInclusiveRange(placed.photo.minZ, placed.photo.maxZ));
      }
    },
  );

  test('no bit shift in the detection (on the web, -1 << 30 is a big '
      'POSITIVE number: Chrome found nothing)', () {
    final lines = File('lib/features/orchard_designer/sketch_detect.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'));
    expect(lines.any((l) => l.contains('<<') || l.contains('>>')), isFalse);
  });

  test('a blank picture: nothing found', () {
    final white = Uint8List(400 * 300 * 4)..fillRange(0, 400 * 300 * 4, 250);
    expect(findSketch(SketchImage(400, 300, white)).found, isFalse);
  });

  group('real phone photos (test/sketches/real/)', () {
    final dir = Directory('test/sketches/real');
    final files = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .where(
                (f) => RegExp(
                  r'\.(jpe?g|png)$',
                  caseSensitive: false,
                ).hasMatch(f.path),
              )
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];
    if (files.isEmpty) {
      test('none yet (put the .jpg files in test/sketches/real/)', () {});
    }
    for (final file in files) {
      test(file.uri.pathSegments.last, () {
        final result = findSketch(readPhoto(file.path));
        final outline = placeSketch(result, 200).outline;
        // ignore: avoid_print
        print(
          '${file.uri.pathSegments.last}: found ${result.found}, '
          '${outline?.length ?? 0} corners, straightened ${result.straightened}, '
          'tilt ${result.tiltDegrees.toStringAsFixed(1)}°',
        );
        expect(outline, isNotNull, reason: 'no closed shape found');
        expect(outline!.length, inInclusiveRange(3, 12));
      });
    }
  });
}
