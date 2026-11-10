// LIVE test of the DEMO LOGIN (migration 010 + Edge Function "demo-auth")
// against the REAL Supabase project, in the app, with codes that are NOT
// 123456 (any 6 digits work while app_settings.demo_login_enabled = true):
//
//   0. the switch is on and the function answers (nothing is created)
//   1. +216 22 999 001 (never existed): sign up, every step, as a farmer
//   2. +216 22 999 001: sign in again with another code
//   3. +216 22 999 002: sign in without account → refused, nothing created
//   4. +216 22 999 003 (never existed): sign up as an expert (no packs)
//   5. the rules of the database for an account made by the demo login
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/demo_login_live_test.dart --dart-define-from-file=.env
//
// Run again: 22 999 001 and 22 999 003 have an account then, and tests 1 and
// 4 check "هذا الرقم لديه حساب بالفعل" instead. To test them as NEW users
// again, delete them in Supabase > Authentication > Users.
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/auth_messages.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart'
    show newClient, printRow, serverCall, step, tapAndWait, typeDigits, waitFor;
import 'signup_payment_live_test.dart' show closeTheApp, openApp;

const farmerPhone = '+21622999001';
const nobodyPhone = '+21622999002';
const expertPhone = '+21622999003';
const _slow = Timeout(Duration(minutes: 6));

/// Calls the Edge Function like the app: (HTTP status, answer).
Future<(int, Object?)> demoAuth(
  SupabaseClient client,
  Map<String, Object?> body,
) async {
  try {
    final response = await client.functions.invoke('demo-auth', body: body);
    return (response.status, response.data);
  } on FunctionException catch (e) {
    return (e.status, e.details);
  }
}

/// "start" + sign in: does this number have an account? (nothing is made)
Future<bool> hasAccount(SupabaseClient client, String phone) async {
  final (_, answer) = await demoAuth(client, {
    'action': 'start',
    'phone': phone,
    'signUp': false,
  });
  return answer is Map && answer['demo'] == true;
}

/// From the start screen: the button, the 8 digits, "إرسال الرمز", then the
/// code screen (no SMS: no minute to wait).
Future<void> phoneStep(
  WidgetTester tester, {
  required bool signUp,
  required String digits,
}) async {
  await tapAndWait(tester, find.text(signUp ? 'إنشاء حساب' : 'تسجيل الدخول'));
  await typeDigits(tester, digits);
  await tester.tap(find.text('إرسال الرمز'));
  await waitFor(tester, [find.byType(CodeScreen), find.byType(AuthNote)]);
}

/// The code screen: [code] (any 6 digits), "تأكيد", the next screen.
Future<void> codeStep(WidgetTester tester, String code) async {
  expect(find.byType(CodeScreen), findsOneWidget);
  await typeDigits(tester, code);
  await tester.tap(find.text('تأكيد'));
  await waitFor(tester, [
    find.byType(RoleScreen),
    find.byType(AccountExistsScreen),
    find.byType(SignUpInfoScreen),
    find.byType(PackScreen),
    find.byType(HomePage),
    find.byType(AuthNote),
  ]);
}

/// The profile row saved for the user logged in on [client].
Future<Map<String, dynamic>> myProfile(
  WidgetTester tester,
  SupabaseClient client,
) => serverCall(
  tester,
  'profile',
  () => client
      .from('profiles')
      .select(
        'phone, first_name, last_name, role, verified, organisation, zone, '
        'almond_trees, irrigation, language, chosen_plan, plan_chosen_at',
      )
      .single(),
);

void main() {
  late SupabaseClient client;
  final isNew = <String, bool>{};

  setUpAll(() async {
    await loadAppFonts();
    // Real internet (Flutter tests block it by default).
    HttpOverrides.global = null;
    expect(
      SupabaseConfig.hasKeys,
      isTrue,
      reason: 'Run with --dart-define-from-file=.env',
    );
    client = newClient();
    for (final phone in [farmerPhone, expertPhone]) {
      isNew[phone] = !await hasAccount(client, phone);
      step(
        '$phone ${isNew[phone]! ? 'never existed' : 'already has an account'}',
      );
    }
  });
  tearDownAll(() => client.dispose());
  tearDown(resetAppState);

  // (22 123 456 has an account since the demo-login step: it owns the demo
  // orchard. 22 999 002 never has one: test 3 checks it is still so.)
  test('0. demo-auth is deployed and the demo login is on', () async {
    final signUp = await demoAuth(client, {
      'action': 'start',
      'phone': nobodyPhone,
      'signUp': true,
    });
    final signIn = await demoAuth(client, {
      'action': 'start',
      'phone': nobodyPhone,
      'signUp': false,
    });
    printRow('demo-auth "start" with $nobodyPhone (no account):', {
      'signUp true': {'status': signUp.$1, 'answer': signUp.$2},
      'signUp false': {'status': signIn.$1, 'answer': signIn.$2},
    });
    expect(signUp.$1, 200, reason: '401 = "Verify JWT" is still on');
    expect(signUp.$2, {'demo': true});
    expect(signIn.$2, {'error': 'no_account'});
  });

  testWidgets('1. $farmerPhone: sign up as a farmer with the code 482915: '
      'who are you, information, pack, welcome, Home', (tester) async {
    final app = await openApp(tester);
    step('phone (sign up)');
    await phoneStep(tester, signUp: true, digits: '22999001');
    step('code 482915');
    await codeStep(tester, '482915');

    if (!isNew[farmerPhone]!) {
      step('an earlier run made the account: "already has an account"');
      expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
    } else {
      expect(find.byType(RoleScreen), findsOneWidget);
      step('who are you: farmer');
      await tapAndWait(tester, find.text('فلاح'));
      step('information');
      await tester.enterText(signUpField('الاسم'), 'كمال');
      await tester.enterText(signUpField('اللقب'), 'العياري');
      await pickGovernorate(tester, 'سيدي بوزيد');
      await scrollTo(tester, find.text('عدد أشجار اللوز (اختياري)'));
      await tester.enterText(signUpField('عدد أشجار اللوز (اختياري)'), '80');
      await scrollAndTap(tester, find.text('مسقي'));
      await scrollAndTap(tester, find.text('متابعة'));
      await waitFor(tester, [find.byType(PackScreen)]);
      await waitFor(tester, [find.text('8 د.ت للمنطقة / 30 يومًا')]);
      step('pack: Free');
      await scrollAndTap(tester, find.text('مجاني'));
      await scrollAndTap(tester, find.text('متابعة'));
      await waitFor(tester, [find.byType(WelcomeScreen)]);
      expect(find.text('مرحبًا يا كمال'), findsOneWidget);
      await tapAndWait(tester, find.text('ابدأ'));
    }
    if (find.byType(AccountExistsScreen).evaluate().isNotEmpty) {
      await tester.tap(find.text('تسجيل الدخول'));
    }
    await waitFor(tester, [find.byType(HomePage)]);
    expect(find.byType(HomePage), findsOneWidget);

    final profile = await myProfile(tester, app);
    printRow('profile of $farmerPhone:', profile);
    expect(profile['phone'], farmerPhone);
    expect(profile['first_name'], 'كمال');
    expect(profile['role'], 'farmer');
    expect(profile['zone'], 'sidi_bouzid');
    expect(profile['almond_trees'], 80);
    expect(profile['irrigation'], 'irrigated');
    expect(profile['language'], 'ar');
    expect(profile['chosen_plan'], 'free');
    expect(profile['plan_chosen_at'], isNotNull);
    expect(currentUser.value?.phone, farmerPhone);
    await closeTheApp(tester, app);
  }, timeout: _slow);

  testWidgets('2. $farmerPhone signs in again with ANOTHER code (135790)', (
    tester,
  ) async {
    final app = await openApp(tester);
    await phoneStep(tester, signUp: false, digits: '22999001');
    await codeStep(tester, '135790');
    await waitFor(tester, [find.byType(HomePage)]);
    expect(find.byType(HomePage), findsOneWidget);
    expect(currentUser.value?.phone, farmerPhone);
    await closeTheApp(tester, app);
  }, timeout: _slow);

  testWidgets('3. $nobodyPhone: sign in without account → refused, nothing '
      'created', (tester) async {
    final app = await openApp(tester);
    await phoneStep(tester, signUp: false, digits: '22999002');
    expect(find.text('لا يوجد حساب بهذا الرقم.'), findsOneWidget);
    expect(find.byType(CodeScreen), findsNothing);
    expect(find.text('إنشاء حساب'), findsOneWidget); // the sign-up button
    final created = await serverCall(
      tester,
      'has 22 999 002 an account now?',
      () => hasAccount(client, nobodyPhone),
    );
    expect(created, isFalse);
    await closeTheApp(tester, app);
  }, timeout: _slow);

  testWidgets('4. $expertPhone: sign up as an expert (code 246810): only the '
      'name, governorate and organisation; no packs', (tester) async {
    final app = await openApp(tester);
    await phoneStep(tester, signUp: true, digits: '22999003');
    await codeStep(tester, '246810');
    if (!isNew[expertPhone]!) {
      step('an earlier run made the account: "already has an account"');
      expect(find.text('هذا الرقم لديه حساب بالفعل.'), findsOneWidget);
      await tester.tap(find.text('تسجيل الدخول'));
    } else {
      step('who are you: expert');
      await tapAndWait(tester, find.text('مهندس فلاحي أو مرشد'));
      await scrollTo(tester, find.text('متابعة'));
      expect(find.text('عدد أشجار اللوز (اختياري)'), findsNothing);
      expect(find.text('السقي (اختياري)'), findsNothing);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.enterText(signUpField('الاسم'), 'ليلى');
      await tester.enterText(signUpField('اللقب'), 'الشابي');
      await pickGovernorate(tester, 'صفاقس');
      await scrollTo(tester, find.text('المؤسسة (اختياري)'));
      await tester.enterText(
        signUpField('المؤسسة (اختياري)'),
        'المعهد الوطني للبحوث الزراعية',
      );
      await scrollAndTap(tester, find.text('متابعة'));
      await waitFor(tester, [find.byType(WelcomeScreen)]);
      expect(find.byType(PackScreen), findsNothing);
      await tapAndWait(tester, find.text('ابدأ'));
    }
    await waitFor(tester, [find.byType(HomePage)]);

    final profile = await myProfile(tester, app);
    printRow('profile of $expertPhone:', profile);
    expect(profile['role'], 'expert');
    expect(profile['verified'], isFalse); // only an admin gives the badge
    expect(profile['organisation'], 'المعهد الوطني للبحوث الزراعية');
    expect(profile['almond_trees'], isNull);
    expect(profile['irrigation'], isNull);
    expect(profile['chosen_plan'], 'free');
    await closeTheApp(tester, app);
  }, timeout: _slow);

  test('5. An account made by the demo login has the normal rules', () async {
    final user = newClient();
    final auth = SupabaseAuthService(user);
    await auth.sendCode(farmerPhone, language: 'ar', createAccount: false);
    await auth.verifyCode(farmerPhone, '777777');
    final me = user.auth.currentUser!.id;

    final off = await user
        .from('app_settings')
        .update({'demo_login_enabled': false})
        .eq('id', true)
        .select();
    final settings = await user.from('app_settings').select().single();
    final profiles = await user.from('profiles').select('id');
    String? check;
    try {
      await user.rpc('demo_login_check', params: {'p_phone': expertPhone});
    } on PostgrestException catch (e) {
      check = e.code;
    }
    printRow('Rules for $farmerPhone:', {
      'turn the demo login off (rows changed)': off.length,
      'demo_login_enabled': settings['demo_login_enabled'],
      'profiles visible': profiles.length,
      'call demo_login_check()': check,
    });
    expect(off, isEmpty);
    expect(settings['demo_login_enabled'], isTrue);
    expect(profiles.map((p) => p['id']), [me]); // only his own
    expect(check, '42501');
    await user.auth.signOut();
    await user.dispose();
  }, timeout: _slow);
}
