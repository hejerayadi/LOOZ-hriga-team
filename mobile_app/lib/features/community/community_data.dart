// FAKE posts for the "Communauté" page. Edit freely.
import '../../core/enums.dart';

/// One post shared by a farmer or an expert.
class Post {
  const Post({
    required this.author,
    required this.role,
    required this.text,
    required this.likes,
    required this.comments,
  });

  final String author;
  final UserRole role;
  final String text;
  final int likes;
  final int comments;
}

const List<Post> fakePosts = [
  Post(
    author: 'Mohamed B.',
    role: UserRole.farmer,
    text: 'Belle floraison cette année ! 🌸',
    likes: 24,
    comments: 5,
  ),
  Post(
    author: 'Dr. Salma K.',
    role: UserRole.expert,
    text: 'Taches sur les feuilles ? Vérifiez la tavelure.',
    likes: 41,
    comments: 12,
  ),
  Post(
    author: 'Fatma R.',
    role: UserRole.farmer,
    text: 'Goutte-à-goutte installé. Moins d\'eau perdue 💧',
    likes: 17,
    comments: 3,
  ),
];
