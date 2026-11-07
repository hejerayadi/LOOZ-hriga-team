// The small pieces of the community screens, in the design's style:
// buttons, badge, state cards, the text box, the photo of a new post and
// the sheets ("delete?", camera or gallery).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/community_photos.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import 'community_texts.dart';

/// The round ▶ of the design's card. The voice answers can't be played
/// yet: it says "قريبًا".
class PlayButton extends StatelessWidget {
  const PlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.a11yPlay,
      child: GestureDetector(
        onTap: () => showSoon(context),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
          ),
          child: SymbolText('▶', style: AppTextStyles.of(16)),
        ),
      ),
    );
  }
}

/// The round button to delete your own question or answer (not in the
/// design: same size as the speaker button).
class DeleteButton extends StatelessWidget {
  const DeleteButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.deleteAction,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.peach,
              shape: BoxShape.circle,
            ),
            child: const LoozIcon(AppIcon.trash, size: 22),
          ),
        ),
      ),
    );
  }
}

/// "＋ انشر": the green pill next to the title of the community (not in the
/// design: the color and shadow of its camera button).
class PublishButton extends StatelessWidget {
  const PublishButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.publish,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 52,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 0),
          decoration: BoxDecoration(
            color: AppColors.leaf,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.camera,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoozIcon(AppIcon.plus, size: 22),
              const SizedBox(width: 6),
              Text(
                context.l10n.publish,
                style: AppTextStyles.of(18, FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white card with an icon blob and a word, like the choices of the Ask
/// screen ("صورة", "كتابة"): "التقط صورة", "اختر من الصور".
class PhotoChoice extends StatelessWidget {
  const PhotoChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;

  /// null = not now (e.g. while publishing): shown faded.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: CssBox(
            minHeight: 90,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            shadows: AppShadows.card,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                IconBlob(icon: icon, iconSize: 38),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.of(22, FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo chosen for a new post, like it will be in the list (220 high),
/// with "تغيير" and "إزالة" under it.
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({
    super.key,
    required this.photo,
    required this.onChange,
    required this.onRemove,
  });

  final PreparedPhoto photo;

  /// null = not now (while publishing).
  final VoidCallback? onChange;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.memory(
              photo.bytes,
              height: 220,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: l10n.a11yPostPhoto,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallPill(
                  icon: AppIcon.image,
                  label: l10n.changePhoto,
                  color: AppColors.softGreen,
                  onTap: onChange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallPill(
                  icon: AppIcon.trash,
                  label: l10n.removePhoto,
                  color: AppColors.peach,
                  onTap: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoozIcon(icon, size: 22),
                const SizedBox(width: 8),
                Text(label, style: AppTextStyles.of(17, FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In the place of the photo while it is being made smaller (a second or
/// two): a pale card with "جاري تحضير الصورة…".
class PhotoPreparing extends StatelessWidget {
  const PhotoPreparing({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: CssBox(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        shadows: AppShadows.card,
        padding: const EdgeInsets.all(10),
        child: Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mintWhite,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoozIcon(AppIcon.image, size: 34),
              const SizedBox(height: 8),
              Text(
                context.l10n.preparingPhoto,
                style: AppTextStyles.of(17, FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "◆ خبير موثّق" on mint (smaller next to the name of an answer).
class ExpertBadge extends StatelessWidget {
  const ExpertBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: SymbolText(
        '◆ ${context.l10n.verifiedExpert}',
        style: AppTextStyles.of(small ? 13 : 16, FontWeight.w800),
      ),
    );
  }
}

/// A big state card of the design ("اسأل سؤالك الأول", "لا يوجد إنترنت",
/// "حاول مرة أخرى"): an icon blob and a bold text on a colored card.
class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
    this.height = 180,
  });

  final AppIcon icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          height: height,
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          shadows: AppShadows.card,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconBlob(icon: icon),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(17, FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's state card for an error: "لا يوجد إنترنت" (with "حاول مرة
/// أخرى" under it) or "حاول مرة أخرى". Both try again when tapped.
class FailureCard extends StatelessWidget {
  const FailureCard({
    super.key,
    required this.failure,
    required this.onRetry,
    this.height = 180,
  });

  final CommunityFailure failure;
  final VoidCallback onRetry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (failure != CommunityFailure.noInternet) {
      return StateCard(
        icon: AppIcon.warning,
        text: l10n.tryAgain,
        color: AppColors.peach,
        onTap: onRetry,
        height: height,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StateCard(
          icon: AppIcon.wifi,
          text: l10n.noInternet,
          color: AppColors.sky,
          onTap: onRetry,
          height: height,
        ),
        TextLink(label: l10n.tryAgain, onTap: onRetry),
      ],
    );
  }
}

/// A pale card in the place of a question while the list is loading.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.photo = true});

  /// false = smaller, like an answer.
  final bool photo;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.mintWhite,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
    return Semantics(
      label: context.l10n.loading,
      child: CssBox(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(photo ? AppRadius.xl : 26),
        shadows: AppShadows.card,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.mintWhite,
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bar(0.8, 22),
                  const SizedBox(height: 12),
                  bar(0.5, 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A message card under the text box: an icon on a blob and a bold text
/// (like the messages of the login).
class CommunityNote extends StatelessWidget {
  const CommunityNote(this.failure, {super.key});

  final CommunityFailure failure;

  @override
  Widget build(BuildContext context) {
    // No internet = wifi on sky, wait = clock on yellow, camera = camera,
    // photo = picture, others = bug (on peach).
    final (icon, color) = switch (failure) {
      CommunityFailure.noInternet => (AppIcon.wifi, AppColors.sky),
      CommunityFailure.tooFast => (AppIcon.clock, AppColors.yellow),
      CommunityFailure.cameraDenied ||
      CommunityFailure.galleryDenied ||
      CommunityFailure.noCamera => (AppIcon.camera, AppColors.peach),
      CommunityFailure.photoTooBig ||
      CommunityFailure.photoWrongType ||
      CommunityFailure.uploadFailed => (AppIcon.image, AppColors.peach),
      _ => (AppIcon.warning, AppColors.peach),
    };
    return Semantics(
      liveRegion: true,
      child: CssBox(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        shadows: AppShadows.card,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconBlob(icon: icon, size: 46, iconSize: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                communityFailureMessage(context.l10n, failure),
                style: AppTextStyles.of(16, FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white box to write a question or an answer (like the name boxes of
/// the sign-up), with the number of letters and the error under it.
class CommunityTextBox extends StatefulWidget {
  const CommunityTextBox({
    super.key,
    required this.controller,
    required this.hint,
    required this.problem,
    required this.onChanged,
    this.minLines = 3,
    this.maxLines = 8,
  });

  final TextEditingController controller;
  final String hint;

  /// What is wrong (null = nothing): shown under the box.
  final TextProblem? problem;

  final VoidCallback onChanged;
  final int minLines;
  final int maxLines;

  @override
  State<CommunityTextBox> createState() => _CommunityTextBoxState();
}

class _CommunityTextBoxState extends State<CommunityTextBox> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final problem = widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            // A green line while typing (and a dark one when it is wrong).
            border: Border.all(
              color: problem != null
                  ? AppColors.danger
                  : _focus.hasFocus
                  ? AppColors.leaf
                  : AppColors.white,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _focus,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.of(18, FontWeight.w600),
                cursorColor: AppColors.green,
                // No line of its own: the white box draws the green line
                // (the app's theme would add a second one when typing).
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hint,
                  hintStyle: AppTextStyles.of(18)
                      .copyWith(color: AppColors.textMuted),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (_) => widget.onChanged(),
              ),
              const SizedBox(height: 6),
              // "120 / 1000", always left to right (also in Arabic).
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final length = textLength(value.text);
                  return Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      l10n.charCount(length, communityTextMaxLength),
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.of(13, FontWeight.w700).copyWith(
                        color: length > communityTextMaxLength
                            ? AppColors.danger
                            : AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (problem != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
            child: Text(
              textProblemMessage(l10n, problem),
              style: AppTextStyles.of(
                15,
                FontWeight.w700,
              ).copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Asks "delete?" in a white sheet at the bottom. true = delete.
Future<bool> confirmDelete(BuildContext context, String question) async {
  final l10n = context.l10n;
  final answer = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CssBox(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          shadows: AppShadows.card,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                question,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(20, FontWeight.w800),
              ),
              const SizedBox(height: 20),
              ActionButton(
                label: l10n.deleteAction,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 12),
              ActionButton(
                label: l10n.cancelAction,
                secondary: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// Asks where the new photo comes from, in a white sheet at the bottom:
/// "التقط صورة" or "اختر من الصور" (null = closed).
Future<PhotoSource?> choosePhotoSource(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CssBox(
          color: AppColors.mintWhite,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          shadows: AppShadows.card,
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              PhotoChoice(
                icon: AppIcon.camera,
                label: l10n.takePhoto,
                onTap: () => Navigator.of(context).pop(PhotoSource.camera),
              ),
              const SizedBox(height: 14),
              PhotoChoice(
                icon: AppIcon.image,
                label: l10n.choosePhoto,
                onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
