// LIVE test: the new start of the app against the REAL Supabase project
// (migrations 008 and 009), with the test numbers (code 123456, no SMS):
//
//   +21650000004: "تسجيل الدخول" is refused (no account yet), then the whole
//     sign-up in the app: farmer, Essential, the DEMO payment with the test
//     card that fails (4000 0000 0000 0002), then a good one: paid, 30 days.
//   +21650000005: sign-up as a farmer who chooses Connected: a request of
//     the LOOZ kit, the farmer stays on Free (Connected can't be paid
//     before the kit is installed).
//
// The card is only typed in the demo form of the app: it is never sent to
// Supabase (the test checks that no payment row holds it).
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/signup_payment_live_test.dart --dart-define-from-file=.env
//
// Run again: 04 and 05 have an account then, and the test checks "هذا
// الرقم لديه حساب بالفعل" instead (or, if 04 stopped before paying, it
// goes on with the payment). To test them as NEW users again, delete
// them in Supabase > Authentication > Users (their profile, payments user
// and kit request go with them).
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/start_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/premium/kit_requested_screen.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart'
    show
        newClient,
        printRow,
        sendCodeOnScreen,
        sendCodeWaiting,
        serverCall,
        step,
        tapAndWait,
        testCode,
        typeDigits,
        waitFor;

const phone04 = '+21650000004';
const phone05 = '+21650000005';
const _slow = Timeout(Duration(minutes: 6));

/// true = the number had no account when the test started.
final isNew = <String, bool>{};

/// Logs [phone] in with a client of its own (not the app's).
Future<SupabaseClient> logIn(String phone) async {
  final client = newClient();
  final auth = SupabaseAuthService(client);
  await sendCodeWaiting(auth, phone);
  await auth.verifyCode(phone, testCode);
  return client;
}

/// The app, on the start screen, with a new client.
Future<SupabaseClient> openApp(WidgetTester tester) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  final client = (await tester.runAsync(() async => newClient()))!;
  authService = SupabaseAuthService(client);
  paymentService = DemoPaymentService(client);
  await tester.pumpWidget(const LoozApp());
  await tester.pumpAndSettle();
  expect(find.byType(StartScreen), findsOneWidget);
  return client;
}

/// "إنشاء حساب", the number, the code: the next screen.
Future<void> signUpWithPhone(WidgetTester tester, String digits) async {
  await tapAndWait(tester, find.text('إنشاء حساب'));
  await typeDigits(tester, digits);
  await sendCodeOnScreen(tester, 'إرسال الرمز');
  await enterCode(tester);
}

Future<void> enterCode(WidgetTester tester) async {
  await typeDigits(tester, testCode);
  await tester.tap(find.text('تأكيد'));
  await waitFor(tester, [
    find.byType(RoleScreen),
    find.byType(SignUpInfoScreen),
    find.byType(AccountExistsScreen),
    find.byType(PackScreen),
    find.byType(PaymentScreen),
    find.byType(HomePage),
  ]);
  // A new account: "من أنت؟" → "فلاح" (the sign-ups of this test).
  if (find.byType(RoleScreen).evaluate().isNotEmpty) {
    step('who are you: farmer');
    await tapAndWait(tester, find.text('فلاح'));
  }
}

/// The step "معلوماتك" of a farmer.
Future<void> fillInfo(
  WidgetTester tester, {
  required String first,
  required String last,
  required String governorate,
  String? trees,
  String? area,
}) async {
  step('information');
  await tester.enterText(signUpField('الاسم'), first);
  await tester.enterText(signUpField('اللقب'), last);
  await pickGovernorate(tester, governorate);
  if (trees != null) {
    await scrollTo(tester, signUpField('عدد أشجار اللوز (اختياري)'));
    await tester.enterText(signUpField('عدد أشجار اللوز (اختياري)'), trees);
  }
  if (area != null) {
    await scrollTo(tester, signUpField('المساحة بالهكتار (اختياري)'));
    await tester.enterText(signUpField('المساحة بالهكتار (اختياري)'), area);
  }
  await scrollAndTap(tester, find.text('بعلي'));
  await scrollTo(tester, find.text('متابعة'));
  await tester.tap(find.text('متابعة'));
  await waitFor(tester, [find.byType(PackScreen)]);
  await waitFor(tester, [find.text('15 د.ت / 30 يومًا')]);
}

/// "★ تأكيد" with a card in the demo form, then the result of the server.
Future<void> payWithCard(WidgetTester tester, String number) async {
  await typeDemoCard(tester, number: number);
  final button = findTextWithSymbol('★ تأكيد');
  await scrollTo(tester, button);
  await tester.tap(button);
  await tester.pump();
  expect(find.text('جاري التحقق من الدفع…'), findsOneWidget);
  await waitFor(tester, [find.byType(PaymentResultScreen)], seconds: 60);
}

/// Days from now to [iso].
double daysTo(String iso) =>
    DateTime.parse(iso).difference(DateTime.now()).inMinutes / (60 * 24);

/// Ends a test that used the app: lets its calls finish, closes the client.
Future<void> closeTheApp(WidgetTester tester, SupabaseClient client) async {
  await serverCall(
    tester,
    'last calls of the app',
    () => Future<void>.delayed(const Duration(seconds: 2)),
  );
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
  await serverCall(tester, 'closing the client', () async {
    await client.auth.signOut();
    await client.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // Real internet (Flutter tests block it by default).
    HttpOverrides.global = null;
    expect(
      SupabaseConfig.hasKeys,
      isTrue,
      reason: 'Run with --dart-define-from-file=.env',
    );
    // Has each number an account already? ("sign in": nothing is created)
    for (final phone in [phone04, phone05]) {
      final client = newClient();
      try {
        await SupabaseAuthService(client)
            .sendCode(phone, language: 'ar', createAccount: false);
        isNew[phone] = false;
      } on AuthError catch (e) {
        isNew[phone] = e.failure == AuthFailure.noAccount;
        if (e.failure != AuthFailure.noAccount &&
            e.failure != AuthFailure.tooManyTries) {
          rethrow;
        }
      } finally {
        await client.dispose();
      }
      step(
        '$phone ${isNew[phone]! ? 'has NO account: a new user' : 'already has an account'}',
      );
    }
  });
  tearDown(resetAppState);

  testWidgets('1. $phone04: sign-up in the app, Essential, demo payment '
      'refused, then paid for 30 days', (tester) async {
    final client = await openApp(tester);

    if (isNew[phone04]!) {
      // "تسجيل الدخول" with a number that has no account: refused.
      step('sign in without account');
      await tapAndWait(tester, find.text('تسجيل الدخول'));
      await typeDigits(tester, '50000004');
      await tester.tap(find.text('إرسال الرمز'));
      await waitFor(tester, [find.text('لا يوجد حساب بهذا الرقم.')]);
      expect(find.byType(CodeScreen), findsNothing);
      // "إنشاء حساب" keeps the number.
      await tapAndWait(tester, find.text('إنشاء حساب'));
      expect(find.text('+216 50 000 004'), findsOneWidget);
      await sendCodeOnScreen(tester, 'إرسال الرمز');
      await enterCode(tester);
    } else {
      await signUpWithPhone(tester, '50000004');
    }

    if (find.byType(AccountExistsScreen).evaluate().isNotEmpty) {
      // An earlier run made the account: nothing is changed.
      step('04 already has an account: "هذا الرقم لديه حساب بالفعل"');
      expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
      await tester.tap(find.text('تسجيل الدخول'));
      await waitFor(tester, [find.byType(HomePage)]);
    } else {
      if (find.byType(PaymentScreen).evaluate().isNotEmpty) {
        // An earlier run stopped before paying: the missing step again.
        step('04 stopped before paying: back to the payment');
      }
      if (find.byType(SignUpInfoScreen).evaluate().isNotEmpty) {
        await fillInfo(
          tester,
          first: 'منير',
          last: 'الحامدي',
          governorate: 'سيدي بوزيد',
          trees: '120',
          area: '2,5',
        );
      }
      if (find.byType(PackScreen).evaluate().isNotEmpty) {
        step('pack: Essential');
        await scrollAndTap(tester, find.text('أساسي'));
        await scrollTo(tester, find.text('متابعة'));
        await tester.tap(find.text('متابعة'));
        await waitFor(tester, [find.byType(PaymentScreen)]);
      }
      expect(find.text('وضع تجريبي'), findsOneWidget);
      await waitFor(tester, [find.text('15 د.ت / 30 يومًا')]);

      step('the test card that always fails');
      await payWithCard(tester, refusedTestCard);
      expect(find.text('لم يكتمل الدفع'), findsOneWidget);
      await tapAndWait(tester, find.text('حاول مرة أخرى'));

      step('a good card');
      await payWithCard(tester, acceptedTestCard);
      expect(find.text('تم الدفع!'), findsOneWidget);
      final end = DateTime.now().add(const Duration(days: 30));
      expect(
        find.text('باقتك مفعّلة حتى ${end.day}/${end.month}/${end.year}'),
        findsOneWidget,
      );
      await tapAndWait(tester, find.text('متابعة'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tapAndWait(tester, find.text('ابدأ'));
      expect(find.byType(HomePage), findsOneWidget);
    }

    // What the database saved.
    final profile = await serverCall(
      tester,
      'profile of 04',
      () => client
          .from('profiles')
          .select(
            'first_name, last_name, role, zone, almond_trees, '
            'orchard_area_ha, irrigation, chosen_plan, payment_status',
          )
          .single(),
    );
    final payments = await serverCall(
      tester,
      'payments of 04',
      () => client
          .from('payments')
          .select()
          .order('created_at', ascending: true), // (newest first by default)
    );
    final subscription = await serverCall(
      tester,
      'subscription of 04',
      () =>
          client.from('subscriptions').select('plan, status, ends_at').single(),
    );
    final plan = await serverCall(
      tester,
      'user_plan()',
      () => client.rpc('user_plan'),
    );
    printRow('profile of $phone04:', profile);
    printRow('payments of $phone04:', {'rows': payments});
    printRow('subscription of $phone04:', {
      ...subscription,
      'user_plan()': plan,
    });

    expect(profile['role'], 'farmer');
    expect(profile['zone'], 'sidi_bouzid');
    expect(profile['payment_status'], 'paid');
    expect(profile['chosen_plan'], 'essential');
    final statuses = [for (final p in payments) p['status']];
    expect(statuses, containsAllInOrder(['failed_demo', 'paid_demo']));
    for (final p in payments) {
      expect(p['provider'], 'demo');
      expect(p['amount_millimes'], 15000);
    }
    // The card never reached the database.
    final saved = jsonEncode(payments);
    expect(saved, isNot(contains('4242')));
    expect(saved, isNot(contains('4000000000000002')));
    expect(plan, 'essential');
    expect(subscription['plan'], 'essential');
    // 30 days from the payment (also true when a later run only reads it).
    final paid = payments.lastWhere((p) => p['status'] == 'paid_demo');
    final days =
        DateTime.parse(subscription['ends_at'] as String)
            .difference(DateTime.parse(paid['paid_at'] as String))
            .inMinutes /
        (60 * 24);
    expect(days, closeTo(30, 0.01));
    expect(daysTo(subscription['ends_at'] as String), greaterThan(0)); // active
    expect(currentPlan.value, Plan.essential);

    await closeTheApp(tester, client);
  }, timeout: _slow);

  testWidgets('2. $phone05: Connected = a request of the LOOZ kit, the '
      'farmer stays on Free', (tester) async {
    final client = await openApp(tester);
    await signUpWithPhone(tester, '50000005');

    if (find.byType(AccountExistsScreen).evaluate().isNotEmpty) {
      step('05 already has an account: "هذا الرقم لديه حساب بالفعل"');
      await tester.tap(find.text('تسجيل الدخول'));
      await waitFor(tester, [find.byType(HomePage)]);
    } else {
      if (find.byType(SignUpInfoScreen).evaluate().isNotEmpty) {
        await fillInfo(
          tester,
          first: 'سنية',
          last: 'الزغلامي',
          governorate: 'القيروان',
          trees: '300',
          area: '4',
        );
      }
      step('pack: Connected');
      await waitFor(tester, [find.text('8 د.ت لكل حسّاس / 30 يومًا')]);
      await scrollAndTap(tester, find.text('متصل'));
      await scrollTo(tester, find.text('متابعة'));
      await tester.tap(find.text('متابعة'));
      await waitFor(tester, [find.byType(KitRequestedScreen)]);
      expect(
        find.text('سنتصل بك لتركيب عُدّة الحسّاسات في بستانك.'),
        findsOneWidget,
      );
      await tapAndWait(tester, find.text('متابعة'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tapAndWait(tester, find.text('ابدأ'));
      expect(find.byType(HomePage), findsOneWidget);
    }

    final kit = await serverCall(
      tester,
      'kit request of 05',
      () => client
          .from('kit_requests')
          .select(
            'phone, governorate, almond_trees, orchard_area_ha, status, sensors',
          )
          .order('created_at', ascending: false)
          .limit(1)
          .single(),
    );
    final profile = await serverCall(
      tester,
      'profile of 05',
      () => client
          .from('profiles')
          .select('chosen_plan, payment_status, plan_chosen_at')
          .single(),
    );
    final plan = await serverCall(
      tester,
      'user_plan()',
      () => client.rpc('user_plan'),
    );
    printRow('kit request of $phone05:', kit);
    printRow('profile of $phone05:', {...profile, 'user_plan()': plan});
    expect(kit['phone'], phone05); // copied by the database
    expect(kit['governorate'], 'kairouan');
    expect(kit['almond_trees'], 300);
    expect(kit['status'], 'new');
    expect(kit['sensors'], isNull);
    expect(profile['chosen_plan'], 'free');
    expect(profile['plan_chosen_at'], isNotNull);
    expect(plan, 'free');

    // Connected can't be paid before the kit is installed.
    final refused = await serverCall(tester, 'paying Connected (05)', () async {
      try {
        await DemoPaymentService(client)
            .pay(Plan.connected, cardAccepted: true);
        return null;
      } on PaymentError catch (e) {
        return e.failure;
      }
    });
    expect(refused, PaymentFailure.kitNotInstalled);

    await closeTheApp(tester, client);
  }, timeout: _slow);

  test('3. The rules of the real database (as 04)', () async {
    final client = await logIn(phone04);
    final me = client.auth.currentUser!.id;
    final results = <String, Object?>{};

    // Demo payments: on, and a farmer can't turn them off.
    final off = await client
        .from('app_settings')
        .update({'demo_payments_enabled': false})
        .eq('id', true)
        .select();
    final settings = await client.from('app_settings').select().single();
    results['turn demo payments off (rows changed)'] = off.length;
    expect(off, isEmpty);
    expect(settings['demo_payments_enabled'], isTrue);

    // Prices: read, never changed.
    final prices = await client
        .from('plan_prices')
        .select('plan, price_millimes, per_sensor');
    final cheaper = await client
        .from('plan_prices')
        .update({'price_millimes': 1000})
        .eq('plan', 'essential')
        .select();
    results['prices'] = prices;
    results['change a price (rows changed)'] = cheaper.length;
    expect(cheaper, isEmpty);

    Future<String?> codeOf(Future<Object?> Function() call) async {
      try {
        await call();
        return null;
      } on PostgrestException catch (e) {
        return e.code;
      }
    }

    results['insert a "paid" payment'] = await codeOf(
      () => client.from('payments').insert({
        'user_id': me,
        'plan': 'connected',
        'amount_millimes': 1,
        'period_days': 365,
        'status': 'paid_demo',
      }),
    );
    results['activate_pack() (give himself a pack)'] = await codeOf(
      () => client.rpc(
        'activate_pack',
        params: {'p_user': me, 'p_plan': 'connected', 'p_days': 365},
      ),
    );
    results['confirm_payment()'] = await codeOf(
      () =>
          client.rpc('confirm_payment', params: {'p_ref': 'x', 'p_amount': 1}),
    );
    results['write a kit request himself'] = await codeOf(
      () => client.from('kit_requests').insert({
        'user_id': me,
        'status': 'installed',
        'sensors': 50,
      }),
    );
    results['become expert after the sign-up'] = await codeOf(
      () => client.rpc('choose_role', params: {'p_role': 'expert'}),
    );
    results['demo payment of "free"'] = await codeOf(
      () => client.rpc('demo_payment', params: {'p_plan': 'free'}),
    );
    final others = await client
        .from('payments')
        .select('id')
        .neq('user_id', me);
    results["payments of others visible"] = others.length;
    printRow('Refused (as they should be):', results);

    expect(results['insert a "paid" payment'], isNotNull);
    expect(results['activate_pack() (give himself a pack)'], '42501');
    expect(results['confirm_payment()'], '42501');
    expect(results['write a kit request himself'], isNotNull);
    expect(results['become expert after the sign-up'], '42501');
    expect(results['demo payment of "free"'], '22023');
    expect(others, isEmpty);

    await client.auth.signOut();
    await client.dispose();
  }, timeout: _slow);

  testWidgets('4. $phone04 signs in again: Home and its pack; sign up with it: '
      '"already has an account"', (tester) async {
    final client = await openApp(tester);
    step('sign in');
    await tapAndWait(tester, find.text('تسجيل الدخول'));
    await typeDigits(tester, '50000004');
    await sendCodeOnScreen(tester, 'إرسال الرمز');
    await enterCode(tester);
    expect(find.byType(HomePage), findsOneWidget);

    step('Profile: my pack');
    await tapAndWait(tester, find.text('حسابي').last);
    await waitFor(tester, [find.textContaining('أساسي · حتى')]);

    step('log out, then "إنشاء حساب" with the same number');
    await tester.tap(find.text('تسجيل الخروج'));
    await waitFor(tester, [find.byType(StartScreen)]);
    await signUpWithPhone(tester, '50000004');
    expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
    await tester.tap(find.text('تسجيل الدخول'));
    await waitFor(tester, [find.byType(HomePage)]);
    expect(currentUser.value?.phone, phone04);

    await closeTheApp(tester, client);
  }, timeout: _slow);
}
