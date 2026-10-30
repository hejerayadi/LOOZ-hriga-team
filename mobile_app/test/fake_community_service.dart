// A fake community for the tests: the questions, answers and photos are
// kept in memory, with the same rules as the database (only your own can
// be deleted, texts are checked). No internet needed.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/core/validators.dart';
import 'package:looz_mobile/data/community_models.dart';
import 'package:looz_mobile/data/community_photos.dart';
import 'package:looz_mobile/data/community_service.dart';

class FakeCommunityService implements CommunityService {
  /// Empty: no question yet.
  FakeCommunityService();

  /// 3 questions with answers, written in [lang] (like real farmers of
  /// that language would), the newest 2 hours ago.
  factory FakeCommunityService.sample([String lang = 'ar']) {
    final ar = lang == 'ar';
    final now = DateTime.now();
    final fatma = Author(
      id: 'fatma',
      firstName: ar ? 'فاطمة' : 'Fatma',
      lastName: ar ? 'القاسمي' : 'Gasmi',
      region: 'kairouan',
    );
    final sami = Author(
      id: 'sami',
      firstName: ar ? 'سامي' : 'Sami',
      lastName: ar ? 'الدريدي' : 'Dridi',
      region: 'sidi_bouzid',
      verifiedExpert: true,
    );
    final karim = Author(
      id: 'karim',
      firstName: 'Karim',
      lastName: 'Ben Youssef',
      region: 'sfax',
    );
    final fake = FakeCommunityService();
    fake.posts.addAll([
      Post(
        id: 'p1',
        type: PostType.question,
        text: ar
            ? 'شجرة اللوز عندي نوّرت في أكتوبر. هل هذه الزهرة سليمة؟'
            : 'Mon amandier a fleuri en octobre. Cette fleur est-elle saine ?',
        photo: 'demo:almond_blossoms',
        createdAt: now.subtract(const Duration(hours: 2)),
        author: fatma,
      ),
      Post(
        id: 'p2',
        type: PostType.question,
        text: ar
            ? 'قداش لازم نسقي اللوز في الخريف؟'
            : 'Combien arroser les amandiers en automne ?',
        createdAt: now.subtract(const Duration(days: 1)),
        author: ar ? fatma : karim,
      ),
      Post(
        id: 'p3',
        type: PostType.tip,
        text: ar
            ? 'نصيحة: نظّفوا الأرض من اللوز اللي طاح.'
            : 'Astuce : ramassez les amandes tombées.',
        createdAt: now.subtract(const Duration(days: 3)),
        author: ar ? fatma : karim,
      ),
    ]);
    fake.comments['p1'] = [
      Comment(
        id: 'c1',
        postId: 'p1',
        text: ar
            ? 'الزهرة سليمة، لكن التنوير في الخريف يضعف الشجرة.'
            : 'La fleur est saine, mais fleurir en automne affaiblit l’arbre.',
        createdAt: now.subtract(const Duration(hours: 1)),
        author: sami,
      ),
      Comment(
        id: 'c2',
        postId: 'p1',
        text: ar ? 'يعطيك الصحة.' : 'Merci beaucoup.',
        createdAt: now.subtract(const Duration(minutes: 30)),
        author: fatma,
      ),
    ];
    fake.comments['p2'] = [];
    fake.comments['p3'] = [];
    return fake;
  }

  /// The questions, newest first.
  final List<Post> posts = [];

  /// The answers of each question, oldest first.
  final Map<String, List<Comment>> comments = {};

  /// The photos of the bucket, by name (`<folder>/photo-1.jpg`).
  final Map<String, Uint8List> photos = {};

  /// The upload of the next photo fails with this error (once).
  CommunityFailure? failUpload;

  /// The next post with a photo is refused after its photo was uploaded
  /// (once): the photo must be removed again.
  CommunityFailure? failAfterUpload;

  /// Not null = the upload of a photo waits for it (to see "جاري رفع الصورة…").
  Completer<void>? holdUpload;

  /// Not null = writing the post waits for it (to see "جاري النشر…").
  Completer<void>? holdPublish;

  /// The next call fails with this error (once).
  CommunityFailure? failNext;

  /// Every call fails with "no internet".
  bool offline = false;

  /// The methods called, in order (e.g. "writeComment p1").
  final List<String> calls = [];

  var _nextId = 0;

  void _maybeFail() {
    if (offline) throw const CommunityError(CommunityFailure.noInternet);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw CommunityError(failure);
    }
  }

  /// The logged-in farmer, as the database would show him.
  Author get _me {
    final user = currentUser.value;
    if (user == null) {
      throw const CommunityError(CommunityFailure.sessionExpired);
    }
    return Author(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
    );
  }

  Post _withCounts(Post post) {
    final list = comments[post.id] ?? [];
    return post.copyWith(
      commentCount: list.length,
      hasExpertAnswer: list.any((c) => c.author.verifiedExpert),
    );
  }

  void _check(String text) {
    if (checkText(text) != null) {
      throw const CommunityError(CommunityFailure.invalidText);
    }
  }

  @override
  Future<List<Post>> loadPosts() async {
    calls.add('loadPosts');
    _maybeFail();
    return [for (final post in posts) _withCounts(post)];
  }

  @override
  Future<List<Comment>> loadComments(String postId) async {
    calls.add('loadComments $postId');
    _maybeFail();
    final list = comments[postId];
    if (list == null) throw const CommunityError(CommunityFailure.postGone);
    return List.of(list);
  }

  @override
  Future<Post> writePost(
    String text, {
    PreparedPhoto? photo,
    VoidCallback? onPhotoUploaded,
  }) async {
    calls.add(photo == null ? 'writePost' : 'writePost +photo');
    _maybeFail();
    _check(text);
    String? path;
    if (photo != null) {
      await holdUpload?.future;
      final failure = failUpload;
      if (failure != null) {
        failUpload = null;
        throw CommunityError(failure);
      }
      // Like the bucket: in the folder of the user.
      final folder = _me.id.replaceAll(RegExp(r'[^\w-]'), '');
      path = '$folder/photo-${_nextId++}.jpg';
      photos[path] = photo.bytes;
      onPhotoUploaded?.call();
    }
    await holdPublish?.future;
    final refused = path == null ? null : failAfterUpload;
    if (refused != null) {
      failAfterUpload = null;
      photos.remove(path); // like the app: no photo without its post
      throw CommunityError(refused);
    }
    final post = Post(
      id: 'new-post-${_nextId++}',
      type: PostType.question,
      text: cleanText(text),
      photo: path,
      createdAt: DateTime.now(),
      author: _me,
    );
    posts.insert(0, post);
    comments[post.id] = [];
    return post;
  }

  @override
  Future<Comment> writeComment(String postId, String text) async {
    calls.add('writeComment $postId');
    _maybeFail();
    _check(text);
    final list = comments[postId];
    if (list == null) throw const CommunityError(CommunityFailure.postGone);
    final comment = Comment(
      id: 'new-comment-${_nextId++}',
      postId: postId,
      text: cleanText(text),
      createdAt: DateTime.now(),
      author: _me,
    );
    list.add(comment);
    return comment;
  }

  @override
  Future<void> deletePost(Post post) async {
    calls.add('deletePost ${post.id}');
    _maybeFail();
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0 || posts[index].author.id != _me.id) {
      throw const CommunityError(CommunityFailure.notAllowed);
    }
    // Like the app: the photo first, then the post.
    final photo = posts[index].photoPath;
    if (photo != null) {
      calls.add('removePhoto $photo');
      photos.remove(photo);
    }
    posts.removeAt(index);
    comments.remove(post.id);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    calls.add('deleteComment $commentId');
    _maybeFail();
    for (final list in comments.values) {
      final index = list.indexWhere((c) => c.id == commentId);
      if (index < 0) continue;
      if (list[index].author.id != _me.id) {
        throw const CommunityError(CommunityFailure.notAllowed);
      }
      list.removeAt(index);
      return;
    }
    throw const CommunityError(CommunityFailure.notAllowed);
  }

  @override
  Future<Uint8List> loadPhoto(String path) async {
    calls.add('loadPhoto $path');
    _maybeFail();
    final bytes = photos[path];
    if (bytes == null) throw const CommunityError(CommunityFailure.unknown);
    return bytes;
  }
}
