// "من صورة" in the orchard designer (a photo of a sketch on paper), with a
// fake photo picker and a fake reader (the image processing itself:
// sketch_detect_test.dart):
//   the third card (hand drawing stays the default), the tips screen, the
//   outline found → the outline step with the photo, the size typed (the
//   photo is stretched too), the zones; nothing found → the corners on the
//   photo / another photo / drawing by hand; errors; French; a small phone;
//   Chrome (no camera). And the editor with a photo (undo / redo).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';
import 'package:looz_mobile/features/orchard_designer/orchard_canvas.dart';
import 'package:looz_mobile/features/orchard_designer/outline_editor.dart';
import 'package:looz_mobile/features/orchard_designer/outline_screen.dart';
import 'package:looz_mobile/features/orchard_designer/sketch_reader.dart';
import 'package:looz_mobile/features/orchard_designer/sketch_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zones_screen.dart';

import 'designer_test.dart' show openDesignerStart, at, typeSize, next;
import 'fake_photo_picker.dart';
import 'fake_sketch_reader.dart';
import 'test_helpers.dart';

FakeSketchReader get reader => sketchReader as FakeSketchReader;
FakePhotoPicker get picker => photoPicker as FakePhotoPicker;

/// The start screen → "من صورة" → "★ ابدأ الرسم" → the tips screen.
Future<void> openSketch(WidgetTester tester, {String lang = 'ar'}) async {
  await scrollAndTap(
    tester,
    find.text(lang == 'ar' ? 'من صورة' : 'Depuis une photo'),
  );
  await scrollAndTap(
    tester,
    findTextWithSymbol(lang == 'ar' ? '★ ابدأ الرسم' : '★ Commencer le dessin'),
  );
  expect(find.byType(SketchScreen), findsOneWidget);
}

/// The round button (the camera; on web: the photos).
Future<void> takePhoto(
  WidgetTester tester, {
  String label = 'التقط صورة',
}) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

OrchardCanvas canvas(WidgetTester tester) =>
    tester.widget<OrchardCanvas>(find.byType(OrchardCanvas));

void main() {
  setUpAll(loadAppFonts);
  setUp(resetAppState);
  tearDown(resetAppState);

  testWidgets('The third card; the hand drawing stays the default', (
    tester,
  ) async {
    await openDesignerStart(tester);
    expect(find.text('بإصبعك، على شبكة'), findsOneWidget);
    expect(find.text('من صورة'), findsOneWidget);
    expect(find.text('ارسم بستانك على ورقة وصوّرها'), findsOneWidget);
    expect(find.text('على صورة القمر الصناعي'), findsOneWidget);
    await scrollAndTap(tester, findTextWithSymbol('★ ابدأ الرسم'));
    expect(find.byType(OutlineScreen), findsOneWidget); // no photo step
    expect(canvas(tester).photoPlace, isNull);
    expect(reader.sides, isEmpty);
    await closeApp(tester);
  });

  testWidgets('Found: the tips, "نبحث…", the outline on the photo, the size '
      '(the photo stretched too), "التالي" → the zones', (tester) async {
    final (orchard, _) = await openDesignerStart(tester);
    await openSketch(tester);
    expect(find.text('صوّر رسمة بستانك'), findsOneWidget);
    for (final tip in [
      'قلم أسود غليظ',
      'ورقة بيضاء',
      'صوّر من فوق',
      'الورقة كاملة في الصورة',
    ]) {
      expect(find.text(tip), findsOneWidget);
    }
    expect(find.text('الصورة تبقى في هاتفك، لا نرسلها.'), findsOneWidget);
    expect(
      find.text('اختر من الصور'),
      findsOneWidget,
    ); // a phone: the gallery too

    reader.hold = Completer<void>();
    await tester.tap(find.bySemanticsLabel('التقط صورة'));
    await tester.pump();
    await tester.pump();
    expect(find.text('نبحث عن حدود البستان…'), findsOneWidget);
    expect(picker.calls, contains('pick camera'));
    reader.hold!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(OutlineScreen), findsOneWidget);
    expect(find.byType(SketchScreen), findsNothing);
    expect(
      find.text('وجدنا حدود بستانك. حرّك النقاط إذا لزم.'),
      findsOneWidget,
    );
    expect(canvas(tester).outline, sketchOutline);
    expect(canvas(tester).photoPlace, sketchPlace);
    expect(find.text('140 م'), findsOneWidget); // the width found

    await typeSize(tester, '280', '180');
    final place = canvas(tester).photoPlace!;
    expect(place.width, closeTo(400, 0.01)); // 200 m × 2
    expect(place.length, closeTo(300, 0.01)); // 150 m × 2
    expect(
      find.text('اسحب نقطة لتحريكها'),
      findsOneWidget,
    ); // changed: the usual hint

    await next(tester);
    expect(find.byType(ZonesScreen), findsOneWidget);
    final saved = orchard.design!;
    expect(saved.outline, hasLength(4));
    expect(boundsOf(saved.outline).width, closeTo(280, 0.01));
    expect(saved.toJson()['mode'], 'grid'); // saved like a hand drawing
    await closeApp(tester);
  });

  testWidgets('Not found: the message; "حدّد الزوايا على الصورة" → the corners '
      'tapped on the photo', (tester) async {
    await openDesignerStart(tester);
    await openSketch(tester);
    reader.next.add(FakeSketchReader.notFound);
    await takePhoto(tester);
    expect(find.text('لم نجد حدود البستان في الصورة.'), findsOneWidget);
    expect(
      find.text('ارسم الحدود بخط واضح ومغلق، أو حدّد الزوايا بنفسك.'),
      findsOneWidget,
    );
    await tester.tap(find.text('حدّد الزوايا على الصورة'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlineScreen), findsOneWidget);
    expect(canvas(tester).photoPlace, sketchPlace);
    expect(canvas(tester).outline, isEmpty);
    expect(find.text('اضغط على زوايا بستانك، واحدة بعد واحدة'), findsOneWidget);
    final corners = [
      at(tester, 0.25, 0.25),
      at(tester, 0.75, 0.25),
      at(tester, 0.75, 0.75),
      at(tester, 0.25, 0.75),
    ];
    for (final c in [...corners, corners.first]) {
      await tester.tapAt(c);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(canvas(tester).outline, hasLength(4));
    expect(canvas(tester).photoPlace, sketchPlace); // the photo stays
    await next(tester);
    expect(find.byType(ZonesScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets(
    'Not found: "صورة أخرى" (then found), and "ارسم بيدك" (no photo)',
    (tester) async {
      await openDesignerStart(tester);
      await openSketch(tester);
      reader.next.add(FakeSketchReader.notFound);
      await takePhoto(tester);
      await tester.tap(find.text('صورة أخرى'));
      await tester.pumpAndSettle();
      expect(find.text('لم نجد حدود البستان في الصورة.'), findsNothing);
      expect(find.byType(SketchScreen), findsOneWidget);

      reader.next.add(FakeSketchReader.notFound);
      await tester.tap(find.text('اختر من الصور'));
      await tester.pumpAndSettle();
      expect(picker.calls, contains('pick gallery'));
      await tester.tap(find.text('ارسم بيدك'));
      await tester.pumpAndSettle();
      expect(find.byType(OutlineScreen), findsOneWidget);
      expect(canvas(tester).photoPlace, isNull);
      expect(
        find.text('ارسم حدود بستانك بإصبعك'),
        findsOneWidget,
      ); // the pen, as usual
      await closeApp(tester);
    },
  );

  testWidgets(
    'Errors: the camera refused, not a photo; closed without a photo; '
    '× goes back',
    (tester) async {
      await openDesignerStart(tester);
      await openSketch(tester);
      picker.next.add(CommunityFailure.cameraDenied);
      await takePhoto(tester);
      expect(find.byType(SketchScreen), findsOneWidget);
      expect(find.textContaining('الكاميرا'), findsWidgets);

      reader.next.add(CommunityFailure.photoWrongType);
      await takePhoto(tester);
      expect(find.byType(SketchScreen), findsOneWidget);

      picker.next.add(null); // closed without a photo
      await takePhoto(tester);
      expect(find.byType(SketchScreen), findsOneWidget);
      expect(find.text('نبحث عن حدود البستان…'), findsNothing);

      await tester.tap(find.bySemanticsLabel(RegExp('^إغلاق')));
      await tester.pumpAndSettle();
      expect(find.byType(DesignerStartScreen), findsOneWidget);
      await closeApp(tester);
    },
  );

  testWidgets('French: the card, the tips, the message', (tester) async {
    await openDesignerStart(tester, lang: 'fr');
    expect(
      find.text('Dessinez votre verger sur papier et prenez-le en photo'),
      findsOneWidget,
    );
    await openSketch(tester, lang: 'fr');
    expect(find.text('Photographiez votre croquis'), findsOneWidget);
    expect(find.text('Feutre noir épais'), findsOneWidget);
    expect(
      find.text("La photo reste sur votre téléphone : elle n'est pas envoyée."),
      findsOneWidget,
    );
    reader.next.add(FakeSketchReader.notFound);
    await takePhoto(tester, label: 'Prendre une photo');
    expect(
      find.text('Contour du verger non trouvé sur la photo.'),
      findsOneWidget,
    );
    expect(find.text('Placer les coins sur la photo'), findsOneWidget);
    expect(find.text('Une autre photo'), findsOneWidget);
    expect(find.text('Dessiner à la main'), findsOneWidget);
    await tester.tap(find.text('Une autre photo'));
    await tester.pumpAndSettle();
    await takePhoto(tester, label: 'Prendre une photo');
    expect(
      find.text('Contour trouvé. Déplacez les points si besoin.'),
      findsOneWidget,
    );
    await closeApp(tester);
  });

  testWidgets(
    'A small phone (360 x 640): the tips screen and the message fit',
    (tester) async {
      await openDesignerStart(tester, screen: const Size(360, 640));
      await openSketch(tester);
      expect(tester.takeException(), isNull);
      reader.next.add(FakeSketchReader.notFound);
      await takePhoto(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('ارسم بيدك'), findsOneWidget);
      await closeApp(tester);
    },
  );

  testWidgets('Chrome (no camera): the round button chooses a photo', (
    tester,
  ) async {
    await openDesignerStart(tester);
    photoPicker = FakePhotoPicker(hasCamera: false);
    await openSketch(tester);
    expect(find.text('اختر من الصور'), findsNothing); // no second button
    await takePhoto(tester, label: 'اختر من الصور');
    expect(picker.calls, contains('pick gallery'));
    expect(find.byType(OutlineScreen), findsOneWidget);
    await closeApp(tester);
  });

  group('the editor with a photo', () {
    test(
      'the size stretches the photo like the shape; undo / redo bring it back',
      () {
        final e = OutlineEditor(sketchOutline, sketchPlace);
        expect(e.photo, sketchPlace);
        e.scaleTo(280, 180); // × 2
        expect(e.photo!.width, closeTo(400, 0.001));
        expect(e.photo!.length, closeTo(300, 0.001));
        e.undo();
        expect(e.photo, sketchPlace);
        e.redo();
        expect(e.photo!.width, closeTo(400, 0.001));
        e.erase();
        expect(
          e.photo,
          isNotNull,
        ); // the photo stays: the corners can be tapped on it
      },
    );

    test('without a photo: as before', () {
      final e = OutlineEditor(const [
        OrchardPoint(0, 0),
        OrchardPoint(100, 0),
        OrchardPoint(100, 50),
      ]);
      e.scaleTo(200, 100);
      expect(e.photo, isNull);
      expect(boundsOf(e.points).width, closeTo(200, 0.001));
    });
  });
}
