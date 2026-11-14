// The community: the posts (questions and tips of the farmers) and the
// comments under them (shown as "answers" / "إجابة", like in the design).
// Read from the lists "community_posts" and "community_comments" of the
// database (migration 006): they never contain a phone number.

/// The public information about the author of a post or a comment.
class Author {
  const Author({
    required this.id,
    this.firstName,
    this.lastName,
    this.region,
    this.verifiedExpert = false,
  });

  final String id;
  final String? firstName;
  final String? lastName;

  /// A code like "sfax" (shown in Arabic or French), null = not given.
  final String? region;

  /// An expert checked by the Looz team ("◆ خبير موثّق").
  final bool verifiedExpert;

  /// "محمد بن سالم", or null when the author has no name yet.
  String? get fullName {
    final name = [
      firstName,
      lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }

  static Author fromRow(Map<String, dynamic> row) => Author(
    id: row['author_id'] as String,
    firstName: row['author_first_name'] as String?,
    lastName: row['author_last_name'] as String?,
    region: row['author_region'] as String?,
    verifiedExpert: row['author_verified_expert'] as bool? ?? false,
  );
}

enum PostType { question, tip }

/// What is reported with "إبلاغ": a post or an answer.
enum ReportTarget { post, comment }

/// Why ("إعلان أو إزعاج", "كلام مسيء", "نصيحة خاطئة أو خطيرة", "سبب آخر").
enum ReportReason { spam, insult, wrongAdvice, other }

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.text,
    required this.createdAt,
    required this.author,
    this.photo,
    this.voiceNote,
    this.commentCount = 0,
    this.hasExpertAnswer = false,
  });

  final String id;
  final PostType type;
  final String text;
  final DateTime createdAt;
  final Author author;

  /// The photo of the farmer in the "community" bucket of Supabase Storage
  /// (`<user id>/<random id>.jpg`, see photoPath), or "demo:almond_blossoms"
  /// = a picture shipped in the app (only in the demo data).
  final String? photo;

  /// Not played yet (see the ▶ button).
  final String? voiceNote;

  final int commentCount;

  /// A verified expert answered ("◆ خبير موثّق" on the card).
  final bool hasExpertAnswer;

  static const columns =
      'id, type, text, photo, voice_note, created_at, author_id, '
      'author_first_name, author_last_name, author_region, '
      'author_verified_expert, comment_count, has_expert_answer';

  /// The picture of the app to show, or null.
  String? get photoAsset {
    final match = RegExp(r'^demo:([a-z0-9_]+)$').firstMatch(photo ?? '');
    return match == null ? null : 'assets/images/${match.group(1)}.jpg';
  }

  /// The name of the farmer's photo in the bucket, or null (no photo, or
  /// the demo picture).
  String? get photoPath {
    final name = photo ?? '';
    return RegExp(r'^[\w-]+/[\w-]+\.(jpg|jpeg|png|webp)$').hasMatch(name)
        ? name
        : null;
  }

  static Post fromRow(Map<String, dynamic> row) => Post(
    id: row['id'] as String,
    type: row['type'] == 'tip' ? PostType.tip : PostType.question,
    text: row['text'] as String,
    photo: row['photo'] as String?,
    voiceNote: row['voice_note'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    author: Author.fromRow(row),
    commentCount: (row['comment_count'] as num?)?.toInt() ?? 0,
    hasExpertAnswer: row['has_expert_answer'] as bool? ?? false,
  );

  Post copyWith({int? commentCount, bool? hasExpertAnswer}) => Post(
    id: id,
    type: type,
    text: text,
    createdAt: createdAt,
    author: author,
    photo: photo,
    voiceNote: voiceNote,
    commentCount: commentCount ?? this.commentCount,
    hasExpertAnswer: hasExpertAnswer ?? this.hasExpertAnswer,
  );
}

/// An answer under a post (table "comments").
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.text,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String postId;
  final String text;
  final DateTime createdAt;
  final Author author;

  static const columns =
      'id, post_id, text, created_at, author_id, author_first_name, '
      'author_last_name, author_region, author_verified_expert';

  static Comment fromRow(Map<String, dynamic> row) => Comment(
    id: row['id'] as String,
    postId: row['post_id'] as String,
    text: row['text'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    author: Author.fromRow(row),
  );
}
