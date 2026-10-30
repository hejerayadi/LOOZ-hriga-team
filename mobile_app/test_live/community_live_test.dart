// LIVE test: the community against the REAL Supabase project (migration
// 006 + the demo data), with the test phone numbers (code 123456):
//
//   +21650000001 (01) asks a test question and writes an answer,
//   +21650000002 (02) sees it with the name of 01 but can't delete it,
//   01 deletes it. +21650000003 (03) hits the spam limit.
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/community_live_test.dart --dart-define-from-file=.env
//
// Everything it writes is deleted at the end (texts start with
// "تجربة آلية").
//
// (6 minutes for each step: Supabase sends 1 code per number per minute,
// the login of the 3 numbers may wait.)
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/features/community/community_widgets.dart';
import 'package:looz_mobile/features/community/post_card.dart';
import 'package:looz_mobile/features/community/post_screen.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart'
    show newClient, sendCodeWaiting, serverCall, step, testCode, waitFor;

const phone01 = '+21650000001';
const phone02 = '+21650000002';
const phone03 = '+21650000003';
const _slow = Timeout(Duration(minutes: 6));

/// Every text written by this test starts with it (to clean up).
const marker = 'تجربة آلية';

/// The demo question with the photo (supabase/seed/community_demo.sql).
const blossomQuestion = 'شجرة اللوز عندي نوّرت في أكتوبر';

/// The 3 users, logged in once for all the tests.
late final SupabaseClient c01, c02, c03;
late final SupabaseCommunityService s01, s02, s03;

/// The test question of 01 (deleted at the end).
late final Post question;

/// The test question as [service] sees it now.
Future<Post> reload(CommunityService service) async {
  final posts = await service.loadPosts();
  return posts.firstWhere((p) => p.id == question.id);
}

Future<SupabaseClient> logIn(String phone) async {
  final client = newClient();
  final auth = SupabaseAuthService(client);
  await sendCodeWaiting(auth, phone);
  await auth.verifyCode(phone, testCode);
  return client;
}

String idOf(SupabaseClient client) => client.auth.currentUser!.id;

void show(String title, Object value) {
  // ignore: avoid_print
  print('\n$title\n${const JsonEncoder.withIndent('  ').convert(value)}');
}

Future<Post> findBlossomQuestion(CommunityService service) async {
  final posts = await service.loadPosts();
  return posts.firstWhere(
    (p) => p.text.startsWith(blossomQuestion),
    orElse: () => throw TestFailure(
      'Demo question not found: run supabase/seed/community_demo.sql',
    ),
  );
}

/// Deletes what this test wrote (also after a failed test).
Future<void> cleanUp(SupabaseClient client) async {
  final me = idOf(client);
  await client
      .from('comments')
      .delete()
      .eq('author_id', me)
      .like('text', '$marker%');
  await client
      .from('posts')
      .delete()
      .eq('author_id', me)
      .like('text', '$marker%');
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // Real internet (Flutter tests block it by default).
    HttpOverrides.global = null;
    expect(
      SupabaseConfig.hasKeys,
      isTrue,
      reason: 'Run with --dart-define-from-file=.env',
    );
    c01 = await logIn(phone01);
    c02 = await logIn(phone02);
    c03 = await logIn(phone03);
    s01 = SupabaseCommunityService(c01);
    s02 = SupabaseCommunityService(c02);
    s03 = SupabaseCommunityService(c03);
    question = await s01.writePost(
      '$marker: سؤال الاختبار، هل تصلكم الإجابات؟',
    );
  });

  tearDownAll(() async {
    for (final client in [c01, c02, c03]) {
      await cleanUp(client);
      await client.auth.signOut();
      await client.dispose();
    }
  });
  tearDown(resetAppState);

  test('1. The demo questions are there, newest first', () async {
    final posts = await s01.loadPosts();
    show('community_posts seen by 01 (${posts.length} questions):', [
      for (final p in posts.take(5))
        {
          'text': p.text,
          'author': p.author.fullName,
          'region': p.author.region,
          'answers': p.commentCount,
          'expert answered': p.hasExpertAnswer,
          'date': p.createdAt.toIso8601String(),
        },
    ]);
    expect(
      posts.where((p) => !p.text.startsWith(marker)).length,
      greaterThanOrEqualTo(15),
      reason: 'The demo data is missing: run supabase/seed/community_demo.sql',
    );
    for (var i = 1; i < posts.length; i++) {
      expect(posts[i - 1].createdAt.isBefore(posts[i].createdAt), isFalse);
    }
    final blossom = await findBlossomQuestion(s01);
    expect(blossom.photoAsset, 'assets/images/almond_blossoms.jpg');
    expect(blossom.commentCount, greaterThanOrEqualTo(6));
    expect(blossom.hasExpertAnswer, isTrue);
    final answers = await s01.loadComments(blossom.id);
    expect(answers.first.createdAt.isBefore(answers.last.createdAt), isTrue);
    expect(answers.any((a) => a.author.verifiedExpert), isTrue);
  });

  test('2. 01 answers, 02 sees it, 02 cannot delete it, 01 can', () async {
    final before = (await reload(s01)).commentCount;
    final text = '$marker: إجابة من 01 (ستُحذف)';

    final mine = await s01.writeComment(question.id, text);
    expect(mine.author.id, idOf(c01));
    expect(mine.author.fullName, 'محمد بن سالم');

    // 02 sees it, with the name of 01 (and nothing else about him).
    final seen = (await s02.loadComments(question.id))
        .firstWhere((c) => c.id == mine.id);
    show('The answer of 01, as 02 sees it:', {
      'text': seen.text,
      'author': seen.author.fullName,
      'region': seen.author.region,
      'verified expert': seen.author.verifiedExpert,
      'date': seen.createdAt.toIso8601String(),
    });
    expect(seen.text, text);
    expect(seen.author.fullName, 'محمد بن سالم');
    expect((await reload(s02)).commentCount, before + 1);

    // 02 can't delete it, nor change it.
    await expectLater(
      s02.deleteComment(mine.id),
      throwsA(
        isA<CommunityError>().having(
          (e) => e.failure,
          'failure',
          CommunityFailure.notAllowed,
        ),
      ),
    );
    final changed = await c02
        .from('comments')
        .update({'text': '$marker: changé par 02'})
        .eq('id', mine.id)
        .select();
    expect(changed, isEmpty);
    expect(
      (await s02.loadComments(question.id)).where((c) => c.id == mine.id),
      hasLength(1),
    );
    final still = await c01
        .from('comments')
        .select('text')
        .eq('id', mine.id)
        .single();
    expect(still['text'], text);

    // 01 deletes it: gone for 02 too.
    await s01.deleteComment(mine.id);
    expect(
      (await s02.loadComments(question.id)).where((c) => c.id == mine.id),
      isEmpty,
    );
    expect((await reload(s02)).commentCount, before);
  });

  test('3. The database sets the author and refuses wrong texts', () async {
    // 01 tries to write as 02: the database writes 01.
    final row = await c01
        .from('comments')
        .insert({
          'post_id': question.id,
          'text': '$marker: أنا 02؟',
          'author_id': idOf(c02),
          'created_at': '2020-01-01T00:00:00Z',
          'hidden': true,
        })
        .select('id, author_id, created_at, hidden')
        .single();
    expect(row['author_id'], idOf(c01));
    expect(
      DateTime.parse(row['created_at'] as String).year,
      DateTime.now().year,
    );
    expect(row['hidden'], isFalse);
    await c01.from('comments').delete().eq('id', row['id'] as String);

    // Refused by the database itself (code 23514), even without the app.
    for (final text in ['', '   ', '<b>$marker</b>', 'ا' * 1001]) {
      await expectLater(
        c01.from('comments').insert({'post_id': question.id, 'text': text}),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
        reason: text.length > 20 ? '1001 letters' : '"$text"',
      );
    }

    // A demo farmer can't be made: is_demo is protected.
    await expectLater(
      c01.from('profiles').update({'is_demo': true}).eq('id', idOf(c01)),
      throwsA(isA<PostgrestException>()),
    );

    // 02 can't delete or hide the question of 01.
    final deleted = await c02
        .from('posts')
        .delete()
        .eq('id', question.id)
        .select();
    expect(deleted, isEmpty);
    final hidden = await c02
        .from('posts')
        .update({'hidden': true})
        .eq('id', question.id)
        .select();
    expect(hidden, isEmpty);
    expect((await reload(s02)).id, question.id);
  });

  test('4. No phone number can be read from the community', () async {
    final posts = await c02.from('community_posts').select();
    final comments = await c02.from('community_comments').select();
    expect(posts, isNotEmpty); // at least the test question
    final all = jsonEncode([posts, comments]);
    expect(all, isNot(contains('+216')));
    expect(all, isNot(contains('21650000')));
    for (final row in [...posts, ...comments]) {
      expect(row.keys, isNot(contains('phone')));
      expect(row.keys, isNot(contains('payment_status')));
      expect(row.keys, isNot(contains('chosen_plan')));
      expect(row.keys, isNot(contains('role')));
    }
    // The lists have no such column at all.
    for (final view in ['community_posts', 'community_comments']) {
      await expectLater(
        c02.from(view).select('author_phone'),
        throwsA(isA<PostgrestException>()),
      );
    }
    // The public profile of 01: 4 things only.
    final public = await c02.rpc(
      'public_profile',
      params: {'p_user': idOf(c01)},
    );
    show('public_profile(01), asked by 02:', public as Object);
    final fields = (public as List).single as Map;
    expect(fields.keys.toSet(), {
      'first_name',
      'last_name',
      'region',
      'verified_expert',
    });
    // The profiles table: 02 only reads his own row.
    final profiles = await c02.from('profiles').select('id, phone');
    expect(profiles, hasLength(1));
    expect(profiles.single['phone'], phone02);

    // Not logged in: nothing at all.
    final anonymous = newClient();
    for (final view in ['community_posts', 'community_comments', 'posts']) {
      Object? rows;
      try {
        rows = await anonymous.from(view).select('id');
      } on PostgrestException {
        rows = null; // refused: fine
      }
      expect(rows == null || (rows as List).isEmpty, isTrue, reason: view);
    }
    await expectLater(
      anonymous.rpc('public_profile', params: {'p_user': idOf(c01)}),
      throwsA(isA<PostgrestException>()),
    );
    await anonymous.dispose();
  });

  test('5. Spam: 03 can write 5 answers in a minute, not 6', () async {
    for (var i = 1; i <= 5; i++) {
      await s03.writeComment(question.id, '$marker: رسالة $i');
    }
    await expectLater(
      s03.writeComment(question.id, '$marker: رسالة 6'),
      throwsA(
        isA<CommunityError>().having(
          (e) => e.failure,
          'failure',
          CommunityFailure.tooFast,
        ),
      ),
    );
    // And 3 questions in 10 minutes, not 4.
    for (var i = 1; i <= 3; i++) {
      await s03.writePost('$marker: سؤال $i');
    }
    await expectLater(
      s03.writePost('$marker: سؤال 4'),
      throwsA(
        isA<CommunityError>().having(
          (e) => e.failure,
          'failure',
          CommunityFailure.tooFast,
        ),
      ),
    );
    await cleanUp(c03);
    final left = await c03
        .from('comments')
        .select('id')
        .eq('author_id', idOf(c03));
    expect(left, isEmpty);
  }, timeout: _slow);

  testWidgets('6. In the app: 01 answers a question, then deletes it', (
    tester,
  ) async {
    usePhoneScreen(tester);
    noAnimations(tester);
    // The app opened with the saved session of 01.
    final saved = jsonEncode(c01.auth.currentSession!.toJson());
    final client = await serverCall(tester, 'saved session of 01', () async {
      final c = newClient();
      await c.auth.recoverSession(saved);
      return c;
    });
    authService = SupabaseAuthService(client);
    communityService = SupabaseCommunityService(client);
    await serverCall(tester, 'profile of 01', startSessionAfterLogin);
    currentTab.value = AppTab.community;
    await tester.pumpWidget(const LoozApp(home: MainShell()));
    await waitFor(tester, [find.byType(PostCard)]);
    // The test question of 01 is the newest: on top.
    expect(find.textContaining(question.text), findsOneWidget);

    step('opening the question');
    await tester.tap(find.textContaining(question.text));
    await waitFor(tester, [find.text('لا توجد إجابات بعد. كن أول من يجيب')]);
    // My own question: it can be deleted; no answer yet.
    expect(find.byType(DeleteButton), findsOneWidget);

    step('writing an answer');
    final text = '$marker: إجابة من التطبيق';
    final box = find.byType(TextField);
    await tester.scrollUntilVisible(
      box,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(box, text);
    await tester.ensureVisible(find.text('أرسل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرسل'));
    // The answer card (not the box, which still shows the text while sending).
    final answerCard = find.byWidgetPredicate(
      (w) => w is Text && w.data == text,
    );
    await waitFor(tester, [answerCard]);
    // Back up to the question: "1 answer" now.
    await tester.scrollUntilVisible(
      find.text('إجابة واحدة'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إجابة واحدة'), findsOneWidget);
    expect(find.byType(DeleteButton), findsNWidgets(2)); // question + answer

    // 02 sees it (with the name of 01).
    final seen = await serverCall(
      tester,
      'answers seen by 02',
      () => s02.loadComments(question.id),
    );
    expect(
      seen.where((c) => c.text == text).single.author.fullName,
      'محمد بن سالم',
    );

    step('deleting it');
    final answerDelete = find.byType(DeleteButton).last;
    await tester.ensureVisible(answerDelete);
    await tester.pumpAndSettle();
    await tester.tap(answerDelete);
    await tester.pumpAndSettle();
    expect(find.text('هل تريد حذف إجابتك؟'), findsOneWidget);
    await tester.tap(find.text('حذف'));
    for (var i = 0; i < 200 && answerCard.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(answerCard, findsNothing);
    expect(find.byType(PostScreen), findsOneWidget);

    // 02 doesn't see it any more.
    final answers = await serverCall(
      tester,
      'answers seen by 02',
      () => s02.loadComments(question.id),
    );
    expect(answers.where((c) => c.text == text), isEmpty);

    // The list of the community refreshes after the delete: let it finish
    // (and let the waits of the app run out) before closing.
    await serverCall(
      tester,
      'last refresh of the list',
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    await serverCall(tester, 'closing the client', client.dispose);
  }, timeout: _slow);
}
