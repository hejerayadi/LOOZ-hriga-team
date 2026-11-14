// A question of the community with its answers (not in the design: the
// app's own screen, in the design's style). The logged-in farmer can write
// an answer, and delete his own answers and his own question. On the
// question and the answers of others: "إبلاغ" (a reason, then "✓ أبلغت";
// the Looz team decides in the dashboard, the text stays visible).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/community_models.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import 'community_texts.dart';
import 'community_widgets.dart';
import 'post_card.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late Post _post = widget.post;
  final _answer = TextEditingController();

  /// null = not loaded yet.
  List<Comment>? _comments;
  CommunityFailure? _loadFailure;

  /// What is wrong with the typed answer (shown under the box).
  TextProblem? _problem;

  /// Why the last sending or deleting failed (shown under the box).
  CommunityFailure? _failure;
  bool _sending = false;

  /// The ids of the question / answers this farmer reported.
  final Set<String> _reported = {};

  /// The id being reported (its button is faded).
  String? _reporting;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final ids = await Future.sync(communityService.loadMyReports);
      if (mounted) setState(() => _reported.addAll(ids));
    } catch (_) {
      // Not known (no internet): the buttons stay; the database refuses a
      // second report anyway.
    }
  }

  Future<void> _report(ReportTarget target, String id) async {
    final l10n = context.l10n;
    final reason = await chooseReportReason(context);
    if (reason == null || !mounted || _reporting != null) return;
    setState(() => _reporting = id);
    var message = l10n.reportThanks;
    try {
      await communityService.report(target, id, reason);
      _reported.add(id);
    } catch (error) {
      final failure = communityFailureOf(error);
      if (failure == CommunityFailure.alreadyReported) _reported.add(id);
      message = communityFailureMessage(l10n, failure);
    } finally {
      if (mounted) setState(() => _reporting = null);
    }
    if (mounted) showMessage(context, message);
  }

  /// The "إبلاغ" of a text: null on your own text or once reported
  /// ("✓ أبلغت"); one report at a time.
  VoidCallback? _reportAction(ReportTarget target, String id, Author author) {
    if (_isMine(author) || _reported.contains(id)) return null;
    if (_reporting != null) return () {}; // one at a time
    return () => _report(target, id);
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  bool _isMine(Author author) => author.id == currentUser.value?.id;

  Future<void> _load() async {
    try {
      // (Future.sync: even an error at once arrives after initState.)
      final comments = await Future.sync(
        () => communityService.loadComments(_post.id),
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadFailure = null;
        _post = _post.copyWith(commentCount: comments.length);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadFailure = communityFailureOf(error));
    }
  }

  Future<void> _send() async {
    final problem = checkText(_answer.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final comment = await communityService.writeComment(
        _post.id,
        _answer.text,
      );
      if (!mounted) return;
      _answer.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _comments = [...?_comments, comment];
        _post = _post.copyWith(
          commentCount: _post.commentCount + 1,
          hasExpertAnswer:
              _post.hasExpertAnswer || comment.author.verifiedExpert,
        );
      });
      communityChanges.value++;
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final l10n = context.l10n;
    if (!await confirmDelete(context, l10n.deleteAnswerQuestion)) return;
    try {
      await communityService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _failure = null;
        _comments = [
          for (final c in _comments ?? <Comment>[])
            if (c.id != comment.id) c,
        ];
        _post = _post.copyWith(commentCount: _comments!.length);
      });
      communityChanges.value++;
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
    }
  }

  Future<void> _deletePost() async {
    final l10n = context.l10n;
    if (!await confirmDelete(context, l10n.deletePostQuestion)) return;
    try {
      await communityService.deletePost(_post); // its photo too
      communityChanges.value++;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comments = _comments;
    final loadFailure = _loadFailure;
    final failure = _failure;
    return ShellPage(
      children: [
        const SizedBox(height: 26),
        PostCard(
          post: _post,
          full: true,
          onDelete: _isMine(_post.author) ? _deletePost : null,
          onReport: _reportAction(ReportTarget.post, _post.id, _post.author),
          reported: _reported.contains(_post.id),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            l10n.communityAnswersTitle,
            style: AppTextStyles.sectionTitle,
          ),
        ),
        const SizedBox(height: 12),
        if (comments == null && loadFailure != null)
          FailureCard(failure: loadFailure, onRetry: _load, height: 150)
        else if (comments == null)
          const LoadingCard(photo: false)
        else if (comments.isEmpty)
          StateCard(
            icon: AppIcon.book,
            text: l10n.noAnswersYet,
            color: AppColors.mint,
            height: 150,
          )
        else
          for (final (i, comment) in comments.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _CommentCard(
              comment: comment,
              onDelete: _isMine(comment.author)
                  ? () => _deleteComment(comment)
                  : null,
              onReport: _reportAction(
                ReportTarget.comment,
                comment.id,
                comment.author,
              ),
              reported: _reported.contains(comment.id),
            ),
          ],
        const SizedBox(height: 18),
        CommunityTextBox(
          controller: _answer,
          hint: l10n.writeAnswerHint,
          problem: _problem,
          onChanged: () {
            if (_problem != null) setState(() => _problem = null);
          },
        ),
        if (failure != null) ...[
          const SizedBox(height: 12),
          CommunityNote(failure),
        ],
        const SizedBox(height: 14),
        ActionButton(
          label: _sending ? l10n.sending : l10n.send,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}

/// An answer: the name (and the expert badge), where and when, the text.
class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.onDelete,
    required this.onReport,
    required this.reported,
  });

  final Comment comment;

  /// Only on your own answers (null = no delete button).
  final VoidCallback? onDelete;

  /// "إبلاغ" on the answer of someone else (null = no button).
  final VoidCallback? onReport;

  /// Already reported: "✓ أبلغت".
  final bool reported;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final author = comment.author;
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(26),
      shadows: AppShadows.card,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          authorName(l10n, author),
                          style: AppTextStyles.of(17, FontWeight.w800),
                        ),
                        if (author.verifiedExpert)
                          const ExpertBadge(small: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      placeAndTime(l10n, author, comment.createdAt),
                      style: AppTextStyles.of(
                        14,
                        FontWeight.w600,
                      ).copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                DeleteButton(onPressed: onDelete)
              else if (onReport != null || reported)
                ReportButton(reported: reported, onPressed: onReport),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment.text, style: AppTextStyles.of(17)),
        ],
      ),
    );
  }
}
