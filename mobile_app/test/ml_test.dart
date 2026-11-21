// The ML predictions in the app (migration 019), with fake live data (no
// internet): the section "بستاني" of the alerts tab, the number on the bell,
// a card -> the zone panel in the 3D tab (state, how sure, reasons as bars,
// explanation, ONE action, readings), the text made from the codes when Groq
// gave none, the in-app banner when "Realtime" brings a new problem (once),
// paid farmers only, French, a small phone, and the states of a zone.
// Run it with: flutter test test/ml_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/ml_service.dart';
import 'package:looz_mobile/features/alerts/orchard_alerts.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_data.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_live_store.dart';
import 'package:looz_mobile/features/orchard_3d/zone_panel.dart';
import 'package:looz_mobile/shared/widgets/looz_tab_bar.dart';

import 'fake_alerts_service.dart';
import 'fake_ml_service.dart';
import 'fake_orchard_service.dart';
import 'test_helpers.dart';

final arabic = RegExp('[؀-ۿ]');
final latin = RegExp('[A-Za-z]');

Future<FakeMlService> startApp(
  WidgetTester tester, {
  FakeMlService? ml,
  AppTab tab = AppTab.alerts,
  Plan plan = Plan.paid,
  String lang = 'ar',
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  noAnimations(tester);
  appLocale.value = Locale(lang);
  currentPlan.value = plan;
  logInTestUser(lang);
  useFakeCommunity(lang);
  useAlerts(FakeAlertsService());
  final fake = useMl(ml);
  currentTab.value = tab;
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  return fake;
}

String bellNumber(WidgetTester tester) {
  for (final element in find
      .descendant(of: find.byType(LoozTabBar), matching: find.byType(Text))
      .evaluate()) {
    final text = (element.widget as Text).data ?? '';
    if (RegExp(r'^\d+\+?$').hasMatch(text)) return text;
  }
  return '';
}

List<String> textsOf(Finder finder) => [
  for (final e in find.descendant(of: finder, matching: find.byType(Text)).evaluate())
    (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
];

void main() {
  setUpAll(loadAppFonts);
  setUp(resetAppState);
  final ar = lookupAppLocalizations(const Locale('ar'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  testWidgets('the alerts tab: "بستاني" with one card per problem, the bell counts it', (tester) async {
    await startApp(tester);
    await scrollTo(tester, find.text('المنطقة ب: نقص الماء'));
    expect(find.text('المنطقة ب: نقص الماء'), findsOneWidget);
    expect(find.text('شوف خط السقي واسقي الشجر.'), findsOneWidget); // the action (Groq)
    expect(find.text(ar.alertNew), findsOneWidget);
    expect(bellNumber(tester), '1');
    expect(find.text(ar.sensorAlertsSoon), findsNothing); // no "قريبًا" any more
  });

  testWidgets('a card opens the zone in the 3D tab: the panel with everything', (tester) async {
    final ml = await startApp(tester);
    await scrollAndTap(tester, find.text('المنطقة ب: نقص الماء'));
    expect(currentTab.value, AppTab.orchard);
    expect(find.byType(ZonePanel), findsOneWidget);
    final panel = find.byType(ZonePanel);
    final texts = textsOf(panel);
    expect(texts, contains(ar.mlStateWaterDeficit));
    expect(texts, contains(ar.verdictLikely));
    expect(texts, contains('الشجر في المنطقة ب عطشان. التربة ناشفة.')); // Groq's Derja
    expect(texts, contains(ar.whatToDo));
    expect(texts, contains('شوف خط السقي واسقي الشجر.'));
    expect(texts, contains(ar.mlWhy));
    expect(texts, contains(ar.mlFactorSoilWaterLow)); // a reason in farmer words
    expect(texts, contains(ar.mlFactorAirDrynessHigh));
    expect(texts.join(' '), isNot(contains('rew_'))); // never a feature name
    expect(texts, contains('${ar.mlTonight}: '));
    expect(texts, contains(ar.mlStateNoFrost));
    expect(texts, contains('15 %')); // the readings
    expect(texts.any((t) => t.startsWith(ar.mlUpdated('').trim())), isTrue);
    expect(texts.where((t) => latin.hasMatch(t)), isEmpty); // 100 % Arabic
    expect(ml.marked, ['n-1']); // seen
    await tester.tap(find.byTooltip(ar.a11yClose).last);
    await tester.pumpAndSettle();
    expect(find.byType(ZonePanel), findsNothing);
    expect(bellNumber(tester), '');
  });

  testWidgets('no Groq text: a simple text from the codes, and "not sure"', (tester) async {
    final live = sampleLive();
    final b = live.predictions['node-B']!;
    final ml = FakeMlService(
      OrchardLive(
        nodes: live.nodes,
        predictions: {
          ...live.predictions,
          'node-B': {...b, 'stress': prediction('node-B', 'stress', 'heat', likely: false)},
        },
        notifications: [notification('n-2', 'node-B', 'stress', 'heat')],
      ),
    );
    await startApp(tester, ml: ml);
    await scrollAndTap(tester, find.text('المنطقة ب: ${ar.mlStateHeat}'));
    final texts = textsOf(find.byType(ZonePanel));
    final expected = ar.mlTemplateText(
      'المنطقة ب',
      ar.mlStateHeat,
      [ar.mlFactorSoilWaterLow, ar.mlFactorAirDrynessHigh].join(ar.mlListSeparator),
    );
    expect(texts, contains('$expected ${ar.mlTemplateUnsure}'));
    expect(texts, contains(ar.verdictUnsure));
    expect(texts, contains(ar.mlActionHeat)); // the template's action
  });

  testWidgets('Realtime: a new frost risk shows a banner once, a tap opens the zone', (tester) async {
    final ml = await startApp(tester, tab: AppTab.home);
    expect(ml.listening, isTrue); // listening to Supabase Realtime
    expect(find.byType(MlBannerHost), findsOneWidget);
    expect(find.text(ar.mlToastOpen), findsNothing); // no banner for the old problem
    final frost = notification('n-9', 'node-A', 'frost', 'frost_risk', danger: true, minutesAgo: 0);
    final live = sampleLive(notifications: [frost, ...sampleLive().notifications]);
    ml.push(
      OrchardLive(
        nodes: live.nodes,
        predictions: {
          ...live.predictions,
          'node-A': {
            ...live.predictions['node-A']!,
            'frost': prediction('node-A', 'frost', 'frost_risk'),
          },
        },
        notifications: live.notifications,
      ),
    );
    await tester.pump(const Duration(seconds: 1)); // the store waits 0.8 s, then reads
    await tester.pumpAndSettle(); // the banner slides in
    expect(find.text('المنطقة أ: ${ar.mlStateFrostRisk}'), findsOneWidget);
    expect(find.text(ar.mlToastOpen), findsOneWidget);
    expect(bellNumber(tester), '2');
    // the same notification again: no new banner
    await tester.tap(find.byTooltip(ar.a11yClose).first);
    await tester.pumpAndSettle();
    ml.push(ml.live);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(ar.mlToastOpen), findsNothing);
    // a new one, tapped: the zone A panel in the 3D tab
    ml.push(sampleLive(notifications: [
      notification('n-10', 'node-A', 'stress', 'heat', minutesAgo: 0),
      ...ml.live.notifications,
    ]));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.mlToastOpen));
    await tester.pumpAndSettle();
    expect(currentTab.value, AppTab.orchard);
    expect(find.byType(ZonePanel), findsOneWidget);
    expect(ml.marked, contains('n-10'));
  });

  testWidgets('free farmers: no "بستاني" section, nothing read', (tester) async {
    final ml = await startApp(tester, plan: Plan.free);
    expect(find.byType(OrchardAlertsSection), findsNothing);
    expect(ml.loads, 0);
    expect(ml.listening, isFalse);
  });

  testWidgets('all fine: "كل مناطقك بخير."', (tester) async {
    await startApp(tester, ml: FakeMlService(sampleLive(notifications: const [])));
    await scrollTo(tester, find.text(ar.mlAllZonesFine));
    expect(find.text(ar.mlAllZonesFine), findsOneWidget);
    expect(bellNumber(tester), '');
  });

  testWidgets('French: the card and the panel are 100 % French', (tester) async {
    await startApp(tester, lang: 'fr');
    await scrollAndTap(tester, find.text('Zone B : ${fr.mlStateWaterDeficit}'));
    final texts = textsOf(find.byType(ZonePanel));
    expect(texts, contains('Les arbres de la Zone B ont soif. Le sol est sec.'));
    expect(texts, contains(fr.mlFactorSoilWaterLow));
    expect(texts, contains(fr.verdictLikely));
    expect(texts.where((t) => arabic.hasMatch(t)), isEmpty);
  });

  testWidgets('a small phone (360 x 640): the panel fits and scrolls', (tester) async {
    await startApp(tester, size: const Size(360, 640));
    await scrollAndTap(tester, find.text('المنطقة ب: نقص الماء'));
    expect(find.byType(ZonePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the panel of a box with a problem: sensor, offline, not enough data, waiting', (tester) async {
    usePhoneScreen(tester);
    appLocale.value = const Locale('ar');
    final zone = demoOrchard().zones.first;
    final node = demoOrchard().nodes.first;
    Future<List<String>> panelFor(OrchardLive live, {bool installed = true}) async {
      orchardLive.value = OrchardLiveState(live: live);
      await tester.pumpWidget(
        LoozApp(
          home: Scaffold(
            body: ZonePanel(
              zone: zone,
              node: installed ? node : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return textsOf(find.byType(ZonePanel));
    }

    var texts = await panelFor(OrchardLive(nodes: {'node-A': nodeLive('node-A', status: 'sensor_problem')}));
    expect(texts, containsAll([ar.mlStateSensorProblem, ar.mlSensorProblemText]));
    expect(texts, isNot(contains(ar.verdictLikely)));
    texts = await panelFor(OrchardLive(nodes: {'node-A': nodeLive('node-A', status: 'offline')}));
    expect(texts, containsAll([ar.mlStateOffline, ar.mlOfflineText]));
    texts = await panelFor(OrchardLive(nodes: {'node-A': nodeLive('node-A')}, predictions: {
      'node-A': {'stress': prediction('node-A', 'stress', null, status: 'not_enough_data')},
    }));
    expect(texts, containsAll([ar.mlStateNotEnoughData, ar.mlNotEnoughDataText]));
    texts = await panelFor(const OrchardLive(), installed: false);
    expect(texts, containsAll([ar.nodeWaiting, ar.mlWaitingText]));
  });

  test('the state of a zone: sensor first, then frost risk, then the trees', () {
    final live = OrchardLive(
      nodes: {
        'n1': nodeLive('node-A'),
        'n2': nodeLive('node-B', status: 'sensor_problem'),
        'n3': nodeLive('node-C', status: 'offline'),
      },
      predictions: {
        'n1': {
          'frost': prediction('node-A', 'frost', 'frost_risk'),
          'stress': prediction('node-A', 'stress', 'water_deficit'),
        },
        'n2': {'stress': prediction('node-B', 'stress', 'heat')},
        'n4': {'stress': prediction('node-D', 'stress', null, status: 'not_enough_data')},
      },
    );
    expect(live.zone('n1').state, ZoneState.frostRisk);
    expect(live.zone('n1').main?.model, 'frost');
    expect(live.zone('n2').state, ZoneState.sensorProblem);
    expect(live.zone('n3').state, ZoneState.offline);
    expect(live.zone('n4').state, ZoneState.notEnoughData);
    expect(live.zone('n5', installed: false).state, ZoneState.waiting);
    expect(zoneStateOf('frost'), ZoneState.frostDamage);
    expect(zoneStateOf('no_frost'), ZoneState.ok);
  });

  test('the 3D gets a colour and both languages for each zone', () {
    final json = jsonDecode(orchardLiveJson(demoOrchard(), sampleLive())) as Map;
    final zones = json['zones'] as Map;
    expect(zones.keys, containsAll(['zone-a', 'zone-b', 'zone-c', 'zone-d']));
    expect(zones['zone-b']['state'], 'waterDeficit');
    expect(zones['zone-b']['labels'], {'ar': ar.mlStateWaterDeficit, 'fr': fr.mlStateWaterDeficit});
    expect(zones['zone-b']['problem'], isTrue);
    expect(zones['zone-a']['state'], 'ok');
    expect(zones['zone-c']['state'], 'offline');
    expect(zones['zone-d']['state'], 'waiting'); // not installed yet
    expect(zones['zone-b']['color'], matches(RegExp(r'^#[0-9a-f]{6}$')));
    expect(zones['zone-b']['soil_moisture'], 14.6);
  });
}
