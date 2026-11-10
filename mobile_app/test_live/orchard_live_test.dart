// LIVE test of the TWO packs and the REAL orchard (migration 011 + the demo
// seed supabase/seed/orchard_demo.sql) against the REAL Supabase project:
//
//   0. the demo orchard of +216 22 123 456 is there (read only)
//   1. the app's orchard service reads it; the JSON of the 3D page
//   2. in the app: 22 123 456 → "بستاني ★" = its orchard in 3D
//   3. in the app: Premium → the bill (4 zones = 32 DT), the test card that
//      always fails → "لم يكتمل الدفع", nothing changed but a "failed_demo"
//   4. a free account sees nothing of the orchard
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/orchard_live_test.dart --dart-define-from-file=.env
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_data.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_view.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart'
    show newClient, printRow, serverCall, step, tapAndWait, waitFor;
import 'demo_login_live_test.dart' show codeStep, phoneStep;
import 'signup_payment_live_test.dart' show closeTheApp, openApp, payWithCard;

const demoPhone = '+21622123456';
const freePhone = '+21622123457';
const _slow = Timeout(Duration(minutes: 6));

/// Logs [phone] in with the demo login (any code), on a client of its own.
Future<SupabaseClient> logIn(String phone) async {
  final client = newClient();
  final auth = SupabaseAuthService(client);
  await auth.sendCode(phone, language: 'ar', createAccount: false);
  await auth.verifyCode(phone, '246810');
  return client;
}

/// In the app (start screen): sign in with 22 123 456 → Home.
Future<void> signInDemo(WidgetTester tester) async {
  step('sign in 22 123 456 (demo login)');
  await phoneStep(tester, signUp: false, digits: '22123456');
  await codeStep(tester, '135790');
  await waitFor(tester, [find.byType(HomePage)]);
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

  test('0. The demo orchard of $demoPhone is in Supabase', () async {
    final client = await logIn(demoPhone);
    final orchard = await client
        .from('orchards')
        .select('status, area, draw_mode, is_demo, design')
        .maybeSingle();
    final zones = await client
        .from('zones')
        .select('letter, zone_type, color, tree_count, health')
        .isFilter('archived_at', null)
        .order('letter', ascending: true);
    final nodes = await client.from('nodes').select('status, installed_at');
    final trees = await client
        .from('trees')
        .select('id')
        .isFilter('archived_at', null);
    final plan = await client.rpc('user_plan');
    final quote = await client.rpc('orchard_quote');
    printRow('Demo orchard of $demoPhone:', {
      'orchard': orchard,
      'zones': zones,
      'nodes': nodes,
      'trees': trees.length,
      'user_plan()': plan,
      'orchard_quote()': quote,
    });
    expect(orchard?['status'], 'complete');
    expect(orchard?['is_demo'], isTrue);
    expect(zones.map((z) => z['letter']), ['A', 'B', 'C', 'D']);
    expect(nodes, hasLength(4));
    expect(trees.length, greaterThan(600));
    expect(plan, 'paid');
    await client.auth.signOut();
    await client.dispose();
  });

  test('1. The app reads the orchard; the JSON of the 3D page', () async {
    final client = await logIn(demoPhone);
    final orchard = await SupabaseOrchardService(client).loadMyOrchard();
    expect(orchard, isNotNull);
    expect(orchard!.complete, isTrue);
    final data = jsonDecode(
      orchard3dJson(orchard, language: 'fr'),
    ) as Map<String, dynamic>;
    final zones = data['zones'] as List;
    final nodes = data['nodes'] as List;
    final trees = data['trees'] as List;
    printRow('What the 3D page gets (French):', {
      'orchard': data['orchard'],
      'zones': [
        for (final z in zones)
          {
            'name': z['name'],
            'type': z['type'],
            'color': z['color'],
            'health': z['health'],
          },
      ],
      'nodes': [
        for (final n in nodes)
          {'status': n['status'], 'installed': n['installed']},
      ],
      'trees': trees.length,
      'trees with a photo': trees
          .where((t) => t['photo_status'] != null)
          .length,
    });
    expect(data['real'], isTrue);
    expect((data['orchard'] as Map)['outline'], hasLength(5));
    expect((data['orchard'] as Map)['width'], 195);
    expect((data['orchard'] as Map)['length'], 145);
    expect(zones.map((z) => z['name']), [
      'Zone A',
      'Zone B',
      'Zone C',
      'Zone D',
    ]);
    expect(zones.map((z) => z['color']), [
      '#8BC34A',
      '#4FC3F7',
      '#FFB74D',
      '#BA68C8',
    ]);
    expect(nodes.every((n) => n['installed'] == true), isTrue);
    expect(nodes.map((n) => n['status']).toList()..sort(), [
      'offline',
      'online',
      'online',
      'online',
    ]);
    expect(trees.length, greaterThan(600));
    expect(trees.map((t) => t['id']).toSet().length, trees.length);
    await client.auth.signOut();
    await client.dispose();
  });

  testWidgets('2. In the app: 22 123 456 → "بستاني ★" = its orchard in 3D', (
    tester,
  ) async {
    final client = await openApp(tester);
    await signInDemo(tester);
    expect(currentPlan.value, Plan.paid);
    step('"بستاني ★"');
    // No pumpAndSettle here: the spinner turns while the orchard loads, and
    // pumpAndSettle would push the fake clock past the 30 s time limit.
    await tester.tap(findTextWithSymbol('بستاني ★'));
    await tester.pump();
    await waitFor(tester, [find.byType(Orchard3dView)], seconds: 60);
    final view = tester.widget<Orchard3dView>(find.byType(Orchard3dView));
    final data = jsonDecode(view.data) as Map<String, dynamic>;
    expect(view.language, 'ar');
    expect(data['lang'], 'ar');
    expect(data['zones'], hasLength(4));
    expect((data['zones'] as List).first['name'], 'المنطقة A');
    expect((data['trees'] as List).length, greaterThan(600));
    expect(find.text('بستانك في جيبك'), findsNothing); // not locked
    await closeTheApp(tester, client);
  }, timeout: _slow);

  testWidgets('3. In the app: Premium → the bill (4 zones = 32 DT), the test '
      'card that always fails: "لم يكتمل الدفع", the pack unchanged', (
    tester,
  ) async {
    final client = await openApp(tester);
    await signInDemo(tester);
    final before = await serverCall(
      tester,
      'pack before',
      () =>
          client.from('subscriptions').select('plan, ends_at, nodes').single(),
    );
    step('Profile → "خطتي" → Premium');
    await tapAndWait(tester, find.text('حسابي').last);
    await tapAndWait(tester, find.text('خطتي'));
    await waitFor(tester, [findTextWithSymbol('★ جدّد باقتك')]);
    await scrollAndTap(tester, findTextWithSymbol('★ جدّد باقتك'));
    await waitFor(tester, [find.byType(PaymentScreen)]);
    // The bill of the database: covered now, so a payment = the next month.
    expect(find.text('32 د.ت / 30 يومًا'), findsOneWidget);
    expect(find.text('4 مناطق'), findsOneWidget);
    expect(find.text('وضع تجريبي'), findsOneWidget);
    step('the test card that always fails');
    await payWithCard(tester, refusedTestCard);
    expect(find.text('لم يكتمل الدفع'), findsOneWidget);

    final after = await serverCall(
      tester,
      'pack after',
      () =>
          client.from('subscriptions').select('plan, ends_at, nodes').single(),
    );
    final last = await serverCall(
      tester,
      'last payment',
      () => client
          .from('payments')
          .select('plan, status, amount_millimes, nodes, kind, provider')
          .order('created_at', ascending: false)
          .limit(1)
          .single(),
    );
    printRow('Refused test card:', {
      'pack before': before,
      'pack after': after,
      'last payment': last,
    });
    expect(after, before); // nothing changed
    expect(last, {
      'plan': 'paid',
      'status': 'failed_demo',
      'amount_millimes': 32000,
      'nodes': 4,
      'kind': 'period',
      'provider': 'demo',
    });
    expect(jsonEncode(last), isNot(contains('4000000000000002')));
    await closeTheApp(tester, client);
  }, timeout: _slow);

  test('4. A free account sees nothing of the orchard', () async {
    final client = await logIn(freePhone);
    final orchards = await client.from('orchards').select('id');
    final zones = await client.from('zones').select('id');
    final nodes = await client.from('nodes').select('id');
    final trees = await client.from('trees').select('id');
    final plan = await client.rpc('user_plan');
    printRow('$freePhone (Free) sees:', {
      'user_plan()': plan,
      'orchards': orchards.length,
      'zones': zones.length,
      'nodes': nodes.length,
      'trees': trees.length,
    });
    expect(plan, 'free');
    expect(orchards, isEmpty);
    expect(zones, isEmpty);
    expect(nodes, isEmpty);
    expect(trees, isEmpty);
    await client.auth.signOut();
    await client.dispose();
  });
}
