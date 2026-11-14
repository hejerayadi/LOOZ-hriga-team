// "إبلاغ / Signaler" in the community (fake community, no internet): on the
// question and the answers of others (never your own, never in the list),
// the 4 reasons, "✓ أبلغت" (kept when the question is opened again), the
// text stays visible, once per text, 10 a day, a text already hidden, no
// internet, French.
// Run it with: flutter test test/report_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/features/community/post_screen.dart';

import 'fake_community_service.dart';
import 'test_helpers.dart';

/// Opens the first question of the fake community (Fatma's, with Sami's
/// and Fatma's answers), as the test farmer.
Future<FakeCommunityService> openQuestion(
  WidgetTester tester, {
  String lang = 'ar',
  void Function(FakeCommunityService fake)? before,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  appLocale.value = Locale(lang);
  logInTestUser(lang);
  final fake = useFakeCommunity(lang);
  before?.call(fake);
  await tester.pumpWidget(LoozApp(home: PostScreen(post: fake.posts.first)));
  await tester.pumpAndSettle();
  return fake;
}

/// The "إبلاغ" buttons, from the top (the question, then the answers).
Finder reportButtons([String label = 'إبلاغ']) => find.text(label);

/// Taps "إبلاغ" number [index], then the reason [reason] in the sheet.
Future<void> report(
  WidgetTester tester,
  int index,
  String reason, {
  String label = 'إبلاغ',
}) async {
  await scrollTo(tester, reportButtons(label).at(index));
  await tester.tap(reportButtons(label).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(reason));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('"إبلاغ" on the question and the answers of others only', (
    tester,
  ) async {
    await openQuestion(
      tester,
      before: (fake) => fake.comments['p1']!.add(
        Comment(
          id: 'mine',
          postId: 'p1',
          text: 'شكرًا على السؤال',
          createdAt: DateTime.now(),
          author: Author(id: currentUser.value!.id, firstName: 'محمد'),
        ),
      ),
    );
    // The question (Fatma), Sami's answer, Fatma's answer: 3. Mine: 🗑 only.
    expect(reportButtons(), findsNWidgets(3));
    await closeApp(tester);
  });

  testWidgets('never in the list of the community', (tester) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    logInTestUser();
    useFakeCommunity();
    currentTab.value = AppTab.community;
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    await tester.pumpAndSettle();
    expect(find.text('قداش لازم نسقي اللوز في الخريف؟'), findsOneWidget);
    expect(reportButtons(), findsNothing);
    await closeApp(tester);
  });

  testWidgets('the 4 reasons; "إلغاء" sends nothing', (tester) async {
    final fake = await openQuestion(tester);
    await scrollTo(tester, reportButtons().first);
    await tester.tap(reportButtons().first);
    await tester.pumpAndSettle();
    expect(find.text('لماذا تبلّغ؟'), findsOneWidget);
    for (final reason in [
      'إعلان أو إزعاج',
      'كلام مسيء',
      'نصيحة خاطئة أو خطيرة',
      'سبب آخر',
    ]) {
      expect(find.text(reason), findsOneWidget);
    }
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('لماذا تبلّغ؟'), findsNothing);
    expect(fake.calls.where((c) => c.startsWith('report')), isEmpty);
    await closeApp(tester);
  });

  testWidgets('an answer reported: "شكرًا", "✓ أبلغت", the text stays', (
    tester,
  ) async {
    final fake = await openQuestion(tester);
    await report(tester, 1, 'نصيحة خاطئة أو خطيرة'); // Sami's answer
    expect(fake.calls, contains('report comment c1 wrongAdvice'));
    expect(find.text('شكرًا. سيراجعه فريق لوز.'), findsOneWidget);
    expect(findTextWithSymbol('✓ أبلغت'), findsOneWidget);
    expect(reportButtons(), findsNWidgets(2));
    expect(
      find.text('الزهرة سليمة، لكن التنوير في الخريف يضعف الشجرة.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);

    // Opened again: still "✓ أبلغت" (the app asks what it reported).
    await tester.pumpWidget(LoozApp(home: PostScreen(post: fake.posts.first)));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'loadMyReports');
    expect(findTextWithSymbol('✓ أبلغت'), findsOneWidget);
    expect(reportButtons(), findsNWidgets(2));
    await closeApp(tester);
  });

  testWidgets('the question reported (spam)', (tester) async {
    final fake = await openQuestion(tester);
    await report(tester, 0, 'إعلان أو إزعاج');
    expect(fake.calls, contains('report post p1 spam'));
    expect(fake.reports, {'p1': ReportReason.spam});
    expect(findTextWithSymbol('✓ أبلغت'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('already reported (another phone): "✓ أبلغت" too', (
    tester,
  ) async {
    final fake = await openQuestion(tester);
    fake.reports['p1'] = ReportReason.other; // the app did not know it
    await report(tester, 0, 'كلام مسيء');
    expect(find.text('شكرًا. سيراجعه فريق لوز.'), findsOneWidget);
    expect(findTextWithSymbol('✓ أبلغت'), findsOneWidget);
    expect(fake.reports['p1'], ReportReason.other);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('10 a day: "بلغت الحد اليوم. حاول غدًا."', (tester) async {
    final fake = await openQuestion(tester, before: (f) => f.reportsToday = 10);
    await report(tester, 0, 'سبب آخر');
    expect(find.text('بلغت الحد اليوم. حاول غدًا.'), findsOneWidget);
    expect(fake.reports, isEmpty);
    expect(reportButtons(), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('hidden by the Looz team meanwhile: "لم يعد موجودًا"', (
    tester,
  ) async {
    final fake = await openQuestion(tester);
    fake.posts.removeAt(0); // hidden by an admin
    await report(tester, 0, 'إعلان أو إزعاج');
    expect(find.text('هذا السؤال لم يعد موجودًا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('no internet: the message, the button stays', (tester) async {
    final fake = await openQuestion(tester);
    fake.offline = true;
    await report(tester, 0, 'إعلان أو إزعاج');
    expect(
      find.text('لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(reportButtons(), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('French: "Signaler", the reasons, "✓ Signalé"', (tester) async {
    final fake = await openQuestion(tester, lang: 'fr');
    await scrollTo(tester, reportButtons('Signaler').first);
    await tester.tap(reportButtons('Signaler').first);
    await tester.pumpAndSettle();
    expect(find.text('Pourquoi signaler ?'), findsOneWidget);
    expect(find.text('Propos insultants'), findsOneWidget);
    expect(find.text('Conseil faux ou dangereux'), findsOneWidget);
    expect(find.text('Autre raison'), findsOneWidget);
    await tester.tap(find.text('Publicité ou spam'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('report post p1 spam'));
    expect(find.text("Merci. L'équipe LOOZ va vérifier."), findsOneWidget);
    expect(findTextWithSymbol('✓ Signalé'), findsOneWidget);
    expect(textsOnScreen().where(RegExp('[؀-ۿ]').hasMatch), isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });

  testWidgets('a small phone (360 x 640): the 4 reasons fit (or scroll)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    noAnimations(tester);
    logInTestUser();
    final fake = useFakeCommunity();
    await tester.pumpWidget(LoozApp(home: PostScreen(post: fake.posts.first)));
    await tester.pumpAndSettle();
    await scrollTo(tester, reportButtons().first);
    await tester.tap(reportButtons().first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('سبب آخر'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('سبب آخر'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('report post p1 other'));
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester);
  });
}
