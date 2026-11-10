// LIVE test of the ORCHARD DESIGNER (Phase 3 = Milestone 2) against the REAL
// Supabase project, in the app, with a NEW number each run (+216 22 98x xxx,
// the demo login: any code):
//
//   1. sign up → farmer → Premium → "ارسم بستانك" → the outline (corners,
//      the size 150 m x 100 m) → saved draft → 2 automatic zones (120 and
//      180 trees) → zone B "أشجار كبيرة" → the review (the bill of the
//      database: 2 sensors, 16 DT) → the demo payment → the orchard built
//      → the welcome → "بستاني ★" in 3D
//   2. what the database holds now (orchard, zones, nodes, trees, pack,
//      payment, installation visit), and its rules
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/designer_live_test.dart --dart-define-from-file=.env
//
// Every run makes a NEW test account with its orchard. To delete them:
// Supabase › Authentication › Users › search "2298" › Delete user (its
// profile, orchard, zones, nodes and trees go with it; its payments stay,
// without the user).
@Timeout(Duration(minutes: 8))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_view.dart';
import 'package:looz_mobile/features/orchard_designer/build_orchard_screen.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/orchard_designer/orchard_canvas.dart';
import 'package:looz_mobile/features/orchard_designer/outline_screen.dart';
import 'package:looz_mobile/features/orchard_designer/review_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zone_details_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zones_screen.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/shared/widgets/action_button.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart'
    show newClient, printRow, serverCall, step, tapAndWait, waitFor;
import 'demo_login_live_test.dart' show codeStep, hasAccount, phoneStep;
import 'signup_payment_live_test.dart'
    show closeTheApp, codeOf, fillInfo, openApp, payWithCard;

const _slow = Timeout(Duration(minutes: 8));

/// The 8 digits of this run's new number: 2298 + 4 digits of the clock.
late String digits;
String get phone => '+216$digits';

/// Logs [phone] in again on a client of its own (the demo login).
Future<SupabaseClient> logInAgain() async {
  final client = newClient();
  final auth = SupabaseAuthService(client);
  await auth.sendCode(phone, language: 'ar', createAccount: false);
  await auth.verifyCode(phone, '777777');
  return client;
}

/// Taps "★ التالي" and waits for [shown] on the next screen (the draft is
/// saved on the real server first: no pumpAndSettle while it is saved).
/// A screen that loads with a spinner: wait for what it loads, not for the
/// screen (waitFor's pumpAndSettle would push the fake clock past the
/// app's time limit while the spinner turns).
Future<void> nextTo(WidgetTester tester, Finder shown) async {
  await tester.tap(findTextWithSymbol('★ التالي').last);
  await tester.pump();
  await waitFor(tester, [shown]);
}

Offset at(WidgetTester tester, double fx, double fy) {
  final r = tester.getRect(find.byType(OrchardCanvas).last);
  return r.topLeft + Offset(r.width * fx, r.height * fy);
}

void main() {
  late SupabaseClient checker;

  setUpAll(() async {
    await loadAppFonts();
    HttpOverrides.global = null; // real internet
    expect(
      SupabaseConfig.hasKeys,
      isTrue,
      reason: 'Run with --dart-define-from-file=.env',
    );
    checker = newClient();
    // A number that never had an account (never 22 999 002).
    var n = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 10000;
    for (var i = 0; i < 20; i++, n = (n + 7) % 10000) {
      digits = '2298${n.toString().padLeft(4, '0')}';
      if (!await hasAccount(checker, phone)) break;
    }
    step('new number for this run: $phone');
  });
  tearDownAll(() => checker.dispose());
  tearDown(resetAppState);

  testWidgets('1. Sign up → Premium → draw → zones → pay → the orchard in '
      '3D (Milestone 2)', (tester) async {
    final app = await openApp(tester);
    step('sign up $phone (demo login, any code)');
    await phoneStep(tester, signUp: true, digits: digits);
    await codeStep(tester, '582014');
    expect(find.byType(RoleScreen), findsOneWidget, reason: 'a new number');
    await tapAndWait(tester, find.text('فلاح'));
    await waitFor(tester, [find.byType(SignUpInfoScreen)]);
    await fillInfo(
      tester,
      first: 'رسام',
      last: 'البستان',
      governorate: 'القيروان',
      trees: '300',
    );
    step('pack: Premium → "ارسم بستانك"');
    await scrollAndTap(tester, find.text('بريميوم'));
    await scrollTo(tester, find.text('متابعة'));
    await tester.tap(find.text('متابعة'));
    await waitFor(tester, [find.byType(DesignerStartScreen)]);
    // The button works once the server said "no draft yet".
    await waitFor(tester, [
      find.byWidgetPredicate(
        (w) =>
            w is ActionButton &&
            w.onPressed != null &&
            w.label.contains('ابدأ الرسم'),
      ),
    ]);
    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ الرسم'));
    expect(find.byType(OutlineScreen), findsOneWidget);

    step('step 1: 5 corners, closed, the size 150 x 100 m');
    await tester.tap(find.text('نقاط'));
    await tester.pump();
    final corners = [
      at(tester, 0.2, 0.25),
      at(tester, 0.8, 0.25),
      at(tester, 0.85, 0.7),
      at(tester, 0.5, 0.8),
      at(tester, 0.15, 0.7),
    ];
    for (final c in [...corners, corners.first]) {
      await tester.tapAt(c);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('العرض'));
    await tester.pumpAndSettle();
    final sizeBoxes = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(sizeBoxes.at(0), '150');
    await tester.enterText(sizeBoxes.at(1), '100');
    await tester.tap(find.text('تمّ'));
    await tester.pumpAndSettle();
    expect(find.text('150 م'), findsOneWidget);
    await nextTo(tester, find.byType(ZonesScreen));

    final draft = await serverCall(
      tester,
      'the draft after step 1',
      () => app.from('orchards').select('status, area, design').single(),
    );
    printRow('Draft after step 1:', {
      'status': draft['status'],
      'area': draft['area'],
      'design.step': (draft['design'] as Map)['step'],
      'design.mode': (draft['design'] as Map)['mode'],
      'design.outline': (draft['design'] as Map)['outline'],
    });
    expect(draft['status'], 'draft');
    expect(draft['area'], isNull); // not built: no area yet
    expect((draft['design'] as Map)['step'], 'zones');
    expect((draft['design'] as Map)['mode'], 'grid');
    expect((draft['design'] as Map)['outline'], hasLength(5));

    step('step 2: automatic, 2 zones (120 and 180 trees)');
    await tester.tap(find.text('أعطي عدد المناطق والأشجار'));
    await tester.pumpAndSettle();
    // 1.2 ha: 2 zones at first.
    final treeBoxes = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(TextField),
    );
    expect(treeBoxes, findsNWidgets(2));
    await tester.enterText(treeBoxes.at(0), '120');
    await tester.enterText(treeBoxes.at(1), '180');
    await tester.pumpAndSettle();
    await nextTo(tester, find.byType(ZoneDetailsScreen));

    step('zone B: "أشجار كبيرة", its own name');
    await tester.tap(find.text('المنطقة B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أشجار كبيرة'));
    final sheetBoxes = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(sheetBoxes.at(1), 'الجنان القديم');
    await tester.tap(find.text('تمّ'));
    await tester.pumpAndSettle();
    expect(find.text('180 شجرة · أشجار كبيرة'), findsOneWidget);
    step('step 3: the bill of the database');
    await nextTo(tester, find.text('حسّاسان'));
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.text('منطقتان'), findsOneWidget);
    expect(find.text('300 شجرة'), findsOneWidget);
    expect(find.text('16 د.ت / 30 يومًا'), findsOneWidget);
    expect(find.textContaining('هكتار'), findsWidgets);

    step('pay (demo card 4242...), then the orchard is built');
    await tester.tap(findTextWithSymbol('★ ادفع وابنِ بستاني'));
    await tester.pump();
    await waitFor(tester, [find.byType(PaymentScreen)]);
    expect(find.text('16 د.ت / 30 يومًا'), findsOneWidget);
    await payWithCard(tester, acceptedTestCard);
    expect(find.text('تم الدفع!'), findsOneWidget);
    expect(find.byType(PaymentResultScreen), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(BuildOrchardScreen), findsOneWidget);
    expect(find.text('جاري بناء بستانك…'), findsOneWidget);
    await waitFor(tester, [find.byType(WelcomeScreen)], seconds: 90);
    expect(find.text('مرحبًا يا رسام'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    expect(currentTab.value, AppTab.orchard);
    await waitFor(tester, [find.byType(Orchard3dView)], seconds: 60);

    final view = tester.widget<Orchard3dView>(find.byType(Orchard3dView));
    final data = jsonDecode(view.data) as Map<String, dynamic>;
    final zones = data['zones'] as List;
    printRow('What the 3D page gets:', {
      'orchard': data['orchard'],
      'zones': [
        for (final z in zones)
          {'name': z['name'], 'type': z['type'], 'trees': z['tree_count']},
      ],
      'nodes': [
        for (final n in data['nodes'] as List)
          {'installed': n['installed'], 'status': n['status']},
      ],
      'trees': (data['trees'] as List).length,
    });
    expect(zones.map((z) => z['name']), ['المنطقة A', 'الجنان القديم']);
    expect(zones.map((z) => z['type']), [null, 'old_trees']);
    expect(
      (data['nodes'] as List).every((n) => n['installed'] == false),
      isTrue,
    );
    // About the 300 trees said (the rows of the database: ±10 %).
    expect((data['trees'] as List).length, inInclusiveRange(250, 330));
    await closeTheApp(tester, app);
  }, timeout: _slow);

  test('2. In the database: the orchard, its zones, sensors, trees, the '
      'pack, the payment, the installation visit; the rules', () async {
    final client = await logInAgain();
    final orchard = await client
        .from('orchards')
        .select('id, status, area, draw_mode, design, outline')
        .single();
    final zones = await client
        .from('zones')
        .select('letter, name, zone_type, color, tree_count')
        .isFilter('archived_at', null)
        .order('letter', ascending: true);
    final nodes = await client.from('nodes').select('installed_at, status');
    final trees = await client
        .from('trees')
        .select('id')
        .isFilter('archived_at', null);
    final pack = await client
        .from('subscriptions')
        .select('plan, status, nodes, ends_at')
        .single();
    final payments = await client
        .from('payments')
        .select('plan, status, amount_millimes, nodes, kind, provider');
    final visit = await client
        .from('kit_requests')
        .select('status, nodes, orchard_id, almond_trees');
    final rules = {
      'build again (no draft)': await codeOf(
        () => client.rpc('orchard_apply_design'),
      ),
      'write a zone by hand': await codeOf(
        () => client.from('zones').insert({
          'orchard_id': orchard['id'],
          'letter': 'C',
          'boundary': const [],
        }),
      ),
      'change the orchard by hand (rows changed)':
          (await client
                  .from('orchards')
                  .update({'confirmed_nodes': 100})
                  .eq('id', orchard['id'])
                  .select())
              .length,
    };
    final quote = await client.rpc('orchard_quote');
    printRow('$phone in the database:', {
      'orchard': {
        ...orchard,
        'outline': '${(orchard['outline'] as List).length} corners',
      },
      'zones': zones,
      'nodes': nodes,
      'trees': trees.length,
      'pack': pack,
      'payments': payments,
      'installation visit': visit,
      'refused': rules,
      'orchard_quote()': quote,
    });
    expect(orchard['status'], 'complete');
    expect(orchard['draw_mode'], 'grid');
    expect(orchard['design'], isNull); // the draft became the orchard
    expect((orchard['area'] as num).toDouble(), inInclusiveRange(1.0, 1.5));
    expect(orchard['outline'], hasLength(5));
    expect(zones.map((z) => z['letter']), ['A', 'B']);
    expect(zones.map((z) => z['tree_count']), [120, 180]);
    expect(zones[1]['zone_type'], 'old_trees');
    expect(zones[1]['name'], 'الجنان القديم');
    expect(nodes, hasLength(2));
    expect(nodes.every((n) => n['installed_at'] == null), isTrue);
    expect(trees.length, inInclusiveRange(250, 330));
    expect(pack['plan'], 'paid');
    expect(pack['nodes'], 2);
    expect(payments, [
      {
        'plan': 'paid',
        'status': 'paid_demo',
        'amount_millimes': 16000,
        'nodes': 2,
        'kind': 'period',
        'provider': 'demo',
      },
    ]);
    expect(jsonEncode(payments), isNot(contains('4242')));
    expect(visit, hasLength(1));
    expect(visit.single['status'], 'new');
    expect(visit.single['nodes'], 2);
    expect(visit.single['orchard_id'], orchard['id']);
    expect(rules['build again (no draft)'], 'PT409');
    expect(rules['write a zone by hand'], '42501');
    expect(rules['change the orchard by hand (rows changed)'], 0);
    await client.auth.signOut();
    await client.dispose();
  });
}
