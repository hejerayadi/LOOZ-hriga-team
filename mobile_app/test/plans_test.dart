// Checks the subscription plans: who can use what, and the locked screens.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/strings/app_strings.dart';
import 'package:looz_mobile/features/alerts/alerts_page.dart';
import 'package:looz_mobile/features/plans/plans_screen.dart';

void main() {
  // currentPlan is shared by all tests: put it back after each one.
  tearDown(() => currentPlan.value = Plan.connected);

  test('each feature needs the right plan', () {
    const free = [Feature.community, Feature.assistant, Feature.regionalAlerts];
    const essential = [
      Feature.landSetup,
      Feature.orchardDrawing,
      Feature.orchard3d,
      Feature.aiLayout,
      Feature.photoDiagnosis,
      Feature.treeAlerts,
    ];
    const connected = [
      Feature.liveZoneData,
      Feature.zoneAlerts,
      Feature.aiPredictions,
    ];
    for (final f in free) {
      expect(canUse(f, Plan.free), isTrue, reason: f.name);
    }
    for (final f in essential) {
      expect(canUse(f, Plan.free), isFalse, reason: f.name);
      expect(canUse(f, Plan.essential), isTrue, reason: f.name);
    }
    for (final f in connected) {
      expect(canUse(f, Plan.essential), isFalse, reason: f.name);
      expect(canUse(f, Plan.connected), isTrue, reason: f.name);
    }
  });

  test('assistant: 10 questions a day on free, no limit on paid plans', () {
    expect(assistantDailyLimit(Plan.free), 10);
    expect(assistantDailyLimit(Plan.essential), isNull);
    expect(assistantDailyLimit(Plan.connected), isNull);
  });

  testWidgets('free plan: 3D and photos locked on "Mon verger"', (tester) async {
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    expect(find.text(AppStrings.feature(Feature.orchard3d)), findsOneWidget);
    expect(find.text(AppStrings.upgradeTo(Plan.essential)), findsNWidgets(2));
  });

  testWidgets('connected plan: nothing locked on "Mon verger"', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    expect(find.textContaining('Passer à'), findsNothing);
  });

  testWidgets('alerts: essential sees tree alerts, zone alerts locked', (
    tester,
  ) async {
    currentPlan.value = Plan.essential;
    await tester.pumpWidget(const MaterialApp(home: AlertsPage()));
    expect(find.text('Risque maladie'), findsOneWidget); // tree (photo)
    expect(find.text('Forte chaleur'), findsOneWidget); // regional
    expect(find.text('Sol sec'), findsNothing); // zone: locked
    expect(find.text(AppStrings.upgradeTo(Plan.connected)), findsOneWidget);
  });

  testWidgets('plans screen: "Contactez-nous" only on bigger plans', (
    tester,
  ) async {
    currentPlan.value = Plan.essential;
    await tester.pumpWidget(const MaterialApp(home: PlansScreen()));
    expect(find.text(AppStrings.yourPlan), findsOneWidget);
    await tester.scrollUntilVisible(find.text(AppStrings.contactUs), 300);
    expect(find.text(AppStrings.contactUs), findsOneWidget); // only Connecté
  });

  testWidgets('profile shows the plan, and the test switch changes it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.tap(find.text(AppStrings.tabProfile).last);
    await tester.pumpAndSettle();
    // Badge + test switch both show "Connecté".
    expect(find.text(AppStrings.plan(Plan.connected)), findsNWidgets(2));

    final freeSegment = find.descendant(
      of: find.byType(SegmentedButton<Plan>),
      matching: find.text(AppStrings.plan(Plan.free)),
    );
    await tester.ensureVisible(freeSegment);
    await tester.pumpAndSettle();
    await tester.tap(freeSegment);
    await tester.pumpAndSettle();
    expect(currentPlan.value, Plan.free);

    // "Mon verger" updates at once.
    await tester.tap(find.text(AppStrings.tabHome).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.upgradeTo(Plan.essential)), findsWidgets);
  });
}
