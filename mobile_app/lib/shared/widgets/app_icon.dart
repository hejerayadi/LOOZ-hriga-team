// The line icons of the design (assets/icons/*.svg), e.g. LoozIcon(AppIcon.sun).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// Every icon of the design. The name = the file in assets/icons/.
enum AppIcon {
  home,
  people,
  tree,
  bell,
  user,
  mic,
  camera,
  sun,
  drop,
  leaf,
  bug,
  book,
  map,
  speaker,
  arrow,
  clock,
  wifi,
  check,
}

class LoozIcon extends StatelessWidget {
  const LoozIcon(this.icon, {super.key, this.size = 28, this.color});

  final AppIcon icon;
  final double size;

  /// null = the color of the icons around (dark green by default).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? AppColors.green;
    return SvgPicture.asset(
      'assets/icons/${icon.name}.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}
