// A fake "من صورة" reader for the tests: no decoding, no image processing.
// It answers with an outline found (by default), none, or an error.
import 'dart:async';
import 'dart:typed_data';

import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';
import 'package:looz_mobile/features/orchard_designer/sketch_reader.dart';

/// The photo on the grid: 200 x 150 m, centred.
const sketchPlace = Bounds(-100, -75, 100, 75);

/// The outline "found" on it: 140 x 90 m.
const sketchOutline = [
  OrchardPoint(-70, -45),
  OrchardPoint(70, -45),
  OrchardPoint(70, 45),
  OrchardPoint(-70, 45),
];

class FakeSketchReader implements SketchReader {
  /// The answers of the next reads, in order: a SketchPhoto, or a
  /// CommunityFailure (thrown). Empty = the outline found.
  final List<Object> next = [];

  /// Not null = read() waits for it (to see "نبحث عن حدود البستان…").
  Completer<void>? hold;

  /// The sides asked (metres).
  final List<double> sides = [];

  static const found = SketchPhoto(place: sketchPlace, outline: sketchOutline);
  static const notFound = SketchPhoto(place: sketchPlace);

  @override
  Future<SketchPhoto> read(Uint8List bytes, {required double side}) async {
    sides.add(side);
    await hold?.future;
    final answer = next.isEmpty ? found : next.removeAt(0);
    if (answer is CommunityFailure) throw CommunityError(answer);
    return answer as SketchPhoto;
  }
}
