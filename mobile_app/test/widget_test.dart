// A simple test: the app starts and shows the 4 tabs.
// Run it with: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/strings/app_strings.dart';

void main() {
  testWidgets('App starts on "Mon verger" with 4 tabs', (tester) async {
    await tester.pumpWidget(const LoozApp());

    // "Mon verger" appears twice: page title + tab label.
    expect(find.text(AppStrings.tabHome), findsNWidgets(2));
    expect(find.text(AppStrings.tabCommunity), findsOneWidget);
    expect(find.text(AppStrings.tabAlerts), findsOneWidget);
    expect(find.text(AppStrings.tabProfile), findsOneWidget);
  });
}
