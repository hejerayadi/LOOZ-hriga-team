// The photo of a community post: taken with the camera or chosen in the
// gallery (on web: the gallery only), then made small and safe before it
// is uploaded (migration 007, bucket "community"):
//  - at most 1600 px (already made smaller while picking: fast),
//  - only a JPEG, PNG or WebP (checked on the first bytes of the file),
//  - turned upright, and saved as JPEG at 80 % WITHOUT the hidden data of
//    the photo (EXIF: the GPS position of the farm, the phone...).
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'community_service.dart';

/// The longest side of a photo, in pixels.
const photoMaxSide = 1600;

/// The JPEG quality of the uploaded photo (0 to 100).
const photoJpegQuality = 80;

/// The limit of the "community" bucket: 5 MB.
const photoMaxBytes = 5 * 1024 * 1024;

/// A picked file bigger than this is refused before it is read (the
/// memory of the phone).
const photoMaxPickedBytes = 30 * 1024 * 1024;

enum PhotoSource { camera, gallery }

/// A photo ready to upload: a JPEG without hidden data.
class PreparedPhoto {
  const PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  static const contentType = 'image/jpeg';
  static const extension = 'jpg';
}

/// Takes or chooses a photo. The app uses DevicePhotoPicker; the tests use
/// a fake one (no camera needed).
abstract class PhotoPicker {
  /// false on web: the gallery only.
  bool get hasCamera;

  /// The photo taken or chosen, or null when the farmer closed the camera
  /// or the gallery without a photo. Throws a CommunityError (camera
  /// refused, too big...).
  Future<Uint8List?> pick(PhotoSource source);

  /// Android only: the photo taken just before Android closed the app to
  /// free memory (null = none).
  Future<Uint8List?> lostPhoto();

  /// Checks the photo and makes it small and safe (see preparePhoto).
  Future<PreparedPhoto> prepare(Uint8List bytes);
}

PhotoPicker? _photoPicker;

/// The camera and the gallery (the tests put a fake one).
PhotoPicker get photoPicker => _photoPicker ??= DevicePhotoPicker();
set photoPicker(PhotoPicker picker) => _photoPicker = picker;

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get hasCamera => !kIsWeb;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Made smaller by the phone itself (the final JPEG is made below).
        maxWidth: photoMaxSide.toDouble(),
        maxHeight: photoMaxSide.toDouble(),
        imageQuality: 90,
        // No need to read the hidden data (no permission asked for it).
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw CommunityError(_pickFailureOf(error), error);
    }
    return file == null ? null : _read(file);
  }

  @override
  Future<Uint8List?> lostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final lost = await _picker.retrieveLostData();
    final file = lost.file;
    return lost.isEmpty || file == null ? null : _read(file);
  }

  @override
  Future<PreparedPhoto> prepare(Uint8List bytes) => preparePhoto(bytes);

  Future<Uint8List> _read(XFile file) async {
    if (await file.length() > photoMaxPickedBytes) {
      throw const CommunityError(CommunityFailure.photoTooBig);
    }
    return file.readAsBytes();
  }
}

/// The errors of the camera and the gallery (codes of image_picker).
CommunityFailure _pickFailureOf(PlatformException error) =>
    switch (error.code) {
      'camera_access_denied' => CommunityFailure.cameraDenied,
      'photo_access_denied' => CommunityFailure.galleryDenied,
      'no_available_camera' => CommunityFailure.noCamera,
      _ => CommunityFailure.unknown,
    };

/// What the first bytes of a file say it is: 'jpeg', 'png', 'webp', or null
/// for anything else (GIF, HEIC, a text file...).
String? photoTypeOf(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) =>
      bytes.length >= at + magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[at + i]].join(',') ==
          magic.join(',');
  if (starts([0xFF, 0xD8, 0xFF])) return 'jpeg';
  if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'png';
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'webp';
  }
  return null;
}

/// Checks a photo and makes it ready to upload: upright, at most 1600 px,
/// JPEG at 80 %, without hidden data, at most 5 MB. Throws a CommunityError
/// (photoWrongType, photoTooBig). On the phone it works in the background.
Future<PreparedPhoto> preparePhoto(Uint8List bytes) async {
  if (photoTypeOf(bytes) == null) {
    throw const CommunityError(CommunityFailure.photoWrongType);
  }
  final PreparedPhoto? photo;
  if (kIsWeb) {
    // Same thread on web: let the screen show "جاري تحضير الصورة…" first.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    photo = _prepareNow(bytes);
  } else {
    photo = await compute(_prepareNow, bytes);
  }
  if (photo == null) {
    throw const CommunityError(CommunityFailure.photoWrongType);
  }
  if (photo.bytes.length > photoMaxBytes) {
    throw const CommunityError(CommunityFailure.photoTooBig);
  }
  return photo;
}

/// null = not a photo that can be read.
PreparedPhoto? _prepareNow(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  // Upright, like the farmer saw it (the phone often saves it turned).
  var photo = img.bakeOrientation(decoded);
  if (max(photo.width, photo.height) > photoMaxSide) {
    final wide = photo.width >= photo.height;
    photo = img.copyResize(
      photo,
      width: wide ? photoMaxSide : null,
      height: wide ? null : photoMaxSide,
      interpolation: img.Interpolation.average,
    );
  }
  // A new picture on white: no transparency (JPEG has none) and none of the
  // hidden data of the old file.
  final clean = img.Image(width: photo.width, height: photo.height);
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, photo);
  return PreparedPhoto(
    bytes: img.encodeJpg(clean, quality: photoJpegQuality),
    width: clean.width,
    height: clean.height,
  );
}

/// A random id like "7a2b0c1f-...": the name of a photo in the bucket.
String randomPhotoId() {
  final random = Random.secure();
  final b = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  b[6] = (b[6] & 0x0f) | 0x40; // version 4 (random)
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
