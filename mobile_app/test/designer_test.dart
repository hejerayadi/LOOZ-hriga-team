// The orchard designer (Phase 3), with a fake orchard and a fake payment:
//   step 1 the outline (finger, corners, undo/redo, move, erase, size,
//   crossing sides), step 2 the zones (automatic by trees, or the
//   farmer's lines) and their details, step 3 the review (the bill, the
//   area minimum, the demo payment), then the orchard is built → 3D.
//   The draft after every step, going on with it, starting again, errors,
//   a mouse, French, a small phone (360 x 640).
// Run it with: flutter test
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/orchard_design.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/onboarding/welcome_screen.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_view.dart';
import 'package:looz_mobile/features/orchard_designer/build_orchard_screen.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';
import 'package:looz_mobile/features/orchard_designer/orchard_canvas.dart';
import 'package:looz_mobile/features/orchard_designer/outline_screen.dart';
import 'package:looz_mobile/features/orchard_designer/review_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zone_details_screen.dart';
import 'package:looz_mobile/features/orchard_designer/zones_screen.dart';
import 'package:looz_mobile/features/premium/payment_result_screen.dart';
import 'package:looz_mobile/features/premium/payment_screen.dart';

import 'fake_auth_service.dart';
import 'fake_orchard_service.dart';
import 'fake_payment_service.dart';
import 'test_helpers.dart';

/// 200 m x 100 m (2 ha), centred.
final rectangle = [
  const OrchardPoint(-100, -50),
  const OrchardPoint(100, -50),
  const OrchardPoint(100, 50),
  const OrchardPoint(-100, 50),
];

/// The app on the designer's first screen, with a fake orchard (none, or
/// [draft]) and a fake payment linked to the fake login.
Future<(FakeOrchardService, FakePaymentService)> openDesignerStart(
  WidgetTester tester, {
  OrchardDesign? draft,
  String lang = 'ar',
  bool signUp = false,
  Size? screen,
}) async {
  if (screen == null) {
    usePhoneScreen(tester);
  } else {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  noAnimations(tester);
  logInTestUser(lang);
  final payments = usePayments(authService as FakeAuthService);
  final orchard = useOrchard(null)..design = draft;
  if (draft != null) orchard.orchard = const MyOrchard(complete: false);
  if (draft != null && draft.complete) {
    payments.drawOrchard(draft.zones.length, areaHa: hectares(draft.outline));
  }
  currentPlan.value = signUp ? Plan.free : Plan.paid;
  appLocale.value = Locale(lang);
  await tester.pumpWidget(LoozApp(home: DesignerStartScreen(signUp: signUp)));
  await tester.pumpAndSettle();
  return (orchard, payments);
}

/// A point of the drawing, as parts of its width and height (0..1).
Offset at(WidgetTester tester, double fx, double fy) {
  final r = tester.getRect(find.byType(OrchardCanvas));
  return r.topLeft + Offset(r.width * fx, r.height * fy);
}

/// The finger (or the mouse) goes around [corners] and back to the start,
/// wobbling a little.
Future<void> drawAround(
  WidgetTester tester,
  List<Offset> corners, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await tester.startGesture(
    corners.first,
    kind: kind,
    buttons: kind == PointerDeviceKind.mouse ? kPrimaryMouseButton : 0x01,
  );
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    for (var k = 1; k <= 20; k++) {
      final wobble = Offset(k.isEven ? 1.5 : -1.5, k.isEven ? -1 : 1);
      await gesture.moveTo(Offset.lerp(a, b, k / 20)! + wobble);
    }
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Taps the corners one by one, then the first one again (closed).
Future<void> tapCorners(WidgetTester tester, List<Offset> corners) async {
  await tester.tap(find.text('نقاط'));
  await tester.pump();
  for (final c in [...corners, corners.first]) {
    await tester.tapAt(c);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The orchard of 4 corners of the tests (about 70 % x 50 % of the grid).
List<Offset> square(WidgetTester tester) => [
  at(tester, 0.15, 0.25),
  at(tester, 0.85, 0.25),
  at(tester, 0.85, 0.75),
  at(tester, 0.15, 0.75),
];

Future<void> startDrawing(WidgetTester tester) async {
  await scrollAndTap(tester, findTextWithSymbol('★ ابدأ الرسم'));
  expect(find.byType(OutlineScreen), findsOneWidget);
}

Future<void> next(WidgetTester tester, [String label = '★ التالي']) async {
  await tester.tap(findTextWithSymbol(label));
  await tester.pumpAndSettle();
}

/// Types the size of the orchard in the sheet (the "العرض" chip opens it).
Future<void> typeSize(WidgetTester tester, String width, String length) async {
  await tester.tap(find.text('العرض'));
  await tester.pumpAndSettle();
  final boxes = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );
  await tester.enterText(boxes.at(0), width);
  await tester.enterText(boxes.at(1), length);
  await tester.tap(find.text('تمّ'));
  await tester.pumpAndSettle();
}

/// A draft with its outline and [trees] in automatic zones.
OrchardDesign autoDraft(List<int> trees, {DesignStep step = DesignStep.zones}) {
  final parts = splitByTrees(rectangle, trees);
  return OrchardDesign(
    step: step,
    outline: rectangle,
    zoneMethod: ZoneMethod.auto,
    zones: [
      for (final (i, p) in parts.indexed)
        DesignZone(
          letter: zoneLetter(i),
          boundary: rounded(p),
          color: zoneColors[i],
          treeCount: trees[i],
        ),
    ],
  );
}

void main() {
  setUpAll(loadAppFonts);
  setUp(resetAppState);
  tearDown(resetAppState);

  group('step 1: the outline', () {
    testWidgets('With the finger: the shape is straightened and closed, the '
        'area in hectares; "التالي" saves the draft → the zones', (
      tester,
    ) async {
      final (orchard, _) = await openDesignerStart(tester);
      expect(find.text('على صورة القمر الصناعي'), findsOneWidget);
      await startDrawing(tester);
      expect(find.text('الخطوة 1 من 3'), findsOneWidget);
      expect(find.text('ارسم حدود بستانك بإصبعك'), findsOneWidget);
      final nextButton = find.ancestor(
        of: findTextWithSymbol('★ التالي'),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(nextButton.first).opacity, 0.5);

      await drawAround(tester, square(tester));
      expect(find.text('اسحب نقطة لتحريكها'), findsOneWidget);
      expect(find.textContaining('هكتار'), findsOneWidget);
      expect(find.text('العرض'), findsOneWidget); // the size chips
      await next(tester);

      expect(find.byType(ZonesScreen), findsOneWidget);
      expect(orchard.calls, contains('save zones'));
      final saved = orchard.design!;
      expect(saved.step, DesignStep.zones);
      expect(saved.outline, hasLength(4)); // the wobbles went away
      expect(polygonOk(saved.outline), isTrue);
      expect(boundsOf(saved.outline).center.x, closeTo(0, 0.01)); // centred
      expect(saved.toJson()['mode'], 'grid');
      await closeApp(tester);
    });

    testWidgets('Corners one by one: the first closes; undo, redo, erase', (
      tester,
    ) async {
      await openDesignerStart(tester);
      await startDrawing(tester);
      await tester.tap(find.text('نقاط'));
      await tester.pump();
      expect(
        find.text('اضغط على زوايا بستانك، واحدة بعد واحدة'),
        findsOneWidget,
      );
      final corners = [
        at(tester, 0.2, 0.2),
        at(tester, 0.8, 0.2),
        at(tester, 0.9, 0.6),
        at(tester, 0.5, 0.85),
        at(tester, 0.15, 0.7),
      ];
      for (final c in corners) {
        await tester.tapAt(c);
        await tester.pump();
      }
      expect(find.text('اضغط على النقطة الأولى لإغلاق الشكل'), findsOneWidget);
      await tester.tapAt(corners.first + const Offset(4, 3)); // near it
      await tester.pump();
      expect(find.text('اسحب نقطة لتحريكها'), findsOneWidget);
      final state = tester.state(find.byType(OutlineScreen));
      expect(find.textContaining('هكتار'), findsOneWidget);

      await tester.tap(find.text('تراجع')); // open again
      await tester.pump();
      expect(find.text('اضغط على النقطة الأولى لإغلاق الشكل'), findsOneWidget);
      await tester.tap(find.text('إعادة')); // closed again
      await tester.pump();
      expect(find.text('اسحب نقطة لتحريكها'), findsOneWidget);
      await tester.tap(find.text('امسح'));
      await tester.pump();
      expect(find.textContaining('هكتار'), findsNothing);
      await tester.tap(find.text('تراجع')); // the erase undone
      await tester.pump();
      expect(find.textContaining('هكتار'), findsOneWidget);
      expect(tester.state(find.byType(OutlineScreen)), same(state));
      await closeApp(tester);
    });

    testWidgets('Crossing sides: a short message, no "التالي"; moving a '
        'corner fixes it', (tester) async {
      final (orchard, _) = await openDesignerStart(tester);
      await startDrawing(tester);
      // A bow-tie: the 3rd and 4th corners swapped.
      final a = at(tester, 0.2, 0.2);
      final b = at(tester, 0.8, 0.2);
      final c = at(tester, 0.2, 0.8);
      final d = at(tester, 0.8, 0.8);
      await tapCorners(tester, [a, b, c, d]);
      expect(find.text('خطّان يتقاطعان. حرّك نقطة.'), findsOneWidget);
      await tester.tap(findTextWithSymbol('★ التالي'));
      await tester.pumpAndSettle();
      expect(find.byType(OutlineScreen), findsOneWidget); // not saved
      expect(orchard.calls, isNot(contains(startsWith('save'))));

      // Drag corner 3 (bottom left) to the bottom right, and 4 to the left.
      await tester.dragFrom(c, d - c + const Offset(0, 10));
      await tester.pumpAndSettle();
      await tester.dragFrom(d, c - d);
      await tester.pumpAndSettle();
      expect(find.text('خطّان يتقاطعان. حرّك نقطة.'), findsNothing);
      await next(tester);
      expect(find.byType(ZonesScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('The size in metres: the drawing takes it, the area follows; '
        'a wrong size is refused', (tester) async {
      final (orchard, _) = await openDesignerStart(tester);
      await startDrawing(tester);
      await drawAround(tester, square(tester));
      // A wrong size first.
      await tester.tap(find.text('العرض'));
      await tester.pumpAndSettle();
      expect(find.text('مقاس بستانك تقريبًا'), findsOneWidget);
      final boxes = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(boxes.at(0), '2');
      await tester.tap(find.text('تمّ'));
      await tester.pumpAndSettle();
      expect(find.text('اكتب رقمًا من 5 إلى 3000'), findsOneWidget);
      // Arabic digits work too: ٣٠٠ x 100.
      await tester.enterText(boxes.at(0), '٣٠٠');
      await tester.enterText(boxes.at(1), '100');
      await tester.tap(find.text('تمّ'));
      await tester.pumpAndSettle();
      expect(find.text('300 م'), findsOneWidget);
      expect(find.text('100 م'), findsOneWidget);
      expect(find.text('3.00 هكتار'), findsOneWidget);
      await next(tester);
      final b = boundsOf(orchard.design!.outline);
      expect(b.width, closeTo(300, 0.02));
      expect(b.length, closeTo(100, 0.02));
      await closeApp(tester);
    });

    testWidgets('With a mouse (Chrome): drawing and moving a corner', (
      tester,
    ) async {
      await openDesignerStart(tester);
      await startDrawing(tester);
      await drawAround(tester, square(tester), kind: PointerDeviceKind.mouse);
      expect(find.textContaining('هكتار'), findsOneWidget);
      final corner = square(tester).first;
      final mouse = await tester.startGesture(
        corner,
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveTo(corner + const Offset(30, 0));
      await mouse.moveTo(corner + const Offset(-40, -30));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('اسحب نقطة لتحريكها'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(find.textContaining('هكتار'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('A tiny scribble is not an orchard', (tester) async {
      await openDesignerStart(tester);
      await startDrawing(tester);
      final c = at(tester, 0.5, 0.5);
      await drawAround(tester, [
        c,
        c + const Offset(6, 0),
        c + const Offset(6, 5),
      ]);
      expect(find.text('الشكل صغير جدًا. ارسم أكبر.'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('step 2: the zones', () {
    testWidgets('Automatic: how many zones, the trees of each → the areas '
        'follow the trees', (tester) async {
      final (orchard, _) = await openDesignerStart(
        tester,
        draft: const OrchardDesign(step: DesignStep.zones)
            .copyWith(outline: rectangle),
      );
      expect(find.text('رسمك محفوظ. أكمل من حيث توقّفت.'), findsOneWidget);
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.byType(ZonesScreen), findsOneWidget);
      expect(find.text('أعطي عدد المناطق والأشجار'), findsOneWidget);
      expect(find.text('أرسم خطوط التقسيم بنفسي'), findsOneWidget);

      await tester.tap(find.text('أعطي عدد المناطق والأشجار'));
      await tester.pumpAndSettle();
      expect(find.text('عدد المناطق'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 ha: 2 zones at first
      final boxes = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(TextField),
      );
      await tester.enterText(boxes.at(0), '100');
      await tester.enterText(boxes.at(1), '300');
      await tester.pumpAndSettle();
      // One more zone, then one less.
      await tester.tap(find.bySemanticsLabel('أكثر'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('أقل'));
      await tester.pumpAndSettle();
      await next(tester);

      expect(find.byType(ZoneDetailsScreen), findsOneWidget);
      final zones = orchard.design!.zones;
      expect(orchard.design!.zoneMethod, ZoneMethod.auto);
      expect(zones.map((z) => z.letter), ['A', 'B']);
      expect(zones.map((z) => z.treeCount), [100, 300]);
      expect(polygonArea(zones[0].boundary), closeTo(5000, 1));
      expect(polygonArea(zones[1].boundary), closeTo(15000, 1));
      await closeApp(tester);
    });

    testWidgets('Automatic: a box without trees stops "التالي"', (
      tester,
    ) async {
      await openDesignerStart(
        tester,
        draft: const OrchardDesign().copyWith(outline: rectangle),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      await tester.tap(find.text('أعطي عدد المناطق والأشجار'));
      await tester.pumpAndSettle();
      final boxes = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(TextField),
      );
      await tester.enterText(boxes.at(0), '');
      await tester.pumpAndSettle();
      expect(find.text('شجرة واحدة على الأقل'), findsOneWidget);
      await tester.tap(findTextWithSymbol('★ التالي'));
      await tester.pumpAndSettle();
      expect(find.byType(ZonesScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('My own lines: each line cuts the zones it crosses; undo; '
        'a line that misses says so', (tester) async {
      final (orchard, _) = await openDesignerStart(
        tester,
        draft: const OrchardDesign().copyWith(outline: rectangle),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      await tester.tap(find.text('أرسم خطوط التقسيم بنفسي'));
      await tester.pumpAndSettle();
      expect(find.text('اسحب خطًا من طرف إلى طرف'), findsOneWidget);
      expect(find.text('منطقة واحدة'), findsOneWidget);

      // A line from top to bottom, then one across: 4 zones.
      await tester.dragFrom(
        at(tester, 0.5, 0.05),
        at(tester, 0.5, 0.95) - at(tester, 0.5, 0.05),
      );
      await tester.pumpAndSettle();
      expect(find.text('منطقتان'), findsOneWidget);
      await tester.dragFrom(
        at(tester, 0.02, 0.5),
        at(tester, 0.98, 0.5) - at(tester, 0.02, 0.5),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 مناطق'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(find.text('منطقتان'), findsOneWidget);
      // In a corner of the grid, outside the orchard.
      await tester.dragFrom(at(tester, 0.01, 0.03), const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(find.text('الخط لم يقسم أي منطقة.'), findsOneWidget);

      await next(tester);
      final saved = orchard.design!;
      expect(saved.zoneMethod, ZoneMethod.draw);
      expect(saved.zones, hasLength(2));
      expect(saved.cuts, hasLength(1));
      // The trees shared by area (the test farmer said none: 1 per 7 m).
      expect(
        saved.zones.map((z) => z.treeCount!).reduce((a, b) => a + b),
        estimateTrees(20000),
      );
      await closeApp(tester);
    });

    testWidgets('The details of a zone: trees, type, name, colour', (
      tester,
    ) async {
      final (orchard, _) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300]),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.byType(ZoneDetailsScreen), findsOneWidget); // where it was
      expect(find.text('المنطقة A'), findsOneWidget);
      expect(find.text('100 شجرة'), findsOneWidget);

      await tester.tap(find.text('المنطقة A'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final boxes = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      await tester.enterText(boxes.at(0), '0');
      await tester.tap(find.text('تمّ'));
      await tester.pumpAndSettle();
      expect(find.text('شجرة واحدة على الأقل'), findsOneWidget);
      await tester.enterText(boxes.at(0), '300'); // as many as B
      await tester.tap(find.text('أشجار كبيرة'));
      await tester.enterText(boxes.at(1), 'x' * 31);
      await tester.pump();
      // 30 letters at most (like the database): the 31st is not typed.
      expect(tester.widget<TextField>(boxes.at(1)).controller!.text, 'x' * 30);
      await tester.enterText(boxes.at(1), 'الجنان <b>');
      await tester.tap(find.text('تمّ'));
      await tester.pumpAndSettle();
      expect(find.text('لا تستعمل الرمزين < و >'), findsOneWidget);
      await tester.enterText(boxes.at(1), 'الجنان القبلي');
      await tester.tap(find.bySemanticsLabel('اللون 3'));
      await tester.tap(find.text('تمّ'));
      await tester.pumpAndSettle();

      expect(find.text('الجنان القبلي'), findsOneWidget);
      expect(find.text('300 شجرة · أشجار كبيرة'), findsOneWidget);
      await next(tester);
      final a = orchard.design!.zones.first;
      expect(a.name, 'الجنان القبلي');
      expect(a.type, ZoneType.oldTrees);
      expect(a.color, zoneColors[2]);
      expect(a.treeCount, 300);
      // Automatic zones: 300 and 300 trees → half and half.
      expect(polygonArea(a.boundary), closeTo(10000, 1));
      expect(orchard.design!.step, DesignStep.review);
      await closeApp(tester);
    });
  });

  group('step 3: the review, the payment, the orchard built', () {
    testWidgets('2 zones on 2 ha: 2 sensors, 16 DT → pay → built → 3D', (
      tester,
    ) async {
      final (orchard, payments) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300], step: DesignStep.review),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('الخطوة 3 من 3'), findsOneWidget);
      expect(find.text('2.00 هكتار'), findsOneWidget);
      expect(find.text('منطقتان'), findsOneWidget);
      expect(find.text('400 شجرة'), findsOneWidget);
      expect(find.text('حسّاسان'), findsOneWidget);
      expect(find.text('16 د.ت / 30 يومًا'), findsOneWidget);
      expect(find.textContaining('على الأقل'), findsNothing); // no minimum

      await tester.tap(findTextWithSymbol('★ ادفع وابنِ بستاني'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentScreen), findsOneWidget);
      await typeDemoCard(tester);
      await confirmDemoPayment(tester);
      expect(find.byType(PaymentResultScreen), findsOneWidget);
      expect(find.text('تم الدفع!'), findsOneWidget);
      orchard.holdBuild = Completer<void>();
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BuildOrchardScreen), findsOneWidget);
      expect(find.text('جاري بناء بستانك…'), findsOneWidget);
      orchard.holdBuild!.complete();
      await tester.pumpAndSettle();

      // "بستاني ★" with the orchard just built.
      expect(currentTab.value, AppTab.orchard);
      expect(find.byType(Orchard3dView), findsOneWidget);
      expect(orchard.orchard!.complete, isTrue);
      expect(orchard.orchard!.zones, hasLength(2));
      expect(orchard.orchard!.nodes.every((n) => !n.installed), isTrue);
      expect(orchard.orchard!.trees.length, inInclusiveRange(380, 400));
      expect(orchard.design, isNull);
      expect(payments.activePack!.zones, 2);
      expect(payments.calls, contains('pay accepted'));
      await closeApp(tester);
    });

    testWidgets('A big orchard with few zones: the area minimum in one '
        'sentence, with a tip', (tester) async {
      final big = scaleToSize(rectangle, 500, 200); // 10 ha
      final (_, _) = await openDesignerStart(
        tester,
        draft: OrchardDesign(
          step: DesignStep.review,
          outline: big,
          zoneMethod: ZoneMethod.auto,
          zones: [
            for (final (i, p) in splitByTrees(big, [500, 500]).indexed)
              DesignZone(
                letter: zoneLetter(i),
                boundary: rounded(p),
                color: zoneColors[i],
                treeCount: 500,
              ),
          ],
        ),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.text('5 حسّاسات'), findsOneWidget);
      expect(
        find.text(
          'بستانك 10.00 هكتار: يلزمه 5 حسّاسات على الأقل. '
          'قسّمه إلى 5 مناطق بنفس السعر.',
        ),
        findsOneWidget,
      );
      expect(find.text('40 د.ت / 30 يومًا'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('The pack already covers the zones: "★ ابنِ بستاني", no '
        'payment', (tester) async {
      final (orchard, payments) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300], step: DesignStep.review),
      );
      payments.activePack = ActivePack(
        endsAt: DateTime.now().add(const Duration(days: 20)),
        zones: 4,
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.text('باقتك تكفي هذا البستان.'), findsOneWidget);
      await tester.tap(findTextWithSymbol('★ ابنِ بستاني'));
      await tester.pumpAndSettle();
      expect(find.byType(Orchard3dView), findsOneWidget);
      expect(orchard.orchard!.zones, hasLength(2));
      expect(payments.calls, isNot(contains(startsWith('pay'))));
      await closeApp(tester);
    });

    testWidgets('Too big for one pack (more than 100 sensors): no payment', (
      tester,
    ) async {
      final huge = scaleToSize(rectangle, 2000, 1500); // 300 ha
      await openDesignerStart(
        tester,
        draft: OrchardDesign(
          step: DesignStep.review,
          outline: huge,
          zoneMethod: ZoneMethod.auto,
          zones: [
            DesignZone(
              letter: 'A',
              boundary: rounded(huge),
              color: zoneColors[0],
              treeCount: 9000,
            ),
          ],
        ),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.text('بستانك كبير جدًا. اتصل بنا.'), findsOneWidget);
      expect(findTextWithSymbol('★ ادفع وابنِ بستاني'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('Building fails (no internet): "حاول مرة أخرى" works, the '
        'payment is kept', (tester) async {
      final (orchard, payments) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300], step: DesignStep.review),
      );
      payments.activePack = ActivePack(
        endsAt: DateTime.now().add(const Duration(days: 20)),
        zones: 2,
      );
      orchard.failNext = AuthFailure.noInternet;
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      await tester.tap(findTextWithSymbol('★ ابنِ بستاني'));
      await tester.pumpAndSettle();
      expect(find.byType(BuildOrchardScreen), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();
      expect(find.byType(Orchard3dView), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('the draft', () {
    testWidgets('"بستاني ★" could not read the orchard: "حاول مرة أخرى" '
        'reads it again', (tester) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      logInTestUser();
      final orchard = useOrchard(demoOrchard())
        ..failNext = AuthFailure.noInternet;
      currentTab.value = AppTab.orchard;
      await tester.pumpWidget(const LoozApp(home: MainShell()));
      await tester.pumpAndSettle();
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();
      expect(find.byType(Orchard3dView), findsOneWidget);
      expect(orchard.loads, 2);
      await closeApp(tester);
    });

    testWidgets('"بستاني ★" with a draft: "★ ابدأ الرسم" → "★ أكمل الرسم"', (
      tester,
    ) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      logInTestUser();
      usePayments(authService as FakeAuthService);
      useOrchard(const MyOrchard(complete: false)).design = autoDraft([1, 2]);
      currentTab.value = AppTab.orchard;
      await tester.pumpWidget(const LoozApp(home: MainShell()));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, findTextWithSymbol('★ ابدأ الرسم'));
      expect(find.byType(DesignerStartScreen), findsOneWidget);
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.byType(ZoneDetailsScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('Saving fails (no internet): the drawing stays, a message', (
      tester,
    ) async {
      final (orchard, _) = await openDesignerStart(tester);
      await startDrawing(tester);
      await drawAround(tester, square(tester));
      orchard.failNext = AuthFailure.noInternet;
      await next(tester);
      expect(find.byType(OutlineScreen), findsOneWidget);
      expect(
        find.text('لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.'),
        findsOneWidget,
      );
      expect(find.textContaining('هكتار'), findsOneWidget); // not lost
      await next(tester);
      expect(find.byType(ZonesScreen), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('Going on: at the review → back goes through the steps; '
        '"ابدأ من جديد" erases the draft after a question', (tester) async {
      final (orchard, _) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300], step: DesignStep.review),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      expect(find.byType(ReviewScreen), findsOneWidget);
      for (final screen in [ZoneDetailsScreen, ZonesScreen, OutlineScreen]) {
        await tester.tap(find.byKey(const ValueKey('designer-back')).last);
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: '$screen');
      }
      // The outline is the saved one: "التالي" keeps the zones.
      await next(tester);
      await next(tester);
      expect(find.byType(ZoneDetailsScreen), findsOneWidget);
      expect(orchard.design!.zones, hasLength(2));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('designer-back')).last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(DesignerStartScreen), findsOneWidget);

      await scrollAndTap(tester, find.text('ابدأ من جديد'));
      expect(find.text('هل تمسح رسمك وتبدأ من جديد؟'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(orchard.design, isNotNull);
      await scrollAndTap(tester, find.text('ابدأ من جديد'));
      await tester.tap(find.text('امسح').last);
      await tester.pumpAndSettle();
      expect(orchard.calls, contains('discard'));
      expect(orchard.design, isNull);
      expect(find.byType(OutlineScreen), findsOneWidget);
      expect(find.textContaining('هكتار'), findsNothing); // empty
      await closeApp(tester);
    });

    testWidgets('A new outline drops the old zones', (tester) async {
      final (orchard, _) = await openDesignerStart(
        tester,
        draft: autoDraft([100, 300]),
      );
      await scrollAndTap(tester, findTextWithSymbol('★ أكمل الرسم'));
      await tester.tap(find.byKey(const ValueKey('designer-back')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('designer-back')).last);
      await tester.pumpAndSettle();
      expect(find.byType(OutlineScreen), findsOneWidget);
      await typeSize(tester, '400', '100');
      await next(tester);
      expect(orchard.design!.zones, isEmpty);
      expect(find.text('أعطي عدد المناطق والأشجار'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('the sign-up: Premium → draw → pay → the orchard', () {
    testWidgets('Every step, the payment at the review, the welcome, then '
        '"بستاني ★" in 3D', (tester) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      final auth = useFakeAuth();
      final payments = usePayments(auth);
      final orchard = useOrchard(null);
      auth.addUser(
        '+21650000004',
        firstName: 'سليم',
        lastName: 'الحمروني',
        role: UserRole.farmer,
        chosenPlan: Plan.paid,
        paymentStatus: PaymentStatus.pending,
      );
      auth.loggedIn = '+21650000004';
      currentUser.value = auth.me;
      currentPlan.value = Plan.free;
      await tester.pumpWidget(
        const LoozApp(home: DesignerStartScreen(signUp: true)),
      );
      await tester.pumpAndSettle();

      await startDrawing(tester);
      await tapCorners(tester, square(tester));
      await next(tester);
      await tester.tap(find.text('أعطي عدد المناطق والأشجار'));
      await tester.pumpAndSettle();
      await next(tester);
      await next(tester);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('متابعة مجانًا'), findsOneWidget);
      await tester.tap(findTextWithSymbol('★ ادفع وابنِ بستاني'));
      await tester.pumpAndSettle();
      await typeDemoCard(tester);
      await confirmDemoPayment(tester);
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('مرحبًا يا سليم'), findsOneWidget);
      expect(auth.me.paymentStatus, PaymentStatus.paid);
      await scrollAndTap(tester, find.text('ابدأ'));
      expect(currentTab.value, AppTab.orchard);
      expect(find.byType(Orchard3dView), findsOneWidget);
      expect(orchard.orchard!.complete, isTrue);
      expect(payments.activePack, isNotNull);
      await closeApp(tester);
    });
  });

  group('French and a small phone', () {
    testWidgets('French: every step in French, left to right', (tester) async {
      final (orchard, _) = await openDesignerStart(tester, lang: 'fr');
      expect(find.text("Sur l'image satellite"), findsOneWidget);
      await scrollAndTap(tester, findTextWithSymbol('★ Commencer le dessin'));
      expect(find.text('Étape 1 sur 3'), findsOneWidget);
      expect(find.text('Tracez le contour avec le doigt'), findsOneWidget);
      expect(find.text('Crayon'), findsOneWidget);
      await drawAround(tester, square(tester));
      await tester.tap(findTextWithSymbol('★ Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Divisez votre verger en zones'), findsOneWidget);
      await tester.tap(find.text('Je donne les zones et les arbres'));
      await tester.pumpAndSettle();
      await tester.tap(findTextWithSymbol('★ Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Vos zones'), findsOneWidget);
      expect(find.text('Zone A'), findsOneWidget);
      await tester.tap(findTextWithSymbol('★ Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Vérifiez votre verger'), findsOneWidget);
      expect(find.text('Étape 3 sur 3'), findsOneWidget);
      expect(findTextWithSymbol('★ Payer et créer mon verger'), findsOneWidget);
      expect(orchard.design!.step, DesignStep.review);
      final context = tester.element(find.byType(ReviewScreen));
      expect(Directionality.of(context), TextDirection.ltr);
      await closeApp(tester);
    });

    for (final lang in ['ar', 'fr']) {
      testWidgets('A small phone (360 x 640), $lang: every step fits', (
        tester,
      ) async {
        final small = const Size(360, 640);
        await openDesignerStart(
          tester,
          screen: small,
          lang: lang,
          draft: autoDraft([100, 300, 200], step: DesignStep.review),
        );
        expect(tester.takeException(), isNull);
        final l10n = lookupAppLocalizations(Locale(lang));
        await scrollAndTap(
          tester,
          findTextWithSymbol('★ ${l10n.continueDrawing}'),
        );
        // The review, then back through every step: nothing overflows.
        for (final screen in [
          ReviewScreen,
          ZoneDetailsScreen,
          ZonesScreen,
          OutlineScreen,
        ]) {
          expect(find.byType(screen), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$screen');
          await tester.tap(find.byKey(const ValueKey('designer-back')).last);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await closeApp(tester);
      });
    }
  });
}
