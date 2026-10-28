// All the colors of the app, taken from the design (its CSS).
// Change a color here and it changes everywhere.
//
// Each color is named by what it looks like. The design's own name is in
// the comment, e.g. "--pink" (which is in fact a light green).
import 'package:flutter/material.dart';

import '../enums.dart';

class AppColors {
  // ----- The design's main colors -----
  static const green = Color(0xFF0F3D2B); // --green: text, tab bar
  static const leaf = Color(0xFF8ED04A); // --leaf: active tab, camera, "ok"
  static const lightGreen = Color(0xFFB8DF9B); // --pink: main buttons
  static const midGreen = Color(0xFF72AE4F); // --gold: premium star
  static const mint = Color(0xFFC8EFD9); // --mint: round buttons, tiles
  static const mintWhite = Color(0xFFEAF8F0); // --mintwhite: page background
  static const cream = Color(0xFFFAF8F3); // --cream: page background
  static const sky = Color(0xFFD6F2EA); // --sky: icon blobs
  static const peach = Color(0xFFDFF1D5); // --peach: icon blobs
  static const yellow = Color(0xFFE5F3DA); // --yellow: tiles
  static const softGreen = Color(0xFFD8EFC9); // assistant bar, "Ask" tile
  static const white = Color(0xFFFFFFFF);

  // ----- See-through whites (over drawings and photos) -----
  static const white60 = Color(0x99FFFFFF); // circle behind the tile icons
  static const white70 = Color(0xB3FFFFFF); // border of the language pill
  static const white78 = Color(0xC7FFFFFF); // keypad keys, weather card
  static const white82 = Color(0xD1FFFFFF); // language pill
  static const white84 = Color(0xD6FFFFFF); // weather panel
  static const glass = white84; // old name

  // ----- The drawing of the orchard (sun and hills) -----
  static const heroTop = Color(0xFFF4FBEF);
  static const sun = Color(0xFFDFF2C9);
  static const sunIcon = Color(0xFF28664A);
  static const hillBack = Color(0xFFAADA8A);
  static const hillFront = Color(0xFF66AD6F);
  static const miniTree = Color(0xFF8FCF73);
  static const miniTreeShadow = Color(0xFF5B8956);

  // ----- The assistant "orb" -----
  static const orbDark = Color(0xFF79B85D);
  static const orbIcon = Color(0xFF24583D);

  // ----- The welcome photo: a dark green veil, stronger at the bottom -----
  static const photoVeilTop = Color(0x140F3D2B); // green at 8%
  static const photoVeilBottom = Color(0xD10F3D2B); // green at 82%

  // ----- Status colors (the faces and the side bars of the cards) -----
  // The design uses 3 greens: light = fine, medium = watch, dark = act now.
  static const good = leaf;
  static const warning = Color(0xFF69A66F); // --orange (a medium green)
  static const danger = Color(0xFF28664A); // --red (a dark green)

  /// The color of a status level.
  static Color forLevel(StatusLevel level) {
    switch (level) {
      case StatusLevel.good:
        return good;
      case StatusLevel.warning:
        return warning;
      case StatusLevel.danger:
        return danger;
    }
  }

  // ----- Old names -----
  // The screens not redesigned yet still use these names. They point to the
  // new colors, and will be removed once every screen uses the new names.
  static const olive = green;
  static const almond = cream;
  static const almondLight = white;
  static const brown = midGreen;
  static const textDark = green;
  static const premium = midGreen;
  static const textMuted = Color(0xB30F3D2B); // green at 70%
}
