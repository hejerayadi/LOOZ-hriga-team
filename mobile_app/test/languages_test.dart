// Arabic selected = only Arabic on every screen; French = only French.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/fake_data.dart';
import 'package:looz_mobile/features/alerts/alert_screen.dart';
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
import 'package:looz_mobile/features/onboarding/language_screen.dart';
import 'package:looz_mobile/features/onboarding/name_screen.dart';
import 'package:looz_mobile/features/onboarding/pack_screen.dart';
import 'package:looz_mobile/features/onboarding/payment_choice_screen.dart';
import 'package:looz_mobile/features/onboarding/phone_screen.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';
import 'package:looz_mobile/features/premium/premium_screen.dart';
import 'package:looz_mobile/features/premium/qr_screen.dart';
import 'package:looz_mobile/features/states/states_screen.dart';

import 'fake_community_service.dart';
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
final arabic = RegExp('[؀-ۿ]');

/// Every screen of the app: (name, screen, plan, tab, "done" state).
final screens = <(String, Widget, Plan, AppTab, bool)>[
  ('language', const LanguageScreen(), Plan.connected, AppTab.home, false),
  ('phone', const PhoneScreen(), Plan.connected, AppTab.home, false),
  (
    'code',
    const CodeScreen(phone: '+21650000001'),
    Plan.connected,
    AppTab.home,
    false,
  ),
  ('name', const NameScreen(), Plan.free, AppTab.home, false),
  ('pack', const PackScreen(), Plan.free, AppTab.home, false),
  (
    'pay now or later',
    const PaymentChoiceScreen(plan: Plan.essential),
    Plan.free,
    AppTab.home,
    false,
  ),
  (
    'payment (sign-up)',
    const PaymentScreen(plan: Plan.essential, forSignUp: true),
    Plan.free,
    AppTab.home,
    false,
  ),
  ('welcome', const WelcomeScreen(), Plan.connected, AppTab.home, false),
  ('home', const MainShell(), Plan.connected, AppTab.home, false),
  ('community', const MainShell(), Plan.connected, AppTab.community, false),
  ('my orchard (locked)', const MainShell(), Plan.free, AppTab.orchard, false),
  ('alerts', const MainShell(), Plan.connected, AppTab.alerts, false),
  ('profile', const MainShell(), Plan.connected, AppTab.profile, false),
  (
    'community question',
    const _SamplePostScreen(),
    Plan.connected,
    AppTab.home,
    false,
  ),
  (
    'write a question',
    const WritePostScreen(),
    Plan.connected,
    AppTab.home,
    false,
  ),
  (
    'new post with a photo',
    const _NewPostWithPhoto(),
    Plan.connected,
    AppTab.home,
    false,
  ),
  (
    'community post with a photo',
    const _SamplePhotoPostScreen(),
    Plan.connected,
    AppTab.home,
    false,
  ),
  (
    'photo on the whole screen',
    PhotoViewer(image: MemoryImage(testPhotoBytes()), label: ''),
    Plan.connected,
    AppTab.home,
    false,
  ),
  ('tips', const TipsScreen(), Plan.connected, AppTab.home, false),
  ('ask', const AskScreen(), Plan.connected, AppTab.home, false),
  ('voice', const VoiceScreen(), Plan.connected, AppTab.home, false),
  ('camera', const CameraScreen(), Plan.connected, AppTab.home, false),
  ('thinking', const ThinkingScreen(), Plan.connected, AppTab.home, false),
  ('result', const ResultScreen(), Plan.connected, AppTab.home, false),
  ('alert', const AlertScreen(), Plan.connected, AppTab.home, false),
  ('alert done', const AlertScreen(), Plan.connected, AppTab.home, true),
  ('regional', const RegionalScreen(), Plan.connected, AppTab.home, false),
  ('premium', const PremiumScreen(), Plan.connected, AppTab.home, false),
  ('payment', const PaymentScreen(), Plan.connected, AppTab.home, false),
  ('qr', const QrScreen(), Plan.connected, AppTab.home, false),
  ('map', const MapScreen(), Plan.connected, AppTab.home, false),
  ('journal', const JournalScreen(), Plan.connected, AppTab.home, false),
  ('states', const StatesScreen(), Plan.connected, AppTab.home, false),
];

/// The texts of [screen] in [lang], without the words that are the same in
/// both languages.
Future<List<String>> textsOf(
  WidgetTester tester,
  (String, Widget, Plan, AppTab, bool) screen,
  String lang,
) async {
  final (_, widget, plan, tab, done) = screen;
  // A farmer whose name is written in this language, and a community
  // whose farmers write in this language.
  logInTestUser(lang);
  useFakeCommunity(lang);
  appLocale.value = Locale(lang);
  currentPlan.value = plan;
  currentTab.value = tab;
  fakeTreeWatered.value = done;
  await tester.pumpWidget(LoozApp(home: widget));
  await tester.pump();
  final texts = [
    for (var text in textsOnScreen())
      sameInBoth.fold(text, (t, word) => t.replaceAll(word, '')),
  ];
  await closeApp(tester);
  return texts;
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
