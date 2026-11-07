// Checks the subscription plans: who can use what, and the locked screens.
// Run it with: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/features/camera/camera_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/shared/widgets/camera_button.dart';

import 'fake_auth_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  // The plan, language and tab are shared by all tests: put them back.
  tearDown(resetAppState);

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

  testWidgets('free plan: the 3D orchard and the photos are locked', (
    tester,
  ) async {
    usePhoneScreen(tester);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: MainShell()));

    // The "بستاني ★" tab shows the design's locked screen.
    await tester.tap(findTextWithSymbol('بستاني ★'));
    await tester.pumpAndSettle();
    expect(find.text('بستانك في جيبك'), findsOneWidget);
    expect(findTextWithSymbol('★ ابدأ بريميوم'), findsOneWidget);

    // The camera (photo diagnosis) shows the locked screen too.
    await tester.tap(findTextWithSymbol('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CameraButton));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);
  });

  testWidgets('connected plan: nothing locked', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    expect(find.textContaining('Passer à'), findsNothing);
    expect(find.text('بستانك في جيبك'), findsNothing);
    // (The 3D orchard itself needs a real WebView: not testable here.)
    expect(canUse(Feature.orchard3d), isTrue);

    await tester.tap(find.byType(CameraButton));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
  });

  testWidgets('premium screen: free vs Premium, the price, then Essential '
      'with the demo payment', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    logInTestUser();
    usePayments(authService as FakeAuthService);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: PremiumScreen()));
    await tester.pumpAndSettle();
    expect(find.text('مجاني'), findsOneWidget);
    expect(findTextWithSymbol('★ Premium'), findsOneWidget);
    expect(findTextWithSymbol('✓ خريطة البستان'), findsOneWidget);
    expect(find.text('إلغاء في أي وقت'), findsOneWidget);
    // The price of the smallest pack, from the database.
    expect(find.textContaining('15 د.ت'), findsOneWidget);

    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    await scrollAndTap(tester, find.text('أساسي'));
    await scrollAndTap(tester, find.text('متابعة'));
    expect(find.byType(PaymentScreen), findsOneWidget);
    await typeDemoCard(tester);
    await confirmDemoPayment(tester);
    expect(find.text('تم الدفع!'), findsOneWidget);
    expect(currentPlan.value, Plan.essential);
    await closeApp(tester);
  });

  testWidgets('profile: the test switch changes the plan', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    await tester.tap(find.text('حسابي')); // the Profile tab
    await tester.pumpAndSettle();

    // The switch shows the 3 plans (debug builds only).
    expect(find.text('وضع التجربة: تغيير الخطة'), findsOneWidget);
    expect(find.text('متصل'), findsOneWidget);
    // "مجاني" is also under "خطتي" (the pack now): the switch is the last one.
    expect(find.text('مجاني'), findsNWidgets(2));
    await tester.ensureVisible(find.text('مجاني').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مجاني').last);
    await tester.pumpAndSettle();
    expect(currentPlan.value, Plan.free);

    // The "بستاني ★" tab updates at once: now locked.
    await tester.tap(findTextWithSymbol('بستاني ★'));
    await tester.pumpAndSettle();
    expect(findTextWithSymbol('★ ابدأ بريميوم'), findsOneWidget);
  });
}
