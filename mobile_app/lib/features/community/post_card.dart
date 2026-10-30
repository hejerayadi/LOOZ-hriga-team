// A question of the community, as the design's "feed-card": the photo (if
// any), the text, who wrote it and when, ▶, the number of answers, and
// "◆ خبير موثّق" when a verified expert answered.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_models.dart';
import '../../shared/widgets/css_box.dart';
import 'community_texts.dart';
import 'community_widgets.dart';
import 'post_photo.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onDelete,
    this.full = false,
  });

  final Post post;

  /// Opens the question with its answers (null on the question's own screen).
  final VoidCallback? onTap;

  /// Shown only on your own question (null = no delete button).
  final VoidCallback? onDelete;

  /// true = the whole text; false = the first 3 lines (in the list).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tapping the photo shows it on the whole screen.
          if (post.photoAsset != null || post.photoPath != null)
            PostPhoto(post: post),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.text,
                  maxLines: full ? null : 3,
                  overflow: full ? null : TextOverflow.ellipsis,
                  style: AppTextStyles.of(20, FontWeight.w700),
                ),
                const SizedBox(height: 6),
                // Not in the design: who wrote it, where and when.
                Text(
                  '${authorName(l10n, post.author)} · '
                  '${placeAndTime(l10n, post.author, post.createdAt)}',
                  style: AppTextStyles.of(
                    15,
                    FontWeight.w600,
                  ).copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const PlayButton(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.answers(post.commentCount),
                        style: AppTextStyles.of(16),
                      ),
                    ),
                    if (onDelete != null) DeleteButton(onPressed: onDelete),
                  ],
                ),
                if (post.hasExpertAnswer) ...[
                  const SizedBox(height: 10),
                  const ExpertBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
