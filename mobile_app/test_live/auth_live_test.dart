// LIVE test: the sign-in against the REAL Supabase project, with the test
// phone numbers of the dashboard (code 123456, no SMS sent):
//
//   +21650000001 and +21650000002 = EXISTING users ("تسجيل الدخول")
//
// The sign-up of NEW users (04, 05) and the demo payment:
// test_live/signup_payment_live_test.dart.
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/auth_live_test.dart --dart-define-from-file=.env
//
// Supabase sends 1 code per number per minute: the test waits when needed.
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
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/onboarding/auth_messages.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/start_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';

import '../test/test_helpers.dart';

const newUserPhone = '+21650000001';
const existingUserPhone = '+21650000002';
const testCode = '123456';
const _slow = Timeout(Duration(minutes: 6));

/// A client like the app's (publishable key only), without saving the
/// session on disk (the test keeps it in memory).
SupabaseClient newClient() => SupabaseClient(
  SupabaseConfig.url,
  SupabaseConfig.publishableKey,
  authOptions: const AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
    autoRefreshToken: false,
  ),
);

final _clock = Stopwatch()..start();

/// Prints where the test is (to see the step where a run stops).
void step(String text) {
  // ignore: avoid_print
  print('  [${_clock.elapsed.inSeconds} s] $text');
}

/// Runs [work] like the app's own calls (a client used by the app only
/// answers this way: inside `runAsync` it waits forever), lets real time
/// pass until the server answers, and fails after [seconds].
Future<T> serverCall<T>(
  WidgetTester tester,
  String what,
  Future<T> Function() work, {
  int seconds = 60,
}) async {
  step(what);
  var done = false;
  late T result;
  Object? error;
  work().then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!done && DateTime.now().isBefore(end)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!done) fail('$what: no answer after $seconds s');
  if (error != null) throw error!;
  return result;
}

/// Asks a code, and waits when Supabase says "1 code per minute".
/// ([createAccount] false = sign in: a number without account is refused.)
Future<void> sendCodeWaiting(
  AuthService service,
  String phone, {
  bool createAccount = true,
}) async {
  Future<void> send() =>
      service.sendCode(phone, language: 'ar', createAccount: createAccount);
  try {
    await send();
  } on AuthError catch (error) {
    if (error.failure != AuthFailure.tooManyTries) rethrow;
    final wait = RegExp(r'(\d+) seconds').firstMatch('${error.cause}');
    await Future<void>.delayed(
      Duration(seconds: int.parse(wait?.group(1) ?? '60') + 1),
    );
    await send();
  }
}

/// Lets real time pass (the server answers) and updates the screen, until
/// one of [finders] is shown.
Future<void> waitFor(
  WidgetTester tester,
  List<Finder> finders, {
  int seconds = 40,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
  }
  // The screen may show an error message: say which one.
  final notes = find.byType(AuthNote).evaluate();
  final shown = notes.map((e) => (e.widget as AuthNote).failure).toList();
  fail('Nothing of $finders after $seconds s. Error messages shown: $shown');
}

Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit).last);
  }
  await tester.pump();
}

/// Taps "send the code" on the phone screen until the code screen opens
/// (waits a minute when Supabase asks to).
Future<void> sendCodeOnScreen(WidgetTester tester, String button) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    await tester.tap(find.text(button));
    await waitFor(tester, [find.byType(CodeScreen), find.byType(AuthNote)]);
    if (find.byType(CodeScreen).evaluate().isNotEmpty) return;
    final note = tester.widget<AuthNote>(find.byType(AuthNote));
    if (note.failure == AuthFailure.cannotReceiveCode) {
      fail(
        'Supabase refuses the test number: is "Phone" switched on (and '
        'saved) in Authentication > Sign In / Providers, with the test numbers?',
      );
    }
    if (note.failure != AuthFailure.tooManyTries) {
      fail('Error on the phone screen: ${note.failure}');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 61)),
    );
    await tester.pump();
  }
  fail('No code screen');
}

/// Prints a profile row (what is saved in the database).
void printRow(String title, Map<String, dynamic> row) {
  // ignore: avoid_print
  print('\n$title\n${const JsonEncoder.withIndent('  ').convert(row)}');
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
  });
  tearDown(resetAppState);

  test('0. Supabase: sign-in with the phone is switched on', () async {
    final http = HttpClient();
    final request = await http.getUrl(
      Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
    );
    request.headers.set('apikey', SupabaseConfig.publishableKey);
    final response = await request.close();
    final settings =
        jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    http.close();
    expect(
      (settings['external'] as Map)['phone'],
      isTrue,
      reason:
          'Authentication > Sign In / Providers > Phone: switch it on '
          'and click Save',
    );
  });

  testWidgets('1. $newUserPhone signs in: the missing step, then Home', (
    tester,
  ) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    final client = (await tester.runAsync(() async => newClient()))!;
    authService = SupabaseAuthService(client);
    paymentService = DemoPaymentService(client);
    await tester.pumpWidget(const LoozApp());
    await tester.pumpAndSettle();

    // The start screen: "تسجيل الدخول", the phone, the code.
    expect(find.byType(StartScreen), findsOneWidget);
    await tapAndWait(tester, find.text('تسجيل الدخول'));
    await typeDigits(tester, '50000001');
    step('phone typed, asking the code (sign in)');
    await sendCodeOnScreen(tester, 'إرسال الرمز');
    await typeDigits(tester, testCode);
    step('code typed');
    await tester.tap(find.text('تأكيد'));
    await waitFor(tester, [
      find.byType(HomePage),
      find.byType(DesignerStartScreen),
      find.byType(PackScreen),
      find.byType(SignUpInfoScreen),
      find.byType(RoleScreen),
    ]);
    // Premium chosen at an old sign-up and never paid: drawing the orchard
    // is the missing step (then the bill). "متابعة مجانًا" this time.
    if (find.byType(DesignerStartScreen).evaluate().isNotEmpty) {
      step('"ارسم بستانك" came back: continue for free');
      await scrollAndTap(tester, find.text('متابعة مجانًا'));
      await waitFor(tester, [find.byType(WelcomeScreen)]);
      await tapAndWait(tester, find.text('ابدأ'));
    }
    if (find.byType(PackScreen).evaluate().isNotEmpty) {
      await waitFor(tester, [find.text('8 د.ت للمنطقة / 30 يومًا')]);
      await scrollAndTap(tester, find.text('مجاني'));
      await scrollAndTap(tester, find.text('متابعة'));
      await waitFor(tester, [find.byType(WelcomeScreen)]);
      await tapAndWait(tester, find.text('ابدأ'));
    }
    expect(find.byType(HomePage), findsOneWidget);

    final row = await serverCall(
      tester,
      'reading the profiles row',
      () => client
          .from('profiles')
          .select('${UserProfile.columns}, name, updated_at')
          .eq('phone', newUserPhone)
          .single(),
    );
    printRow('profiles row of $newUserPhone:', row);
    expect(row['plan_chosen_at'], isNotNull);
    expect(row['role'], 'farmer');
    expect(row['payment_status'], isNot('pending'));

    // The app is closed and opened again: the saved session is used.
    final saved = jsonEncode(client.auth.currentSession!.toJson());
    final reopened = await serverCall(tester, 'saved session', () async {
      final c = newClient();
      await c.auth.recoverSession(saved);
      return c;
    });
    currentUser.value = null;
    authService = SupabaseAuthService(reopened);
    paymentService = DemoPaymentService(reopened);
    await tester.pumpWidget(const SizedBox());
    step('app opened again');
    await tester.pumpWidget(const LoozApp());
    await waitFor(tester, [find.byType(HomePage)]);
    expect(find.byType(StartScreen), findsNothing);

    // Log out in Profile: back to the start screen.
    step('log out');
    await tapAndWait(tester, find.text('حسابي').last);
    expect(find.text('+216 50 000 001'), findsOneWidget);
    await tester.tap(find.text('تسجيل الخروج'));
    await waitFor(tester, [find.byType(StartScreen)]);
    expect(reopened.auth.currentSession, isNull);
    expect(currentUser.value, isNull);

    await tester.pumpWidget(const SizedBox());
    await serverCall(tester, 'closing the clients', () async {
      await client.dispose();
      await reopened.dispose();
    });
  }, timeout: _slow);

  testWidgets('2. Existing user $existingUserPhone: sign in, Home', (
    tester,
  ) async {
    usePhoneScreen(tester);
    noAnimations(tester);

    // The first time, this number finishes its sign-up here (no screens).
    await serverCall(
      tester,
      'setup of $existingUserPhone',
      seconds: 150,
      () async {
        final c = newClient();
        final service = SupabaseAuthService(c);
        await sendCodeWaiting(service, existingUserPhone);
        await service.verifyCode(existingUserPhone, testCode);
        final profile = await service.loadProfile();
        if (!profile.hasChosenPlan) {
          await service.saveSignUpInfo(
            const SignUpInfo(
              role: UserRole.farmer,
              firstName: 'Mohamed',
              lastName: 'Ben Salem',
              governorate: 'sfax',
            ),
          );
          await service.choosePlan(Plan.free);
        }
        await service.signOut();
        await c.dispose();
      },
    );

    final client = (await tester.runAsync(() async => newClient()))!;
    authService = SupabaseAuthService(client);
    paymentService = DemoPaymentService(client);
    await tester.pumpWidget(const LoozApp());
    await tester.pumpAndSettle();
    step('French, then "Se connecter"');
    await tapAndWait(tester, find.text('FR'));
    await tapAndWait(tester, find.text('Se connecter'));
    await typeDigits(tester, '50000002');
    step('phone typed, asking the code');
    await sendCodeOnScreen(tester, 'Envoyer le code');
    await typeDigits(tester, testCode);
    step('code typed');
    await tester.tap(find.text('Confirmer'));
    await waitFor(tester, [
      find.byType(HomePage),
      find.byType(SignUpInfoScreen),
      find.byType(RoleScreen),
      find.byType(PackScreen),
      find.byType(DesignerStartScreen),
    ]);

    // Straight to Home: nothing is asked again.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Mohamed, vos arbres vont bien'), findsOneWidget);

    final row = await serverCall(
      tester,
      'reading the profiles row',
      () => client
          .from('profiles')
          .select('${UserProfile.columns}, name, updated_at')
          .eq('phone', existingUserPhone)
          .single(),
    );
    printRow('profiles row of $existingUserPhone (existing user):', row);
    expect(row['first_name'], 'Mohamed');
    expect(row['language'], 'fr'); // the language chosen at this login

    await serverCall(tester, 'closing the client', () async {
      await client.auth.signOut();
      await client.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  }, timeout: _slow);

  test('3. The database rules protect the profiles', () async {
    final client = newClient();
    final service = SupabaseAuthService(client);
    await sendCodeWaiting(service, newUserPhone);
    await service.verifyCode(newUserPhone, testCode);
    final me = client.auth.currentUser!.id;

    // A user reads only his own profile.
    final all = await client.from('profiles').select('id, phone');
    expect(all, hasLength(1));
    expect(all.single['phone'], newUserPhone);
    final other = await client
        .from('profiles')
        .select('id')
        .eq('phone', existingUserPhone);
    expect(other, isEmpty, reason: 'another user is visible');

    // Protected fields: refused.
    for (final change in <Map<String, Object>>[
      {'payment_status': 'paid'},
      {'chosen_plan': 'paid'},
      {'phone': '+21650000009'},
      {'verified': true},
      {'role': 'admin'},
    ]) {
      await expectLater(
        client.from('profiles').update(change).eq('id', me),
        throwsA(isA<PostgrestException>()),
        reason: '$change',
      );
    }

    // Wrong values: refused by the database itself.
    await expectLater(
      client.from('profiles').update({'first_name': '<b>x</b>'}).eq('id', me),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
    );
    await expectLater(
      client.from('profiles').update({'language': 'en'}).eq('id', me),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
    );
    await expectLater(
      client.rpc('choose_plan', params: {'p_plan': 'gold'}),
      throwsA(isA<PostgrestException>()),
    );

    // The plan cannot be changed by the user.
    await client
        .from('subscriptions')
        .update({'plan': 'paid', 'nodes': 100})
        .eq('user_id', me);
    expect(await client.rpc('user_plan'), 'free');
    final subscription = await client.from('subscriptions').select('plan');
    expect(subscription, hasLength(1));

    // The role is chosen during the sign-up only (finished here).
    await expectLater(
      client.rpc('choose_role', params: {'p_role': 'expert'}),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    // A payment can never be written by the app (not even "paid").
    await expectLater(
      client.from('payments').insert({
        'user_id': me,
        'plan': 'paid',
        'amount_millimes': 1,
        'period_days': 30,
        'status': 'paid_demo',
      }),
      throwsA(isA<PostgrestException>()),
    );

    // His own name: allowed.
    final renamed = await client
        .from('profiles')
        .update({'first_name': 'محمد', 'last_name': 'بن سالم'})
        .eq('id', me)
        .select('first_name')
        .single();
    expect(renamed['first_name'], 'محمد');

    // Not logged in: nothing is visible.
    final anonymous = newClient();
    expect(await anonymous.from('profiles').select('id'), isEmpty);

    await service.signOut();
    await client.dispose();
    await anonymous.dispose();
  }, timeout: _slow);

  // Each user can only read his own row: log in as each one to show it.
  test('4. What is saved for $newUserPhone and $existingUserPhone', () async {
    for (final phone in [newUserPhone, existingUserPhone]) {
      final client = newClient();
      final service = SupabaseAuthService(client);
      await sendCodeWaiting(service, phone);
      await service.verifyCode(phone, testCode);
      final row = await client
          .from('profiles')
          .select('${UserProfile.columns}, name, role, updated_at')
          .single();
      printRow('profiles row of $phone:', row);
      printRow('its subscription:', {
        'rows': await client.from('subscriptions').select(),
        'user_plan()': await client.rpc('user_plan'),
      });
      await service.signOut();
      await client.dispose();
    }
  }, timeout: _slow);
}
