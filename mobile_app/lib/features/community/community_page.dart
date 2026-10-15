// Tab 2 — "Communauté": posts from farmers and experts.
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/looz_page.dart';
import '../../shared/widgets/role_badge.dart';
import 'community_data.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoozPage(
      title: AppStrings.tabCommunity,
      children: fakePosts.map((post) => _PostCard(post: post)).toList(),
    );
  }
}

/// One post: author + role badge, photo placeholder, text, like/comment.
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias, // so the photo follows the round corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author line
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.almond,
                  child: Icon(Icons.person, size: 32, color: AppColors.brown),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author, style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      RoleBadge(role: post.role),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Photo placeholder (real photos later)
          Container(
            height: 160,
            width: double.infinity,
            color: AppColors.olive.withValues(alpha: 0.15),
            child: const Icon(Icons.image, size: 64, color: AppColors.olive),
          ),
          // Text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(post.text, style: textTheme.bodyLarge),
          ),
          // Like + comment
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  iconSize: 30,
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border, color: AppColors.danger),
                ),
                Text('${post.likes}', style: textTheme.bodyLarge),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 30,
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.brown),
                ),
                Text('${post.comments}', style: textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
