// A fake camera and gallery for the tests: no phone needed. Each pick gives
// the next answer of [next] (a photo, null = closed, or an error).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';

/// A small real JPEG of one color (green by default).
Uint8List testPhotoBytes({
  int width = 64,
  int height = 48,
  int r = 142,
  int g = 208,
  int b = 74,
}) {
  final photo = img.Image(width: width, height: height);
  img.fill(photo, color: img.ColorRgb8(r, g, b));
  return img.encodeJpg(photo, quality: 80);
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.hasCamera = true});

  /// false = like on web (the gallery only).
  @override
  bool hasCamera;

  /// The answers of the next picks, in order: a Uint8List (the photo), null
  /// (closed without a photo) or a CommunityFailure (thrown). Empty = a green
  /// test photo.
  final List<Object?> next = [];

  /// The photo Android kept when it closed the app (given back once).
  Uint8List? lost;

  /// prepare() fails with this error (once).
  CommunityFailure? failPrepare;

  /// Not null = prepare() waits for it (to see "جاري تحضير الصورة…").
  Completer<void>? holdPrepare;

  /// "pick camera", "pick gallery", "lostPhoto", "prepare".
  final List<String> calls = [];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    calls.add('pick ${source.name}');
    final answer = next.isEmpty ? testPhotoBytes() : next.removeAt(0);
    if (answer is CommunityFailure) throw CommunityError(answer);
    return answer as Uint8List?;
  }

  @override
  Future<Uint8List?> lostPhoto() async {
    calls.add('lostPhoto');
    final photo = lost;
    lost = null;
    return photo;
  }

  @override
  Future<PreparedPhoto> prepare(Uint8List bytes) async {
    calls.add('prepare');
    await holdPrepare?.future;
    final failure = failPrepare;
    if (failure != null) {
      failPrepare = null;
      throw CommunityError(failure);
    }
    final decoded = img.decodeImage(bytes)!;
    return PreparedPhoto(
      bytes: bytes,
      width: decoded.width,
      height: decoded.height,
    );
  }
}
