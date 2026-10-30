// The photos of the community: "＋ انشر", a post with text only or with a
// photo (camera, gallery), changing or removing the photo before
// publishing, the errors, the photo in the cards and on the whole screen,
// deleting a post with its photo, and how a photo is prepared (smaller,
// upright, without its hidden data). In Arabic and French, with a fake
// community and a fake camera (see fake_photo_picker.dart).
// Run it with: flutter test
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/features/community/community_widgets.dart';
import 'package:looz_mobile/features/community/photo_viewer.dart';
import 'package:looz_mobile/features/community/post_card.dart';
import 'package:looz_mobile/features/community/post_photo.dart';
import 'package:looz_mobile/features/community/post_screen.dart';
import 'package:looz_mobile/features/community/write_post_screen.dart';
import 'package:looz_mobile/shared/widgets/screen_title.dart';

import 'fake_community_service.dart';
import 'fake_photo_picker.dart';
import 'test_helpers.dart';

final ar = lookupAppLocalizations(const Locale('ar'));
final fr = lookupAppLocalizations(const Locale('fr'));

/// Opens the community tab, logged in, in [lang] (camera on the phone, or
/// the gallery only like on web).
Future<(FakeCommunityService, FakePhotoPicker)> openCommunity(
  WidgetTester tester, {
  String lang = 'ar',
  bool hasCamera = true,
  FakeCommunityService? community,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  logInTestUser(lang);
  final fake = community ?? useFakeCommunity(lang);
  communityService = fake;
  final picker = usePhotoPicker(hasCamera: hasCamera);
  appLocale.value = Locale(lang);
  currentTab.value = AppTab.community;
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  return (fake, picker);
}

/// "＋ انشر" → the new post screen.
Future<void> openNewPost(WidgetTester tester) async {
  await tester.tap(find.byType(PublishButton));
  await tester.pumpAndSettle();
  expect(find.byType(WritePostScreen), findsOneWidget);
}

Future<void> typePost(WidgetTester tester, String text) async {
  await scrollTo(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// The photo shown in the preview of the new post (null = none).
Uint8List? previewBytes(WidgetTester tester) {
  final preview = find.byType(PhotoPreview);
  if (preview.evaluate().isEmpty) return null;
  final image = tester.widget<Image>(
    find.descendant(of: preview, matching: find.byType(Image)),
  );
  return (image.image as MemoryImage).bytes;
}

/// A post of the logged-in farmer (or of [author]) with a photo of the
/// bucket, on top of the list.
Post addPhotoPost(
  FakeCommunityService fake, {
  String id = 'with-photo',
  String text = 'شوفوا شجرتي، هل هذا مرض؟',
  Author? author,
  bool uploaded = true,
}) {
  final path = 'farmer-1/$id.jpg';
  final post = Post(
    id: id,
    type: PostType.question,
    text: text,
    photo: path,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    author: author ?? Author(id: currentUser.value!.id, firstName: 'محمد'),
  );
  fake.posts.insert(0, post);
  fake.comments[id] = [];
  if (uploaded) fake.photos[path] = testPhotoBytes(r: 200, g: 120, b: 60);
  return post;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  group('"＋ انشر" on the community', () {
    testWidgets('Arabic: the green pill next to the title opens the screen', (
      tester,
    ) async {
      await openCommunity(tester);
      final pill = find.byType(PublishButton);
      expect(
        find.descendant(of: pill, matching: find.text('انشر')),
        findsOneWidget,
      );
      // Right to left: the title on the right, the pill on its left, in the
      // middle of the title and the line under it.
      final title = tester.getRect(find.byType(ScreenTitle).first);
      final pillCenter = tester.getCenter(pill);
      expect(pillCenter.dx, lessThan(title.center.dx));
      expect(pillCenter.dy, inInclusiveRange(title.top, title.bottom));

      await openNewPost(tester);
      expect(find.text('انشر في المجتمع'), findsOneWidget);
      expect(find.text('سؤال أو نصيحة، مع صورة إن أردت'), findsOneWidget);
      expect(find.text('التقط صورة'), findsOneWidget);
      expect(find.text('اختر من الصور'), findsOneWidget);
      await scrollTo(tester, find.text('انشر'));
      expect(find.text('انشر'), findsOneWidget); // the button
    });

    testWidgets('French: "Publier", left to right, on the right of the title', (
      tester,
    ) async {
      await openCommunity(tester, lang: 'fr');
      final pill = find.byType(PublishButton);
      expect(
        find.descendant(of: pill, matching: find.text('Publier')),
        findsOneWidget,
      );
      final title = tester.getRect(find.byType(ScreenTitle).first);
      expect(tester.getCenter(pill).dx, greaterThan(title.center.dx));
      await openNewPost(tester);
      expect(find.text('Publier dans la communauté'), findsOneWidget);
      expect(
        find.text('Une question ou un conseil, avec une photo si vous voulez'),
        findsOneWidget,
      );
      expect(find.text('Prendre une photo'), findsOneWidget);
      expect(find.text('Choisir une photo'), findsOneWidget);
    });
  });

  group('publishing', () {
    testWidgets('Text only: "جاري النشر…", then on top of the community', (
      tester,
    ) async {
      final (fake, _) = await openCommunity(tester);
      await openNewPost(tester);
      await typePost(tester, 'متى أسقي اللوز في نوفمبر؟');
      fake.holdPublish = Completer();
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.publishing), findsOneWidget);
      expect(find.text(ar.uploadingPhoto), findsNothing); // no photo
      fake.holdPublish!.complete();
      await tester.pumpAndSettle();

      expect(fake.calls, contains('writePost'));
      expect(fake.photos, isEmpty);
      expect(find.byType(WritePostScreen), findsNothing);
      expect(currentTab.value, AppTab.community);
      final first = find.byType(PostCard).first;
      expect(
        find.descendant(
          of: first,
          matching: find.text('متى أسقي اللوز في نوفمبر؟'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.byType(PostPhoto)),
        findsNothing,
      );
    });

    testWidgets(
      'With a photo of the gallery: preview, upload, then in the list',
      (tester) async {
        final (fake, picker) = await openCommunity(tester);
        await openNewPost(tester);
        await typePost(tester, 'هل هذه الورقة مريضة؟');
        final photo = testPhotoBytes(r: 30, g: 90, b: 200);
        picker.next.add(photo);
        picker.holdPrepare = Completer();
        await scrollAndTap(tester, find.text(ar.choosePhoto));
        // "جاري تحضير الصورة…" while it is made smaller.
        expect(find.text(ar.preparingPhoto), findsOneWidget);
        picker.holdPrepare!.complete();
        await tester.pumpAndSettle();

        expect(picker.calls, ['lostPhoto', 'pick gallery', 'prepare']);
        expect(previewBytes(tester), photo);
        expect(find.text(ar.changePhoto), findsOneWidget);
        expect(find.text(ar.removePhoto), findsOneWidget);
        expect(find.text(ar.choosePhoto), findsNothing);

        fake.holdUpload = Completer();
        fake.holdPublish = Completer();
        await scrollAndTap(tester, find.text(ar.publish));
        expect(find.text(ar.uploadingPhoto), findsOneWidget);
        // While it is sent, the photo can't be changed.
        await scrollTo(tester, find.text(ar.removePhoto));
        await tester.tap(find.text(ar.removePhoto));
        await tester.pump();
        expect(previewBytes(tester), photo);
        expect(find.text(ar.uploadingPhoto), findsOneWidget);
        fake.holdUpload!.complete();
        await tester.pumpAndSettle(); // (the post itself still waits)
        expect(find.text(ar.publishing), findsOneWidget);
        fake.holdPublish!.complete();
        await tester.pumpAndSettle();

        expect(fake.calls, contains('writePost +photo'));
        expect(fake.photos.values.single, photo);
        expect(currentTab.value, AppTab.community);
        final first = find.byType(PostCard).first;
        expect(
          find.descendant(
            of: first,
            matching: find.text('هل هذه الورقة مريضة؟'),
          ),
          findsOneWidget,
        );
        final shown = tester.widget<Image>(
          find.descendant(of: first, matching: find.byType(Image)).first,
        );
        expect((shown.image as MemoryImage).bytes, photo);
      },
    );

    testWidgets('With the camera: "التقط صورة" opens the camera', (
      tester,
    ) async {
      final (fake, picker) = await openCommunity(tester);
      await openNewPost(tester);
      await scrollAndTap(tester, find.text(ar.takePhoto));
      expect(picker.calls, contains('pick camera'));
      expect(previewBytes(tester), isNotNull);
      await typePost(tester, 'صورة من البستان');
      await scrollAndTap(tester, find.text(ar.publish));
      expect(fake.calls, contains('writePost +photo'));
      expect(fake.photos, hasLength(1));
    });

    testWidgets('Removing the photo before publishing: published without it', (
      tester,
    ) async {
      final (fake, _) = await openCommunity(tester);
      await openNewPost(tester);
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      expect(previewBytes(tester), isNotNull);
      await scrollAndTap(tester, find.text(ar.removePhoto));
      expect(previewBytes(tester), isNull);
      expect(find.text(ar.takePhoto), findsOneWidget); // the choices again
      expect(find.text(ar.choosePhoto), findsOneWidget);

      await typePost(tester, 'سؤال بلا صورة');
      await scrollAndTap(tester, find.text(ar.publish));
      expect(fake.calls, contains('writePost'));
      expect(fake.calls, isNot(contains('writePost +photo')));
      expect(fake.photos, isEmpty);
    });

    testWidgets(
      'Changing the photo: camera or gallery, the new one replaces it',
      (tester) async {
        final (fake, picker) = await openCommunity(tester);
        await openNewPost(tester);
        final red = testPhotoBytes(r: 220, g: 30, b: 30);
        final blue = testPhotoBytes(r: 30, g: 30, b: 220);
        picker.next.addAll([red, blue]);
        await scrollAndTap(tester, find.text(ar.choosePhoto));
        expect(previewBytes(tester), red);

        await scrollAndTap(tester, find.text(ar.changePhoto));
        // The sheet: camera or gallery.
        expect(find.text(ar.takePhoto), findsOneWidget);
        await tester.tap(find.text(ar.choosePhoto));
        await tester.pumpAndSettle();
        expect(previewBytes(tester), blue);

        await typePost(tester, 'الصورة الثانية أوضح');
        await scrollAndTap(tester, find.text(ar.publish));
        expect(fake.photos.values.single, blue);
      },
    );

    testWidgets('Closing the camera without a photo changes nothing', (
      tester,
    ) async {
      final (_, picker) = await openCommunity(tester);
      await openNewPost(tester);
      picker.next.add(null);
      await scrollAndTap(tester, find.text(ar.takePhoto));
      expect(previewBytes(tester), isNull);
      expect(find.byType(CommunityNote), findsNothing);
      expect(find.text(ar.takePhoto), findsOneWidget);
    });

    testWidgets('Like on web (no camera): the gallery only', (tester) async {
      final (_, picker) = await openCommunity(tester, hasCamera: false);
      await openNewPost(tester);
      expect(find.text(ar.takePhoto), findsNothing);
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      // "تغيير" opens the gallery at once (no sheet with the camera).
      await scrollAndTap(tester, find.text(ar.changePhoto));
      expect(find.text(ar.takePhoto), findsNothing);
      expect(picker.calls.where((c) => c == 'pick gallery'), hasLength(2));
      expect(picker.calls, isNot(contains('pick camera')));
    });

    testWidgets('The photo Android kept when it closed the app comes back', (
      tester,
    ) async {
      final (_, picker) = await openCommunity(tester);
      final photo = testPhotoBytes(r: 10, g: 150, b: 10);
      picker.lost = photo;
      await openNewPost(tester);
      expect(previewBytes(tester), photo);
    });
  });

  group('errors', () {
    testWidgets('Camera or photos refused, no camera: a clear message', (
      tester,
    ) async {
      final (_, picker) = await openCommunity(tester);
      await openNewPost(tester);
      await typePost(tester, 'نصّي يبقى');
      for (final (failure, source, message) in [
        (CommunityFailure.cameraDenied, ar.takePhoto, ar.cameraDenied),
        (CommunityFailure.galleryDenied, ar.choosePhoto, ar.galleryDenied),
        (CommunityFailure.noCamera, ar.takePhoto, ar.noCamera),
      ]) {
        picker.next.add(failure);
        await scrollAndTap(tester, find.text(source));
        expect(find.text(message), findsOneWidget, reason: failure.name);
        expect(previewBytes(tester), isNull);
      }
      expect(
        ar.cameraDenied,
        'لم تسمح للوز باستخدام الكاميرا. اسمح بذلك من إعدادات الهاتف.',
      );
      expect(find.text('نصّي يبقى'), findsOneWidget); // the text is kept

      // Allowed now: the photo comes, the message goes.
      await scrollAndTap(tester, find.text(ar.takePhoto));
      expect(previewBytes(tester), isNotNull);
      expect(find.byType(CommunityNote), findsNothing);
    });

    testWidgets('Too big or not a photo: the message, choose another one', (
      tester,
    ) async {
      final (_, picker) = await openCommunity(tester);
      await openNewPost(tester);
      picker.failPrepare = CommunityFailure.photoTooBig;
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      expect(
        find.text('الصورة كبيرة جدًا (أكثر من 5 ميغابايت). اختر صورة أخرى.'),
        findsOneWidget,
      );
      expect(previewBytes(tester), isNull);
      picker.failPrepare = CommunityFailure.photoWrongType;
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      expect(
        find.text('هذا الملف ليس صورة (JPG أو PNG أو WebP).'),
        findsOneWidget,
      );
      expect(find.text(ar.choosePhoto), findsOneWidget);
    });

    testWidgets('Upload failed, no internet, too fast: text and photo kept', (
      tester,
    ) async {
      final (fake, _) = await openCommunity(tester);
      await openNewPost(tester);
      await typePost(tester, 'سؤال مع صورة');
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      final photo = previewBytes(tester);

      fake.failUpload = CommunityFailure.uploadFailed;
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text('لم تُرفع الصورة. حاول مرة أخرى.'), findsOneWidget);
      expect(find.text(ar.publish), findsOneWidget); // ready again

      fake.offline = true;
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.errorNoInternet), findsOneWidget);
      fake.offline = false;

      // Refused after the upload: the photo is removed again.
      fake.failAfterUpload = CommunityFailure.tooFast;
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.tooFast), findsOneWidget);
      expect(fake.photos, isEmpty);
      expect(find.text('سؤال مع صورة'), findsOneWidget);
      expect(previewBytes(tester), photo);

      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.byType(WritePostScreen), findsNothing);
      expect(fake.photos.values.single, photo);
    });

    testWidgets('An empty text with a photo: refused before uploading', (
      tester,
    ) async {
      final (fake, _) = await openCommunity(tester);
      await openNewPost(tester);
      await scrollAndTap(tester, find.text(ar.choosePhoto));
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.textEmpty), findsOneWidget);
      expect(fake.calls.where((c) => c.startsWith('writePost')), isEmpty);
      expect(fake.photos, isEmpty);
    });

    testWidgets('French: the screen, the photo and the errors in French', (
      tester,
    ) async {
      final (fake, picker) = await openCommunity(tester, lang: 'fr');
      await openNewPost(tester);
      picker.next.add(CommunityFailure.cameraDenied);
      await scrollAndTap(tester, find.text('Prendre une photo'));
      expect(
        find.text(
          "Looz n'a pas accès à l'appareil photo. Autorisez-le dans les réglages du téléphone.",
        ),
        findsOneWidget,
      );
      await scrollAndTap(tester, find.text('Choisir une photo'));
      expect(find.text('Changer'), findsOneWidget);
      expect(find.text('Retirer'), findsOneWidget);
      await typePost(tester, 'Mes amandiers ont des taches');
      fake.holdUpload = Completer();
      await scrollAndTap(tester, find.text('Publier'));
      expect(find.text('Envoi de la photo…'), findsOneWidget);
      fake.holdUpload!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mes amandiers ont des taches'), findsOneWidget);
      final page = tester.element(find.byType(PostCard).first);
      expect(Directionality.of(page), TextDirection.ltr);
    });
  });

  group('the photo in the cards', () {
    testWidgets('In the list and on its screen; tap = whole screen, × closes', (
      tester,
    ) async {
      final fake = FakeCommunityService.sample();
      logInTestUser();
      final post = addPhotoPost(fake);
      await openCommunity(tester, community: fake);
      final first = find.byType(PostCard).first;
      expect(
        find.descendant(of: first, matching: find.byType(PostPhoto)),
        findsOneWidget,
      );
      expect(fake.calls, contains('loadPhoto ${post.photo}'));

      await tester.tap(
        find.descendant(of: first, matching: find.byType(PostPhoto)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      final full = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
      expect((full.image as MemoryImage).bytes, fake.photos[post.photo]);
      expect(full.label, ar.a11yPostPhoto);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
      expect(find.byType(PostScreen), findsNothing); // the photo, not the post

      // On the screen of the post too.
      await tester.tap(find.text(post.text));
      await tester.pumpAndSettle();
      expect(find.byType(PostScreen), findsOneWidget);
      await tester.tap(find.byType(PostPhoto));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
    });

    testWidgets('The demo picture still shows, and opens on the whole screen', (
      tester,
    ) async {
      await openCommunity(tester);
      await tester.tap(find.byType(PostPhoto).first);
      await tester.pumpAndSettle();
      final full = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
      expect(
        (full.image as AssetImage).assetName,
        'assets/images/almond_blossoms.jpg',
      );
      expect(full.label, ar.almondBlossoms);
    });

    testWidgets('Not downloaded: "تعذّر عرض الصورة", tap to try again', (
      tester,
    ) async {
      final fake = FakeCommunityService.sample();
      logInTestUser();
      final post = addPhotoPost(fake, uploaded: false);
      await openCommunity(tester, community: fake);
      expect(find.text('تعذّر عرض الصورة'), findsOneWidget);
      fake.photos[post.photo!] = testPhotoBytes();
      await tester.tap(find.text('تعذّر عرض الصورة'));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر عرض الصورة'), findsNothing);
      expect(
        fake.calls.where((c) => c == 'loadPhoto ${post.photo}'),
        hasLength(2),
      );
    });

    testWidgets('Deleting my post: its photo first, then the post', (
      tester,
    ) async {
      final fake = FakeCommunityService.sample();
      logInTestUser();
      final post = addPhotoPost(fake);
      await openCommunity(tester, community: fake);
      await tester.tap(find.text(post.text));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DeleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.deleteAction));
      await tester.pumpAndSettle();

      final i = fake.calls.indexOf('deletePost ${post.id}');
      expect(fake.calls[i + 1], 'removePhoto ${post.photo}');
      expect(fake.photos, isEmpty);
      expect(fake.posts.where((p) => p.id == post.id), isEmpty);
      expect(find.byType(PostScreen), findsNothing);
      expect(find.text(post.text), findsNothing);
    });

    testWidgets("Someone else's post with a photo: no delete button", (
      tester,
    ) async {
      final fake = FakeCommunityService.sample();
      logInTestUser();
      final post = addPhotoPost(
        fake,
        author: const Author(id: 'fatma', firstName: 'فاطمة'),
      );
      await openCommunity(tester, community: fake);
      await tester.tap(find.text(post.text));
      await tester.pumpAndSettle();
      expect(find.byType(PostPhoto), findsOneWidget);
      expect(find.byType(DeleteButton), findsNothing);
    });
  });

  group('preparing a photo', () {
    test(
      'A big photo turned by the phone: upright, 1600 px, JPEG, no hidden data',
      () async {
        // 3000 x 2000, saved "turned" (orientation 6 = to show turned right),
        // with the GPS position of the farm and the phone's name.
        final original = img.Image(width: 3000, height: 2000);
        img.fill(original, color: img.ColorRgb8(120, 180, 90));
        original.exif.imageIfd.orientation = 6;
        original.exif.imageIfd['Make'] = 'PhoneMaker';
        original.exif.gpsIfd.setGpsLocation(latitude: 34.74, longitude: 10.76);
        final bytes = img.encodeJpg(original);
        expect(img.decodeJpg(bytes)!.exif.gpsIfd.hasGPSLatitude, isTrue);

        final photo = await preparePhoto(bytes);
        // Upright: now taller than wide, the longest side 1600 px.
        expect((photo.width, photo.height), (1067, 1600));
        expect(photoTypeOf(photo.bytes), 'jpeg');
        final saved = img.decodeJpg(photo.bytes)!;
        expect((saved.width, saved.height), (1067, 1600));
        expect(saved.exif.isEmpty, isTrue); // no GPS, no phone, no orientation
        expect(photo.bytes.length, lessThan(photoMaxBytes));
      },
    );

    test('A small PNG with transparency: a JPEG on white, same size', () async {
      final png = img.Image(width: 120, height: 80, numChannels: 4);
      img.fill(png, color: img.ColorRgba8(0, 0, 0, 0)); // transparent
      final photo = await preparePhoto(img.encodePng(png));
      expect((photo.width, photo.height), (120, 80));
      final pixel = img.decodeJpg(photo.bytes)!.getPixel(10, 10);
      expect(pixel.r, greaterThan(245));
      expect(pixel.g, greaterThan(245));
      expect(pixel.b, greaterThan(245));
    });

    test('A WebP is accepted too (saved as JPEG)', () async {
      final webp = img.Image(width: 90, height: 60);
      img.fill(webp, color: img.ColorRgb8(200, 60, 60));
      final bytes = img.encodeWebP(webp);
      expect(photoTypeOf(bytes), 'webp');
      final photo = await preparePhoto(bytes);
      expect(photoTypeOf(photo.bytes), 'jpeg');
      expect((photo.width, photo.height), (90, 60));
    });

    test(
      'Not a photo: GIF, HEIC, text, empty, broken JPEG -> wrong type',
      () async {
        final gif = img.encodeGif(img.Image(width: 10, height: 10));
        final heic = Uint8List.fromList([
          0,
          0,
          0,
          24,
          ...'ftypheic'.codeUnits,
          0,
          0,
        ]);
        final text = Uint8List.fromList('<html>photo</html>'.codeUnits);
        final broken = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3, 4, 5]);
        for (final (name, bytes) in [
          ('gif', gif),
          ('heic', heic),
          ('text', text),
          ('empty', Uint8List(0)),
          ('broken', broken),
        ]) {
          await expectLater(
            preparePhoto(bytes),
            throwsA(
              isA<CommunityError>().having(
                (e) => e.failure,
                'failure',
                CommunityFailure.photoWrongType,
              ),
            ),
            reason: name,
          );
        }
        expect(
          photoTypeOf(
            Uint8List.fromList([0x89, ...'PNG'.codeUnits, 13, 10, 26, 10]),
          ),
          'png',
        );
      },
    );

    test(
      'The camera refused, no camera, a huge file: the right error',
      () async {
        Future<CommunityFailure?> failureOf(ImagePicker picker) async {
          try {
            await DevicePhotoPicker(picker).pick(PhotoSource.camera);
            return null;
          } on CommunityError catch (e) {
            return e.failure;
          }
        }

        expect(
          await failureOf(_RefusingPicker('camera_access_denied')),
          CommunityFailure.cameraDenied,
        );
        expect(
          await failureOf(_RefusingPicker('photo_access_denied')),
          CommunityFailure.galleryDenied,
        );
        expect(
          await failureOf(_RefusingPicker('no_available_camera')),
          CommunityFailure.noCamera,
        );
        expect(
          await failureOf(_RefusingPicker('something_else')),
          CommunityFailure.unknown,
        );
        expect(
          await failureOf(_HugeFilePicker()),
          CommunityFailure.photoTooBig,
        );
      },
    );

    test('Photo names: the same rule as the database', () {
      // The rule of community_photo_name_ok() (migration 007).
      final rule = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      final ids = {for (var i = 0; i < 50; i++) randomPhotoId()};
      expect(ids, hasLength(50));
      expect(ids.every(rule.hasMatch), isTrue);

      Post withPhoto(String? photo) => Post(
        id: 'x',
        type: PostType.question,
        text: 't',
        createdAt: DateTime(2026),
        author: const Author(id: 'a'),
        photo: photo,
      );
      final name = '${randomPhotoId()}/${randomPhotoId()}.jpg';
      expect(withPhoto(name).photoPath, name);
      expect(withPhoto(name).photoAsset, isNull);
      expect(withPhoto('demo:almond_blossoms').photoPath, isNull);
      expect(withPhoto('https://example.com/a.jpg').photoPath, isNull);
      expect(withPhoto('../a.jpg').photoPath, isNull);
      expect(withPhoto(null).photoPath, isNull);
    });

    test('Errors of Supabase Storage and of the photo rule', () {
      expect(
        communityFailureOf(
          const StorageException('Payload too large', statusCode: '413'),
        ),
        CommunityFailure.photoTooBig,
      );
      expect(
        communityFailureOf(
          const StorageException(
            'mime type image/gif is not supported',
            statusCode: '415',
          ),
        ),
        CommunityFailure.photoWrongType,
      );
      expect(
        communityFailureOf(
          const StorageException(
            'new row violates row-level security policy',
            statusCode: '403',
          ),
        ),
        CommunityFailure.uploadFailed,
      );
      expect(
        communityFailureOf(
          const StorageException('jwt expired', statusCode: '400'),
        ),
        CommunityFailure.sessionExpired,
      );
      expect(
        communityFailureOf(
          const StorageException('ClientException: Failed host lookup'),
        ),
        CommunityFailure.noInternet,
      );
      expect(
        communityFailureOf(
          const PostgrestException(message: 'not your photo', code: '22023'),
        ),
        CommunityFailure.uploadFailed,
      );
    });
  });
}

/// An image_picker whose camera says no ([code] of image_picker).
class _RefusingPicker extends ImagePicker {
  _RefusingPicker(this.code);

  final String code;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => throw PlatformException(code: code);
}

/// An image_picker that gives a file of 31 MB.
class _HugeFilePicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(Uint8List(photoMaxPickedBytes + 1), name: 'huge.jpg');
}
