// Spaces, sizes, round corners, shadows and gradients of the design.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'css.dart';

/// Spaces between things (in logical pixels).
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  /// Space on the left and right of a page.
  static const page = 20.0;

  /// Same, on small phones.
  static const pageSmallPhone = 14.0;

  /// Space above the content of a page.
  static const pageTop = 28.0;

  /// Space below the content of a page with the bottom bars
  /// (so the last card can scroll above the assistant bar and the tabs).
  static const pageBottom = 190.0;

  /// Phones this wide or narrower are "small phones" (smaller titles, margins).
  static const smallPhoneWidth = 380.0;

  /// The design is drawn for a phone up to 440 px wide. On wider screens
  /// (tablets), the content stays that wide, in the middle.
  static const maxPhoneWidth = 440.0;

  /// true on small phones.
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= smallPhoneWidth;

  /// Space on the left and right of a page, for this screen size.
  /// [shrink] = false: keep 20 on small phones (the login screens).
  static double pageSide(BuildContext context, {bool shrink = true}) {
    final width = MediaQuery.sizeOf(context).width;
    if (shrink && width <= smallPhoneWidth) return pageSmallPhone;
    return page + math.max(0, (width - maxPhoneWidth) / 2);
  }
}

/// Fixed sizes of some elements.
class AppSizes {
  static const tabBarHeight = 74.0;
  static const tabBarBottom = 14.0; // space under the tab bar
  static const tabBarMaxWidth = 416.0;
  static const assistantBarHeight = 62.0;
  static const assistantBarBottom = 94.0; // from the bottom of the screen
  static const assistantBarMaxWidth = 400.0;
  static const roundButton = 62.0; // camera button
  static const backButton = 54.0;
  static const logoWidth = 48.0;
  static const logoHeight = 72.0;
}

/// Round corners.
class AppRadius {
  static const pill = 99.0;
  static const sm = 20.0;
  static const keypad = 22.0;
  static const md = 24.0;
  static const lg = 28.0; // cards, tab bar
  static const tile = 30.0;
  static const xl = 32.0; // big cards
  static const xxl = 36.0;
}

/// The shadows of the design (each one: CSS x, y, blur, color).
class AppShadows {
  /// Cards (the design's "--shadow").
  static final card = [cssShadow(0, 14, 38, const Color(0x1A0F3D2B))];

  /// The language pill.
  static final langPill = [cssShadow(0, 6, 18, const Color(0x1A0F3D2B))];

  /// Big pill buttons.
  static final button = [cssShadow(0, 10, 22, const Color(0x2E0F3D2B))];

  /// The 2 language buttons of the first screen.
  static final languageButton = [cssShadow(0, 10, 25, const Color(0x2E0F3D2B))];

  /// Keypad keys.
  static final key = [cssShadow(0, 8, 22, const Color(0x120F3D2B))];

  /// The faces.
  static final face = [cssShadow(0, 9, 18, const Color(0x240F3D2B))];

  /// The assistant bar.
  static final assistantBar = [cssShadow(0, 8, 24, const Color(0x240F3D2B))];

  /// The camera button.
  static final camera = [cssShadow(0, 8, 24, const Color(0x380F3D2B))];

  /// The tab bar.
  static final tabBar = [cssShadow(0, 12, 30, const Color(0x400F3D2B))];

  /// The trees on the map.
  static final mapTree = [cssShadow(0, 5, 12, const Color(0x33000000))];

  /// Light glow around the sun of the orchard drawing.
  static final sunGlow = [cssShadow(0, 0, 35, AppColors.mintWhite)];

  /// Green glow around the assistant orb.
  static final orb = [cssShadow(0, 0, 28, const Color(0xA68ED04A))];
  static final orbTiny = [cssShadow(0, 0, 16, const Color(0x948ED04A))];

  // Old names, used by the screens not redesigned yet.
  static final small = langPill;
  static final floating = assistantBar;
}

/// The light band at the top of round buttons and faces
/// (CSS `inset 0 <y>px rgba(255,255,255,<opacity>)`).
class AppHighlights {
  static const button = Offset(0, 2); // with white at 55%
  static const buttonColor = Color(0x8CFFFFFF);
  static const face = Offset(0, 4); // with white at 35%
  static const faceColor = Color(0x59FFFFFF);
  static const orb = Offset(0, 3); // with white at 65%
  static const orbColor = Color(0xA6FFFFFF);
}

/// The gradients of the design.
class AppGradients {
  /// Page: cream to light mint (under the 2 glows below).
  static const page = CssLinearGradient(
    angle: 145,
    colors: [AppColors.cream, AppColors.mintWhite],
  );

  /// Page: light green glow at the top left.
  static const pageGlowLeft = CssRadialGradient(
    center: Offset(0.10, 0.08),
    colors: [Color(0x478ED04A), Color(0x008ED04A)],
    stops: [0, 0.24],
  );

  /// Page: mint glow on the right.
  static const pageGlowRight = CssRadialGradient(
    center: Offset(0.95, 0.23),
    colors: [Color(0x9EC8EFD9), Color(0x00C8EFD9)],
    stops: [0, 0.25],
  );

  /// Sky of the orchard drawing.
  static const heroSky = CssLinearGradient(
    angle: 160,
    colors: [AppColors.heroTop, AppColors.sky],
    stops: [0, 0.58],
  );

  /// The assistant orb: white shine at the top left, green below.
  static const orb = CssRadialGradient(
    center: Offset(0.35, 0.25),
    colors: [AppColors.white, AppColors.lightGreen, AppColors.orbDark],
    stops: [0, 0.3, 1],
  );

  /// The dark veil over the welcome photo.
  static const photoVeil = CssLinearGradient(
    angle: 180,
    colors: [AppColors.photoVeilTop, AppColors.photoVeilBottom],
  );
}
