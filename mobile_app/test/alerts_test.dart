// The tab "التنبيهات" with REAL regional alerts (here a fake list, no
// internet): the order, "جديد" and the number on the bell, an alert's
// screen ("ماذا أفعل؟", until when, "أنا أيضًا", "تمّ"), an alert ended
// while open, no alert, no internet, pull down, every minute, back to the
// app, Premium's "قريبًا", French, and the card of Home.
// Run it with: flutter test test/alerts_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/alerts_service.dart';
import 'package:looz_mobile/features/alerts/alert_widgets.dart';
import 'package:looz_mobile/features/alerts/alerts_page.dart';
import 'package:looz_mobile/features/alerts/alerts_store.dart';
import 'package:looz_mobile/features/alerts/regional_screen.dart';
import 'package:looz_mobile/shared/widgets/looz_tab_bar.dart';
import 'package:looz_mobile/shared/widgets/speaker_button.dart';
import 'package:looz_mobile/shared/widgets/symbol_text.dart';

import 'fake_alerts_service.dart';
import 'test_helpers.dart';

/// Starts the app (a farmer of Sfax) on [tab], with [alerts].
Future<FakeAlertsService> startApp(
  WidgetTester tester, {
  FakeAlertsService? alerts,
  AppTab tab = AppTab.alerts,
  Plan plan = Plan.paid,
  String lang = 'ar',
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  appLocale.value = Locale(lang);
  currentPlan.value = plan;
  logInTestUser(lang);
  useFakeCommunity(lang);
  final fake = useAlerts(alerts);
  currentTab.value = tab;
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  return fake;
}

final arabic = RegExp('[؀-ۿ]');

/// The number on the bell ('' = none).
String bellNumber(WidgetTester tester) {
  final texts = find.descendant(
    of: find.byType(LoozTabBar),
    matching: find.byType(Text),
  );
  for (final element in texts.evaluate()) {
    final text = (element.widget as Text).data ?? '';
    if (RegExp(r'^\d+\+?$').hasMatch(text)) return text;
  }
  return '';
}

/// The titles of the alert cards, from the top.
List<String> cardTitles(WidgetTester tester) =>
    [
      for (final title in [
        'صقيع الليلة',
        'موجة حرّ',
        'أمطار غزيرة غدًا',
        'برد',
      ])
        if (find.text(title).evaluate().isNotEmpty) title,
    ]..sort(
      (a, b) => tester
          .getTopLeft(find.text(a).first)
          .dy
          .compareTo(tester.getTopLeft(find.text(b).first).dy),
    );

Future<void> tap(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets(
    'the tab: the most serious first, "جديد", the bell, the subtitle',
    (tester) async {
      await startApp(tester);
      expect(find.byType(AlertsPage), findsOneWidget);
      expect(find.text('التنبيهات'), findsWidgets);
      expect(find.text('3 تحتاج انتباهك'), findsOneWidget);
      expect(find.text('في منطقتك · صفاقس'), findsOneWidget);
      expect(cardTitles(tester), [
        'صقيع الليلة',
        'موجة حرّ',
        'أمطار غزيرة غدًا',
      ]);
      // The second line: the first thing to do, or the severity (no advice).
      expect(find.text('غطّ الأشجار الصغيرة'), findsOneWidget);
      expect(find.text('معلومة'), findsOneWidget);
      // Frost and rain were not opened yet.
      expect(find.text('جديد'), findsNWidgets(2));
      expect(bellNumber(tester), '2');
      await closeApp(tester);
    },
  );

  testWidgets('an alert: what is happening, the steps, until when, opened', (
    tester,
  ) async {
    final fake = await startApp(tester);
    await tap(tester, find.text('صقيع الليلة'));
    expect(find.byType(RegionalScreen), findsOneWidget);
    expect(find.text('تنبيه في منطقتك'), findsOneWidget);
    expect(find.text('صفاقس'), findsOneWidget);
    expect(find.text('خطر'), findsOneWidget);
    expect(find.text('صقيع'), findsOneWidget);
    expect(
      find.text('برد شديد بعد منتصف الليل. الأزهار والأشجار الصغيرة في خطر.'),
      findsOneWidget,
    );
    expect(find.text('ماذا أفعل؟'), findsOneWidget);
    Finder step(String n) =>
        find.descendant(of: find.byType(AdviceSteps), matching: find.text(n));
    expect(step('1'), findsOneWidget);
    expect(find.text('غطّ الأشجار الصغيرة'), findsOneWidget);
    expect(step('2'), findsOneWidget);
    expect(find.text('اسقِ قبل الليل'), findsOneWidget);
    expect(find.text('صالح حتى 16/11 على الساعة 08:00'), findsOneWidget);
    expect(find.text('3 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    // Opened: saved, no more "جديد", one less on the bell.
    expect(fake.calls, contains('read frost'));
    expect(bellNumber(tester), '1');
    // 🔊 reads aloud later.
    await tap(tester, find.byType(SpeakerButton));
    expect(find.text('قريبًا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    Navigator.of(tester.element(find.byType(RegionalScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('جديد'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('"أنا أيضًا": once, the count, "تراجع"', (tester) async {
    final fake = await startApp(tester);
    await tap(tester, find.text('صقيع الليلة'));
    await tap(tester, find.text('أنا أيضًا'));
    expect(fake.calls, contains('meToo frost true'));
    expect(find.text('4 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SymbolText && w.text == '✓ أنا أيضًا'),
      findsOneWidget,
    );
    // Once: no button "أنا أيضًا" any more.
    expect(find.text('أنا أيضًا'), findsNothing);
    await tap(tester, find.text('تراجع').first);
    expect(fake.calls, contains('meToo frost false'));
    expect(find.text('3 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    expect(find.text('أنا أيضًا'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets(
    '"تمّ": "أحسنت!", the end of the list, not on the bell, "تراجع"',
    (tester) async {
      final fake = await startApp(tester);
      await tap(tester, find.text('صقيع الليلة'));
      await tap(tester, find.text('تمّ'));
      expect(fake.calls, contains('done frost true'));
      expect(find.text('أحسنت!'), findsOneWidget);
      expect(find.text('قمت بما يلزم.'), findsOneWidget);
      Navigator.of(tester.element(find.byType(RegionalScreen))).pop();
      await tester.pumpAndSettle();
      // At the end of the list, "تمّ" on its card; 2 left to do.
      expect(cardTitles(tester), [
        'موجة حرّ',
        'أمطار غزيرة غدًا',
        'صقيع الليلة',
      ]);
      expect(find.text('2 تحتاج انتباهك'), findsOneWidget);
      expect(bellNumber(tester), '1');

      // Taken back: at the top again.
      await tap(tester, find.text('صقيع الليلة'));
      await tap(tester, find.text('تراجع'));
      expect(fake.calls, contains('done frost false'));
      expect(find.text('أحسنت!'), findsNothing);
      Navigator.of(tester.element(find.byType(RegionalScreen))).pop();
      await tester.pumpAndSettle();
      expect(cardTitles(tester).first, 'صقيع الليلة');
      await closeApp(tester);
    },
  );

  testWidgets(
    'an alert without advice: no "ماذا أفعل؟", no "تمّ", no end date',
    (tester) async {
      await startApp(tester);
      await tap(tester, find.text('أمطار غزيرة غدًا'));
      expect(find.text('ماذا أفعل؟'), findsNothing);
      expect(find.text('تمّ'), findsNothing);
      expect(find.text('صالح حتى إشعار آخر'), findsOneWidget);
      expect(find.text('12 فلاحًا قالوا: أنا أيضًا'), findsOneWidget);
      expect(find.text('معلومة'), findsOneWidget);
      await closeApp(tester);
    },
  );

  testWidgets('one sentence of advice per step; nobody yet: "كن أول من يقول"', (
    tester,
  ) async {
    await startApp(tester);
    await tap(tester, find.text('موجة حرّ'));
    expect(find.text('اسقِ في الصباح الباكر.'), findsOneWidget);
    expect(find.text('لا تسقِ في الظهر.'), findsOneWidget);
    expect(find.text('كن أول من يقول: أنا أيضًا'), findsOneWidget);
    await tap(tester, find.text('أنا أيضًا'));
    expect(find.text('فلاح واحد قال: أنا أيضًا'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('ended by an admin while open: "انتهى هذا التنبيه." and back', (
    tester,
  ) async {
    final fake = await startApp(tester);
    await tap(tester, find.text('صقيع الليلة'));
    fake.end('frost'); // the admin taps "Terminer"
    await tap(tester, find.text('أنا أيضًا'));
    expect(find.text('انتهى هذا التنبيه.'), findsOneWidget);
    expect(find.text('أنا أيضًا'), findsNothing);
    await tap(tester, find.text('رجوع إلى التنبيهات'));
    expect(find.byType(RegionalScreen), findsNothing);
    expect(find.text('صقيع الليلة'), findsNothing);
    expect(cardTitles(tester), ['موجة حرّ', 'أمطار غزيرة غدًا']);
    await closeApp(tester);
  });

  testWidgets('no internet on a button: a message, nothing changes', (
    tester,
  ) async {
    final fake = await startApp(tester);
    await tap(tester, find.text('صقيع الليلة'));
    fake.offline = true;
    await tap(tester, find.text('أنا أيضًا'));
    expect(
      find.text('لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(find.text('3 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    expect(find.text('أنا أيضًا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets(
    'no alert in the region: the calm card, Home says "كل شيء بخير"',
    (tester) async {
      await startApp(tester, alerts: FakeAlertsService(), tab: AppTab.home);
      expect(find.text('كل شيء بخير'), findsOneWidget);
      expect(find.text('لا تنبيه في منطقتك'), findsOneWidget);
      await tap(tester, find.text('كل شيء بخير'));
      expect(find.byType(AlertsPage), findsOneWidget);
      expect(find.text('لا تنبيه في منطقتك. كل شيء هادئ.'), findsOneWidget);
      expect(find.text('لا تنبيه اليوم'), findsOneWidget);
      expect(bellNumber(tester), '');
      await closeApp(tester);
    },
  );

  testWidgets('Home: the most important alert, then the next one when done', (
    tester,
  ) async {
    final fake = await startApp(tester, tab: AppTab.home);
    expect(find.text('صقيع الليلة'), findsOneWidget);
    expect(find.text('موجة حرّ'), findsNothing);
    await tap(tester, find.text('صقيع الليلة'));
    expect(find.byType(RegionalScreen), findsOneWidget);
    await tap(tester, find.text('تمّ'));
    Navigator.of(tester.element(find.byType(RegionalScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('موجة حرّ'), findsOneWidget);
    expect(fake.calls, contains('done frost true'));
    await closeApp(tester);
  });

  testWidgets('no internet: "لا يوجد إنترنت", then "حاول مرة أخرى" loads', (
    tester,
  ) async {
    final fake = FakeAlertsService.sample()..offline = true;
    await startApp(tester, alerts: fake);
    expect(find.text('لا يوجد إنترنت'), findsOneWidget);
    fake.offline = false;
    await tap(tester, find.text('حاول مرة أخرى'));
    expect(find.text('صقيع الليلة'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a new alert: pull down, every minute, back to the app', (
    tester,
  ) async {
    final fake = await startApp(tester, alerts: FakeAlertsService());
    expect(bellNumber(tester), '');

    // Pull down.
    fake.publish(sampleFrost());
    await tester.fling(
      find.descendant(
        of: find.byType(AlertsPage),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('صقيع الليلة'), findsOneWidget);
    expect(bellNumber(tester), '1');

    // An admin ends it: gone at the next minute.
    fake.end('frost');
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('صقيع الليلة'), findsOneWidget);
    await tester.pump(alertsRefreshEvery);
    await tester.pumpAndSettle();
    expect(find.text('صقيع الليلة'), findsNothing);
    expect(bellNumber(tester), '');

    // In the background: nothing loaded; back to the app: at once.
    final before = fake.calls.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(alertsRefreshEvery * 3);
    expect(fake.calls.length, before);
    fake.publish(sampleRain());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('أمطار غزيرة غدًا'), findsOneWidget);
    expect(bellNumber(tester), '1');
    await closeApp(tester);
  });

  testWidgets('the tab opened again: loaded again', (tester) async {
    final fake = await startApp(tester, alerts: FakeAlertsService());
    goToTab(tester.element(find.byType(AlertsPage)), AppTab.home);
    await tester.pumpAndSettle();
    fake.publish(sampleHeat());
    goToTab(tester.element(find.byType(MainShell)), AppTab.alerts);
    await tester.pumpAndSettle();
    expect(find.text('موجة حرّ'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Premium: "بستاني" (sensors: قريبًا); Free: not shown', (
    tester,
  ) async {
    await startApp(tester);
    await scrollTo(tester, find.text('تنبيهات حسّاسات بستانك'));
    expect(find.text('بستاني'), findsOneWidget);
    await tap(tester, find.text('الإشعارات على الهاتف'));
    expect(find.text('قريبًا'), findsWidgets);
    await closeApp(tester);
    resetAppState();

    await startApp(tester, plan: Plan.free);
    await scrollTo(tester, find.text('الإشعارات على الهاتف'));
    expect(find.text('تنبيهات حسّاسات بستانك'), findsNothing);
    expect(find.text('بستاني'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('French: the list and an alert, all in French', (tester) async {
    final fake = await startApp(tester, lang: 'fr');
    expect(find.text('Dans votre région · Sfax'), findsOneWidget);
    expect(find.text('Gel cette nuit'), findsOneWidget);
    expect(find.text('Nouveau'), findsNWidgets(2));
    await tap(tester, find.text('Gel cette nuit'));
    expect(find.text('Alerte régionale'), findsOneWidget);
    expect(find.text('Que faire ?'), findsOneWidget);
    expect(find.text('Couvrez les jeunes arbres'), findsOneWidget);
    expect(find.text("Valable jusqu'au 16/11 à 08:00"), findsOneWidget);
    expect(find.text('3 agriculteurs ont dit «\u00A0Moi\u00A0aussi\u00A0»'), findsOneWidget);
    await tap(tester, find.text('Moi aussi'));
    expect(find.text('4 agriculteurs ont dit «\u00A0Moi\u00A0aussi\u00A0»'), findsOneWidget);
    await tap(tester, find.text('Fait'));
    expect(find.text('Bravo !'), findsOneWidget);
    expect(fake.calls, containsAll(['meToo frost true', 'done frost true']));
    expect(textsOnScreen().where(arabic.hasMatch), isEmpty);
    await closeApp(tester);
  });

  testWidgets('logged out: the alerts of the last farmer are forgotten', (
    tester,
  ) async {
    await startApp(tester);
    expect(regionalAlerts.value.alerts, hasLength(3));
    await closeApp(tester); // like the log out: the main screen is closed
    expect(regionalAlerts.value.alerts, isNull);
    expect(regionalAlerts.value.unreadCount, 0);
    currentUser.value = null;
    await refreshAlerts(); // nobody logged in: nothing loaded
    expect(regionalAlerts.value.alerts, isNull);
  });

  test('advice: one step per line, or one per sentence', () {
    expect(sampleFrost().adviceSteps('ar'), [
      'غطّ الأشجار الصغيرة',
      'اسقِ قبل الليل',
    ]);
    expect(sampleHeat().adviceSteps('fr'), [
      'Arrosez tôt le matin.',
      "N'arrosez pas à midi.",
    ]);
    expect(sampleRain().adviceSteps('ar'), isEmpty);
    expect(sampleRain().hasAdvice, isFalse);
  });

  test('the database rows become alerts', () {
    final alert = RegionalAlert.fromRow({
      'id': 'a1',
      'kind': 'frost',
      'severity': 'danger',
      'title_ar': 'صقيع',
      'title_fr': 'Gel',
      'body_ar': 'برد',
      'body_fr': 'Froid',
      'advice_ar': null,
      'advice_fr': null,
      'starts_at': '2026-11-14T10:00:00+00:00',
      'ends_at': null,
      'updated_at': '2026-11-14T10:00:00+00:00',
      'seen_count': 2,
      'me_too': true,
      'is_new': false,
      'done': true,
    });
    expect(alert.kind, AlertKind.frost);
    expect(alert.severity, AlertSeverity.danger);
    expect(alert.endsAt, isNull);
    expect(alert.seenCount, 2);
    expect(alert.meToo, isTrue);
    expect(alert.unread, isFalse);
    expect(alert.title('fr'), 'Gel');
  });
}
