// Shared helpers for the tests.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/alerts_service.dart';
import 'package:looz_mobile/data/diagnosis_service.dart';
import 'package:looz_mobile/data/ml_service.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/alerts/alerts_store.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_live_store.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_tab.dart';
import 'package:looz_mobile/features/premium/demo_card_form.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';

import 'fake_alerts_service.dart';
import 'fake_auth_service.dart';
import 'fake_diagnosis_service.dart';
import 'fake_ml_service.dart';
import 'fake_community_service.dart';
import 'fake_orchard_service.dart';
import 'fake_payment_service.dart';
import 'fake_photo_picker.dart';
import 'fake_voice.dart';

/// Tests use a font where every letter is a square: load Cairo instead,
/// so the screens are laid out like in the app (call it in setUpAll).
Future<void> loadAppFonts() async {
  final cairo = FontLoader('Cairo');
  for (final weight in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    cairo.addFont(rootBundle.load('assets/fonts/Cairo-$weight.ttf'));
  }
  await cairo.load();
}

/// Tests run on an 800 x 600 screen by default: use a phone screen
/// instead (390 x 844, like the screenshots of the design).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Like the phone setting "remove animations": the voice screen and the
/// petals stay still, so `pumpAndSettle` can finish.
void noAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The app keeps the language, plan, tab, user, community, camera, payment,
/// orchard and demo state in global values: put them back after each test
/// (and forget what the "phone" remembered, like the language). By default
/// the user has Premium and the demo orchard (fake_orchard_service.dart).
void resetAppState() {
  appLocale.value = const Locale('ar');
  currentPlan.value = Plan.paid;
  currentTab.value = AppTab.home;
  orchardPanelOpen.value = false;
  currentUser.value = null;
  communityService = FakeCommunityService();
  alertsService = FakeAlertsService();
  diagnosisService = FakeDiagnosisService();
  FakeVoice(); // the voice assistant: fake Google, microphone, loudspeaker
  clearAlerts();
  mlService = FakeMlService(const OrchardLive()); // no prediction yet
  clearOrchardLive();
  photoPicker = FakePhotoPicker();
  paymentService = FakePaymentService();
  orchardService = FakeOrchardService(demoOrchard());
  SharedPreferences.setMockInitialValues({});
}

/// Uses fake regional alerts ([fake] = the 3 sample alerts by default):
/// returns them, to publish or end one, or to check what was saved.
FakeAlertsService useAlerts([FakeAlertsService? fake]) {
  final alerts = fake ?? FakeAlertsService.sample();
  alertsService = alerts;
  clearAlerts();
  return alerts;
}

/// Uses fake live data of the orchard ([fake] = the demo: zone B short of
/// water): returns it, to push a change ("Realtime") or check what was read.
FakeMlService useMl([FakeMlService? fake]) {
  final ml = fake ?? FakeMlService();
  mlService = ml;
  clearOrchardLive();
  return ml;
}

/// Uses a fake photo diagnosis ([fake] = "shot hole, probably" by default):
/// returns it, to change the answer, fail, or check what was linked.
FakeDiagnosisService useDiagnosis([FakeDiagnosisService? fake]) {
  final diagnosis = fake ?? FakeDiagnosisService();
  diagnosisService = diagnosis;
  return diagnosis;
}

/// Uses a fake orchard: [orchard] (null = none drawn yet). Returns it, to
/// make the next read fail or to count the reads.
FakeOrchardService useOrchard(MyOrchard? orchard) {
  final fake = FakeOrchardService(orchard);
  orchardService = fake;
  return fake;
}

/// Uses a fake community (no internet) with 3 questions written in [lang]:
/// returns it, to add questions or to check what was written. The camera
/// and the gallery are fake too (see usePhotoPicker).
FakeCommunityService useFakeCommunity([String lang = 'ar']) {
  final fake = FakeCommunityService.sample(lang);
  communityService = fake;
  photoPicker = FakePhotoPicker();
  return fake;
}

/// Uses a fake camera and gallery: returns it, to choose what they give.
FakePhotoPicker usePhotoPicker({bool hasCamera = true}) {
  final fake = FakePhotoPicker(hasCamera: hasCamera);
  photoPicker = fake;
  return fake;
}

/// Uses a fake paid pack and a fake demo payment (no internet), linked to
/// the fake login [auth]: returns it, to draw an orchard, turn the demo off...
FakePaymentService usePayments([FakeAuthService? auth]) {
  final fake = FakePaymentService(auth: auth);
  paymentService = fake;
  return fake;
}

/// Uses a fake login system (no internet): returns it, to add accounts or
/// to check what was saved.
FakeAuthService useFakeAuth() {
  final fake = FakeAuthService();
  authService = fake;
  return fake;
}

/// A logged-in farmer whose name is written in [lang] (like a real user
/// would), for the screens that show the name (Home, Profile, welcome).
void logInTestUser([String lang = 'ar']) {
  final fake = useFakeAuth();
  final phone = '+21650000002';
  currentUser.value = lang == 'ar'
      ? fake.addUser(
          phone,
          firstName: 'محمد',
          lastName: 'بن سالم',
          language: 'ar',
        )
      : fake.addUser(phone, language: 'fr');
  fake.loggedIn = phone;
}

/// Scrolls the page until [finder] is built (the list only builds what is
/// near the screen), then shows it above the bottom bars.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Scrolls to [finder] (above the bottom bars), then taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The box under the question [label] of the sign-up screen "معلوماتك".
Finder signUpField(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// Opens the list of the governorates ("اختر ولايتك") and taps [name].
Future<void> pickGovernorate(WidgetTester tester, String name) async {
  final l10n = lookupAppLocalizations(appLocale.value);
  await scrollAndTap(tester, find.text(l10n.chooseGovernorate).first);
  await tester.scrollUntilVisible(
    find.text(name),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// A public test card number that the demo payment accepts, and the one it
/// always refuses. Only typed in the demo form: never sent anywhere.
const acceptedTestCard = '4242424242424242';
const refusedTestCard = '4000000000000002';

/// Types a card in the demo payment form (number, expiry, code, name).
Future<void> typeDemoCard(
  WidgetTester tester, {
  String number = acceptedTestCard,
  String expiry = '1230',
  String code = '123',
  String name = 'Mohamed Ben Salem',
}) async {
  final boxes = find.descendant(
    of: find.byType(DemoCardForm),
    matching: find.byType(TextField),
  );
  await tester.enterText(boxes.at(0), number);
  await tester.enterText(boxes.at(1), expiry);
  await tester.enterText(boxes.at(2), code);
  await tester.enterText(boxes.at(3), name);
  await tester.pump();
}

/// "★ تأكيد" on the payment screen, then the ~2 seconds of "جاري التحقق من
/// الدفع…" ([checking] false: a card the form refuses, nothing is checked).
Future<void> confirmDemoPayment(
  WidgetTester tester, {
  bool checking = true,
}) async {
  final l10n = lookupAppLocalizations(appLocale.value);
  final button = findTextWithSymbol('★ ${l10n.confirm}');
  await scrollTo(tester, button);
  await tester.tap(button);
  await tester.pump();
  if (checking) {
    expect(find.text(l10n.checkingPayment), findsOneWidget);
    await tester.pump(PaymentScreen.checkingTime);
  }
  await tester.pumpAndSettle();
}

/// Closes the screens (stops their timers) at the end of a test.
Future<void> closeApp(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

/// Finds a text that may contain a drawn symbol (★, ✿...): the symbols
/// are not letters, so only the longest part without them is searched.
Finder findTextWithSymbol(String text) {
  final parts = text.split(RegExp('[★✿⌫←→✓◆]')).map((p) => p.trim()).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return find.textContaining(parts.first, findRichText: true);
}

/// Every text on the screen (the screen on top, not the hidden ones).
List<String> textsOnScreen() => [
  for (final element in find.byType(RichText).evaluate())
    (element.widget as RichText).text.toPlainText(),
];
