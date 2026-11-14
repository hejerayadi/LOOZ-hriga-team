// "تنبيه في منطقتك": one REAL regional alert (frost, heat...): what is
// happening, "ماذا أفعل؟" in short steps, until when, how many farmers said
// "أنا أيضًا", and the buttons "أنا أيضًا" (once, can be taken back) and
// "تمّ" (when there is advice: "أحسنت!" with the petals, can be taken back).
// Opening it removes "جديد" (and the number on the bell).
import 'package:flutter/material.dart';

import '../../core/governorates.dart';
import '../../core/locale.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/alerts_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/falling_petals.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../shared/widgets/symbol_text.dart';
import '../../shared/widgets/text_link.dart';
import 'alert_widgets.dart';
import 'alerts_store.dart';

class RegionalScreen extends StatefulWidget {
  const RegionalScreen({super.key, required this.alert});

  final RegionalAlert alert;

  @override
  State<RegionalScreen> createState() => _RegionalScreenState();
}

class _RegionalScreenState extends State<RegionalScreen> {
  late RegionalAlert _alert = widget.alert;

  /// An admin ended it (or it is not for this farmer any more).
  bool _gone = false;

  /// A button is waiting for the server.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_alert.isNew) _markRead();
  }

  Future<void> _markRead() async {
    try {
      await Future.sync(() => alertsService.markRead(_alert.id));
      _keep(_alert.copyWith(isNew: false));
    } catch (error) {
      // Not saved (no internet...): it stays "جديد", nothing else to say.
      if (alertsFailureOf(error) == AlertsFailure.gone) _setGone();
    }
  }

  void _keep(RegionalAlert alert) {
    updateAlert(alert);
    if (mounted) setState(() => _alert = alert);
  }

  void _setGone() {
    removeAlert(_alert.id);
    if (mounted) setState(() => _gone = true);
  }

  /// Runs a button: one at a time; "ended" shows the message, other errors
  /// a short message.
  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final failure = alertsFailureOf(error);
      if (failure == AlertsFailure.gone) {
        _setGone();
      } else if (mounted) {
        showMessage(context, alertsFailureMessage(context.l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _meToo(bool on) => _act(() async {
    final count = await alertsService.setMeToo(_alert.id, on);
    _keep(_alert.copyWith(meToo: on, seenCount: count, isNew: false));
  });

  Future<void> _done(bool done) => _act(() async {
    await alertsService.setDone(_alert.id, done);
    _keep(_alert.copyWith(done: done, isNew: false));
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final alert = _alert;
    final steps = alert.adviceSteps(language);
    final region = governorateName(l10n, currentUser.value?.governorate);
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.regionalTitle, subtitle: region),
        // What is happening (the design's yellow card).
        CssBox(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          gradient: const CssLinearGradient(
            angle: 145,
            colors: [AppColors.yellow, AppColors.peach],
          ),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
          child: Column(
            children: [
              IconBlob(icon: kindIcon(alert.kind), size: 90, iconSize: 60),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  AlertPill(
                    text: severityName(l10n, alert.severity),
                    color: severityColor(alert.severity),
                  ),
                  AlertPill(text: kindName(l10n, alert.kind)),
                ],
              ),
              const SizedBox(height: 12),
              MoodFace(
                level: levelOf(alert.severity),
                small: true,
                semanticLabel: severityName(l10n, alert.severity),
              ),
              const SizedBox(height: 12),
              Text(
                alert.title(language),
                textAlign: TextAlign.center,
                style: AppTextStyles.of(24, FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                alert.body(language),
                textAlign: TextAlign.center,
                style: AppTextStyles.of(18),
              ),
            ],
          ),
        ),
        // "ماذا أفعل؟" with the steps, and 🔊 (reading aloud: "قريبًا").
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 14),
          CssBox(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            shadows: AppShadows.card,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.whatToDo,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    SpeakerButton(onPressed: () => showSoon(context)),
                  ],
                ),
                const SizedBox(height: 12),
                AdviceSteps(steps: steps),
              ],
            ),
          ),
        ],
        // Until when.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
          child: Row(
            children: [
              const LoozIcon(AppIcon.clock),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  alertValidity(l10n, alert),
                  style: AppTextStyles.of(17),
                ),
              ),
            ],
          ),
        ),
        // How many said "أنا أيضًا".
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          child: Row(
            children: [
              const LoozIcon(AppIcon.people),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  alert.seenCount == 0
                      ? l10n.meTooFirst
                      : l10n.meTooSaid(alert.seenCount),
                  style: AppTextStyles.of(18, FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (_gone) ..._goneNote(context) else ..._buttons(context, steps),
      ],
    );
  }

  /// "انتهى هذا التنبيه." and the way back to the list.
  List<Widget> _goneNote(BuildContext context) {
    final l10n = context.l10n;
    return [
      Semantics(
        liveRegion: true,
        child: CssBox(
          color: AppColors.peach,
          borderRadius: BorderRadius.circular(AppRadius.md),
          shadows: AppShadows.card,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const IconBlob(icon: AppIcon.clock, size: 46, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.alertGone,
                  style: AppTextStyles.of(17, FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      ActionButton(
        label: l10n.backToAlerts,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  List<Widget> _buttons(BuildContext context, List<String> steps) {
    final l10n = context.l10n;
    final alert = _alert;
    final busy = _busy;
    return [
      // "أنا أيضًا" → "✓ أنا أيضًا" + "تراجع".
      if (!alert.meToo)
        ActionButton(
          label: l10n.meToo,
          onPressed: busy ? null : () => _meToo(true),
        )
      else ...[
        _Chosen('✓ ${l10n.meToo}'),
        TextLink(
          label: l10n.takeBack,
          onTap: busy ? () {} : () => _meToo(false),
        ),
      ],
      // "تمّ" (only with advice) → "أحسنت!" + "تراجع".
      if (steps.isNotEmpty) ...[
        const SizedBox(height: 14),
        if (!alert.done)
          ActionButton(
            label: l10n.done,
            secondary: true,
            onPressed: busy ? null : () => _done(true),
          )
        else ...[
          const _WellDone(),
          TextLink(
            label: l10n.takeBack,
            onTap: busy ? () {} : () => _done(false),
          ),
        ],
      ],
    ];
  }
}

/// The answer already given ("✓ أنا أيضًا"): a mint pill, not a button.
class _Chosen extends StatelessWidget {
  const _Chosen(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return CssBox(
      minHeight: 64,
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: SymbolText(text, style: AppTextStyles.button),
    );
  }
}

/// "أحسنت!" with the falling petals (like the design's "done").
class _WellDone extends StatelessWidget {
  const _WellDone();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: CssBox(
        height: 170,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: const CssLinearGradient(
          angle: 180,
          colors: [AppColors.sky, AppColors.mint],
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // The petals fall from the top to just above the words.
            const Positioned(top: 6, child: FallingPetals()),
            Positioned.fill(
              top: 82,
              child: Column(
                children: [
                  Text(
                    l10n.wellDone,
                    style: AppTextStyles.of(24, FontWeight.w800),
                  ),
                  Text(l10n.alertDoneText, style: AppTextStyles.of(17)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
