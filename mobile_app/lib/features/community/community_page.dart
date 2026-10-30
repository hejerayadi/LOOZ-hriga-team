// Tab 2 — Community ("المجتمع"): the questions of the farmers, read from
// the database (newest first), the tip of the day, and a button to ask.
// Like the design: the newest question on top, then the tip and the
// button; the older questions come under them. Pull down to refresh.
// Not in the design: "＋ انشر" next to the title (a post with a photo).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_models.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/tip_row.dart';
import '../ask/ask_screen.dart';
import 'community_widgets.dart';
import 'post_card.dart';
import 'post_screen.dart';
import 'tips_screen.dart';
import 'write_post_screen.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  /// null = not loaded yet.
  List<Post>? _posts;

  /// The last loading failed (the old list, if any, is still shown).
  CommunityFailure? _failure;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh after a question or an answer was written or deleted, and
    // when the tab is opened again.
    communityChanges.addListener(_load);
    currentTab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    communityChanges.removeListener(_load);
    currentTab.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (currentTab.value == AppTab.community) _load();
  }

  Future<void> _load() async {
    try {
      // (Future.sync: even an error at once arrives after initState.)
      final posts = await Future.sync(() => communityService.loadPosts());
      if (!mounted) return;
      final oldFirst = _posts?.firstOrNull?.id;
      setState(() {
        _posts = posts;
        _failure = null;
      });
      // My question was just published: show it (it is on top).
      final first = posts.firstOrNull;
      if (oldFirst != null &&
          first != null &&
          first.id != oldFirst &&
          first.author.id == currentUser.value?.id &&
          _scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = communityFailureOf(error));
    }
  }

  void _open(Post post) => openScreen(context, PostScreen(post: post));

  void _ask() => openScreen(context, const AskScreen());

  void _write() => openScreen(context, const WritePostScreen());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final posts = _posts;
    final failure = _failure;
    final Widget top;
    if (posts == null) {
      top = failure == null
          ? const LoadingCard()
          : FailureCard(failure: failure, onRetry: _load);
    } else if (posts.isEmpty) {
      // The design's "empty" state.
      top = StateCard(
        icon: AppIcon.book,
        text: l10n.askFirstQuestion,
        color: AppColors.mint,
        onTap: _ask,
      );
    } else {
      top = PostCard(post: posts.first, onTap: () => _open(posts.first));
    }
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _load,
      child: ShellContent(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ScreenTitle(
                  title: l10n.communityTitle,
                  subtitle: l10n.communitySubtitle,
                ),
              ),
              const SizedBox(width: 12),
              // In the middle of the title and the line under it.
              Padding(
                padding: const EdgeInsets.only(top: 35),
                child: PublishButton(onPressed: _write),
              ),
            ],
          ),
          // Refreshing failed: the old list stays, with the reason on top.
          if (posts != null && failure != null) ...[
            CommunityNote(failure),
            const SizedBox(height: 14),
          ],
          top,
          const SizedBox(height: 14),
          TipRow(
            icon: AppIcon.drop,
            text: l10n.tipOfTheDay,
            onSpeaker: () => openScreen(context, const TipsScreen()),
          ),
          const SizedBox(height: 14),
          ActionButton(label: l10n.askAQuestion, onPressed: _ask),
          if (posts != null)
            for (final post in posts.skip(1)) ...[
              const SizedBox(height: 14),
              PostCard(post: post, onTap: () => _open(post)),
            ],
        ],
      ),
    );
  }
}
