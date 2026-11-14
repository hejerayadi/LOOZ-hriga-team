// "جاري النظر…": the photo is sent to the diagnosis (the Edge Function
// "diagnose"), then the result opens. If it fails: one clear message and
// the next step ("حاول مرة أخرى", "اسأل خبيرًا", "صوّر ورقة أخرى").
// The paid pack ended meanwhile: the locked screen.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_photos.dart';
import '../../data/diagnosis_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/assistant_orb.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_logo.dart';
import '../../shared/widgets/text_link.dart';
import '../community/write_post_screen.dart';
import 'camera_screen.dart';
import 'diagnosis_texts.dart';
import 'result_screen.dart';

class ThinkingScreen extends StatefulWidget {
  const ThinkingScreen({super.key, required this.photo});

  /// Already small and without its hidden data (GPS).
  final PreparedPhoto photo;

  @override
  State<ThinkingScreen> createState() => _ThinkingScreenState();
}

class _ThinkingScreenState extends State<ThinkingScreen> {
  DiagnosisError? _error;

  @override
  void initState() {
    super.initState();
    _send();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    try {
      final diagnosis = await Future.sync(
        () => diagnosisService.diagnose(widget.photo),
      );
      if (mounted) {
        replaceWith(
          context,
          ResultScreen(diagnosis: diagnosis, photo: widget.photo),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final failure = error is DiagnosisError
          ? error
          : DiagnosisError(diagnosisFailureOf(error), cause: error);
      if (failure.failure == DiagnosisFailure.notPaid) {
        goToTab(context, AppTab.orchard); // the locked screen
        return;
      }
      setState(() => _error = failure);
    }
  }

  void _askExpert() =>
      replaceWith(context, WritePostScreen(initialPhoto: widget.photo));

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    final error = _error;
    return Scaffold(
      body: LoozBackground(
        child: Stack(
          children: [
            Positioned(
              top: system.top + 30,
              left: 0,
              right: 0,
              child: const Center(child: LoozLogo()),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  system.top + 110,
                  20,
                  system.bottom + 24,
                ),
                child: error == null
                    ? _Looking(photo: widget.photo)
                    : _Failure(
                        error: error,
                        onRetry: _send,
                        onAskExpert: _askExpert,
                        onNewPhoto: () =>
                            replaceWith(context, const CameraScreen()),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The orb, "جاري النظر…" and the photo being looked at.
class _Looking extends StatelessWidget {
  const _Looking({required this.photo});

  final PreparedPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AssistantOrb(size: OrbSize.giant),
        const SizedBox(height: 28),
        Semantics(
          liveRegion: true,
          child: Text(
            context.l10n.looking,
            textAlign: TextAlign.center,
            style: AppTextStyles.headline,
          ),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.memory(
            photo.bytes,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ],
    );
  }
}

/// One message and the next steps.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.error,
    required this.onRetry,
    required this.onAskExpert,
    required this.onNewPhoto,
  });

  final DiagnosisError error;
  final VoidCallback onRetry;
  final VoidCallback onAskExpert;
  final VoidCallback onNewPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = error.failure;
    final icon = switch (failure) {
      DiagnosisFailure.noInternet => AppIcon.wifi,
      DiagnosisFailure.limitDay => AppIcon.clock,
      DiagnosisFailure.badImage => AppIcon.image,
      _ => AppIcon.warning,
    };
    // Try again: when it may work in a moment.
    final retry =
        failure == DiagnosisFailure.noInternet ||
        failure == DiagnosisFailure.unknown;
    // An expert can look at the photo when the diagnosis can't.
    final expert =
        failure == DiagnosisFailure.limitDay ||
        failure == DiagnosisFailure.busy ||
        failure == DiagnosisFailure.unavailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: IconBlob(
            icon: icon,
            size: 96,
            iconSize: 52,
            color: AppColors.peach,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            diagnosisFailureMessage(l10n, failure, perDay: error.perDay),
            textAlign: TextAlign.center,
            style: AppTextStyles.of(22, FontWeight.w800),
          ),
        ),
        const SizedBox(height: 26),
        if (retry) ActionButton(label: l10n.tryAgain, onPressed: onRetry),
        if (expert)
          ActionButton(label: l10n.askAnExpert, onPressed: onAskExpert),
        if (failure == DiagnosisFailure.badImage)
          ActionButton(label: l10n.takeAnotherPhoto, onPressed: onNewPhoto),
        const SizedBox(height: 6),
        TextLink(
          label: l10n.back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
