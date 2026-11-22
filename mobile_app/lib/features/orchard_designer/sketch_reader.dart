// "من صورة": the photo of a sketch → what the outline step shows: the
// picture (upright, straightened when the sheet was found) and the outline
// found on it, both placed on the grid. Everything happens on the phone (or
// in Chrome): the photo is never sent and never saved.
// The tests put a fake reader (sketchReader = ...).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../data/community_photos.dart' show photoTypeOf;
import '../../data/community_service.dart';
import 'geometry.dart';
import 'sketch_detect.dart';

/// The photo of the sketch, ready for the outline step.
class SketchPhoto {
  const SketchPhoto({required this.place, this.image, this.outline});

  /// The picture shown faded behind the grid (null in the tests).
  final ui.Image? image;

  /// Its place on the grid (metres).
  final Bounds place;

  /// The outline found (metres, cleaned like a finger's line); null = none
  /// (the farmer taps the corners on the photo).
  final Polygon? outline;

  bool get found => outline != null;
}

abstract class SketchReader {
  /// Reads [bytes] (a JPEG / PNG / WebP photo) and finds the outline. The
  /// photo's longest side becomes [side] metres. Throws a CommunityError
  /// (photoWrongType) when it is not a photo that can be read.
  Future<SketchPhoto> read(Uint8List bytes, {required double side});
}

SketchReader? _sketchReader;

SketchReader get sketchReader => _sketchReader ??= DeviceSketchReader();
set sketchReader(SketchReader reader) => _sketchReader = reader;

class DeviceSketchReader implements SketchReader {
  @override
  Future<SketchPhoto> read(Uint8List bytes, {required double side}) async {
    if (photoTypeOf(bytes) == null) {
      throw const CommunityError(CommunityFailure.photoWrongType);
    }
    final SketchImage photo;
    try {
      photo = await _decode(bytes);
    } catch (_) {
      throw const CommunityError(CommunityFailure.photoWrongType);
    }
    final SketchResult result;
    if (kIsWeb) {
      // Same thread on web: let the screen show "نبحث…" first.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      result = findSketch(photo);
    } else {
      result = await compute(findSketch, photo);
    }
    final placed = placeSketch(result, side);
    return SketchPhoto(
      image: await _toImage(result.sheet),
      place: placed.photo,
      outline: placed.outline,
    );
  }
}

/// The photo's pixels, upright (the phone's turn is applied by Flutter),
/// at most [sketchMaxSide].
Future<SketchImage> _decode(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final side = math.max(w, h);
      if (side <= sketchMaxSide) return ui.TargetImageSize(width: w, height: h);
      final f = sketchMaxSide / side;
      return ui.TargetImageSize(
        width: math.max(1, (w * f).round()),
        height: math.max(1, (h * f).round()),
      );
    },
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  // Exactly the pixels (in Chrome the bytes may sit inside a bigger block).
  final pixels = SketchImage(
    image.width,
    image.height,
    Uint8List.fromList(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ),
  );
  image.dispose();
  codec.dispose();
  return pixels;
}

Future<ui.Image> _toImage(SketchImage pixels) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels.rgba,
    pixels.width,
    pixels.height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}
