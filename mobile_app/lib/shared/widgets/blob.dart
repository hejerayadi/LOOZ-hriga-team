// The soft "blob" shapes of the design (a circle that is a bit uneven),
// and IconBlob: an icon on a colored blob.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// The blob shapes of the design. Each list = the round corners as a part of
/// the size, in this order: top-left, top-right, bottom-right, bottom-left.
class BlobShapes {
  static const icon = [0.44, 0.56, 0.61, 0.39];
  static const orb = [0.48, 0.52, 0.58, 0.42];
  static const avatar = [0.45, 0.55, 0.50, 0.50];
  static const tile = [0.45, 0.55, 0.58, 0.42]; // the circle on Home's tiles

  // The face has different corners across (width) and up-down (height).
  static const faceAcross = [0.48, 0.52, 0.43, 0.57];
  static const faceUpDown = [0.58, 0.44, 0.56, 0.42];
}

/// Turns a blob shape into round corners for a box of this size.
/// [upDown] = corners in the height, when they differ from [across].
BorderRadius blobRadius(
  Size size,
  List<double> across, [
  List<double>? upDown,
]) {
  final v = upDown ?? across;
  // Like in CSS: if two corners of one side are too big together, shrink all.
  final scale = [
    1.0,
    1 / (across[0] + across[1]),
    1 / (across[3] + across[2]),
    1 / (v[0] + v[3]),
    1 / (v[1] + v[2]),
  ].reduce(math.min);
  Radius corner(int i) => Radius.elliptical(
    across[i] * size.width * scale,
    v[i] * size.height * scale,
  );
  return BorderRadius.only(
    topLeft: corner(0),
    topRight: corner(1),
    bottomRight: corner(2),
    bottomLeft: corner(3),
  );
}

/// An icon on a pale colored blob (the design's "icon-blob").
class IconBlob extends StatelessWidget {
  const IconBlob({
    super.key,
    required this.icon,
    this.color = AppColors.sky,
    this.size = 58,
    this.iconSize = 28,
  });

  final AppIcon icon;

  /// Color of the blob behind the icon.
  final Color color;

  /// Width and height of the blob (58, or 90 for the big ones).
  final double size;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: blobRadius(Size.square(size), BlobShapes.icon),
      ),
      child: LoozIcon(icon, size: iconSize),
    );
  }
}
