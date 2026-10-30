// The community: the list of questions, a question with its answers,
// writing and deleting, the errors and the special states, in Arabic and
// French. With a fake community (see fake_community_service.dart).
// Run it with: flutter test
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/validators.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/features/ask/ask_screen.dart';
import 'package:looz_mobile/features/community/community_page.dart';
import 'package:looz_mobile/features/community/community_texts.dart';
import 'package:looz_mobile/features/community/community_widgets.dart';
import 'package:looz_mobile/features/community/post_card.dart';
import 'package:looz_mobile/features/community/post_screen.dart';
import 'package:looz_mobile/features/community/tips_screen.dart';
import 'package:looz_mobile/features/community/write_post_screen.dart';
import 'package:looz_mobile/shared/widgets/speaker_button.dart';

import 'fake_community_service.dart';
import 'test_helpers.dart';

final ar = lookupAppLocalizations(const Locale('ar'));
final fr = lookupAppLocalizations(const Locale('fr'));

/// Opens the community tab, logged in, in [lang].
Future<FakeCommunityService> openCommunity(
  WidgetTester tester, {
  String lang = 'ar',
  FakeCommunityService? community,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  logInTestUser(lang);
  final fake = community ?? useFakeCommunity(lang);
  communityService = fake;
  appLocale.value = Locale(lang);
  currentTab.value = AppTab.community;
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  return fake;
}

/// Opens the first question (the newest).
Future<void> openFirstQuestion(WidgetTester tester) async {
  await tester.tap(find.byType(PostCard).first);
  await tester.pumpAndSettle();
  expect(find.byType(PostScreen), findsOneWidget);
}

/// Types an answer and taps "أرسل".
Future<void> sendAnswer(WidgetTester tester, String text) async {
  await scrollTo(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await scrollAndTap(tester, find.text(ar.send));
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  group('the list of questions', () {
    testWidgets('Arabic: newest on top, then the tip, the button, the older', (
      tester,
    ) async {
      await openCommunity(tester);
      // Like the design, plus who wrote it, where and when.
      expect(find.text('المجتمع').first, findsOneWidget);
      expect(
        find.text('شجرة اللوز عندي نوّرت في أكتوبر. هل هذه الزهرة سليمة؟'),
        findsOneWidget,
      );
      expect(
        find.text('فاطمة القاسمي · القيروان · منذ ساعتين'),
        findsOneWidget,
      );
      expect(find.text('إجابتان'), findsOneWidget);
      expect(findTextWithSymbol('◆ خبير موثّق'), findsOneWidget);
      expect(find.text('نصيحة اليوم: اسقِ صباحًا'), findsOneWidget);

      // The order: question 1, tip, button, question 2, question 3.
      double top(Finder f) => tester.getTopLeft(f).dy;
      final first = top(find.byType(PostCard).first);
      final tip = top(find.text('نصيحة اليوم: اسقِ صباحًا'));
      final button = top(find.text('اسأل سؤالًا'));
      final second = top(find.text('قداش لازم نسقي اللوز في الخريف؟'));
      expect(first < tip && tip < button && button < second, isTrue);

      // An older question without photo, answers or expert.
      await scrollTo(
        tester,
        find.text('نصيحة: نظّفوا الأرض من اللوز اللي طاح.'),
      );
      expect(find.text('لا إجابة بعد'), findsNWidgets(2));
      expect(
        find.text('فاطمة القاسمي · القيروان · منذ 3 أيام'),
        findsOneWidget,
      );
    });

    testWidgets('French: the same list in French, left to right', (
      tester,
    ) async {
      await openCommunity(tester, lang: 'fr');
      expect(find.text('Communauté').first, findsOneWidget);
      expect(find.text('Fatma Gasmi · Kairouan · il y a 2 h'), findsOneWidget);
      expect(find.text('2 réponses'), findsOneWidget);
      expect(findTextWithSymbol('◆ Expert vérifié'), findsOneWidget);
      final page = tester.element(find.byType(CommunityPage));
      expect(Directionality.of(page), TextDirection.ltr);
    });

    testWidgets('Nothing yet: the design\'s "empty" card opens Ask', (
      tester,
    ) async {
      await openCommunity(tester, community: FakeCommunityService());
      expect(find.text(ar.askFirstQuestion), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      await tester.tap(find.text(ar.askFirstQuestion));
      await tester.pumpAndSettle();
      expect(find.byType(AskScreen), findsOneWidget);
    });

    testWidgets('No internet: the offline card, then "try again" loads', (
      tester,
    ) async {
      final fake = FakeCommunityService.sample()..offline = true;
      await openCommunity(tester, community: fake);
      expect(find.text(ar.noInternet), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);

      fake.offline = false;
      await tester.tap(find.text(ar.tryAgain));
      await tester.pumpAndSettle();
      expect(find.text(ar.noInternet), findsNothing);
      expect(find.byType(PostCard), findsWidgets);
    });

    testWidgets('Server error: the "try again" card', (tester) async {
      final fake = FakeCommunityService.sample()
        ..failNext = CommunityFailure.unknown;
      await openCommunity(tester, community: fake);
      expect(find.text(ar.tryAgain), findsOneWidget);
      await tester.tap(find.text(ar.tryAgain));
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsWidgets);
    });

    testWidgets('While loading: a pale card in the place of the question', (
      tester,
    ) async {
      final slow = _SlowCommunity();
      await openCommunity(tester, community: slow);
      expect(find.byType(LoadingCard), findsOneWidget);
      slow.release();
      await tester.pumpAndSettle();
      expect(find.byType(LoadingCard), findsNothing);
      expect(find.byType(PostCard), findsWidgets);
    });
  });

  group('a question and its answers', () {
    testWidgets('Opening a question shows all its text and its answers', (
      tester,
    ) async {
      await openCommunity(tester);
      await openFirstQuestion(tester);
      expect(find.text(ar.communityAnswersTitle), findsOneWidget);
      expect(find.text('سامي الدريدي'), findsOneWidget);
      expect(find.byType(ExpertBadge), findsNWidgets(2)); // card + answer
      expect(
        find.text('الزهرة سليمة، لكن التنوير في الخريف يضعف الشجرة.'),
        findsOneWidget,
      );
      expect(find.text('سيدي بوزيد · منذ ساعة'), findsOneWidget);
      expect(find.text('القيروان · منذ 30 دقيقة'), findsOneWidget);
      // Nothing of someone else can be deleted.
      expect(find.byType(DeleteButton), findsNothing);
    });

    testWidgets('A question without answers says so', (tester) async {
      await openCommunity(tester);
      await scrollAndTap(tester, find.text('قداش لازم نسقي اللوز في الخريف؟'));
      expect(find.text(ar.noAnswersYet), findsOneWidget);
    });

    testWidgets('Writing an answer: it is shown with my name, +1 answer', (
      tester,
    ) async {
      final fake = await openCommunity(tester);
      await openFirstQuestion(tester);
      await sendAnswer(tester, '  باهي، يعطيكم الصحة  ');

      expect(fake.calls, contains('writeComment p1'));
      expect(fake.comments['p1']!.last.text, 'باهي، يعطيكم الصحة');
      expect(find.text('باهي، يعطيكم الصحة'), findsOneWidget);
      expect(find.text('محمد بن سالم'), findsOneWidget); // my name
      expect(find.text(ar.timeJustNow), findsOneWidget);
      expect(find.text('3 إجابات'), findsOneWidget);
      // The box is empty again.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      // Back in the list: the new number of answers.
      Navigator.of(tester.element(find.byType(PostScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('3 إجابات'), findsOneWidget);
    });

    testWidgets('Deleting my answer: asked first, "إلغاء" keeps it', (
      tester,
    ) async {
      final fake = await openCommunity(tester);
      await openFirstQuestion(tester);
      await sendAnswer(tester, 'إجابة للحذف');
      expect(find.byType(DeleteButton), findsOneWidget); // only on mine

      await scrollAndTap(tester, find.byType(DeleteButton));
      expect(find.text(ar.deleteAnswerQuestion), findsOneWidget);
      await tester.tap(find.text(ar.cancelAction));
      await tester.pumpAndSettle();
      expect(find.text('إجابة للحذف'), findsOneWidget);

      await scrollAndTap(tester, find.byType(DeleteButton));
      await tester.tap(find.text(ar.deleteAction));
      await tester.pumpAndSettle();
      expect(find.text('إجابة للحذف'), findsNothing);
      expect(fake.calls, contains(startsWith('deleteComment')));
      expect(fake.comments['p1'], hasLength(2));
      expect(find.text('إجابتان'), findsOneWidget);
    });

    testWidgets('Deleting my question: back to the list, without it', (
      tester,
    ) async {
      final fake = FakeCommunityService.sample();
      logInTestUser();
      fake.posts.insert(
        0,
        Post(
          id: 'mine',
          type: PostType.question,
          text: 'سؤالي أنا',
          createdAt: DateTime.now(),
          author: Author(id: currentUser.value!.id, firstName: 'محمد'),
        ),
      );
      fake.comments['mine'] = [];
      await openCommunity(tester, community: fake);
      await openFirstQuestion(tester);
      await tester.tap(find.byType(DeleteButton));
      await tester.pumpAndSettle();
      expect(find.text(ar.deletePostQuestion), findsOneWidget);
      await tester.tap(find.text(ar.deleteAction));
      await tester.pumpAndSettle();

      expect(find.byType(PostScreen), findsNothing);
      expect(find.text('سؤالي أنا'), findsNothing);
      expect(fake.calls, contains('deletePost mine'));
    });

    testWidgets('Wrong answers are refused by the app (nothing sent)', (
      tester,
    ) async {
      final fake = await openCommunity(tester);
      await openFirstQuestion(tester);

      await sendAnswer(tester, '   ');
      expect(find.text(ar.textEmpty), findsOneWidget);

      await sendAnswer(tester, 'ا' * 1001);
      expect(find.text(ar.textTooLong('1000')), findsOneWidget);
      expect(find.text('1001 / 1000'), findsOneWidget);

      await sendAnswer(tester, '<b>مرحبا</b>');
      expect(find.text(ar.textBadCharacters), findsOneWidget);

      expect(fake.calls.where((c) => c.startsWith('writeComment')), isEmpty);
    });

    testWidgets('Errors of the server: too fast, no internet (text kept)', (
      tester,
    ) async {
      final fake = await openCommunity(tester);
      await openFirstQuestion(tester);

      fake.failNext = CommunityFailure.tooFast;
      await sendAnswer(tester, 'جواب');
      expect(find.text(ar.tooFast), findsOneWidget);
      expect(find.text('جواب'), findsOneWidget); // still in the box

      fake.offline = true;
      await scrollAndTap(tester, find.text(ar.send));
      expect(find.text(ar.errorNoInternet), findsOneWidget);

      fake.offline = false;
      await scrollAndTap(tester, find.text(ar.send));
      expect(find.text(ar.errorNoInternet), findsNothing);
      expect(fake.comments['p1']!.last.text, 'جواب');
    });

    testWidgets('French: the answers and the box in French', (tester) async {
      await openCommunity(tester, lang: 'fr');
      await openFirstQuestion(tester);
      expect(find.text('Réponses'), findsOneWidget);
      expect(find.text('Sami Dridi'), findsOneWidget);
      expect(find.text('Sidi Bouzid · il y a 1 h'), findsOneWidget);
      await scrollTo(tester, find.byType(TextField));
      expect(find.text('Écrivez votre réponse ici'), findsOneWidget);
      expect(find.text('0 / 1000'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '<i>');
      await scrollAndTap(tester, find.text(fr.send));
      expect(find.text("N'utilisez pas les signes < et >"), findsOneWidget);
    });
  });

  group('writing a question', () {
    testWidgets('Ask → "كتابة" → publish: the community shows it on top', (
      tester,
    ) async {
      final fake = await openCommunity(tester);
      await scrollAndTap(tester, find.text('اسأل سؤالًا'));
      await tester.tap(find.text('كتابة'));
      await tester.pumpAndSettle();
      expect(find.byType(WritePostScreen), findsOneWidget);
      expect(find.text('انشر في المجتمع'), findsOneWidget);

      // Empty: refused.
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.textEmpty), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'أوراق اللوز صفراء، شنوة نعمل؟',
      );
      await scrollAndTap(tester, find.text(ar.publish));

      expect(fake.calls, contains('writePost'));
      expect(fake.posts.first.author.id, currentUser.value!.id);
      expect(find.byType(WritePostScreen), findsNothing);
      expect(currentTab.value, AppTab.community);
      expect(find.text('أوراق اللوز صفراء، شنوة نعمل؟'), findsOneWidget);
      expect(find.text('محمد بن سالم · الآن'), findsOneWidget);
    });

    testWidgets('Too fast: the message, the question is not lost', (
      tester,
    ) async {
      usePhoneScreen(tester);
      logInTestUser();
      final fake = useFakeCommunity()..failNext = CommunityFailure.tooFast;
      await tester.pumpWidget(const LoozApp(home: WritePostScreen()));
      await tester.enterText(find.byType(TextField), 'سؤال');
      await scrollAndTap(tester, find.text(ar.publish));
      expect(find.text(ar.tooFast), findsOneWidget);
      expect(find.text('سؤال'), findsOneWidget);
      expect(fake.posts, hasLength(3));
    });
  });

  group('buttons that do not work yet say "قريبًا"', () {
    testWidgets('▶ on a question', (tester) async {
      await openCommunity(tester);
      await tester.tap(find.byType(PlayButton).first);
      await tester.pump();
      expect(find.text('قريبًا'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('the speakers of the tips library (French)', (tester) async {
      usePhoneScreen(tester);
      appLocale.value = const Locale('fr');
      await tester.pumpWidget(const LoozApp(home: TipsScreen()));
      await tester.tap(find.byType(SpeakerButton).first);
      await tester.pump();
      expect(find.text('Bientôt'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('texts and errors', () {
    test('"منذ…" with the right Arabic forms, and in French', () {
      final now = DateTime(2026, 10, 29, 12);
      String agoAr(Duration d) => timeAgo(ar, now.subtract(d), now: now);
      String agoFr(Duration d) => timeAgo(fr, now.subtract(d), now: now);
      expect(agoAr(const Duration(seconds: 20)), 'الآن');
      expect(agoAr(const Duration(minutes: 1)), 'منذ دقيقة');
      expect(agoAr(const Duration(minutes: 2)), 'منذ دقيقتين');
      expect(agoAr(const Duration(minutes: 5)), 'منذ 5 دقائق');
      expect(agoAr(const Duration(minutes: 15)), 'منذ 15 دقيقة');
      expect(agoAr(const Duration(hours: 1)), 'منذ ساعة');
      expect(agoAr(const Duration(hours: 2)), 'منذ ساعتين');
      expect(agoAr(const Duration(hours: 3)), 'منذ 3 ساعات');
      expect(agoAr(const Duration(hours: 12)), 'منذ 12 ساعة');
      expect(agoAr(const Duration(days: 1)), 'منذ يوم');
      expect(agoAr(const Duration(days: 2)), 'منذ يومين');
      expect(agoAr(const Duration(days: 3)), 'منذ 3 أيام');
      expect(agoAr(const Duration(days: 11)), 'منذ 11 يومًا');
      expect(agoAr(const Duration(days: 100)), 'منذ 100 يوم');
      expect(agoFr(const Duration(seconds: 20)), "À l'instant");
      expect(agoFr(const Duration(minutes: 15)), 'il y a 15 min');
      expect(agoFr(const Duration(hours: 2)), 'il y a 2 h');
      expect(agoFr(const Duration(days: 1)), 'il y a 1 jour');
      expect(agoFr(const Duration(days: 11)), 'il y a 11 jours');
    });

    test('the number of answers', () {
      expect(ar.answers(0), 'لا إجابة بعد');
      expect(ar.answers(1), 'إجابة واحدة');
      expect(ar.answers(2), 'إجابتان');
      expect(ar.answers(3), '3 إجابات');
      expect(ar.answers(12), '12 إجابة'); // like the design
      expect(fr.answers(0), 'Aucune réponse');
      expect(fr.answers(1), '1 réponse');
      expect(fr.answers(12), '12 réponses'); // like the design
    });

    test('the check of a question or an answer', () {
      expect(checkText('هل هذه الزهرة سليمة؟'), isNull);
      expect(checkText('Ligne 1\nLigne 2'), isNull); // line breaks are fine
      expect(checkText('ا' * 1000), isNull);
      expect(checkText(''), TextProblem.empty);
      expect(checkText('  \n  '), TextProblem.empty);
      expect(checkText('ا' * 1001), TextProblem.tooLong);
      for (final bad in [
        '<script>',
        'a > b',
        'a${String.fromCharCode(0)}b', // control character
        'a${String.fromCharCode(7)}b',
        'a${String.fromCharCode(0x202E)}b', // turns the text direction
      ]) {
        expect(checkText(bad), TextProblem.badCharacters, reason: bad);
      }
      expect(cleanText('  نص  \n'), 'نص');
    });

    test('a row of "community_posts" becomes a Post (no phone in it)', () {
      final post = Post.fromRow({
        'id': 'p1',
        'type': 'question',
        'text': 'نص',
        'photo': 'demo:almond_blossoms',
        'voice_note': null,
        'created_at': '2026-10-29T10:00:00+00:00',
        'author_id': 'a1',
        'author_first_name': 'فاطمة',
        'author_last_name': 'القاسمي',
        'author_region': 'kairouan',
        'author_verified_expert': false,
        'comment_count': 6,
        'has_expert_answer': true,
      });
      expect(post.photoAsset, 'assets/images/almond_blossoms.jpg');
      expect(post.author.fullName, 'فاطمة القاسمي');
      expect(post.commentCount, 6);
      expect(post.hasExpertAnswer, isTrue);
      expect(Post.columns, isNot(contains('phone')));
      expect(Comment.columns, isNot(contains('phone')));
      // A link that is not a demo picture is never loaded.
      final other = Post.fromRow({
        ...{'id': 'p2', 'type': 'tip', 'text': 'x'},
        'photo': 'https://example.com/a.jpg',
        'created_at': '2026-10-29T10:00:00+00:00',
        'author_id': 'a2',
      });
      expect(other.photoAsset, isNull);
      expect(other.type, PostType.tip);
      expect(authorName(ar, other.author), 'فلاح');
      expect(authorName(fr, other.author), 'Agriculteur');
    });

    test('each error of the server becomes the right message', () {
      final cases = <Object, CommunityFailure>{
        const PostgrestException(message: 'Too many', code: 'PT429'):
            CommunityFailure.tooFast,
        const PostgrestException(message: 'check', code: '23514'):
            CommunityFailure.invalidText,
        const PostgrestException(message: 'fk', code: '23503'):
            CommunityFailure.postGone,
        const PostgrestException(message: '0 rows', code: 'PGRST116'):
            CommunityFailure.postGone,
        const PostgrestException(message: 'rls', code: '42501'):
            CommunityFailure.notAllowed,
        const PostgrestException(message: 'JWT expired', code: 'PGRST303'):
            CommunityFailure.sessionExpired,
        TimeoutException('slow'): CommunityFailure.noInternet,
        AuthRetryableFetchException(message: 'Failed host lookup'):
            CommunityFailure.noInternet,
        StateError('?'): CommunityFailure.unknown,
      };
      cases.forEach((error, failure) {
        expect(communityFailureOf(error), failure, reason: '$error');
      });
    });

    test('every message is 100% Arabic or 100% French', () {
      final latin = RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]');
      final arabic = RegExp('[؀-ۿ]');
      List<String> all(AppLocalizations l10n) => [
        for (final f in CommunityFailure.values)
          communityFailureMessage(l10n, f),
        for (final p in TextProblem.values) textProblemMessage(l10n, p),
        for (final code in [
          'sfax',
          'kairouan',
          'sidi_bouzid',
          'gafsa',
          'kasserine',
          'mahdia',
          'zaghouan',
        ])
          regionName(l10n, code)!,
      ];
      // The names of the photo formats are the same in both languages
      // (the text was checked by the user): only them are allowed.
      String withoutFormats(String text) =>
          text.replaceAll(RegExp(r'\b(JPG|PNG|WebP)\b'), '');
      for (final text in all(ar)) {
        expect(withoutFormats(text), isNot(matches(latin)), reason: text);
      }
      for (final text in all(fr)) {
        expect(text, isNot(matches(arabic)), reason: text);
      }
      expect(regionName(ar, 'paris'), isNull);
    });
  });
}

/// A community that answers only when [release] is called (to see the
/// "loading" state).
class _SlowCommunity extends FakeCommunityService {
  _SlowCommunity() {
    posts.addAll(FakeCommunityService.sample().posts);
  }

  final _answer = Completer<void>();

  void release() => _answer.complete();

  @override
  Future<List<Post>> loadPosts() async {
    await _answer.future;
    return super.loadPosts();
  }
}
