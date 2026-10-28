// Shared helpers for the tests.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/fake_data.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_tab.dart';

/// Tests use a font where every letter is a square: load Cairo instead,
/// so the screens are laid out like in the app (call it in setUpAll).
Future<void> loadAppFonts() async {
  final cairo = FontLoader('Cairo');
  for (final weight in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    cairo.addFont(rootBundle.load('assets/fonts/Cairo-$weight.ttf'));
  }
  await cairo.load();
}

/// Tests run on an 800 x 600 screen by default: use a phone screen
/// instead (390 x 844, like the screenshots of the design).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Like the phone setting "remove animations": the voice screen and the
/// petals stay still, so `pumpAndSettle` can finish.
void noAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The app keeps the language, plan, tab and demo state in global values:
/// put them back after each test.
void resetAppState() {
  appLocale.value = const Locale('ar');
  currentPlan.value = Plan.connected;
  currentTab.value = AppTab.home;
  orchardPanelOpen.value = false;
  fakeTreeWatered.value = false;
}

/// Closes the screens (stops their timers) at the end of a test.
Future<void> closeApp(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

/// Finds a text that may contain a drawn symbol (★, ✿...): the symbols
/// are not letters, so only the longest part without them is searched.
Finder findTextWithSymbol(String text) {
  final parts = text.split(RegExp('[★✿⌫←→✓◆]')).map((p) => p.trim()).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return find.textContaining(parts.first, findRichText: true);
}

/// Every text on the screen (the screen on top, not the hidden ones).
List<String> textsOnScreen() => [
  for (final element in find.byType(RichText).evaluate())
    (element.widget as RichText).text.toPlainText(),
];
