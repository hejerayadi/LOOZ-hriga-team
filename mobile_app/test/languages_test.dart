// Arabic selected = only Arabic on every screen; French = only French.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/alerts_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/alerts/regional_screen.dart';
import 'package:looz_mobile/features/ask/ask_screen.dart';
import 'package:looz_mobile/features/ask/voice_screen.dart';
import 'package:looz_mobile/features/camera/camera_screen.dart';
import 'package:looz_mobile/features/camera/result_screen.dart';
import 'package:looz_mobile/features/camera/thinking_screen.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/features/community/photo_viewer.dart';
import 'package:looz_mobile/features/community/post_screen.dart';
import 'package:looz_mobile/features/community/tips_screen.dart';
import 'package:looz_mobile/features/community/write_post_screen.dart';
import 'package:looz_mobile/features/journal/journal_screen.dart';
import 'package:looz_mobile/features/map/map_screen.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/role_screen.dart';
import 'package:looz_mobile/features/onboarding/sign_up_info_screen.dart';
import 'package:looz_mobile/features/onboarding/start_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/data/orchard_design.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_designer/design_session.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';
import 'package:looz_mobile/features/orchard_designer/outline_screen.dart';
import 'package:looz_mobile/features/orchard_designer/review_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zone_details_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zones_screen.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/features/premium/qr_screen.dart';
import 'package:looz_mobile/features/states/states_screen.dart';

import 'fake_alerts_service.dart';
import 'fake_community_service.dart';
import 'fake_orchard_service.dart';
import 'fake_photo_picker.dart';
import 'test_helpers.dart';

// Words the design shows the same in both languages.
// (Longest first: "العربية" contains "عربي".)
const sameInBoth = [
  'Français',
  'Premium',
  'LOOZ',
  'A-18',
  'XX',
  'FR',
  'العربية',
  'عربي',
];

final latin = RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]');

/// The letter of a zone ("المنطقة A", the 3D's labels): A to T in both
/// languages, like the database (zones.letter).
final zoneLetterAlone = RegExp('(?<![A-Za-z])[A-T](?![A-Za-z])');

/// A bill of 4 zones (a new month) and one of 6 zones on a pack of 4.
final monthQuote = OrchardQuote.fromRow({
  'area_ha': 2.37,
  'zones': 4,
  'billed_nodes': 4,
  'paid_nodes': 0,
  'price_per_node': 8000,
  'period_days': 30,
  'monthly_millimes': 32000,
  'kind': 'new',
  'due_now_millimes': 32000,
  'ends_at': null,
});
final extraQuote = OrchardQuote.fromRow({
  'area_ha': 2.37,
  'zones': 6,
  'billed_nodes': 6,
  'paid_nodes': 4,
  'price_per_node': 8000,
  'period_days': 30,
  'monthly_millimes': 48000,
  'kind': 'extra_nodes',
  'due_now_millimes': 8000,
  'ends_at': '2026-12-03T18:00:00Z',
});
final arabic = RegExp('[؀-ۿ]');

/// A draft of the designer: the demo outline, 4 automatic zones.
OrchardDesign designDraft({bool zones = true}) {
  final outline = demoOutline;
  final parts = splitByTrees(outline, [160, 210, 120, 190]);
  return OrchardDesign(
    step: DesignStep.review,
    outline: outline,
    zoneMethod: zones ? ZoneMethod.auto : null,
    zones: [
      if (zones)
        for (final (i, p) in parts.indexed)
          DesignZone(
            letter: zoneLetter(i),
            boundary: p,
            color: zoneColors[i],
            treeCount: 100 + 20 * i,
            type: ZoneType.values[i],
          ),
    ],
  );
}

DesignSession designSession({bool zones = true}) =>
    DesignSession(design: designDraft(zones: zones));

/// Every screen of the app: (name, screen, plan, tab, "done" state).
final screens = <(String, Widget, Plan, AppTab, bool)>[
  ('start', const StartScreen(), Plan.paid, AppTab.home, false),
  ('phone (sign in)', const PhoneScreen(), Plan.paid, AppTab.home, false),
  (
    'phone (sign up)',
    const PhoneScreen(signUp: true),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'code',
    const CodeScreen(phone: '+21650000001'),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'number that has an account',
    const AccountExistsScreen(),
    Plan.free,
    AppTab.home,
    false,
  ),
  ('who are you', const RoleScreen(), Plan.free, AppTab.home, false),
  (
    'your information (farmer)',
    const SignUpInfoScreen(role: UserRole.farmer),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'your information (expert)',
    const SignUpInfoScreen(role: UserRole.expert),
    Plan.free,
    AppTab.home,
    false,
  ),
  ('pack', const PackScreen(), Plan.free, AppTab.home, false),
  (
    'payment (sign-up)',
    PaymentScreen(quote: monthQuote, signUp: true),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'paid',
    PaymentResultScreen(paid: true, endsAt: DateTime(2026, 11, 30)),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'not paid',
    const PaymentResultScreen(paid: false),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'draw your orchard (sign-up)',
    const DesignerStartScreen(signUp: true),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'draw your orchard (in the app)',
    const DesignerStartScreen(),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'designer: the outline',
    OutlineScreen(session: designSession()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'designer: the zones (how)',
    ZonesScreen(session: designSession(zones: false)),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'designer: the zones (automatic)',
    ZonesScreen(session: designSession()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'designer: the details of the zones',
    ZoneDetailsScreen(session: designSession()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'designer: the review',
    ReviewScreen(session: designSession()),
    Plan.free,
    AppTab.home,
    false,
  ),
  ('welcome', const WelcomeScreen(), Plan.paid, AppTab.home, false),
  ('home', const MainShell(), Plan.paid, AppTab.home, false),
  ('community', const MainShell(), Plan.paid, AppTab.community, false),
  ('my orchard (locked)', const MainShell(), Plan.free, AppTab.orchard, false),
  ('my orchard (3D)', const MainShell(), Plan.paid, AppTab.orchard, false),
  (
    'my orchard (none drawn yet)',
    const MainShell(),
    Plan.paid,
    AppTab.orchard,
    false,
  ),
  ('alerts', const MainShell(), Plan.paid, AppTab.alerts, false),
  ('profile', const MainShell(), Plan.paid, AppTab.profile, false),
  (
    'community question',
    const _SamplePostScreen(),
    Plan.paid,
    AppTab.home,
    false,
  ),
  ('write a question', const WritePostScreen(), Plan.paid, AppTab.home, false),
  (
    'new post with a photo',
    const _NewPostWithPhoto(),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'community post with a photo',
    const _SamplePhotoPostScreen(),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'photo on the whole screen',
    PhotoViewer(image: MemoryImage(testPhotoBytes()), label: ''),
    Plan.paid,
    AppTab.home,
    false,
  ),
  ('tips', const TipsScreen(), Plan.paid, AppTab.home, false),
  ('ask', const AskScreen(), Plan.paid, AppTab.home, false),
  ('voice', const VoiceScreen(), Plan.paid, AppTab.home, false),
  ('camera', const CameraScreen(), Plan.paid, AppTab.home, false),
  ('thinking', const ThinkingScreen(), Plan.paid, AppTab.home, false),
  ('result', const ResultScreen(), Plan.paid, AppTab.home, false),
  // The regional alerts (written by the admins in both languages).
  ('alerts (free)', const MainShell(), Plan.free, AppTab.alerts, false),
  (
    'alerts (none in the region)',
    const MainShell(),
    Plan.paid,
    AppTab.alerts,
    false,
  ),
  (
    'regional alert (frost)',
    RegionalScreen(alert: sampleFrost()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'regional alert (frost, Moi aussi + done)',
    RegionalScreen(alert: sampleFrost().copyWith(meToo: true, done: true)),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'regional alert (heat)',
    RegionalScreen(alert: sampleHeat()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  (
    'regional alert (rain, no advice)',
    RegionalScreen(alert: sampleRain()),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'regional alert (ended while open)',
    RegionalScreen(alert: _endedAlert()),
    Plan.paid,
    AppTab.home,
    false,
  ),
  ('premium', const PremiumScreen(), Plan.paid, AppTab.home, false),
  (
    'payment (Premium, a month)',
    PaymentScreen(quote: monthQuote),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'payment (Premium, extra zones)',
    PaymentScreen(quote: extraQuote),
    Plan.paid,
    AppTab.home,
    false,
  ),
  ('qr', const QrScreen(), Plan.paid, AppTab.home, false),
  ('map', const MapScreen(), Plan.paid, AppTab.home, false),
  ('journal', const JournalScreen(), Plan.paid, AppTab.home, false),
  ('states', const StatesScreen(), Plan.paid, AppTab.home, false),
];

/// The texts of [screen] in [lang], without the words that are the same in
/// both languages.
Future<List<String>> textsOf(
  WidgetTester tester,
  (String, Widget, Plan, AppTab, bool) screen,
  String lang,
) async {
  final (name, widget, plan, tab, _) = screen;
  // A farmer whose name is written in this language, and a community
  // whose farmers write in this language.
  logInTestUser(lang);
  useFakeCommunity(lang);
  usePayments().drawOrchard(4, areaHa: 2.37);
  useOrchard(name.contains('none drawn') ? null : demoOrchard());
  useAlerts(
    name.contains('none in the region')
        ? FakeAlertsService()
        : FakeAlertsService.sample(),
  );
  appLocale.value = Locale(lang);
  currentPlan.value = plan;
  currentTab.value = tab;
  await tester.pumpWidget(LoozApp(home: widget));
  await tester.pump();
  await tester.pump(); // the alerts are loaded
  final texts = [
    for (var text in textsOnScreen())
      sameInBoth
          .fold(text, (t, word) => t.replaceAll(word, ''))
          .replaceAll(zoneLetterAlone, ''),
  ];
  await closeApp(tester);
  return texts;
}

/// An alert that an admin ended before it was opened (it is not in the
/// fake list any more): "انتهى هذا التنبيه.".
RegionalAlert _endedAlert() {
  final frost = sampleFrost();
  return RegionalAlert(
    id: 'ended',
    kind: frost.kind,
    severity: frost.severity,
    titleAr: frost.titleAr,
    titleFr: frost.titleFr,
    bodyAr: frost.bodyAr,
    bodyFr: frost.bodyFr,
    adviceAr: frost.adviceAr,
    adviceFr: frost.adviceFr,
    startsAt: frost.startsAt,
    endsAt: frost.endsAt,
    updatedAt: frost.updatedAt,
  );
}

/// The first question of the fake community (in the language of the test),
/// with its answers.
class _SamplePostScreen extends StatelessWidget {
  const _SamplePostScreen();

  @override
  Widget build(BuildContext context) =>
      PostScreen(post: (communityService as FakeCommunityService).posts.first);
}

/// The new post screen with a photo chosen (given back by the fake camera).
class _NewPostWithPhoto extends StatelessWidget {
  const _NewPostWithPhoto();

  @override
  Widget build(BuildContext context) {
    (photoPicker as FakePhotoPicker).lost ??= testPhotoBytes();
    return const WritePostScreen();
  }
}

/// A question of the fake community with a farmer's photo.
class _SamplePhotoPostScreen extends StatelessWidget {
  const _SamplePhotoPostScreen();

  @override
  Widget build(BuildContext context) {
    final fake = communityService as FakeCommunityService;
    final first = fake.posts.first;
    final post = Post(
      id: 'photo-post',
      type: PostType.question,
      text: first.text,
      photo: 'farmer-1/photo-post.jpg',
      createdAt: first.createdAt,
      author: first.author,
    );
    fake.photos[post.photo!] = testPhotoBytes();
    fake.comments[post.id] = fake.comments[first.id] ?? [];
    return PostScreen(post: post);
  }
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('Arabic: no French (or other Latin) text on any screen', (
    tester,
  ) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    for (final screen in screens) {
      final texts = await textsOf(tester, screen, 'ar');
      expect(texts, isNotEmpty, reason: screen.$1);
      final french = texts.where(latin.hasMatch).toList();
      expect(french, isEmpty, reason: 'French text on "${screen.$1}"');
    }
  });

  testWidgets('French: no Arabic text on any screen', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    for (final screen in screens) {
      final texts = await textsOf(tester, screen, 'fr');
      expect(texts, isNotEmpty, reason: screen.$1);
      final arabicTexts = texts.where(arabic.hasMatch).toList();
      expect(arabicTexts, isEmpty, reason: 'Arabic text on "${screen.$1}"');
    }
  });

  testWidgets('Arabic is right to left, French left to right', (tester) async {
    usePhoneScreen(tester);
    for (final (lang, direction) in [
      ('ar', TextDirection.rtl),
      ('fr', TextDirection.ltr),
    ]) {
      appLocale.value = Locale(lang);
      await tester.pumpWidget(const LoozApp(home: TipsScreen()));
      await tester.pump();
      final context = tester.element(find.byType(TipsScreen));
      expect(Directionality.of(context), direction, reason: lang);
    }
    await closeApp(tester);
  });

  test('Arabic and French have the same texts', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(ar.localeName, 'ar');
    expect(fr.localeName, 'fr');
    // A text missing in French would make the generated French class
    // fail to compile, so here we just check a few of them differ.
    expect(ar.homeTitle, isNot(fr.homeTitle));
    expect(ar.tabOrchard, isNot(fr.tabOrchard));
    expect(ar.zoneName('A'), isNot(fr.zoneName('A')));
  });
}
