// LIVE test: the start of the app and the TWO packs against the REAL
// Supabase project (migration 011), with the test numbers (code 123456):
//
//   +21650000004: paid Essential before migration 011 → Premium now, with
//     1 zone and the same end date; nothing drawn yet: "ارسم بستانك".
//   +21650000005: had asked the LOOZ kit (the old Connected) → Free, the
//     request cancelled with a note; Premium → "ارسم بستانك" (nothing to
//     pay without a drawing).
//   The rules: nobody gives himself a pack, zones, an orchard or a price.
//
// The real demo payment of a drawn orchard: test_live/orchard_live_test.dart.
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/signup_payment_live_test.dart --dart-define-from-file=.env
//
// Numbers with no account (deleted in Supabase > Authentication > Users):
// the sign-up is done in the app (farmer, Premium → "ارسم بستانك", then
// "متابعة مجانًا").
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
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/start_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/premium/pack_texts.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';

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

/// The app, on the start screen, with a new client (login, packs and the
/// orchard all read the real Supabase).
Future<SupabaseClient> openApp(WidgetTester tester) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  final client = (await tester.runAsync(() async => newClient()))!;
  authService = SupabaseAuthService(client);
  paymentService = DemoPaymentService(client);
  orchardService = SupabaseOrchardService(client);
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
    find.byType(DesignerStartScreen),
    find.byType(PaymentScreen),
    find.byType(HomePage),
  ]);
  // A new account: "من أنت؟" → "فلاح" (the sign-ups of this test).
  if (find.byType(RoleScreen).evaluate().isNotEmpty) {
    step('who are you: farmer');
    await tapAndWait(tester, find.text('فلاح'));
  }
}

/// The step "معلوماتك" of a farmer, then the packs.
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
  await waitFor(tester, [find.text('8 د.ت للمنطقة / 30 يومًا')]);
}

/// A new account (no account when the test started): the sign-up in the
/// app, Premium chosen → "ارسم بستانك" → "متابعة مجانًا" → Home.
Future<void> signUpPremiumThenFree(
  WidgetTester tester, {
  required String first,
  required String governorate,
}) async {
  if (find.byType(SignUpInfoScreen).evaluate().isNotEmpty) {
    await fillInfo(
      tester,
      first: first,
      last: 'Test',
      governorate: governorate,
    );
  }
  if (find.byType(PackScreen).evaluate().isNotEmpty) {
    step('pack: Premium');
    await scrollAndTap(tester, find.text('بريميوم'));
    await scrollTo(tester, find.text('متابعة'));
    await tester.tap(find.text('متابعة'));
  }
  await waitFor(tester, [find.byType(DesignerStartScreen)]);
  step('"ارسم بستانك" (the designer: phase 3), then free for now');
  await scrollAndTap(tester, find.text('متابعة مجانًا'));
  await waitFor(tester, [find.byType(WelcomeScreen)]);
  await tapAndWait(tester, find.text('ابدأ'));
  await waitFor(tester, [find.byType(HomePage)]);
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

/// The error code of a call (null = it worked).
Future<String?> codeOf(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on PostgrestException catch (e) {
    return e.code;
  }
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

  testWidgets('1. $phone04 (paid Essential before 011): Premium now, 1 zone, '
      'the same end date; nothing drawn: "ارسم بستانك"', (tester) async {
    final client = await openApp(tester);
    if (isNew[phone04]!) {
      await signUpWithPhone(tester, '50000004');
      await signUpPremiumThenFree(
        tester,
        first: 'منير',
        governorate: 'سيدي بوزيد',
      );
    } else {
      step('sign in');
      await tapAndWait(tester, find.text('تسجيل الدخول'));
      await typeDigits(tester, '50000004');
      await sendCodeOnScreen(tester, 'إرسال الرمز');
      await enterCode(tester);
    }
    expect(find.byType(HomePage), findsOneWidget);

    // What the database has now.
    final profile = await serverCall(
      tester,
      'profile of 04',
      () => client
          .from('profiles')
          .select('chosen_plan, payment_status')
          .single(),
    );
    final subscription = await serverCall(
      tester,
      'subscription of 04',
      () => client
          .from('subscriptions')
          .select('plan, status, ends_at, nodes')
          .single(),
    );
    final payments = await serverCall(
      tester,
      'payments of 04',
      () => client
          .from('payments')
          .select('plan, status, amount_millimes, nodes, kind, provider')
          .order('created_at', ascending: true),
    );
    final plan = await serverCall(
      tester,
      'user_plan()',
      () => client.rpc('user_plan'),
    );
    final quote = await serverCall(
      tester,
      'orchard_quote()',
      () => codeOf(() => client.rpc('orchard_quote')),
    );
    printRow('$phone04 now:', {
      'profile': profile,
      'subscription': subscription,
      'payments': payments,
      'user_plan()': plan,
      'orchard_quote() error': quote,
    });
    if (!isNew[phone04]!) {
      // Essential (paid on 31/10) became Premium with 1 zone.
      expect(profile['chosen_plan'], 'paid');
      expect(profile['payment_status'], 'paid');
      expect(subscription['plan'], 'paid');
      expect(subscription['nodes'], 1);
      final running = daysTo(subscription['ends_at'] as String) > 0;
      expect(plan, running ? 'paid' : 'free');
      expect(currentPlan.value, running ? Plan.paid : Plan.free);
      // Its old payments keep their pack name (history), never a card.
      expect(payments.map((p) => p['plan']), everyElement('essential'));
      expect(jsonEncode(payments), isNot(contains('4242')));
    }
    // Nothing drawn yet: nothing to bill.
    expect(quote, 'PT409');

    if (currentPlan.value == Plan.paid) {
      step('"بستاني ★": no orchard yet → "ارسم بستانك"');
      // No pumpAndSettle while the orchard loads (the spinner would push the
      // fake clock past the 30 s time limit).
      await tester.tap(findTextWithSymbol('بستاني ★'));
      await tester.pump();
      await waitFor(tester, [findTextWithSymbol('★ ابدأ الرسم')]);
      expect(find.text('ارسم بستانك'), findsOneWidget);
      await tapAndWait(tester, findTextWithSymbol('★ ابدأ الرسم'));
      expect(find.byType(DesignerStartScreen), findsOneWidget);
      await waitFor(tester, [find.text('8 د.ت للمنطقة / 30 يومًا')]);

      step('Profile: my pack');
      Navigator.of(tester.element(find.byType(DesignerStartScreen))).pop();
      await tester.pumpAndSettle();
      await tapAndWait(tester, find.text('حسابي').last);
      final end = dayText(DateTime.parse(subscription['ends_at'] as String));
      await waitFor(tester, [find.text('بريميوم · منطقة واحدة · حتى $end')]);
    }
    await closeTheApp(tester, client);
  }, timeout: _slow);

  testWidgets('2. $phone05 (had asked the LOOZ kit): Free, the request '
      'cancelled with a note; Premium → "ارسم بستانك"', (tester) async {
    final client = await openApp(tester);
    if (isNew[phone05]!) {
      await signUpWithPhone(tester, '50000005');
      await signUpPremiumThenFree(
        tester,
        first: 'سنية',
        governorate: 'القيروان',
      );
    } else {
      step('sign in');
      await tapAndWait(tester, find.text('تسجيل الدخول'));
      await typeDigits(tester, '50000005');
      await sendCodeOnScreen(tester, 'إرسال الرمز');
      await enterCode(tester);
    }
    expect(find.byType(HomePage), findsOneWidget);

    final kits = await serverCall(
      tester,
      'kit requests of 05',
      () => client
          .from('kit_requests')
          .select('status, admin_note, nodes, orchard_id')
          .order('created_at', ascending: true),
    );
    final plan = await serverCall(
      tester,
      'user_plan()',
      () => client.rpc('user_plan'),
    );
    final pay = await serverCall(tester, 'paying without a drawing', () async {
      try {
        await DemoPaymentService(client).pay(cardAccepted: true);
        return null;
      } on PaymentError catch (e) {
        return e.failure;
      }
    });
    printRow('$phone05 now:', {
      'kit requests': kits,
      'user_plan()': plan,
      'pay without a drawing': pay?.name,
    });
    expect(plan, 'free');
    if (!isNew[phone05]!) {
      expect(kits.first['status'], 'cancelled');
      expect(kits.first['admin_note'], contains('Migration 011'));
    }
    expect(pay, PaymentFailure.noDrawing);

    step('"بستاني ★" locked → Premium → "★ ابدأ بريميوم" → "ارسم بستانك"');
    await tapAndWait(tester, findTextWithSymbol('بستاني ★'));
    expect(find.text('بستانك في جيبك'), findsOneWidget);
    await tapAndWait(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    expect(find.byType(PremiumScreen), findsOneWidget);
    await waitFor(tester, [find.text('8 د.ت للمنطقة / 30 يومًا')]);
    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    await waitFor(tester, [find.byType(DesignerStartScreen)]);
    expect(find.text('ارسم بستانك'), findsOneWidget);
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
    expect(settings['hectares_per_node'], 2);

    // The price: read, never changed.
    final prices = await client
        .from('plan_prices')
        .select('plan, price_millimes, period_days, per_node');
    final cheaper = await client
        .from('plan_prices')
        .update({'price_millimes': 1000})
        .eq('plan', 'paid')
        .select();
    final nodes = await client
        .from('subscriptions')
        .update({'nodes': 100, 'plan': 'paid'})
        .eq('user_id', me)
        .select();
    results['prices'] = prices;
    results['change the price (rows changed)'] = cheaper.length;
    results['give himself 100 zones (rows changed)'] = nodes.length;
    expect(prices, [
      {
        'plan': 'paid',
        'price_millimes': 8000,
        'period_days': 30,
        'per_node': true,
      },
    ]);
    expect(cheaper, isEmpty);
    expect(nodes, isEmpty);

    results['insert a "paid" payment'] = await codeOf(
      () => client.from('payments').insert({
        'user_id': me,
        'plan': 'paid',
        'amount_millimes': 1,
        'period_days': 365,
        'status': 'paid_demo',
      }),
    );
    results['activate_pack() (give himself a pack)'] = await codeOf(
      () => client.rpc(
        'activate_pack',
        params: {'p_user': me, 'p_plan': 'paid', 'p_days': 365, 'p_nodes': 100},
      ),
    );
    results['set_pack_nodes()'] = await codeOf(
      () =>
          client.rpc('set_pack_nodes', params: {'p_user': me, 'p_nodes': 100}),
    );
    results['confirm_payment()'] = await codeOf(
      () =>
          client.rpc('confirm_payment', params: {'p_ref': 'x', 'p_amount': 1}),
    );
    results['orchard_apply_design_for() (build without paying)'] = await codeOf(
      () => client.rpc(
        'orchard_apply_design_for',
        params: {'p_user': me, 'p_check': false},
      ),
    );
    results['orchard_quote_for() (another bill)'] = await codeOf(
      () => client.rpc('orchard_quote_for', params: {'p_user': me}),
    );
    results['write an orchard directly'] = await codeOf(
      () => client.from('orchards').insert({
        'farmer_id': me,
        'name': 'x',
        'status': 'complete',
      }),
    );
    results['write a kit request himself'] = await codeOf(
      () => client.from('kit_requests').insert({
        'user_id': me,
        'status': 'installed',
        'nodes': 50,
      }),
    );
    results['become expert after the sign-up'] = await codeOf(
      () => client.rpc('choose_role', params: {'p_role': 'expert'}),
    );
    results['demo payment of "free"'] = await codeOf(
      () => client.rpc('demo_payment', params: {'p_plan': 'free'}),
    );
    results['demo payment without a drawing'] = await codeOf(
      () => client.rpc('demo_payment', params: {'p_plan': 'paid'}),
    );
    results['request_kit() (removed)'] = await codeOf(
      () => client.rpc('request_kit'),
    );
    final others = await client
        .from('payments')
        .select('id')
        .neq('user_id', me);
    final otherOrchards = await client.from('orchards').select('id');
    results['payments of others visible'] = others.length;
    results['orchards visible'] = otherOrchards.length;
    printRow('Refused (as they should be):', results);

    expect(results['insert a "paid" payment'], isNotNull);
    expect(results['activate_pack() (give himself a pack)'], '42501');
    expect(results['set_pack_nodes()'], '42501');
    expect(results['confirm_payment()'], '42501');
    expect(
      results['orchard_apply_design_for() (build without paying)'],
      '42501',
    );
    expect(results['orchard_quote_for() (another bill)'], '42501');
    expect(results['write an orchard directly'], '42501');
    expect(results['write a kit request himself'], isNotNull);
    expect(results['become expert after the sign-up'], '42501');
    expect(results['demo payment of "free"'], '22023');
    expect(results['demo payment without a drawing'], 'PT409');
    expect(results['request_kit() (removed)'], isNotNull);
    expect(others, isEmpty);
    expect(otherOrchards, isEmpty); // 04 has none; others' are not visible

    await client.auth.signOut();
    await client.dispose();
  }, timeout: _slow);

  testWidgets('4. Sign up with $phone04 again: "already has an account"', (
    tester,
  ) async {
    final client = await openApp(tester);
    await signUpWithPhone(tester, '50000004');
    expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
    await tester.tap(find.text('تسجيل الدخول'));
    await waitFor(tester, [find.byType(HomePage)]);
    expect(currentUser.value?.phone, phone04);
    await closeTheApp(tester, client);
  }, timeout: _slow);
}
