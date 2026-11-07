// The start of the app: the start screen, sign in, sign up (farmer: Free,
// Essential with the DEMO payment, Connected = a kit request; expert),
// stopped in the middle, Premium and Profile. With a fake login and fake
// packs (test/fake_auth_service.dart, test/fake_payment_service.dart:
// every code is 123456, no internet). Against the real Supabase:
// test_live/signup_payment_live_test.dart.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/start_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/premium/demo_card_form.dart';
import 'package:looz_mobile/features/premium/kit_requested_screen.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/features/premium/qr_screen.dart';
import 'package:looz_mobile/shared/widgets/looz_tab_bar.dart';
import 'package:looz_mobile/shared/widgets/symbol_text.dart';

import 'fake_auth_service.dart';
import 'fake_payment_service.dart';
import 'test_helpers.dart';

final ar = lookupAppLocalizations(const Locale('ar'));
final fr = lookupAppLocalizations(const Locale('fr'));

/// Starts the app like on a phone (the first screen decides where to go).
Future<(FakeAuthService, FakePaymentService)> startApp(
  WidgetTester tester, {
  FakeAuthService? auth,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  final login = auth ?? useFakeAuth();
  authService = login;
  final payments = usePayments(login);
  await tester.pumpWidget(const LoozApp());
  await tester.pumpAndSettle();
  return (login, payments);
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

/// The texts in the language shown now.
AppLocalizations lookup() => lookupAppLocalizations(appLocale.value);

/// From the start screen: "إنشاء حساب" or "تسجيل الدخول", the number, the code.
Future<void> logIn(
  WidgetTester tester, {
  required bool signUp,
  required String digits,
  String code = FakeAuthService.code,
}) async {
  expect(find.byType(StartScreen), findsOneWidget);
  await tapAndWait(
    tester,
    find.text(signUp ? lookup().createAccount : lookup().signIn),
  );
  expect(find.byType(PhoneScreen), findsOneWidget);
  await typeDigits(tester, digits);
  await tapAndWait(tester, find.text(lookup().sendCode));
  expect(find.byType(CodeScreen), findsOneWidget);
  await typeDigits(tester, code);
  await tapAndWait(tester, find.text(lookup().confirm));
}

/// Chooses farmer or expert on "من أنت؟" (if shown), fills "معلوماتك" and
/// taps "متابعة".
Future<void> fillInfo(
  WidgetTester tester, {
  String first = 'محمد',
  String last = 'بن سالم',
  String governorate = 'سيدي بوزيد',
  bool expert = false,
  String? organisation,
  String? trees,
  String? area,
  String? irrigation,
}) async {
  final l10n = lookup();
  if (find.byType(RoleScreen).evaluate().isNotEmpty) {
    await tapAndWait(
      tester,
      find.text(expert ? l10n.roleExpert : l10n.roleFarmer),
    );
  }
  expect(find.byType(SignUpInfoScreen), findsOneWidget);
  await tester.enterText(signUpField(l10n.firstName), first);
  await tester.enterText(signUpField(l10n.lastName), last);
  await pickGovernorate(tester, governorate);
  if (organisation != null) {
    await scrollTo(tester, signUpField(l10n.organisationOptional));
    await tester.enterText(
      signUpField(l10n.organisationOptional),
      organisation,
    );
  }
  if (trees != null) {
    await scrollTo(tester, signUpField(l10n.almondTreesOptional));
    await tester.enterText(signUpField(l10n.almondTreesOptional), trees);
  }
  if (area != null) {
    await scrollTo(tester, signUpField(l10n.areaOptional));
    await tester.enterText(signUpField(l10n.areaOptional), area);
  }
  if (irrigation != null) await scrollAndTap(tester, find.text(irrigation));
  await scrollAndTap(tester, find.text(l10n.continueLabel));
}

/// What the card boxes hold now (also on a screen under another one).
List<String> cardTexts(WidgetTester tester) => [
  for (final box
      in find
          .descendant(
            of: find.byType(DemoCardForm, skipOffstage: false),
            matching: find.byType(TextField, skipOffstage: false),
          )
          .evaluate())
    (box.widget as TextField).controller!.text,
];

String inDays(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.day}/${d.month}/${d.year}';
}

void main() {
  setUpAll(loadAppFonts);
  setUp(resetAppState);
  tearDown(resetAppState);

  group('start screen', () {
    testWidgets('Arabic: photo, "عربي | FR", the two big buttons', (
      tester,
    ) async {
      await startApp(tester);
      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.text('أهلًا بك في لوز'), findsOneWidget);
      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('عربي'), findsOneWidget);
      expect(find.text('FR'), findsOneWidget);
      // "إنشاء حساب" first, then "تسجيل الدخول".
      expect(
        tester.getTopLeft(find.text('إنشاء حساب')).dy <
            tester.getTopLeft(find.text('تسجيل الدخول')).dy,
        isTrue,
      );
    });

    testWidgets('FR: the app in French, remembered at the next start', (
      tester,
    ) async {
      await startApp(tester);
      await tapAndWait(tester, find.text('FR'));
      expect(find.text('Créer un compte'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('language'), 'fr');

      // The app closed and opened again: still French.
      appLocale.value = const Locale('ar');
      await tester.pumpWidget(const SizedBox());
      await loadSavedLanguage();
      await tester.pumpWidget(const LoozApp());
      await tester.pumpAndSettle();
      expect(find.text('Créer un compte'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('An existing farmer: phone, code, Home (nothing else asked)', (
      tester,
    ) async {
      final auth = useFakeAuth()
        ..addUser(
          '+21650000002',
          language: 'fr',
          chosenPlan: Plan.essential,
          paymentStatus: PaymentStatus.paid,
        )
        ..plans['+21650000002'] = Plan.essential; // paid
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: false, digits: '50000002');
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Mohamed، أشجارك بخير اليوم'), findsOneWidget);
      expect(auth.calls.first, 'sendCode +21650000002 sign in');
      expect(auth.calls.where((c) => c.startsWith('saveSignUpInfo')), isEmpty);
      expect(auth.calls.where((c) => c.startsWith('choosePlan')), isEmpty);
      expect(auth.calls, contains('saveLanguage ar'));
      expect(currentPlan.value, Plan.essential);
    });

    testWidgets('A number without account: a message, nothing created, '
        '"إنشاء حساب" keeps the number', (tester) async {
      final (auth, _) = await startApp(tester);
      await tapAndWait(tester, find.text('تسجيل الدخول'));
      await typeDigits(tester, '50000009');
      await tapAndWait(tester, find.text(ar.sendCode));
      expect(find.text('لا يوجد حساب بهذا الرقم.'), findsOneWidget);
      expect(find.byType(CodeScreen), findsNothing);
      expect(auth.accounts, isEmpty); // not created

      await tapAndWait(tester, find.text('إنشاء حساب'));
      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(find.text('+216 50 000 009'), findsOneWidget); // kept
      await tapAndWait(tester, find.text(ar.sendCode));
      expect(auth.calls.last, 'sendCode +21650000009 sign up');
      await typeDigits(tester, FakeAuthService.code);
      await tapAndWait(tester, find.text(ar.confirm));
      expect(find.byType(RoleScreen), findsOneWidget);
    });

    testWidgets('Wrong code: a message, then the right code works', (
      tester,
    ) async {
      final (auth, _) = await startApp(tester);
      auth.addUser('+21650000002', language: 'ar');
      await logIn(tester, signUp: false, digits: '50000002', code: '111111');
      expect(find.byType(CodeScreen), findsOneWidget);
      expect(find.text('الرمز غير صحيح أو انتهت صلاحيته.'), findsOneWidget);
      await tapAndWait(tester, find.text('أعد إرسال الرمز'));
      expect(find.text('أرسلنا رمزًا جديدًا'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(
          find.byWidgetPredicate((w) => w is SymbolText && w.text == '⌫'),
        );
      }
      await typeDigits(tester, FakeAuthService.code);
      await tapAndWait(tester, find.text('تأكيد'));
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets(
      'Phone screen errors: no internet, a number that cannot receive',
      (tester) async {
        final (auth, _) = await startApp(tester);
        await tapAndWait(tester, find.text('FR'));
        await tapAndWait(tester, find.text('Créer un compte'));
        await typeDigits(tester, '98123456');
        auth.failNext = AuthFailure.noInternet;
        await tapAndWait(tester, find.text('Envoyer le code'));
        expect(
          find.text("Pas d'internet. Vérifiez la connexion et réessayez."),
          findsOneWidget,
        );
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
      },
    );
  });

  group('sign up', () {
    testWidgets('Farmer, Free (Arabic): information, pack, welcome, Home', (
      tester,
    ) async {
      final (auth, payments) = await startApp(tester);
      await logIn(tester, signUp: true, digits: '50000004');
      expect(auth.calls.first, 'sendCode +21650000004 sign up');

      // "من أنت؟" on its own screen: two big buttons.
      expect(find.byType(RoleScreen), findsOneWidget);
      expect(find.text('من أنت؟'), findsOneWidget);
      expect(find.text('فلاح'), findsOneWidget);
      expect(find.text('عندي بستان لوز'), findsOneWidget);
      expect(find.text('مهندس فلاحي أو مرشد'), findsOneWidget);
      expect(find.text('أنصح الفلاحين في المجتمع'), findsOneWidget);
      expect(find.text('معلوماتك'), findsNothing);
      await tapAndWait(tester, find.text('فلاح'));

      // "معلوماتك": no role question any more, then the required boxes.
      expect(find.text('معلوماتك'), findsOneWidget);
      expect(find.text('مهندس فلاحي أو مرشد'), findsNothing);
      await scrollAndTap(tester, find.text('متابعة'));
      expect(find.text('هذه الخانة مطلوبة'), findsNWidgets(3));
      expect(find.byType(SignUpInfoScreen), findsOneWidget);

      // Wrong numbers are refused (an empty optional box is fine).
      await fillInfo(tester, trees: '0', area: 'abc');
      expect(
        find.text('اكتب رقمًا صحيحًا'),
        findsOneWidget,
      ); // trees (area: letters cannot be typed)
      await scrollTo(tester, signUpField(ar.almondTreesOptional));
      // An Arabic keyboard: "١٢٠" = 120; area "2,5" = 2.5.
      await tester.enterText(signUpField(ar.almondTreesOptional), '١٢٠');
      await tester.enterText(signUpField(ar.areaOptional), '2,5');
      await scrollAndTap(tester, find.text('بعلي'));
      await scrollAndTap(tester, find.text('متابعة'));

      // The packs, with the prices of the database.
      expect(find.byType(PackScreen), findsOneWidget);
      expect(find.text('اختر باقتك'), findsOneWidget);
      expect(find.text('15 د.ت / 30 يومًا'), findsOneWidget);
      expect(find.text('8 د.ت لكل حسّاس / 30 يومًا'), findsOneWidget);
      expect(find.text('مع عُدّة حسّاسات لوز (نركّبها لك)'), findsOneWidget);
      await scrollAndTap(tester, find.text('متابعة')); // nothing chosen
      expect(find.byType(PackScreen), findsOneWidget);
      await scrollAndTap(tester, find.text('مجاني'));
      await scrollAndTap(tester, find.text('متابعة'));

      expect(find.text('مرحبًا يا محمد'), findsOneWidget);
      expect(find.text(ar.expertPendingNote), findsNothing);
      await tapAndWait(tester, find.text('ابدأ'));
      expect(find.byType(HomePage), findsOneWidget);

      final saved = auth.accounts['+21650000004']!;
      expect(saved.fullName, 'محمد بن سالم');
      expect(saved.role, UserRole.farmer);
      expect(saved.governorate, 'sidi_bouzid');
      expect(saved.almondTrees, 120);
      expect(saved.orchardAreaHa, 2.5);
      expect(saved.irrigation, Irrigation.rainfed);
      expect(saved.chosenPlan, Plan.free);
      expect(saved.hasChosenPlan, isTrue);
      expect(currentPlan.value, Plan.free);
      expect(payments.calls.where((c) => c.startsWith('pay')), isEmpty);
    });

    testWidgets(
      'Essential: the demo payment, "جاري التحقق…", paid for 30 days',
      (tester) async {
        final (auth, payments) = await startApp(tester);
        await logIn(tester, signUp: true, digits: '50000004');
        await fillInfo(tester);
        await scrollAndTap(tester, find.text('أساسي'));
        await scrollAndTap(tester, find.text('متابعة'));
        // Saved as "pending" first (if the app closes, the payment comes back).
        expect(
          auth.accounts['+21650000004']!.paymentStatus,
          PaymentStatus.pending,
        );

        // The design's payment screen, with the small "وضع تجريبي".
        expect(find.byType(PaymentScreen), findsOneWidget);
        expect(
          find.byType(LoozTabBar),
          findsNothing,
        ); // the app is not open yet
        expect(find.text('وضع تجريبي'), findsOneWidget);
        expect(find.text('الدفع'), findsOneWidget);
        expect(find.text('15 د.ت / 30 يومًا'), findsOneWidget);

        // Empty or wrong card: what is wrong, nothing paid.
        await confirmDemoPayment(tester, checking: false);
        expect(find.text('16 رقمًا'), findsOneWidget);
        expect(find.text('تاريخ غير صحيح (شهر/سنة)'), findsOneWidget);
        expect(find.text('3 أرقام'), findsOneWidget);
        expect(find.text('هذه الخانة مطلوبة'), findsOneWidget);
        await typeDemoCard(
          tester,
          number: '4242 4242',
          expiry: '1320',
          code: '12',
        );
        await confirmDemoPayment(tester, checking: false);
        expect(find.text('16 رقمًا'), findsOneWidget);
        expect(find.text('تاريخ غير صحيح (شهر/سنة)'), findsOneWidget);
        expect(payments.calls.where((c) => c.startsWith('pay')), isEmpty);

        // A good card: grouped by 4, then paid.
        await typeDemoCard(tester);
        expect(find.text('4242 4242 4242 4242'), findsOneWidget);
        expect(find.text('12/30'), findsOneWidget);
        await confirmDemoPayment(tester);
        expect(find.byType(PaymentResultScreen), findsOneWidget);
        expect(find.text('تم الدفع!'), findsOneWidget);
        expect(find.text('باقتك مفعّلة حتى ${inDays(30)}'), findsOneWidget);

        // The card was forgotten, and only "accepted" left the form.
        expect(cardTexts(tester).every((t) => t.isEmpty), isTrue);
        expect(payments.calls.where((c) => c.startsWith('pay')), [
          'pay essential accepted',
        ]);
        expect(payments.calls.join(' '), isNot(contains('4242')));

        await tapAndWait(tester, find.text('متابعة'));
        expect(find.byType(WelcomeScreen), findsOneWidget);
        await tapAndWait(tester, find.text('ابدأ'));
        expect(find.byType(HomePage), findsOneWidget);
        expect(currentPlan.value, Plan.essential);
        expect(
          auth.accounts['+21650000004']!.paymentStatus,
          PaymentStatus.paid,
        );
      },
    );

    testWidgets('The test card 4000 0000 0000 0002: not paid, try again, '
        'then continue free', (tester) async {
      final (auth, payments) = await startApp(tester);
      await logIn(tester, signUp: true, digits: '50000004');
      await fillInfo(tester);
      await scrollAndTap(tester, find.text('أساسي'));
      await scrollAndTap(tester, find.text('متابعة'));
      await typeDemoCard(tester, number: refusedTestCard);
      await confirmDemoPayment(tester);
      expect(find.text('لم يكتمل الدفع'), findsOneWidget);
      expect(
        find.text('ستبقى على الخطة المجانية، ويمكنك الدفع لاحقًا من «حسابي».'),
        findsOneWidget,
      );

      // Try again: the payment screen, with an empty card.
      await tapAndWait(tester, find.text('حاول مرة أخرى'));
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(cardTexts(tester).every((t) => t.isEmpty), isTrue);
      await typeDemoCard(tester, number: refusedTestCard);
      await confirmDemoPayment(tester);
      await tapAndWait(tester, find.text('متابعة مجانًا'));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(payments.calls.where((c) => c.startsWith('pay')), [
        'pay essential refused',
        'pay essential refused',
      ]);
      final saved = auth.accounts['+21650000004']!;
      expect(saved.chosenPlan, Plan.free);
      expect(saved.paymentStatus, PaymentStatus.free);
      expect(currentPlan.value, Plan.free);
    });

    testWidgets('Demo payments turned off by an admin: a clear message', (
      tester,
    ) async {
      final (_, payments) = await startApp(tester);
      payments.demoOff = true;
      await logIn(tester, signUp: true, digits: '50000004');
      await fillInfo(tester);
      await scrollAndTap(tester, find.text('أساسي'));
      await scrollAndTap(tester, find.text('متابعة'));
      await typeDemoCard(tester);
      await confirmDemoPayment(tester);
      expect(find.text('لم يكتمل الدفع'), findsOneWidget);
      expect(find.text('الدفع غير متاح الآن.'), findsOneWidget);
      expect(currentPlan.value, Plan.free);
    });

    testWidgets('Connected: the LOOZ kit is asked, the farmer stays on Free', (
      tester,
    ) async {
      final (auth, payments) = await startApp(tester);
      await logIn(tester, signUp: true, digits: '50000005');
      await fillInfo(tester, governorate: 'القيروان', trees: '300');
      await scrollAndTap(tester, find.text('متصل'));
      await scrollAndTap(tester, find.text('متابعة'));

      expect(find.byType(KitRequestedScreen), findsOneWidget);
      expect(find.text('عُدّة لوز'), findsOneWidget);
      expect(
        find.text('سنتصل بك لتركيب عُدّة الحسّاسات في بستانك.'),
        findsOneWidget,
      );
      expect(
        find.text('حتى ذلك الوقت، تستعمل الباقة المجانية.'),
        findsOneWidget,
      );
      await tapAndWait(tester, find.text('متابعة'));
      expect(find.byType(WelcomeScreen), findsOneWidget);

      expect(payments.kit?.status, KitStatus.requested);
      expect(payments.calls.where((c) => c.startsWith('pay')), isEmpty);
      expect(auth.accounts['+21650000005']!.chosenPlan, Plan.free);
      expect(auth.accounts['+21650000005']!.hasChosenPlan, isTrue);
      expect(currentPlan.value, Plan.free);
    });

    testWidgets(
      'Expert: only name, governorate and organisation; no pack, no payment; '
      'welcome says the badge comes later',
      (tester) async {
        final (auth, payments) = await startApp(tester);
        await logIn(tester, signUp: true, digits: '50000004');
        await tapAndWait(tester, find.text(ar.roleFarmer));
        expect(find.text(ar.organisationOptional), findsNothing); // farmers

        // A farmer has the 3 orchard boxes: some are filled, then the
        // phone's "back" to "من أنت؟", and "expert".
        await scrollTo(tester, find.text(ar.almondTreesOptional));
        await tester.enterText(signUpField(ar.almondTreesOptional), '50');
        await scrollAndTap(tester, find.text(ar.rainfed));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(RoleScreen), findsOneWidget);
        await tapAndWait(tester, find.text(ar.roleExpert));

        // An expert: no orchard boxes, the organisation instead (checked at
        // the bottom of the list: everything below the name is built).
        await scrollTo(tester, find.text(ar.continueLabel));
        expect(find.text(ar.almondTreesOptional), findsNothing);
        expect(find.text(ar.areaOptional), findsNothing);
        expect(find.text(ar.irrigationOptional), findsNothing);
        expect(find.text(ar.rainfed), findsNothing);
        expect(find.text(ar.organisationOptional), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle(); // back to the top
        await fillInfo(
          tester,
          first: 'سامي',
          last: 'الدريدي',
          organisation: 'المندوبية الجهوية للفلاحة',
        );
        expect(find.byType(PackScreen), findsNothing);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.text('مرحبًا يا سامي'), findsOneWidget);
        expect(
          findTextWithSymbol(
            'ستظهر شارة «◆ خبير موثّق» بعد أن نتحقق من حسابك.',
          ),
          findsOneWidget,
        );
        final saved = auth.accounts['+21650000004']!;
        expect(saved.role, UserRole.expert);
        expect(saved.verified, isFalse); // only an admin checks him
        expect(saved.organisation, 'المندوبية الجهوية للفلاحة');
        // What was typed as a farmer is not saved for an expert.
        expect(saved.almondTrees, isNull);
        expect(saved.orchardAreaHa, isNull);
        expect(saved.irrigation, isNull);
        expect(saved.chosenPlan, Plan.free);
        expect(saved.hasChosenPlan, isTrue);
        expect(payments.calls, isNot(contains(startsWith('pay'))));
        await tapAndWait(tester, find.text('ابدأ'));
        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets('A number that already has an account: nothing changed, '
        '"تسجيل الدخول" → Home', (tester) async {
      final auth = useFakeAuth()..addUser('+21650000002', language: 'ar');
      final before = auth.accounts['+21650000002'];
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: true, digits: '50000002');
      expect(find.text('مرحبًا من جديد'), findsOneWidget);
      expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
      await tapAndWait(tester, find.text('تسجيل الدخول'));
      expect(find.byType(HomePage), findsOneWidget);
      expect(auth.calls.where((c) => c.startsWith('saveSignUpInfo')), isEmpty);
      expect(auth.calls.where((c) => c.startsWith('choosePlan')), isEmpty);
      expect(auth.accounts['+21650000002']!.fullName, before!.fullName);
    });

    testWidgets('French: the information, the packs and the payment', (
      tester,
    ) async {
      await startApp(tester);
      await tapAndWait(tester, find.text('FR'));
      await logIn(tester, signUp: true, digits: '50000004');
      expect(find.text('Qui êtes-vous ?'), findsOneWidget);
      expect(find.text('Choisissez ce qui vous correspond'), findsOneWidget);
      expect(find.text('Agriculteur'), findsOneWidget);
      expect(find.text("J'ai un verger d'amandiers"), findsOneWidget);
      expect(find.text('Agronome ou conseiller'), findsOneWidget);
      expect(find.text('Je conseille les agriculteurs'), findsOneWidget);
      await tapAndWait(tester, find.text('Agriculteur'));
      expect(find.text('Vos informations'), findsOneWidget);
      await scrollTo(tester, find.text("Nombre d'amandiers (facultatif)"));
      expect(find.text("Nombre d'amandiers (facultatif)"), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await fillInfo(
        tester,
        first: 'Amine',
        last: "Ben-Ali M'barek",
        governorate: 'Sfax',
        area: '1.25',
      );
      expect(find.text('15 DT / 30 jours'), findsOneWidget);
      expect(find.text('8 DT par capteur / 30 jours'), findsOneWidget);
      await scrollAndTap(tester, find.text('Essentiel'));
      await scrollAndTap(tester, find.text('Continuer'));
      expect(find.text('Mode démo'), findsOneWidget);
      expect(find.text('Paiement'), findsOneWidget);
      await typeDemoCard(tester, name: 'Amine Ben Ali');
      await confirmDemoPayment(tester);
      expect(find.text('Paiement reçu !'), findsOneWidget);
      expect(
        find.text("Votre pack est actif jusqu'au ${inDays(30)}"),
        findsOneWidget,
      );
      final page = tester.element(find.byType(PaymentResultScreen));
      expect(Directionality.of(page), TextDirection.ltr);
    });
  });

  group('stopped in the middle: the missing step', () {
    testWidgets('No information yet → "من أنت؟"', (tester) async {
      final auth = useFakeAuth()
        ..addUser(
          '+21650000004',
          firstName: null,
          lastName: null,
          governorate: null,
          language: 'ar',
          finished: false,
        );
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: false, digits: '50000004');
      expect(find.byType(RoleScreen), findsOneWidget);
    });

    testWidgets('An expert with his information, stopped before the end → '
        'his information again (no packs)', (tester) async {
      final auth = useFakeAuth()
        ..addUser(
          '+21650000004',
          language: 'ar',
          role: UserRole.expert,
          finished: false,
        );
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: false, digits: '50000004');
      expect(find.byType(SignUpInfoScreen), findsOneWidget);
      expect(find.text(ar.organisationOptional), findsOneWidget);
      expect(find.byType(PackScreen), findsNothing);
      await scrollAndTap(tester, find.text(ar.continueLabel));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(auth.calls, contains('choosePlan free'));
    });

    testWidgets('Information saved, no pack → the packs', (tester) async {
      final auth = useFakeAuth()
        ..addUser('+21650000004', language: 'ar', finished: false);
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: true, digits: '50000004');
      expect(find.byType(PackScreen), findsOneWidget);
    });

    testWidgets('Essential chosen, not paid → the payment (back = the packs)', (
      tester,
    ) async {
      final auth = useFakeAuth()
        ..addUser('+21650000004', language: 'ar', chosenPlan: Plan.essential);
      auth.loggedIn = '+21650000004'; // the app opens with the session
      await startApp(tester, auth: auth);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('وضع تجريبي'), findsOneWidget);
      await tester.binding.handlePopRoute(); // the phone's "back"
      await tester.pumpAndSettle();
      expect(find.byType(PackScreen), findsOneWidget);
    });

    testWidgets('Essential not paid, "إنشاء حساب" again → the payment '
        '(not "already has an account")', (tester) async {
      final auth = useFakeAuth()
        ..addUser('+21650000004', language: 'ar', chosenPlan: Plan.essential);
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: true, digits: '50000004');
      expect(find.byType(AccountExistsScreen), findsNothing);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(auth.calls.where((c) => c.startsWith('choosePlan')), isEmpty);
    });
  });

  group('after the sign-up', () {
    testWidgets('Premium → Connected once the kit is installed: 8 DT x 5 '
        'sensors, paid, then the QR screen', (tester) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      logInTestUser();
      final auth = authService as FakeAuthService;
      final payments = usePayments(auth)..installKit(5);
      await tester.pumpWidget(const LoozApp(home: PremiumScreen()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('15 د.ت'),
        findsOneWidget,
      ); // the smallest pack
      await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));

      // Only the paid packs; Connected = 8 x 5 sensors.
      expect(find.byType(PackScreen), findsOneWidget);
      expect(find.text('مجاني'), findsNothing);
      expect(find.text('40 د.ت / 30 يومًا'), findsOneWidget);
      expect(find.text('5 حسّاسات'), findsOneWidget);
      await scrollAndTap(tester, find.text('متصل'));
      await scrollAndTap(tester, find.text('متابعة'));

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('40 د.ت / 30 يومًا'), findsOneWidget);
      expect(find.text('5 حسّاسات'), findsOneWidget); // why 40
      await typeDemoCard(tester);
      await confirmDemoPayment(tester);
      expect(find.text('تم الدفع!'), findsOneWidget);
      expect(payments.calls, contains('pay connected accepted'));
      expect(currentPlan.value, Plan.connected);
      await tapAndWait(tester, find.text('متابعة'));
      expect(find.byType(QrScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('Premium → Connected without a kit: the kit is asked', (
      tester,
    ) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      logInTestUser();
      final payments = usePayments(authService as FakeAuthService);
      await tester.pumpWidget(const LoozApp(home: PremiumScreen()));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));
      await scrollAndTap(tester, find.text('متصل'));
      await scrollAndTap(tester, find.text('متابعة'));
      expect(find.byType(KitRequestedScreen), findsOneWidget);
      expect(payments.kit?.status, KitStatus.requested);
      expect(payments.calls, isNot(contains(startsWith('pay'))));
      await closeApp(tester);
    });

    testWidgets('Profile: my pack and until when', (tester) async {
      usePhoneScreen(tester);
      logInTestUser();
      final payments = usePayments(authService as FakeAuthService)
        ..activePack = ActivePack(
          plan: Plan.essential,
          endsAt: DateTime.now().add(const Duration(days: 12)),
        );
      currentTab.value = AppTab.profile;
      await tester.pumpWidget(const LoozApp(home: MainShell()));
      await tester.pumpAndSettle();
      expect(find.text('أساسي · حتى ${inDays(12)}'), findsOneWidget);
      payments.activePack = null;
      await closeApp(tester);
    });
  });

  group('demo login (any number, any code, no SMS)', () {
    testWidgets('A number that never existed and ANY code: every step of the '
        'sign-up (who are you, information, pack, payment, welcome), Home', (
      tester,
    ) async {
      final auth = useFakeAuth()..demoLogin = true;
      final (_, payments) = await startApp(tester, auth: auth);
      await tapAndWait(tester, find.text(ar.createAccount));
      await typeDigits(tester, '22123456');
      await tapAndWait(tester, find.text(ar.sendCode));
      expect(find.byType(CodeScreen), findsOneWidget);
      expect(auth.accounts, isEmpty); // made only with the code
      await typeDigits(tester, '987654'); // not 123456: any 6 digits
      await tapAndWait(tester, find.text(ar.confirm));
      expect(auth.calls.take(2), [
        'sendCode +21622123456 sign up',
        'verifyCode +21622123456',
      ]);

      expect(find.byType(RoleScreen), findsOneWidget);
      await fillInfo(tester, trees: '120', irrigation: ar.irrigated);
      expect(find.byType(PackScreen), findsOneWidget);
      await scrollAndTap(tester, find.text(ar.planEssential));
      await scrollAndTap(tester, find.text(ar.continueLabel));
      expect(find.byType(PaymentScreen), findsOneWidget);
      await typeDemoCard(tester);
      await confirmDemoPayment(tester);
      expect(find.text(ar.paidTitle), findsOneWidget);
      await tapAndWait(tester, find.text(ar.continueLabel));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tapAndWait(tester, find.text(ar.start));
      expect(find.byType(HomePage), findsOneWidget);

      final saved = auth.accounts['+21622123456']!;
      expect(saved.fullName, 'محمد بن سالم');
      expect(saved.role, UserRole.farmer);
      expect(saved.almondTrees, 120);
      expect(saved.chosenPlan, Plan.essential);
      expect(payments.calls, contains('pay essential accepted'));
    });

    testWidgets('Sign in with ANY code: Home', (tester) async {
      final auth = useFakeAuth()
        ..demoLogin = true
        ..addUser('+21650000002', language: 'ar');
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: false, digits: '50000002', code: '000000');
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Sign in with a number without account: the message and '
        '"إنشاء حساب" (nothing created)', (tester) async {
      final auth = useFakeAuth()..demoLogin = true;
      await startApp(tester, auth: auth);
      await tapAndWait(tester, find.text(ar.signIn));
      await typeDigits(tester, '22123457');
      await tapAndWait(tester, find.text(ar.sendCode));
      expect(find.text('لا يوجد حساب بهذا الرقم.'), findsOneWidget);
      expect(find.byType(CodeScreen), findsNothing);
      expect(auth.accounts, isEmpty);
      await tapAndWait(tester, find.text(ar.createAccount));
      expect(find.text('+216 22 123 457'), findsOneWidget); // kept
    });

    testWidgets('Sign up with a finished account and ANY code: "already has '
        'an account" + "تسجيل الدخول", nothing changed', (tester) async {
      final auth = useFakeAuth()
        ..demoLogin = true
        ..addUser('+21650000002', language: 'ar');
      final before = auth.accounts['+21650000002']!.fullName;
      await startApp(tester, auth: auth);
      await logIn(tester, signUp: true, digits: '50000002', code: '111111');
      expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
      await tapAndWait(tester, find.text(ar.signIn));
      expect(find.byType(HomePage), findsOneWidget);
      expect(auth.accounts['+21650000002']!.fullName, before);
      expect(auth.calls.where((c) => c.startsWith('saveSignUpInfo')), isEmpty);
    });
  });

  group('the session', () {
    testWidgets('Logged in: the app opens on Home, in the saved language', (
      tester,
    ) async {
      final auth = useFakeAuth()..addUser('+21650000002', language: 'fr');
      auth.loggedIn = '+21650000002';
      await startApp(tester, auth: auth);
      expect(find.byType(StartScreen), findsNothing);
      expect(find.text('Bonjour'), findsOneWidget);
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

    testWidgets('Session not valid any more: back to the start screen', (
      tester,
    ) async {
      final auth = useFakeAuth()..addUser('+21650000002');
      auth
        ..loggedIn = '+21650000002'
        ..failNext = AuthFailure.sessionExpired;
      await startApp(tester, auth: auth);
      expect(find.byType(StartScreen), findsOneWidget);
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
      expect(find.byType(StartScreen), findsOneWidget);
      expect(auth.hasSession, isFalse);
      expect(currentUser.value, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const LoozApp());
      await tester.pumpAndSettle();
      expect(find.byType(StartScreen), findsOneWidget);
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
  });
}
