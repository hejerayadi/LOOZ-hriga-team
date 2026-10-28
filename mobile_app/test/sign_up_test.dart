// Sign up and sign in with the phone number, with a fake login system
// (test/fake_auth_service.dart: every code is 123456, no internet needed).
// The same flow against the real Supabase: test_live/auth_live_test.dart.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/language_screen.dart';
import 'package:looz_mobile/features/onboarding/name_screen.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/payment_choice_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/shared/widgets/looz_tab_bar.dart';
import 'package:looz_mobile/shared/widgets/symbol_text.dart';

import 'fake_auth_service.dart';
import 'test_helpers.dart';

/// Starts the app like on a phone (the first screen decides where to go).
Future<FakeAuthService> startApp(
  WidgetTester tester, {
  FakeAuthService? auth,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  final fake = auth ?? useFakeAuth();
  authService = fake;
  await tester.pumpWidget(const LoozApp());
  await tester.pumpAndSettle();
  return fake;
}

/// Scrolls to it if needed, taps it, and waits for the next screen.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Types digits on the keypad of the phone and code screens.
Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit).last);
  }
  await tester.pump();
}

/// Language → phone (+216 and the 8 digits) → code.
Future<void> logIn(
  WidgetTester tester, {
  required String language,
  required String digits,
  String code = FakeAuthService.code,
}) async {
  await tapAndWait(tester, find.text(language));
  expect(find.byType(PhoneScreen), findsOneWidget);
  await typeDigits(tester, digits);
  await tapAndWait(tester, find.text(lookup(tester).sendCode));
  expect(find.byType(CodeScreen), findsOneWidget);
  await typeDigits(tester, code);
  await tapAndWait(tester, find.text(lookup(tester).confirm));
}

/// The texts in the language shown now.
AppLocalizations lookup(WidgetTester tester) =>
    lookupAppLocalizations(appLocale.value);

/// The ⌫ key of the keypad (drawn as a picture, not a letter).
final backspaceKey = find.byWidgetPredicate(
  (widget) => widget is SymbolText && widget.text == '⌫',
);

/// The name boxes.
Finder nameField(int i) => find.byType(TextField).at(i);

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('New user (Arabic): name, free pack, welcome, Home', (
    tester,
  ) async {
    final auth = await startApp(tester);
    expect(find.byType(LanguageScreen), findsOneWidget); // nobody logged in

    await logIn(tester, language: 'العربية', digits: '50000001');
    expect(auth.calls.first, 'sendCode +21650000001');

    // New user: the name. Both are required.
    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text('ما اسمك؟'), findsOneWidget);
    await tapAndWait(tester, find.text('متابعة'));
    expect(find.text('هذه الخانة مطلوبة'), findsNWidgets(2));
    expect(find.byType(NameScreen), findsOneWidget);

    // No digits or symbols.
    await tester.enterText(nameField(0), 'محمد');
    await tester.enterText(nameField(1), 'بن سالم 2');
    await tapAndWait(tester, find.text('متابعة'));
    expect(find.text('استعمل الحروف فقط'), findsOneWidget);
    expect(find.text('هذه الخانة مطلوبة'), findsNothing);

    await tester.enterText(nameField(1), '  بن   سالم ');
    await tapAndWait(tester, find.text('متابعة'));

    // The pack: "متابعة" does nothing until a pack is chosen.
    expect(find.byType(PackScreen), findsOneWidget);
    expect(find.text('اختر باقتك'), findsOneWidget);
    expect(find.text('مجاني'), findsOneWidget);
    expect(find.text('أساسي'), findsOneWidget);
    expect(find.text('متصل'), findsOneWidget);
    await tapAndWait(tester, find.text('متابعة'));
    expect(find.byType(PackScreen), findsOneWidget);
    await tapAndWait(tester, find.text('مجاني'));
    await tapAndWait(tester, find.text('متابعة'));

    // Welcome with the real first name, then Home.
    expect(find.text('مرحبًا يا محمد'), findsOneWidget);
    await tapAndWait(tester, find.text('ابدأ'));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('محمد، أشجارك بخير اليوم'), findsOneWidget);

    // What was saved.
    final saved = auth.accounts['+21650000001']!;
    expect(saved.firstName, 'محمد');
    expect(saved.lastName, 'بن سالم'); // spaces cleaned
    expect(saved.language, 'ar');
    expect(saved.chosenPlan, Plan.free);
    expect(saved.paymentStatus, PaymentStatus.free);
    expect(saved.hasChosenPlan, isTrue);
    expect(currentPlan.value, Plan.free);
    expect(auth.hasSession, isTrue);
  });

  testWidgets('New user (French): paid pack, "pay later" = pending, free', (
    tester,
  ) async {
    final auth = await startApp(tester);
    await logIn(tester, language: 'Français', digits: '50000003');

    await tester.enterText(nameField(0), 'Amine');
    await tester.enterText(nameField(1), "Ben-Ali M'barek");
    await tapAndWait(tester, find.text('Continuer'));

    await tapAndWait(tester, find.text('Essentiel'));
    await tapAndWait(tester, find.text('Continuer'));

    // Pay now or later.
    expect(find.byType(PaymentChoiceScreen), findsOneWidget);
    expect(find.text('Quand payer ?'), findsOneWidget);
    expect(find.text('Essentiel'), findsOneWidget);
    expect(find.text('XX DT / mois'), findsOneWidget);
    await tapAndWait(tester, find.text('Payer plus tard'));

    expect(find.text('Bienvenue Amine'), findsOneWidget);
    final saved = auth.accounts['+21650000003']!;
    expect(saved.fullName, "Amine Ben-Ali M'barek");
    expect(saved.language, 'fr');
    expect(saved.chosenPlan, Plan.essential);
    expect(saved.paymentStatus, PaymentStatus.pending);
    // Not paid yet: the free plan.
    expect(currentPlan.value, Plan.free);
  });

  testWidgets('New user: paid pack, "pay now" = payment screen, pending', (
    tester,
  ) async {
    final auth = await startApp(tester);
    await logIn(tester, language: 'العربية', digits: '50000004');
    await tester.enterText(nameField(0), 'سارة');
    await tester.enterText(nameField(1), 'الطرابلسي');
    await tapAndWait(tester, find.text('متابعة'));
    await tapAndWait(tester, find.text('متصل'));
    await tapAndWait(tester, find.text('متابعة'));

    await tapAndWait(tester, findTextWithSymbol('★ ادفع الآن'));
    expect(find.byType(PaymentScreen), findsOneWidget);
    // The app is not open yet: no tab bar.
    expect(find.byType(LoozTabBar), findsNothing);
    await tapAndWait(tester, findTextWithSymbol('★ تأكيد'));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('مرحبًا يا سارة'), findsOneWidget);
    final saved = auth.accounts['+21650000004']!;
    expect(saved.chosenPlan, Plan.connected);
    expect(saved.paymentStatus, PaymentStatus.pending);
    expect(currentPlan.value, Plan.free);
  });

  testWidgets('Existing user: phone, code, then Home directly', (tester) async {
    final auth = useFakeAuth()
      ..addUser('+21650000002', language: 'fr', chosenPlan: Plan.essential)
      ..plans['+21650000002'] = Plan.essential; // paid
    await startApp(tester, auth: auth);

    await logIn(tester, language: 'العربية', digits: '50000002');
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Mohamed، أشجارك بخير اليوم'), findsOneWidget);
    expect(find.byType(NameScreen), findsNothing);
    // No sign-up step was saved again; the language just chosen was.
    expect(auth.calls, isNot(contains('saveName')));
    expect(auth.calls.where((c) => c.startsWith('choosePlan')), isEmpty);
    expect(auth.calls, contains('saveLanguage ar'));
    expect(auth.accounts['+21650000002']!.language, 'ar');
    // The plan comes from the database.
    expect(currentPlan.value, Plan.essential);
  });

  testWidgets('Sign-up stopped after the name: the next login shows the pack', (
    tester,
  ) async {
    final auth = useFakeAuth()
      ..addUser('+21650000005', language: 'ar', finished: false);
    await startApp(tester, auth: auth);
    await logIn(tester, language: 'العربية', digits: '50000005');
    expect(find.byType(PackScreen), findsOneWidget);
  });

  testWidgets('Wrong code: a message, then the right code works', (
    tester,
  ) async {
    await startApp(tester);
    await logIn(
      tester,
      language: 'العربية',
      digits: '50000001',
      code: '111111',
    );
    expect(find.byType(CodeScreen), findsOneWidget);
    expect(find.text('الرمز غير صحيح أو انتهت صلاحيته.'), findsOneWidget);

    // A new code can be asked.
    await tapAndWait(tester, find.text('أعد إرسال الرمز'));
    expect(find.text('أرسلنا رمزًا جديدًا'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.tap(backspaceKey);
    }
    await typeDigits(tester, FakeAuthService.code);
    await tapAndWait(tester, find.text('تأكيد'));
    expect(find.byType(NameScreen), findsOneWidget);
  });

  testWidgets('Phone screen errors: no internet, number that cannot receive', (
    tester,
  ) async {
    final auth = await startApp(tester);
    await tapAndWait(tester, find.text('Français'));
    await typeDigits(tester, '98123456');

    auth.failNext = AuthFailure.noInternet;
    await tapAndWait(tester, find.text('Envoyer le code'));
    expect(
      find.text("Pas d'internet. Vérifiez la connexion et réessayez."),
      findsOneWidget,
    );
    expect(find.byType(PhoneScreen), findsOneWidget);

    // A real number while only the test numbers are set up.
    auth.cannotReceive.add('+21698123456');
    await tapAndWait(tester, find.text('Envoyer le code'));
    expect(
      find.text('Ce numéro ne peut pas encore recevoir de code.'),
      findsOneWidget,
    );

    auth.failNext = AuthFailure.tooManyTries;
    await tapAndWait(tester, find.text('Envoyer le code'));
    expect(
      find.text("Trop d'essais. Attendez une minute et réessayez."),
      findsOneWidget,
    );
    expect(find.byType(CodeScreen), findsNothing);
  });

  testWidgets('Logged in: the app opens on Home, in the saved language', (
    tester,
  ) async {
    final auth = useFakeAuth()..addUser('+21650000002', language: 'fr');
    auth.loggedIn = '+21650000002'; // the session kept on the phone
    await startApp(tester, auth: auth);

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Mohamed, vos arbres vont bien'), findsOneWidget);
    expect(appLocale.value.languageCode, 'fr');
  });

  testWidgets('Logged in but offline: a message and "try again"', (
    tester,
  ) async {
    final auth = useFakeAuth()..addUser('+21650000002', language: 'ar');
    auth
      ..loggedIn = '+21650000002'
      ..failNext = AuthFailure.noInternet;
    await startApp(tester, auth: auth);

    expect(
      find.text('لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.'),
      findsOneWidget,
    );
    await tapAndWait(tester, find.text('حاول مرة أخرى'));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Session not valid any more: back to the language screen', (
    tester,
  ) async {
    final auth = useFakeAuth()..addUser('+21650000002');
    auth
      ..loggedIn = '+21650000002'
      ..failNext = AuthFailure.sessionExpired;
    await startApp(tester, auth: auth);
    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(auth.hasSession, isFalse);
  });

  testWidgets('Profile: real name and phone, then log out', (tester) async {
    final auth = useFakeAuth()
      ..addUser(
        '+21650000002',
        firstName: 'محمد',
        lastName: 'بن سالم',
        language: 'ar',
      );
    auth.loggedIn = '+21650000002';
    await startApp(tester, auth: auth);

    await tapAndWait(tester, find.text('حسابي').last);
    expect(find.text('محمد بن سالم'), findsOneWidget);
    expect(find.text('+216 50 000 002'), findsOneWidget);
    expect(find.text('م'), findsOneWidget); // the avatar letter

    await tapAndWait(tester, find.text('تسجيل الخروج'));
    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(auth.hasSession, isFalse);
    expect(currentUser.value, isNull);

    // The app opened again: still logged out.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const LoozApp());
    await tester.pumpAndSettle();
    expect(find.byType(LanguageScreen), findsOneWidget);
  });

  testWidgets('The language switch is saved in the profile', (tester) async {
    final auth = useFakeAuth()..addUser('+21650000002', language: 'fr');
    auth.loggedIn = '+21650000002';
    await startApp(tester, auth: auth);
    expect(find.text('Bonjour'), findsOneWidget);

    await tapAndWait(tester, find.text('عربي'));
    expect(find.text('صباح الخير'), findsOneWidget);
    expect(auth.calls, contains('saveLanguage ar'));
    expect(auth.accounts['+21650000002']!.language, 'ar');
  });
}
