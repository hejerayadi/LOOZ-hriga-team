// LIVE test: the photos of the community against the REAL Supabase project
// (migration 007, bucket "community"), with the test phone numbers (code
// 123456):
//
//   +21650000001 (01) publishes a post with a photo,
//   +21650000002 (02) sees the post and its photo, but can't delete them,
//   01 deletes the post: its photo is removed from Storage.
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/community_photo_live_test.dart --dart-define-from-file=.env
//
// Everything it writes is deleted at the end (texts start with
// "تجربة آلية", photos in the folder of 01).
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/supabase_config.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/features/community/community_widgets.dart';
import 'package:looz_mobile/features/community/photo_viewer.dart';
import 'package:looz_mobile/features/community/post_card.dart';
import 'package:looz_mobile/features/community/post_photo.dart';
import 'package:looz_mobile/features/community/post_screen.dart';
import 'package:looz_mobile/features/community/write_post_screen.dart';

import '../test/test_helpers.dart';
import 'auth_live_test.dart' show newClient, serverCall, step, waitFor;
import 'community_live_test.dart'
    show idOf, logIn, marker, phone01, phone02, show;

const _slow = Timeout(Duration(minutes: 6));
const bucket = SupabaseCommunityService.photoBucket;

/// The rule of community_photo_name_ok() (migration 007).
final photoName = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$',
);

late final SupabaseClient c01, c02;
late final SupabaseCommunityService s01, s02;

/// A photo like a phone's (2000 x 1500, made smaller by the app).
late final PreparedPhoto photo;

/// A new service each time: nothing kept in memory, the photo is really
/// downloaded.
Future<Uint8List> download(SupabaseClient client, String path) =>
    SupabaseCommunityService(client).loadPhoto(path);

/// Asks Storage itself, past the CDN cache (a new `cacheNonce` each time).
Future<Uint8List> fromStorage(SupabaseClient client, String path) =>
    client.storage.from(bucket).download(path, cacheNonce: randomPhotoId());

/// After a delete: is the photo really gone? (Supabase's CDN may still give
/// the link someone opened before, for at most 10 minutes: only printed.)
Future<Map<String, String?>> deletedPhoto(String path) async => {
  'in the folder of 01': (await photosOf(c01)).contains(path) ? 'yes' : null,
  '01 downloads it': await errorOf(() => download(c01, path)),
  '02 downloads it from Storage': await errorOf(() => fromStorage(c02, path)),
  '02 opens its old link again (CDN cache)': await errorOf(
    () => download(c02, path),
  ),
};

void expectGone(Map<String, String?> result) {
  expect(result['in the folder of 01'], isNull);
  expect(result['01 downloads it'], contains('Object not found'));
  expect(result['02 downloads it from Storage'], contains('Object not found'));
}

/// The names of the photos in the folder of [client]'s user.
Future<List<String>> photosOf(SupabaseClient client) async {
  final me = idOf(client);
  final files = await client.storage.from(bucket).list(path: me);
  return [for (final f in files) '$me/${f.name}'];
}

/// Why [work] failed (null = it did not fail).
Future<String?> errorOf(Future<Object?> Function() work) async {
  try {
    await work();
    return null;
  } on StorageException catch (e) {
    return 'StorageException ${e.statusCode}: ${e.message}';
  } on PostgrestException catch (e) {
    return 'PostgrestException ${e.code}: ${e.message}';
  } on CommunityError catch (e) {
    return 'CommunityError ${e.failure.name} (${e.cause})';
  }
}

Matcher failsWith(CommunityFailure failure) =>
    throwsA(isA<CommunityError>().having((e) => e.failure, 'failure', failure));

/// Deletes what this test wrote: the photos first, then the posts.
Future<void> cleanUp(SupabaseClient client) async {
  final me = idOf(client);
  final rows = await client
      .from('posts')
      .select('id, photo')
      .eq('author_id', me)
      .like('text', '$marker%');
  final mine = await photosOf(client);
  if (mine.isNotEmpty) await client.storage.from(bucket).remove(mine);
  for (final row in rows) {
    await client.from('posts').delete().eq('id', row['id'] as String);
  }
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
    s01 = SupabaseCommunityService(c01);
    s02 = SupabaseCommunityService(c02);
    await cleanUp(c01); // a run that stopped in the middle
    final big = img.Image(width: 2000, height: 1500);
    for (final p in big) {
      p
        ..r = 60 + p.x * 120 ~/ 2000
        ..g = 140 + p.y * 80 ~/ 1500
        ..b = 70;
    }
    photo = await preparePhoto(img.encodeJpg(big, quality: 95));
  });

  tearDownAll(() async {
    // New clients from the saved sessions: c01 and c02 were also used in the
    // app test, where a failure can leave them stuck (then cleaning up would
    // wait forever).
    for (final client in [c01, c02]) {
      final saved = jsonEncode(client.auth.currentSession!.toJson());
      final fresh = newClient();
      await fresh.auth.recoverSession(saved);
      await cleanUp(fresh).timeout(const Duration(seconds: 60));
      await fresh.auth.signOut();
      await fresh.dispose();
    }
  });
  tearDown(resetAppState);

  test(
    '1. 01 posts a photo, 02 sees it but cannot delete it, 01 deletes it',
    () async {
      step('01 publishes a post with a photo');
      var uploaded = false;
      final post = await s01.writePost(
        '$marker: منشور مع صورة',
        photo: photo,
        onPhotoUploaded: () => uploaded = true,
      );
      final path = post.photoPath!;
      expect(uploaded, isTrue);
      expect(path, startsWith('${idOf(c01)}/'));
      expect(path, matches(photoName));
      expect(await photosOf(c01), contains(path));
      show('The post of 01:', {
        'text': post.text,
        'photo': post.photo,
        'photo size':
            '${photo.width} x ${photo.height}, ${photo.bytes.length} bytes',
        'author': post.author.fullName,
      });

      step('02 sees the post and its photo');
      final seen = (await s02.loadPosts()).firstWhere((p) => p.id == post.id);
      expect(seen.photo, path);
      expect(seen.author.fullName, 'محمد بن سالم');
      expect(await download(c02, path), photo.bytes);

      step('02 cannot delete the post, nor its photo');
      await expectLater(
        s02.deletePost(seen),
        failsWith(CommunityFailure.notAllowed),
      );
      expect(await c02.storage.from(bucket).remove([path]), isEmpty);
      expect(await download(c02, path), photo.bytes); // still there
      expect((await s02.loadPosts()).any((p) => p.id == post.id), isTrue);

      step('01 deletes the post: the photo is removed from Storage');
      await s01.deletePost(post);
      expect((await s02.loadPosts()).any((p) => p.id == post.id), isFalse);
      final gone = await deletedPhoto(path);
      show('The deleted photo:', gone);
      expectGone(gone);
    },
    timeout: _slow,
  );

  test('2. The rules of the bucket and of posts.photo', () async {
    final me = idOf(c01);
    String newName([String ext = 'jpg']) => '$me/${randomPhotoId()}.$ext';
    final results = <String, String?>{};

    step('not logged in: no upload, no download');
    final anonymous = newClient();
    final anonName = newName();
    results['not logged in: upload'] = await errorOf(
      () => anonymous.storage.from(bucket).uploadBinary(anonName, photo.bytes),
    );
    expect(results['not logged in: upload'], isNotNull);

    step('02 cannot upload into the folder of 01');
    results['02 into the folder of 01'] = await errorOf(
      () => c02.storage
          .from(bucket)
          .uploadBinary(
            newName(),
            photo.bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          ),
    );
    expect(results['02 into the folder of 01'], isNotNull);

    step('the limits of the bucket: 5 MB, only JPEG / PNG / WebP');
    final tooBig = Uint8List(6 * 1024 * 1024)..setAll(0, photo.bytes);
    Future<void> upload(Uint8List bytes, String type, [String ext = 'jpg']) =>
        c01.storage
            .from(bucket)
            .uploadBinary(
              newName(ext),
              bytes,
              fileOptions: FileOptions(contentType: type),
            );
    try {
      await upload(tooBig, 'image/jpeg');
      fail('6 MB accepted');
    } on StorageException catch (e) {
      results['6 MB photo'] = 'StorageException ${e.statusCode}: ${e.message}';
      expect(communityFailureOf(e), CommunityFailure.photoTooBig);
    }
    try {
      await upload(photo.bytes, 'image/gif');
      fail('GIF accepted');
    } on StorageException catch (e) {
      results['GIF'] = 'StorageException ${e.statusCode}: ${e.message}';
      expect(communityFailureOf(e), CommunityFailure.photoWrongType);
    }
    results['a text file'] = await errorOf(
      () => upload(Uint8List.fromList(utf8.encode('hello')), 'text/plain'),
    );
    expect(results['a text file'], isNotNull);
    results['a name that is not random'] = await errorOf(
      () => c01.storage
          .from(bucket)
          .uploadBinary(
            '$me/photo.jpg',
            photo.bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          ),
    );
    expect(results['a name that is not random'], isNotNull);

    step('a photo not published yet: only 01 sees it');
    final draft = newName();
    await c01.storage
        .from(bucket)
        .uploadBinary(
          draft,
          photo.bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    expect(await download(c01, draft), photo.bytes);
    results['02 downloads a photo in no post'] = await errorOf(
      () => download(c02, draft),
    );
    expect(results['02 downloads a photo in no post'], isNotNull);
    results['not logged in downloads it'] = await errorOf(
      () => anonymous.storage.from(bucket).download(draft),
    );
    expect(results['not logged in downloads it'], isNotNull);

    step('posts.photo: only your own uploaded photo');
    Future<void> post(String photoName) => c01.from('posts').insert({
      'type': 'question',
      'text': '$marker: صورة ممنوعة',
      'photo': photoName,
    });
    for (final (what, name) in [
      ('the demo picture', 'demo:almond_blossoms'),
      ('a photo never uploaded', newName()),
      ('a photo of the folder of 02', '${idOf(c02)}/${randomPhotoId()}.jpg'),
      ('a link', 'https://example.com/a.jpg'),
    ]) {
      results['post with $what'] = await errorOf(() => post(name));
      expect(results['post with $what'], contains('22023'), reason: what);
    }

    step('a post refused after its upload: its photo is removed again');
    // 3 posts in 10 minutes = the spam limit: the 4th (with a photo) is refused.
    for (var i = 1; i <= 3; i++) {
      await s01.writePost('$marker: سؤال $i');
    }
    final before = await photosOf(c01);
    await expectLater(
      s01.writePost('$marker: الرابع مع صورة', photo: photo),
      failsWith(CommunityFailure.tooFast),
    );
    // The photo is removed in the background: wait a little.
    var after = await photosOf(c01);
    for (var i = 0; i < 20 && after.length > before.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      after = await photosOf(c01);
    }
    expect(after.toSet(), before.toSet());

    show('Refused (as they should be):', results);
    await cleanUp(c01);
    await anonymous.dispose();
  }, timeout: _slow);

  testWidgets(
    '3. In the app: 01 publishes a photo, opens it, deletes the post',
    (tester) async {
      usePhoneScreen(tester);
      noAnimations(tester);
      // The app opened with the saved session of 01; the gallery gives the photo.
      final saved = jsonEncode(c01.auth.currentSession!.toJson());
      final client = await serverCall(tester, 'saved session of 01', () async {
        final c = newClient();
        await c.auth.recoverSession(saved);
        return c;
      });
      authService = SupabaseAuthService(client);
      communityService = SupabaseCommunityService(client);
      usePhotoPicker().next.add(photo.bytes);
      await serverCall(tester, 'profile of 01', startSessionAfterLogin);
      currentTab.value = AppTab.community;
      await tester.pumpWidget(const LoozApp(home: MainShell()));
      await waitFor(tester, [find.byType(PostCard)]);

      step('"＋ انشر", a text and a photo of the gallery');
      await tester.tap(find.byType(PublishButton));
      await tester.pumpAndSettle();
      expect(find.byType(WritePostScreen), findsOneWidget);
      final text = '$marker: صورة من التطبيق';
      await tester.enterText(find.byType(TextField), text);
      await scrollAndTap(tester, find.text('اختر من الصور'));
      expect(find.byType(PhotoPreview), findsOneWidget);

      step('publishing');
      await scrollAndTap(tester, find.text('انشر'));
      final card = find.descendant(
        of: find.byType(PostCard),
        matching: find.text(text),
      );
      await waitFor(tester, [card], seconds: 90);
      expect(find.byType(WritePostScreen), findsNothing);
      final first = find.byType(PostCard).first;
      expect(
        find.descendant(of: first, matching: find.text(text)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.byType(PostPhoto)),
        findsOneWidget,
      );

      // 02 sees it and its photo.
      final posts = await serverCall(tester, 'posts seen by 02', s02.loadPosts);
      final mine = posts.firstWhere((p) => p.text == text);
      final path = mine.photoPath!;
      expect(path, matches(photoName));
      final bytes = await serverCall(
        tester,
        'photo downloaded by 02',
        () => download(c02, path),
      );
      expect(bytes, photo.bytes);

      step('the photo on the whole screen');
      await tester.tap(
        find.descendant(of: first, matching: find.byType(PostPhoto)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();

      step('deleting the post');
      await tester.tap(find.descendant(of: first, matching: find.text(text)));
      await waitFor(tester, [find.text('لا توجد إجابات بعد. كن أول من يجيب')]);
      await tester.tap(find.byType(DeleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      for (
        var i = 0;
        i < 300 && find.byType(PostScreen).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PostScreen), findsNothing);

      // Gone for 02, and the photo is no more in Storage.
      final left = await serverCall(tester, 'posts seen by 02', s02.loadPosts);
      expect(left.any((p) => p.id == mine.id), isFalse);
      final gone = await serverCall(
        tester,
        'is the photo still in Storage?',
        () => deletedPhoto(path),
      );
      show('In the app, the deleted photo ($path):', gone);
      expectGone(gone);

      // The list refreshes after the delete: let it finish before closing.
      await serverCall(
        tester,
        'last refresh of the list',
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      await serverCall(tester, 'closing the client', client.dispose);
    },
    timeout: _slow,
  );
}
