// The community in the database (migrations 006 and 007): read the posts
// and their answers, write and delete your own, with a photo in the
// "community" bucket of Supabase Storage.
//
// The app only uses the publishable ("anon") key: the database decides who
// may read, write or delete (RLS), sets the author itself (never the app),
// and refuses wrong texts, photos that are not yours, and spam.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../core/validators.dart';
import 'auth_service.dart';
import 'community_models.dart';
import 'community_photos.dart';

/// Why a step failed. Each one has a message in Arabic and French
/// (see communityFailureMessage() in lib/features/community/community_texts.dart).
enum CommunityFailure {
  noInternet,
  tooFast, // the spam limit of the database
  invalidText, // empty, too long, < or > ...
  postGone, // the question was deleted (or hidden by an admin)
  notAllowed, // e.g. deleting the answer of someone else
  sessionExpired,
  photoTooBig, // more than 5 MB
  photoWrongType, // not a JPEG, PNG or WebP
  uploadFailed, // the photo was not uploaded (or refused)
  cameraDenied, // the farmer did not allow the camera
  galleryDenied, // ... or the photos
  noCamera, // no camera on this phone
  alreadyReported, // "إبلاغ" a second time on the same text
  reportLimit, // 10 reports a day
  unknown,
}

/// The error thrown by every CommunityService method.
class CommunityError implements Exception {
  const CommunityError(this.failure, [this.cause]);

  final CommunityFailure failure;

  /// The original error (for the developer).
  final Object? cause;

  @override
  String toString() => 'CommunityError(${failure.name}, $cause)';
}

/// What the app needs from the community. The app uses
/// SupabaseCommunityService; the tests use a fake one (no internet needed).
abstract class CommunityService {
  /// The newest posts first.
  Future<List<Post>> loadPosts();

  /// The answers of a post, oldest first (like a conversation).
  Future<List<Comment>> loadComments(String postId);

  /// Publishes a post of the logged-in user, with an optional photo: the
  /// photo is uploaded first ([onPhotoUploaded] is called then), and
  /// removed again if the post is refused.
  Future<Post> writePost(
    String text, {
    PreparedPhoto? photo,
    VoidCallback? onPhotoUploaded,
  });

  /// Publishes an answer of the logged-in user under a post.
  Future<Comment> writeComment(String postId, String text);

  /// Deletes your own post (and its answers): its photo first, then the
  /// post. If the post can't be deleted, you can try again.
  Future<void> deletePost(Post post);

  /// Deletes your own answer.
  Future<void> deleteComment(String commentId);

  /// The bytes of a photo of the "community" bucket (Post.photoPath).
  Future<Uint8List> loadPhoto(String path);

  /// "إبلاغ": reports a post or an answer of someone else (migration 013,
  /// report_content). Once per text (alreadyReported), 10 a day
  /// (reportLimit), never your own text.
  Future<void> report(ReportTarget target, String id, ReportReason reason);

  /// The ids of the posts and answers the user already reported.
  Future<Set<String>> loadMyReports();
}

CommunityService? _communityService;

/// The community: Supabase in the app (the tests put a fake one).
CommunityService get communityService =>
    _communityService ??= SupabaseCommunityService(supabase);
set communityService(CommunityService service) => _communityService = service;

/// Goes up by one after each question or answer written or deleted: the
/// community tab listens to it to refresh its list.
final ValueNotifier<int> communityChanges = ValueNotifier(0);

class SupabaseCommunityService implements CommunityService {
  SupabaseCommunityService(this._client);

  final SupabaseClient _client;

  /// Longest wait for an answer of the server.
  static const timeout = Duration(seconds: 20);

  /// Longest wait to upload or download a photo (weak mobile internet).
  static const photoTimeout = Duration(seconds: 90);

  /// How many posts the community tab shows (the newest).
  static const maxPosts = 50;

  /// The bucket of the photos (migration 007).
  static const photoBucket = 'community';

  /// The photos downloaded last (the list is not downloaded again each time).
  static const _maxCachedPhotos = 30;
  final _photos = <String, Uint8List>{};

  @override
  Future<List<Post>> loadPosts() => _run(() async {
    final rows = await _client
        .from('community_posts')
        .select(Post.columns)
        .order('created_at', ascending: false)
        .limit(maxPosts);
    return rows.map(Post.fromRow).toList();
  });

  @override
  Future<List<Comment>> loadComments(String postId) => _run(() async {
    final rows = await _client
        .from('community_comments')
        .select(Comment.columns)
        .eq('post_id', postId)
        // (Without "ascending: true" the newest would come first.)
        .order('created_at', ascending: true);
    return rows.map(Comment.fromRow).toList();
  });

  @override
  Future<Post> writePost(
    String text, {
    PreparedPhoto? photo,
    VoidCallback? onPhotoUploaded,
  }) async {
    final path = photo == null ? null : await _uploadPhoto(text, photo);
    if (path != null) onPhotoUploaded?.call();
    try {
      return await _run(() async {
        _check(text);
        // No author and no date: the database sets them.
        final row = await _client
            .from('posts')
            .insert({
              'type': 'question',
              'text': cleanText(text),
              'photo': ?path,
            })
            .select('id')
            .single();
        final post = await _client
            .from('community_posts')
            .select(Post.columns)
            .eq('id', row['id'] as String)
            .single();
        return Post.fromRow(post);
      });
    } catch (_) {
      // The post was refused (too fast...): no photo without its post.
      if (path != null) unawaited(_removePhoto(path));
      rethrow;
    }
  }

  /// Uploads the photo into the folder of the logged-in user:
  /// `<user id>/<random id>.jpg`. Returns its name in the bucket.
  Future<String> _uploadPhoto(String text, PreparedPhoto photo) async {
    _check(text); // not uploaded for a text that will be refused
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const CommunityError(CommunityFailure.sessionExpired);
    }
    if (photo.bytes.length > photoMaxBytes) {
      throw const CommunityError(CommunityFailure.photoTooBig);
    }
    final path = '${user.id}/${randomPhotoId()}.${PreparedPhoto.extension}';
    try {
      await _client.storage
          .from(photoBucket)
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: const FileOptions(
              contentType: PreparedPhoto.contentType,
              // Supabase's CDN keeps a photo at most 10 minutes: after a
              // delete, someone who already opened it can't get it longer.
              cacheControl: '600',
            ),
          )
          .timeout(photoTimeout);
    } catch (error) {
      throw CommunityError(communityFailureOf(error), error);
    }
    _photos[path] = photo.bytes; // no need to download it again
    return path;
  }

  /// Deletes a photo of the bucket (true = deleted). Only your own: the
  /// rules of the bucket silently skip the photos of the others.
  Future<bool> _removePhoto(String path) async {
    _photos.remove(path);
    final removed = await _client.storage.from(photoBucket).remove([path]);
    return removed.isNotEmpty;
  }

  @override
  Future<Comment> writeComment(String postId, String text) => _run(() async {
    _check(text);
    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('comments')
          .insert({'post_id': postId, 'text': cleanText(text)})
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      // Refused by the rules (hidden question) or no such question.
      if (error.code == '42501' || error.code == '23503') {
        throw CommunityError(CommunityFailure.postGone, error);
      }
      rethrow;
    }
    final comment = await _client
        .from('community_comments')
        .select(Comment.columns)
        .eq('id', row['id'] as String)
        .single();
    return Comment.fromRow(comment);
  });

  @override
  Future<void> deletePost(Post post) => _run(() async {
    // The photo first: a photo is never left without its post (Supabase
    // can only delete files with the Storage API, not in the database).
    final photo = post.photoPath;
    if (photo != null) await _removePhoto(photo);
    final rows = await _client
        .from('posts')
        .delete()
        .eq('id', post.id)
        .select('id');
    // The rules only delete your own: nothing deleted = not yours.
    if (rows.isEmpty) throw const CommunityError(CommunityFailure.notAllowed);
  });

  @override
  Future<void> deleteComment(String commentId) => _run(() async {
    final rows = await _client
        .from('comments')
        .delete()
        .eq('id', commentId)
        .select('id');
    if (rows.isEmpty) throw const CommunityError(CommunityFailure.notAllowed);
  });

  @override
  Future<Uint8List> loadPhoto(String path) async {
    final cached = _photos.remove(path);
    if (cached != null) return _photos[path] = cached; // now the newest
    try {
      final bytes = await _client.storage
          .from(photoBucket)
          .download(path)
          .timeout(photoTimeout);
      _photos[path] = bytes;
      if (_photos.length > _maxCachedPhotos) _photos.remove(_photos.keys.first);
      return bytes;
    } catch (error) {
      throw CommunityError(communityFailureOf(error), error);
    }
  }

  @override
  Future<void> report(ReportTarget target, String id, ReportReason reason) =>
      _run(() async {
        try {
          await _client.rpc(
            'report_content',
            params: {
              'p_type': target == ReportTarget.post ? 'post' : 'comment',
              'p_id': id,
              'p_reason': reason == ReportReason.wrongAdvice
                  ? 'wrong_advice'
                  : reason.name,
            },
          );
        } on PostgrestException catch (error) {
          final failure = switch (error.code) {
            '23505' => CommunityFailure.alreadyReported, // once per text
            'PT429' => CommunityFailure.reportLimit, // 10 a day
            'P0002' => CommunityFailure.postGone, // hidden or deleted
            '22023' => CommunityFailure.notAllowed, // your own text
            _ => null,
          };
          if (failure == null) rethrow;
          throw CommunityError(failure, error);
        }
      });

  @override
  Future<Set<String>> loadMyReports() => _run(() async {
    final user = _client.auth.currentUser;
    if (user == null) return <String>{};
    // The rules only give the user his own reports.
    final rows = await _client
        .from('content_reports')
        .select('post_id, comment_id')
        .eq('reporter_id', user.id);
    return {
      for (final row in rows)
        if ((row['post_id'] ?? row['comment_id']) case final String id) id,
    };
  });

  /// The app checks the text first (the database checks it again).
  void _check(String text) {
    final problem = checkText(text);
    if (problem != null) {
      throw CommunityError(CommunityFailure.invalidText, problem);
    }
  }

  /// Runs a call to the server: too slow = no internet, and every error
  /// becomes a CommunityError.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on CommunityError {
      rethrow;
    } catch (error) {
      throw CommunityError(communityFailureOf(error), error);
    }
  }
}

/// Turns an error of Supabase into a CommunityFailure.
CommunityFailure communityFailureOf(Object error) {
  if (error is CommunityError) return error.failure;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == 'PT429') return CommunityFailure.tooFast; // spam limit
    if (code == '23514') return CommunityFailure.invalidText; // text check
    if (code == '23503') return CommunityFailure.postGone; // no such post
    if (code == 'PGRST116') return CommunityFailure.postGone; // 0 rows
    if (code == '42501') return CommunityFailure.notAllowed; // the rules
    if (code == '22023') return CommunityFailure.uploadFailed; // not your photo
    if (code.startsWith('PGRST30')) return CommunityFailure.sessionExpired;
    return CommunityFailure.unknown;
  }
  if (error is StorageException) {
    // The limits of the "community" bucket (migration 007).
    if (error.statusCode == '413') return CommunityFailure.photoTooBig;
    if (error.statusCode == '415') return CommunityFailure.photoWrongType;
    if (error.message.toLowerCase().contains('jwt')) {
      return CommunityFailure.sessionExpired;
    }
    if (isNetworkError(error)) return CommunityFailure.noInternet;
    return CommunityFailure.uploadFailed;
  }
  // No internet, session expired...: the same as for the login.
  switch (failureOf(error)) {
    case AuthFailure.noInternet:
      return CommunityFailure.noInternet;
    case AuthFailure.sessionExpired:
      return CommunityFailure.sessionExpired;
    default:
      return CommunityFailure.unknown;
  }
}
