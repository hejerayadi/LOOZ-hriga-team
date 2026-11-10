// Checks the two packs (migration 011): who can use what, and the locked
// screens. Run it with: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/features/ask/ask_screen.dart';
import 'package:looz_mobile/features/ask/voice_screen.dart';
import 'package:looz_mobile/features/camera/camera_screen.dart';
import 'package:looz_mobile/features/community/community_page.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/features/premium/qr_screen.dart';
import 'package:looz_mobile/shared/widgets/assistant_button.dart';
import 'package:looz_mobile/shared/widgets/camera_button.dart';
import 'package:looz_mobile/shared/widgets/symbol_text.dart';

import 'fake_auth_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  // The plan, language and tab are shared by all tests: put them back.
  tearDown(resetAppState);

  test('each feature needs the right pack: Free = community and regional '
      'alerts, everything else = Premium', () {
    const free = [Feature.community, Feature.regionalAlerts];
    const paid = [
      Feature.assistant,
      Feature.orchard3d,
      Feature.photoDiagnosis,
      Feature.treeAlerts,
      Feature.liveZoneData,
      Feature.zoneAlerts,
      Feature.aiPredictions,
    ];
    expect({...free, ...paid}, Feature.values.toSet());
    for (final f in free) {
      expect(canUse(f, Plan.free), isTrue, reason: f.name);
    }
    for (final f in paid) {
      expect(canUse(f, Plan.free), isFalse, reason: f.name);
      expect(canUse(f, Plan.paid), isTrue, reason: f.name);
    }
  });

  test('the pack names of the database (the old ones = Premium)', () {
    expect(planFromName('free'), Plan.free);
    expect(planFromName('paid'), Plan.paid);
    expect(planFromName('essential'), Plan.paid);
    expect(planFromName('connected'), Plan.paid);
    expect(planFromName(null), Plan.free);
    expect(planFromName('gold'), Plan.free);
  });

  testWidgets('Free: the 3D orchard, the photos, the assistant and the voice '
      'are locked; the community is not', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: MainShell()));

    // The "بستاني ★" tab shows the design's locked screen.
    await tester.tap(findTextWithSymbol('بستاني ★'));
    await tester.pumpAndSettle();
    expect(find.text('بستانك في جيبك'), findsOneWidget);
    expect(findTextWithSymbol('★ ابدأ بريميوم'), findsOneWidget);

    // The camera (photo diagnosis): the locked screen.
    await tester.tap(findTextWithSymbol('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CameraButton));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);

    // The assistant bar "اسأل المساعد": the locked screen.
    await tester.tap(findTextWithSymbol('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);

    // The community: open.
    await tester.tap(findTextWithSymbol('المجتمع'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityPage), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Free, "اسأل": writing to the community works, "تكلّم" is '
      'locked', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: AskScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تكلّم'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceScreen), findsNothing);
    expect(currentTab.value, AppTab.orchard); // the locked screen
    await closeApp(tester);
  });

  testWidgets('Premium: nothing locked (camera and assistant open)', (
    tester,
  ) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    expect(find.text('بستانك في جيبك'), findsNothing);
    expect(canUse(Feature.orchard3d), isTrue);

    await tester.tap(find.byType(CameraButton));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
    await closeApp(tester);

    await tester.pumpWidget(const LoozApp(home: MainShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Premium screen: Free vs Premium, the price of a zone; nothing '
      'drawn yet = "ارسم بستانك"', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    logInTestUser();
    usePayments(authService as FakeAuthService);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: PremiumScreen()));
    await tester.pumpAndSettle();
    expect(find.text('مجاني'), findsOneWidget);
    expect(findTextWithSymbol('✓ تنبيهات منطقتك'), findsOneWidget);
    expect(findTextWithSymbol('★ Premium'), findsOneWidget);
    expect(findTextWithSymbol('✓ خريطة البستان'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SymbolText && w.text == '✓ المساعد'),
      findsOneWidget,
    );
    expect(find.text('إلغاء في أي وقت'), findsOneWidget);
    // The price of a zone, from the database.
    expect(find.text('8 د.ت للمنطقة / 30 يومًا'), findsOneWidget);

    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    expect(find.byType(DesignerStartScreen), findsOneWidget);
    expect(find.text('ارسم بستانك'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Premium screen with an orchard: the bill (4 zones = 32 DT), '
      'the demo payment, then the QR screen', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    logInTestUser();
    final payments = usePayments(authService as FakeAuthService)
      ..drawOrchard(4, areaHa: 2.37);
    currentPlan.value = Plan.free;
    await tester.pumpWidget(const LoozApp(home: PremiumScreen()));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));

    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('بريميوم'), findsOneWidget);
    expect(find.text('32 د.ت / 30 يومًا'), findsOneWidget);
    expect(find.text('4 مناطق'), findsOneWidget);
    await typeDemoCard(tester);
    await confirmDemoPayment(tester);
    expect(find.text('تم الدفع!'), findsOneWidget);
    expect(payments.calls, contains('pay accepted'));
    expect(currentPlan.value, Plan.paid);
    await tapAndWaitPlans(tester, find.text('متابعة'));
    expect(find.byType(QrScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Profile: the test switch shows the 2 packs and changes the '
      'plan', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    await tester.tap(find.text('حسابي')); // the Profile tab
    await tester.pumpAndSettle();

    // The switch shows the 2 packs (debug builds only).
    expect(find.text('وضع التجربة: تغيير الخطة'), findsOneWidget);
    expect(find.text('بريميوم'), findsOneWidget);
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

/// Scrolls to it if needed, taps it, and waits for the next screen.
Future<void> tapAndWaitPlans(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
