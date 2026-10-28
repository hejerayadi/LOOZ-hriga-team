// All the text styles of the app: font Cairo, sizes and weights of the design.
//
// Like in the design, every line is 1.5 times the font size (titles: 1.16),
// with the extra space split evenly above and below the letters, and no
// extra space between letters (Material adds some by default).
// "Normal" text uses Cairo Medium (w500): the design loads 500 to 800 only.
import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  /// The font of the design, bundled in assets/fonts (see pubspec.yaml).
  static const fontFamily = 'Cairo';

  /// Any text of the design: size + weight, dark green.
  static TextStyle of(double size, [FontWeight weight = FontWeight.w500]) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0,
        wordSpacing: 0,
        height: 1.5,
        leadingDistribution: TextLeadingDistribution.even,
        color: AppColors.green,
      );

  // ----- Titles -----

  /// Big page title, e.g. "صباح الخير".
  static const headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.16,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.green,
  );

  /// Big page title on small phones (380 px wide or less).
  static final headlineSmallPhone = headline.copyWith(fontSize: 28);

  /// The line under the page title (shown at 70% opacity).
  static final subtitle = of(18, FontWeight.w600);

  // ----- Buttons -----

  /// Big pill buttons ("ابدأ", "تأكيد"...).
  static final button = of(21, FontWeight.w800);

  /// The 2 big language buttons on the first screen.
  static final languageButton = of(22, FontWeight.w800);

  /// "عربي" / "FR" in the language pill.
  static final langPill = of(15, FontWeight.w800);

  /// Phone number, code and keypad keys.
  static final keypad = of(25, FontWeight.w800);

  // ----- Cards -----

  /// Bold first line of a card, e.g. "التربة جافة".
  static final cardTitle = of(19, FontWeight.w700);

  /// Second line of a card, e.g. "اسقِ اليوم".
  static final cardText = of(16);

  /// Temperature on the weather card.
  static final temperature = of(30, FontWeight.w700);

  /// Advice on the weather card.
  static final weatherText = of(16, FontWeight.w700);

  /// Label of the 3 big tiles on Home ("اسأل", "دفتر", "خريطة").
  static final tileLabel = of(18, FontWeight.w800);

  // ----- Bars at the bottom -----

  /// "اسأل المساعد" in the assistant bar.
  static final assistantBar = of(17, FontWeight.w700);

  /// Tab labels (white). The selected tab is 1 px bigger; on small
  /// phones the others are 9 px.
  static final tabLabel = of(
    10,
    FontWeight.w700,
  ).copyWith(color: AppColors.white);
  static final tabLabelSelected = tabLabel.copyWith(fontSize: 11);
  static final tabLabelSmallPhone = tabLabel.copyWith(fontSize: 9);

  // ----- Old names -----
  // Used by the screens not redesigned yet. Removed at the end.
  static final number = of(30, FontWeight.w800);
  static final sectionTitle = of(22, FontWeight.w800);
  static final cardTitleSmall = of(17, FontWeight.w700);
  static final body = of(18);
  static final bodySmall = of(16);
  static final caption = of(14, FontWeight.w600);
  static final label = of(15, FontWeight.w800);
}
