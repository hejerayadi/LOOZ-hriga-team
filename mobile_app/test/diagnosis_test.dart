// The photo diagnosis (Bêta, paid pack) with a fake diagnosis and a fake
// camera (no internet, no model): the camera screen, "جاري النظر…", the
// result (likely, unsure, nothing), the marks, "اسأل خبيرًا" -> a question
// with the photo in the community, every failure, the limits of the day,
// Free = locked, French, the plural forms, the voice says "قريبًا", and
// the abjad letters of the zones.
// Run it with: flutter test test/diagnosis_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/zone_letters.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/data/diagnosis_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/ask/voice_screen.dart';
import 'package:looz_mobile/features/camera/camera_screen.dart';
import 'package:looz_mobile/features/camera/diagnosis_widgets.dart';
import 'package:looz_mobile/features/camera/result_screen.dart';
import 'package:looz_mobile/features/camera/thinking_screen.dart';
import 'package:looz_mobile/features/community/write_post_screen.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_data.dart';
import 'package:looz_mobile/shared/widgets/camera_button.dart';
import 'package:looz_mobile/shared/widgets/speaker_button.dart';

import 'fake_community_service.dart';
import 'fake_diagnosis_service.dart';
import 'fake_photo_picker.dart';
import 'test_helpers.dart';

final arabic = RegExp('[؀-ۿ]');

/// The app on Home, a farmer of Sfax with the paid pack (or [plan]).
Future<(FakeDiagnosisService, FakePhotoPicker, FakeCommunityService)> startApp(
  WidgetTester tester, {
  Plan plan = Plan.paid,
  String lang = 'ar',
  FakeDiagnosisService? diagnosis,
  bool camera = true,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  appLocale.value = Locale(lang);
  currentPlan.value = plan;
  logInTestUser(lang);
  final community = useFakeCommunity(lang);
  final picker = usePhotoPicker(hasCamera: camera);
  final fake = useDiagnosis(diagnosis);
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  return (fake, picker, community);
}

/// The camera button of the assistant bar.
Future<void> openCamera(WidgetTester tester) async {
  await tester.tap(find.byType(CameraButton));
  await tester.pumpAndSettle();
}

/// The round button of the camera screen (the camera; on web the photos).
Future<void> shoot(WidgetTester tester) async {
  await tester.tap(
    find
        .bySemanticsLabel(
          RegExp(
            'التقط صورة|اختر من الصور|Prendre une photo|Choisir une photo',
          ),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

AppLocalizations get ar => lookupAppLocalizations(const Locale('ar'));
AppLocalizations get fr => lookupAppLocalizations(const Locale('fr'));

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('Free: the camera button shows the locked screen', (
    tester,
  ) async {
    await startApp(tester, plan: Plan.free);
    await openCamera(tester);
    expect(find.byType(CameraScreen), findsNothing);
    expect(currentTab.value, AppTab.orchard);
    await closeApp(tester);
  });

  testWidgets('the camera: Bêta, the tips, the photos left, the privacy note', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (fake, _, _) = await startApp(tester);
    await openCamera(tester);
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.text('صوّر الورقة'), findsOneWidget);
    expect(find.text('تجريبي'), findsOneWidget);
    for (final tip in ['ورقة لوز واحدة', 'من قريب', 'في الضوء']) {
      expect(find.text(tip), findsOneWidget);
    }
    expect(find.text('يمكنك إرسال 7 صور اليوم'), findsOneWidget);
    expect(
      find.text('تُرسل الصورة للفحص، وتُحفظ في حسابك فقط.'),
      findsOneWidget,
    );
    expect(find.text('اختر من الصور'), findsOneWidget);
    expect(fake.calls, ['quota']);
    semantics.dispose();
    await closeApp(tester);
  });

  testWidgets('a sick leaf: camera -> "جاري النظر…" -> the result', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (fake, picker, _) = await startApp(tester);
    fake.hold = Completer();
    await openCamera(tester);
    await shoot(tester);
    expect(picker.calls, containsAll(['pick camera', 'prepare']));
    expect(find.byType(ThinkingScreen), findsOneWidget);
    expect(find.text('جاري النظر…'), findsOneWidget);
    fake.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('diagnose')), hasLength(1));
    // What it probably is, how sure, Bêta.
    expect(find.text('ثقوب في الأوراق'), findsOneWidget);
    expect(find.text('على الأرجح'), findsOneWidget);
    expect(find.text('متأكد'), findsNothing);
    expect(find.text('تجريبي'), findsOneWidget);
    // The photo with the 2 spots marked.
    final photo = tester.widget<MarkedPhoto>(find.byType(MarkedPhoto));
    expect(photo.marked, hasLength(2));
    expect(find.text('الأماكن المريضة مُعلَّمة على الصورة'), findsOneWidget);
    // The 3 first steps, and the honest note.
    await scrollTo(
      tester,
      find.text('اسأل خبيرًا عن العلاج قبل المطر القادم.'),
    );
    expect(find.text('ماذا أفعل؟'), findsOneWidget);
    expect(
      find.text('اجمع الأوراق المريضة والساقطة، وأبعدها عن البستان.'),
      findsOneWidget,
    );
    expect(find.text('اسقِ عند الجذع، لا فوق الأوراق.'), findsOneWidget);
    await scrollTo(
      tester,
      find.text('هذا ليس تشخيصًا نهائيًا. اطلب رأي خبير.'),
    );
    expect(find.text('اسأل خبيرًا'), findsOneWidget);
    semantics.dispose();
    await closeApp(tester);
  });

  testWidgets('not sure: "غير متأكد"', (tester) async {
    await startApp(tester, diagnosis: FakeDiagnosisService(sampleUnsure()));
    await tester.pumpWidget(
      LoozApp(
        home: ResultScreen(diagnosis: sampleUnsure(), photo: await _photo()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تجعّد الأوراق'), findsOneWidget);
    expect(find.text('غير متأكد'), findsOneWidget);
    expect(
      tester.widget<MarkedPhoto>(find.byType(MarkedPhoto)).marked,
      hasLength(1),
    );
    await closeApp(tester);
  });

  testWidgets('nothing found: never "healthy", what we look for, no marks', (
    tester,
  ) async {
    await startApp(tester);
    await tester.pumpWidget(
      LoozApp(
        home: ResultScreen(diagnosis: sampleNothing(), photo: await _photo()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لم نجد هذه الأمراض الثلاثة.'), findsOneWidget);
    expect(find.text('صوّر الورقة من قريب، في الضوء.'), findsOneWidget);
    expect(find.text('هذا لا يعني أن الشجرة سليمة.'), findsOneWidget);
    expect(find.text('نبحث فقط عن: ثقوب، تجعّد، بقع.'), findsOneWidget);
    expect(find.text('ماذا أفعل؟'), findsNothing);
    expect(find.text('الأماكن المريضة مُعلَّمة على الصورة'), findsNothing);
    expect(
      tester.widget<MarkedPhoto>(find.byType(MarkedPhoto)).marked,
      isEmpty,
    );
    expect(find.text('اسأل خبيرًا'), findsOneWidget);
    expect(find.text('صوّر ورقة أخرى'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets(
    '"اسأل خبيرًا": the question with the photo -> the community, linked',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final (fake, _, community) = await startApp(tester);
      await openCamera(tester);
      await shoot(tester);
      await scrollAndTap(tester, find.text('اسأل خبيرًا'));
      expect(find.byType(WritePostScreen), findsOneWidget);
      // The question is ready (the farmer can change it), the photo chosen.
      final question =
          'صوّرت ورقة لوز. التطبيق يقول: ثقوب في الأوراق (على الأرجح). هل هذا صحيح؟';
      expect(find.text(question), findsOneWidget);
      expect(find.text('تغيير'), findsOneWidget);
      await scrollAndTap(tester, find.text('انشر'));
      expect(currentTab.value, AppTab.community);
      expect(community.calls, contains('writePost +photo'));
      final post = community.posts.first;
      expect(post.text, question);
      expect(post.photoPath, isNotNull);
      expect(fake.linked, {'d-sick': post.id});
      expect(find.text('سؤالك في المجتمع'), findsOneWidget);
      semantics.dispose();
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester);
    },
  );

  testWidgets('"صوّر ورقة أخرى" opens the camera; 🔊 says "قريبًا"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await startApp(tester);
    await openCamera(tester);
    await shoot(tester);
    // (The screen reader keeps a message on the screen: not needed here.)
    semantics.dispose();
    await tester.tap(find.byType(SpeakerButton));
    await tester.pump();
    expect(find.text('قريبًا'), findsOneWidget);
    // (Removed here: in the tests it would cover the last line.)
    ScaffoldMessenger.of(tester.element(find.byType(ResultScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('صوّر ورقة أخرى'));
    // The last line of the page: pushed up above the bottom bars.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صوّر ورقة أخرى'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('on web: the round button chooses a photo, no second button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (_, picker, _) = await startApp(tester, camera: false);
    await openCamera(tester);
    expect(find.text('اختر من الصور'), findsNothing); // only the round button
    await shoot(tester);
    expect(picker.calls, contains('pick gallery'));
    expect(find.byType(ResultScreen), findsOneWidget);
    semantics.dispose();
    await closeApp(tester);
  });

  group('failures', () {
    Future<FakeDiagnosisService> failWith(
      WidgetTester tester,
      DiagnosisError error,
    ) async {
      final fake = FakeDiagnosisService()..failNext = error;
      final semantics = tester.ensureSemantics();
      await startApp(tester, diagnosis: fake);
      await openCamera(tester);
      await shoot(tester);
      semantics.dispose();
      return fake;
    }

    testWidgets('no internet: "تحتاج إلى الإنترنت", "حاول مرة أخرى" works', (
      tester,
    ) async {
      final fake = await failWith(
        tester,
        const DiagnosisError(DiagnosisFailure.noInternet),
      );
      expect(find.text('تحتاج إلى الإنترنت'), findsOneWidget);
      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(fake.calls.where((c) => c.startsWith('diagnose')), hasLength(2));
      await closeApp(tester);
    });

    testWidgets(
      'the limit of the day: the plural message, "اسأل خبيرًا" with the photo',
      (tester) async {
        await failWith(
          tester,
          const DiagnosisError(DiagnosisFailure.limitDay, perDay: 10),
        );
        expect(
          find.text('أرسلت اليوم 10 صور. هذا هو الحد. عُد غدًا.'),
          findsOneWidget,
        );
        expect(find.text('حاول مرة أخرى'), findsNothing);
        await tester.tap(find.text('اسأل خبيرًا'));
        await tester.pumpAndSettle();
        expect(find.byType(WritePostScreen), findsOneWidget);
        expect(find.text('تغيير'), findsOneWidget); // the photo is there
        await closeApp(tester);
      },
    );

    testWidgets(
      'busy (no credits) and unavailable: their message + "اسأل خبيرًا"',
      (tester) async {
        await failWith(tester, const DiagnosisError(DiagnosisFailure.busy));
        expect(
          find.text('الفحص مشغول اليوم. حاول غدًا أو اسأل خبيرًا.'),
          findsOneWidget,
        );
        expect(find.text('اسأل خبيرًا'), findsOneWidget);
        await closeApp(tester);
        resetAppState();
        await failWith(
          tester,
          const DiagnosisError(DiagnosisFailure.unavailable),
        );
        expect(find.text('الفحص غير متوفر الآن. اسأل خبيرًا.'), findsOneWidget);
        await closeApp(tester);
      },
    );

    testWidgets('a photo that can\'t be read: "صوّر ورقة أخرى" -> the camera', (
      tester,
    ) async {
      await failWith(tester, const DiagnosisError(DiagnosisFailure.badImage));
      expect(find.text('لم نستطع قراءة الصورة. صوّر من جديد.'), findsOneWidget);
      await tester.tap(find.text('صوّر ورقة أخرى'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('the paid pack ended meanwhile: the locked screen', (
      tester,
    ) async {
      await failWith(tester, const DiagnosisError(DiagnosisFailure.notPaid));
      expect(find.byType(ThinkingScreen), findsNothing);
      expect(currentTab.value, AppTab.orchard);
      await closeApp(tester);
    });

    testWidgets('"رجوع" goes back', (tester) async {
      await failWith(tester, const DiagnosisError(DiagnosisFailure.unknown));
      expect(find.text('حدث خطأ. حاول مرة أخرى.'), findsOneWidget);
      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();
      expect(find.byType(ThinkingScreen), findsNothing);
      await closeApp(tester);
    });
  });

  group('the camera before the photo', () {
    testWidgets('no photo left today: the message, the button does nothing', (
      tester,
    ) async {
      final fake = FakeDiagnosisService()
        ..quota = const DiagnosisQuota(
          enabled: true,
          paid: true,
          perDay: 10,
          usedToday: 10,
        );
      final semantics = tester.ensureSemantics();
      final (_, picker, _) = await startApp(tester, diagnosis: fake);
      await openCamera(tester);
      expect(
        find.text('أرسلت اليوم 10 صور. هذا هو الحد. عُد غدًا.'),
        findsOneWidget,
      );
      await shoot(tester);
      expect(picker.calls, isNot(contains('pick camera')));
      semantics.dispose();
      await closeApp(tester);
    });

    testWidgets('switched off: "الفحص غير متوفر الآن"', (tester) async {
      final fake = FakeDiagnosisService()
        ..quota = const DiagnosisQuota(
          enabled: false,
          paid: true,
          perDay: 10,
          usedToday: 0,
        );
      await startApp(tester, diagnosis: fake);
      await openCamera(tester);
      expect(find.text('الفحص غير متوفر الآن. اسأل خبيرًا.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('no internet: said at once, the photo can still be tried', (
      tester,
    ) async {
      final fake = FakeDiagnosisService()..offline = true;
      final semantics = tester.ensureSemantics();
      final (_, picker, _) = await startApp(tester, diagnosis: fake);
      await openCamera(tester);
      expect(find.text('تحتاج إلى الإنترنت'), findsOneWidget);
      await shoot(tester);
      expect(picker.calls, contains('pick camera'));
      expect(
        find.text('تحتاج إلى الإنترنت'),
        findsOneWidget,
      ); // on "جاري النظر…" too
      semantics.dispose();
      await closeApp(tester);
    });

    testWidgets('the camera refused: its message', (tester) async {
      final semantics = tester.ensureSemantics();
      final (_, picker, _) = await startApp(tester);
      picker.next.add(CommunityFailure.cameraDenied);
      await openCamera(tester);
      await shoot(tester);
      expect(find.byType(CameraScreen), findsOneWidget);
      expect(find.text(ar.cameraDenied), findsOneWidget);
      semantics.dispose();
      await closeApp(tester);
    });

    testWidgets('× closes the camera', (tester) async {
      await startApp(tester);
      await openCamera(tester);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsNothing);
      await closeApp(tester);
    });
  });

  testWidgets('French: the camera and the result, all in French', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await startApp(tester, lang: 'fr');
    await openCamera(tester);
    expect(find.text('Bêta'), findsOneWidget);
    expect(find.text('Encore 7 photos aujourd\'hui'), findsOneWidget);
    expect(textsOnScreen().where(arabic.hasMatch), isEmpty);
    await shoot(tester);
    expect(find.text('Criblure (trous dans les feuilles)'), findsOneWidget);
    expect(find.text('Probablement'), findsOneWidget);
    await scrollTo(tester, find.text('Demander à un expert'));
    expect(find.text('Que faire ?'), findsOneWidget);
    expect(textsOnScreen().where(arabic.hasMatch), isEmpty);
    semantics.dispose();
    await closeApp(tester);
  });

  testWidgets('the assistant bar: "قريبًا", never a fake answer', (
    tester,
  ) async {
    await startApp(tester);
    await tester.tap(find.text('اسأل المساعد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VoiceScreen), findsOneWidget);
    await tester.pump(listeningTime);
    await tester.pumpAndSettle();
    expect(find.byType(VoiceScreen), findsNothing);
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.text('قريبًا'), findsOneWidget);
    expect(find.text('قد تكون حشرة المنّ'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await closeApp(tester);
  });

  test('the Arabic plural forms of the photos', () {
    expect(ar.photosLeftToday(0), 'لا يمكنك إرسال صور أخرى اليوم');
    expect(ar.photosLeftToday(1), 'يمكنك إرسال صورة واحدة اليوم');
    expect(ar.photosLeftToday(2), 'يمكنك إرسال صورتين اليوم');
    expect(ar.photosLeftToday(3), 'يمكنك إرسال 3 صور اليوم');
    expect(ar.photosLeftToday(11), 'يمكنك إرسال 11 صورة اليوم');
    expect(
      ar.limitReached(1),
      'أرسلت اليوم صورة واحدة. هذا هو الحد. عُد غدًا.',
    );
    expect(ar.limitReached(2), 'أرسلت اليوم صورتين. هذا هو الحد. عُد غدًا.');
    expect(ar.limitReached(10), 'أرسلت اليوم 10 صور. هذا هو الحد. عُد غدًا.');
    expect(ar.limitReached(11), 'أرسلت اليوم 11 صورة. هذا هو الحد. عُد غدًا.');
    expect(fr.photosLeftToday(1), "Encore 1 photo aujourd'hui");
    expect(
      fr.limitReached(10),
      "Vous avez envoyé 10 photos aujourd'hui : c'est la limite. Revenez demain.",
    );
  });

  test('the answer of the Edge Function becomes a diagnosis (codes only)', () {
    final d = Diagnosis.fromAnswer({
      'id': 'x',
      'verdict': 'likely',
      'top_class': 'leaf_spot',
      'top_confidence': 0.71,
      'marked': [
        [0.1, 0.2, 0.3, 0.4],
      ],
      'photo_path': 'u/x.jpg',
      'used_today': 2,
      'per_day': 10,
      'created_at': '2026-11-14T10:00:00Z',
    });
    expect(d.disease, Disease.leafSpot);
    expect(d.verdict, Verdict.likely);
    expect(d.marked.single, const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4));
    // An unknown class is never shown as a disease.
    final odd = Diagnosis.fromAnswer({
      'id': 'y',
      'verdict': 'likely',
      'top_class': 'aphids',
    });
    expect(odd.verdict, Verdict.nothing);
    expect(odd.disease, isNull);
    expect(failureOfCode('limit_day'), DiagnosisFailure.limitDay);
    expect(failureOfCode('off'), DiagnosisFailure.unavailable);
    expect(failureOfCode('not_paid'), DiagnosisFailure.notPaid);
  });

  test('zone letters: the abjad order in Arabic (20), A to T in French', () {
    const abjad = 'أ ب ج د ه و ز ح ط ي ك ل م ن س ع ف ص ق ر';
    final letters = [
      for (var i = 0; i < 20; i++) String.fromCharCode(0x41 + i),
    ];
    expect(letters.map((l) => zoneLetterIn(l, 'ar')).join(' '), abjad);
    expect(
      letters.map((l) => zoneLetterIn(l, 'fr')).join(),
      'ABCDEFGHIJKLMNOPQRST',
    );
    expect(zoneLetterIn('B', 'ar'), 'ب');
    expect(ar.zoneName(zoneLetterIn('B', 'ar')), 'المنطقة ب');
    // The 3D gets "المنطقة أ" (Arabic) and "Zone A" (French).
    const zone = OrchardZone(id: 'z', letter: 'A', boundary: []);
    expect(zoneName(zone, 'ar'), 'المنطقة أ');
    expect(zoneName(zone, 'fr'), 'Zone A');
  });
}

/// A small real photo, ready like the camera's.
Future<PreparedPhoto> _photo() => FakePhotoPicker().prepare(testPhotoBytes());
