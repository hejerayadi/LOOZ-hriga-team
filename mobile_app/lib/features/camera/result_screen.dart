// The result of the photo diagnosis (Bêta): what it PROBABLY is ("على
// الأرجح") or "غير متأكد", the photo with the sick spots marked, 2-3 first
// steps (drafts to validate by an agronomist), "this is not a final
// diagnosis", and the big "اسأل خبيرًا": a community question with the
// photo, so a verified expert confirms.
// Nothing found: "لم نجد هذه الأمراض الثلاثة." (never "your tree is healthy").
// Every result: "هذا ليس تشخيصًا نهائيًا. اطلب رأي خبير." and "اسأل خبيرًا".
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_photos.dart';
import '../../data/diagnosis_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../shared/widgets/text_link.dart';
import '../alerts/alert_widgets.dart' show AdviceSteps;
import '../community/write_post_screen.dart';
import 'camera_screen.dart';
import 'diagnosis_texts.dart';
import 'diagnosis_widgets.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.diagnosis, required this.photo});

  final Diagnosis diagnosis;

  /// The photo sent (kept in memory: "اسأل خبيرًا" publishes it).
  final PreparedPhoto photo;

  void _askExpert(BuildContext context) {
    openScreen(
      context,
      WritePostScreen(
        initialText: expertQuestion(context.l10n, diagnosis),
        initialPhoto: photo,
        onPublished: (post) => diagnosisService.linkPost(diagnosis.id, post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disease = diagnosis.disease;
    final found = diagnosis.verdict != Verdict.nothing && disease != null;
    return ShellPage(
      children: [
        ScreenTitle(
          title: found ? diseaseName(l10n, disease) : l10n.notFoundTitle,
          subtitle: found
              ? certaintyWord(l10n, diagnosis.verdict)
              : l10n.notFoundTip,
        ),
        Row(
          children: [
            const BetaTag(),
            const Spacer(),
            // Reading aloud comes later.
            SpeakerButton(onPressed: () => showSoon(context)),
          ],
        ),
        const SizedBox(height: 12),
        MarkedPhoto(photo: photo, marked: found ? diagnosis.marked : const []),
        if (found && diagnosis.marked.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.spotsMarked,
            textAlign: TextAlign.center,
            style: AppTextStyles.of(
              15,
              FontWeight.w700,
            ).copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 14),
        if (found)
          _Card(
            children: [
              Text(l10n.whatToDo, style: AppTextStyles.cardTitle),
              const SizedBox(height: 12),
              AdviceSteps(steps: firstSteps(l10n, disease)),
            ],
          )
        else
          _Card(
            children: [
              _Line(icon: AppIcon.warning, text: l10n.notFoundNotHealthy),
              const SizedBox(height: 10),
              _Line(icon: AppIcon.leaf, text: l10n.weLookFor),
            ],
          ),
        // Always (also "لم نجد"): the model can be wrong.
        const SizedBox(height: 12),
        _Line(icon: AppIcon.warning, text: l10n.notFinalDiagnosis),
        const SizedBox(height: 18),
        ActionButton(
          label: l10n.askAnExpert,
          onPressed: () => _askExpert(context),
        ),
        TextLink(
          label: l10n.takeAnotherPhoto,
          onTap: () => replaceWith(context, const CameraScreen()),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// An icon on a small blob and a short sentence.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final AppIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBlob(icon: icon, size: 44, iconSize: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: AppTextStyles.of(17, FontWeight.w700)),
        ),
      ],
    );
  }
}
