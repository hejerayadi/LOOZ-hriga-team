// A simple test: the main screen shows the 4 tabs.
// (We test MainShell directly: the login screen needs a real Supabase.)
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/strings/app_strings.dart';

void main() {
  testWidgets('Main screen starts on "Mon verger" with 4 tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    // "Mon verger" appears twice: page title + tab label.
    expect(find.text(AppStrings.tabHome), findsNWidgets(2));
    expect(find.text(AppStrings.tabCommunity), findsOneWidget);
    expect(find.text(AppStrings.tabAlerts), findsOneWidget);
    expect(find.text(AppStrings.tabProfile), findsOneWidget);
  });

  testWidgets('Without Supabase keys, a help message is shown', (tester) async {
    await tester.pumpWidget(const MissingKeysApp());
    expect(find.text(AppStrings.missingKeys), findsOneWidget);
  });
}
