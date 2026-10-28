// Moving between screens, like in the design: the 5 tabs, and screens
// opened on top of them (they keep the tab bar, with no tab selected).
import 'package:flutter/material.dart';

import 'plans.dart';

/// The 5 tabs, in the order of the design (from the right in Arabic).
enum AppTab { home, community, orchard, alerts, profile }

/// The tab shown by the main screen (see MainShell in app.dart).
final ValueNotifier<AppTab> currentTab = ValueNotifier(AppTab.home);

/// Shows a tab: closes the screens opened on top, then selects the tab.
void goToTab(BuildContext context, AppTab tab) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  currentTab.value = tab;
}

/// Opens a screen on top. A quick fade, so the bottom bars seem to stay still.
Future<T?> openScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Opens a screen of a paid feature. Without the right plan, shows the
/// design's "locked" screen instead (the "بستاني ★" tab).
void openFeature(BuildContext context, Feature feature, Widget screen) {
  if (canUse(feature)) {
    openScreen(context, screen);
  } else {
    goToTab(context, AppTab.orchard);
  }
}

/// Replaces the current screen (e.g. "جاري النظر…" by the result).
void replaceWith(BuildContext context, Widget screen) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Opens a screen and forgets the previous ones (e.g. after the login:
/// the back button must not go back to the login screens).
void replaceAllWith(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
    (_) => false,
  );
}
