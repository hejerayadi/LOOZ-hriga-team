// The main screen (5 tabs), the 2 languages, and the login.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/features/home/home_page.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('Main screen starts on Home with the 5 tabs, in Arabic', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));

    expect(find.text('صباح الخير'), findsOneWidget); // Home title
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المجتمع'), findsOneWidget);
    expect(findTextWithSymbol('بستاني ★'), findsOneWidget);
    expect(find.text('التنبيهات'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);

    // Arabic is written right to left.
    final home = tester.element(find.byType(HomePage));
    expect(Directionality.of(home), TextDirection.rtl);
  });

  testWidgets('The FR switch puts the whole app in French', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));

    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Communauté'), findsOneWidget);
    expect(findTextWithSymbol('Verger ★'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    final home = tester.element(find.byType(HomePage));
    expect(Directionality.of(home), TextDirection.ltr);

    // And back to Arabic.
    await tester.tap(find.text('عربي'));
    await tester.pumpAndSettle();
    expect(find.text('صباح الخير'), findsOneWidget);
  });

  testWidgets('Login: language, phone, code, name, pack, welcome, Home', (
    tester,
  ) async {
    usePhoneScreen(tester);
    // A fake login system (every code is 123456): see sign_up_test.dart.
    useFakeAuth();
    await tester.pumpWidget(const LoozApp());

    // 1. Choose French.
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Votre téléphone'), findsOneWidget);

    // 2. The button does nothing until the 8 digits are typed.
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();
    expect(find.text('Votre téléphone'), findsOneWidget);
    for (final digit in '12345678'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();
    expect(find.text('+216 12 345 678'), findsOneWidget);
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    // 3. The code (6 digits; the fake login accepts 123456).
    expect(find.text('Entrez le code'), findsOneWidget);
    for (final digit in '123456'.split('')) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();
    expect(find.text('1 2 3 4 5 6'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    // 4. A new number: the name, then the free pack.
    expect(find.text('Votre nom'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Mohamed');
    await tester.enterText(find.byType(TextField).at(1), 'Ben Salem');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gratuit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 5. Welcome, then the app.
    expect(find.text('Bienvenue Mohamed'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour'), findsOneWidget);
  });

  testWidgets('Without Supabase keys, a help message is shown', (tester) async {
    await tester.pumpWidget(const MissingKeysApp());
    await tester.pumpAndSettle();
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(ar.missingKeys), findsOneWidget);
  });
}
