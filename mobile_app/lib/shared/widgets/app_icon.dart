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
  logout, // not in the design: "log out" in Profile (same line style)
  trash, // not in the design: delete your answer in the community
  plus, // not in the design: "＋ انشر" (publish in the community)
  image, // not in the design: choose a photo in the gallery
  userPlus, // not in the design: "إنشاء حساب" on the start screen
  logIn, // not in the design: "تسجيل الدخول" on the start screen
  card, // not in the design: the card number (demo payment)
  lock, // not in the design: the security code of the card
  warning, // not in the design: an error (the bug is only for pests)
  // Not in the design: the orchard designer (same line style).
  pen, // draw with the finger
  corners, // tap the corners one by one
  undo,
  redo,
  erase, // start the drawing again
  ruler, // the size in metres
  scissors, // the dividing lines
  satellite, // the map mode (later)
  minus,
  // Not in the design: the kinds of regional alerts (same line style).
  snow, // frost
  thermo, // heat
  wind,
  rain,
  // Not in the design: "إبلاغ" in the community and its reasons.
  flag,
  megaphone, // spam, advertising
  message, // insult (a speech bubble with ×)
  dots, // another reason
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
