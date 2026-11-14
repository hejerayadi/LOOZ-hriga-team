// The letter of a zone as the farmer reads it. The database keeps A to T
// (zones.letter, 20 zones at most); the screens show the letters of the ARB
// text "zoneLetters":
//  - in French: A, B, C...
//  - in Arabic: the ABJAD order أ ب ج د ه و ز ح ط ي ك ل م ن س ع ف ص ق ر
//    (exactly 20). Not أ ب ت ث: there, many letters differ only by their
//    dots (ب ت ث, ج ح خ, د ذ, ر ز), hard to tell apart for weak readers.
// ONE place for every screen: the designer, the 3D, the alerts, the
// diagnosis.
import 'package:flutter/widgets.dart';

import 'locale.dart';

/// [letter] ("A" to "T") in the language [languageCode] ('ar' or 'fr').
String zoneLetterIn(String letter, String languageCode) {
  final letters = lookupAppLocalizations(
    Locale(languageCode == 'ar' ? 'ar' : 'fr'),
  ).zoneLetters.split(' ');
  if (letter.length != 1) return letter;
  final i = letter.codeUnitAt(0) - 0x41; // 'A'
  return i >= 0 && i < letters.length ? letters[i] : letter;
}

/// [letter] in the language of the screen.
String zoneLetterOf(BuildContext context, String letter) =>
    zoneLetterIn(letter, Localizations.localeOf(context).languageCode);
