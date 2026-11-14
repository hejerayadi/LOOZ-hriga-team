// Every screen opens from its button(s), like in the design (App.tsx).
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/fake_data.dart';
import 'package:looz_mobile/features/alerts/alerts_page.dart';
import 'package:looz_mobile/features/alerts/regional_screen.dart';
import 'package:looz_mobile/features/ask/ask_screen.dart';
import 'package:looz_mobile/features/ask/voice_screen.dart';
import 'package:looz_mobile/features/camera/camera_screen.dart';
import 'package:looz_mobile/features/camera/result_screen.dart';
import 'package:looz_mobile/features/camera/thinking_screen.dart';
import 'package:looz_mobile/features/community/community_page.dart';
import 'package:looz_mobile/features/community/tips_screen.dart';
import 'package:looz_mobile/features/home/home_page.dart';
import 'package:looz_mobile/features/journal/journal_screen.dart';
import 'package:looz_mobile/features/map/map_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/features/premium/qr_screen.dart';
import 'package:looz_mobile/features/profile/profile_page.dart';
import 'package:looz_mobile/features/states/states_screen.dart';
import 'package:looz_mobile/shared/widgets/assistant_button.dart';
import 'package:looz_mobile/shared/widgets/camera_button.dart';
import 'package:looz_mobile/shared/widgets/mood_face.dart';
import 'package:looz_mobile/shared/widgets/speaker_button.dart';
import 'package:looz_mobile/shared/widgets/tip_row.dart';

import 'fake_auth_service.dart';
import 'test_helpers.dart';

/// Starts the app on the 5 tabs (Arabic), on a phone screen.
Future<void> startApp(WidgetTester tester, {Plan plan = Plan.paid}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  currentPlan.value = plan;
  useFakeCommunity();
  // A farmer of Sfax, with the 3 sample alerts of his region.
  if (currentUser.value == null) logInTestUser();
  useAlerts();
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
}

/// Taps something and waits for the new screen.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the page up, so its last button is above the bottom bars
/// (like a person would do on a phone).
Future<void> scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -300));
  await tester.pumpAndSettle();
}

/// Taps a tab of the tab bar.
Future<void> openTab(WidgetTester tester, String label) =>
    tapAndWait(tester, findTextWithSymbol(label).last);

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('Home: the alert, "اسأل", "دفتر" and "خريطة"', (tester) async {
    await startApp(tester);
    // The most important real alert of the region.
    await tapAndWait(tester, find.text('صقيع الليلة'));
    expect(find.byType(RegionalScreen), findsOneWidget);

    await openTab(tester, 'الرئيسية');
    await tapAndWait(tester, find.text('اسأل'));
    expect(find.byType(AskScreen), findsOneWidget);

    await openTab(tester, 'الرئيسية');
    await tapAndWait(tester, find.text('دفتر'));
    expect(find.byType(JournalScreen), findsOneWidget);
    // "حفظ" goes back.
    await tapAndWait(tester, find.text('حفظ'));
    expect(find.byType(HomePage), findsOneWidget);

    await tapAndWait(tester, find.text('خريطة'));
    expect(find.byType(MapScreen), findsOneWidget);
    // A tree on the map: its alerts come later ("قريبًا"), no fake alert.
    await tester.tap(find.byType(MoodFace).first);
    await tester.pump();
    expect(find.text('قريبًا'), findsOneWidget);
    expect(find.byType(MapScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Assistant bar: voice → thinking → answer', (tester) async {
    await startApp(tester);
    await tapAndWait(tester, find.byType(AssistantButton));
    expect(find.byType(VoiceScreen), findsOneWidget);
    expect(find.text('أنا أسمعك'), findsOneWidget);

    await tester.pump(listeningTime);
    await tester.pumpAndSettle();
    expect(find.byType(ThinkingScreen), findsOneWidget);

    await tester.pump(fakeThinkingTime);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);

    // "اسأل خبيرًا" opens the community.
    await tapAndWait(tester, find.text('اسأل خبيرًا'));
    expect(find.byType(CommunityPage), findsOneWidget);
  });

  testWidgets('Camera: shutter → thinking → result, and × closes it', (
    tester,
  ) async {
    await startApp(tester);
    await tapAndWait(tester, find.byType(CameraButton));
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.text('صوّر الورقة'), findsOneWidget);

    await tapAndWait(tester, find.bySemanticsLabel('الكاميرا'));
    expect(find.byType(ThinkingScreen), findsOneWidget);
    await tester.pump(fakeThinkingTime);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);

    await tapAndWait(tester, find.byType(CameraButton));
    await tapAndWait(tester, find.text('×'));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(CameraScreen), findsNothing);
  });

  testWidgets('Community: tips, ask, and the ways to ask', (tester) async {
    await startApp(tester);
    await openTab(tester, 'المجتمع');
    final tipSpeaker = find.descendant(
      of: find.byType(TipRow),
      matching: find.byType(SpeakerButton),
    );
    await tapAndWait(tester, tipSpeaker);
    expect(find.byType(TipsScreen), findsOneWidget);

    await openTab(tester, 'المجتمع');
    await scrollDown(tester);
    await tapAndWait(tester, find.text('اسأل سؤالًا'));
    expect(find.byType(AskScreen), findsOneWidget);

    await tapAndWait(tester, find.text('صورة'));
    expect(find.byType(CameraScreen), findsOneWidget);
    await tapAndWait(tester, find.text('×'));

    await openTab(tester, 'المجتمع');
    await scrollDown(tester);
    await tapAndWait(tester, find.text('اسأل سؤالًا'));
    await tapAndWait(tester, find.text('تكلّم'));
    expect(find.byType(VoiceScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Alerts: a regional alert, "أنا أيضًا", "تمّ"', (tester) async {
    await startApp(tester);
    await openTab(tester, 'التنبيهات');
    expect(find.byType(AlertsPage), findsOneWidget);

    await tapAndWait(tester, find.text('صقيع الليلة'));
    expect(find.byType(RegionalScreen), findsOneWidget);
    expect(find.text('3 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    await scrollDown(tester);
    await tapAndWait(tester, find.text('أنا أيضًا'));
    expect(find.text('4 فلاحين قالوا: أنا أيضًا'), findsOneWidget);
    await scrollDown(tester);
    await tapAndWait(tester, find.text('تمّ'));
    expect(find.text('أحسنت!'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Premium: locked → premium → payment → QR → map', (tester) async {
    // A farmer who drew his orchard (5 zones on 3 ha).
    logInTestUser();
    usePayments(authService as FakeAuthService).drawOrchard(5, areaHa: 3);
    await startApp(tester, plan: Plan.free);
    await openTab(tester, 'بستاني ★');
    expect(find.text('بستانك في جيبك'), findsOneWidget);

    await tapAndWait(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    expect(find.byType(PremiumScreen), findsOneWidget);

    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('40 د.ت / 30 يومًا'), findsOneWidget); // 5 zones x 8 DT

    // DEMO payment: a test card, "جاري التحقق…", paid.
    await typeDemoCard(tester);
    await confirmDemoPayment(tester);
    expect(find.text('تم الدفع!'), findsOneWidget);
    expect(currentPlan.value, Plan.paid);
    await scrollAndTap(tester, find.text('متابعة'));
    expect(find.byType(QrScreen), findsOneWidget);

    await tapAndWait(tester, find.text('فتح الخريطة'));
    expect(find.byType(MapScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('"ليس الآن" goes back (locked → Home, Premium → locked)', (
    tester,
  ) async {
    await startApp(tester, plan: Plan.free);
    await openTab(tester, 'بستاني ★');
    await tapAndWait(tester, find.text('ليس الآن'));
    expect(find.byType(HomePage), findsOneWidget);

    await openTab(tester, 'بستاني ★');
    await tapAndWait(tester, findTextWithSymbol('★ ابدأ بريميوم'));
    await tapAndWait(tester, find.text('ليس الآن'));
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Profile: "خطتي" and "حالات التطبيق"', (tester) async {
    await startApp(tester);
    await openTab(tester, 'حسابي');
    expect(find.byType(ProfilePage), findsOneWidget);

    await tapAndWait(tester, find.text('خطتي'));
    expect(find.byType(PremiumScreen), findsOneWidget);

    await openTab(tester, 'حسابي');
    await tapAndWait(tester, find.text('حالات التطبيق'));
    expect(find.byType(StatesScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Free plan: the camera and the map show the locked screen', (
    tester,
  ) async {
    await startApp(tester, plan: Plan.free);
    await tapAndWait(tester, find.byType(CameraButton));
    expect(find.byType(CameraScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);

    await openTab(tester, 'الرئيسية');
    await tapAndWait(tester, find.text('خريطة'));
    expect(find.byType(MapScreen), findsNothing);
    expect(find.text('بستانك في جيبك'), findsOneWidget);
    await closeApp(tester);
  });
}
