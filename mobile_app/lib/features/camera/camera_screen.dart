// "صوّر الورقة" (photo diagnosis, Bêta, paid pack): the design's camera
// screen. The round button opens the phone's camera (on web: the photos);
// "اختر من الصور" chooses a photo. The photo is made small and its hidden
// data (GPS) removed (community_photos.dart), then "جاري النظر…" sends it.
// Above the button: how to take the photo, and how many photos are left
// today (or why the diagnosis can't be used now).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_photos.dart';
import '../../data/community_service.dart';
import '../../data/diagnosis_service.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../community/community_texts.dart';
import 'diagnosis_widgets.dart';
import 'thinking_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  /// null = not known yet (or no internet).
  DiagnosisQuota? _quota;
  bool _quotaFailed = false;

  /// The photo is being made smaller.
  bool _preparing = false;

  /// The camera or the gallery refused (or the photo can't be read).
  CommunityFailure? _pickFailure;

  @override
  void initState() {
    super.initState();
    _loadQuota();
    _recoverLostPhoto();
  }

  Future<void> _loadQuota() async {
    try {
      final quota = await Future.sync(diagnosisService.loadQuota);
      if (mounted) setState(() => _quota = quota);
    } catch (_) {
      // No internet (or no answer): the photo can still be tried.
      if (mounted) setState(() => _quotaFailed = true);
    }
  }

  /// Android may close the app while the camera is open: the photo taken
  /// then comes back here.
  Future<void> _recoverLostPhoto() async {
    try {
      final bytes = await Future.sync(photoPicker.lostPhoto);
      if (bytes != null && mounted) await _use(bytes);
    } catch (_) {
      // Nothing to get back.
    }
  }

  bool get _blocked {
    final quota = _quota;
    return quota != null && (!quota.enabled || quota.left == 0);
  }

  Future<void> _pick(PhotoSource source) async {
    if (_preparing || _blocked) return;
    setState(() => _pickFailure = null);
    final Uint8List? bytes;
    try {
      bytes = await photoPicker.pick(source);
    } catch (error) {
      if (mounted) setState(() => _pickFailure = communityFailureOf(error));
      return;
    }
    // null = closed without a photo: nothing changes.
    if (bytes != null && mounted) await _use(bytes);
  }

  Future<void> _use(Uint8List bytes) async {
    setState(() => _preparing = true);
    try {
      final photo = await photoPicker.prepare(bytes);
      if (mounted) replaceWith(context, ThinkingScreen(photo: photo));
    } catch (error) {
      if (mounted) {
        setState(() {
          _pickFailure = communityFailureOf(error);
          _preparing = false;
        });
      }
    }
  }

  /// What to say above the button (null = nothing).
  String? _message(AppLocalizations l10n) {
    final pickFailure = _pickFailure;
    if (pickFailure != null) return communityFailureMessage(l10n, pickFailure);
    final quota = _quota;
    if (quota != null && !quota.enabled) return l10n.diagnosisUnavailable;
    if (quota != null && quota.left == 0) {
      return l10n.limitReached(quota.perDay);
    }
    if (_quotaFailed) return l10n.needInternet;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final message = _message(l10n);
    final quota = _quota;
    // The frame of the design (270 x 390), smaller on short phones.
    // Under the tips (they may take 2 lines), above the button and its texts.
    final frame = Size(270, (size.height - 520).clamp(160.0, 360.0));
    final frameLeft = (size.width - frame.width - 14).clamp(0.0, 85.0);
    final camera = photoPicker.hasCamera;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/almond_blossoms.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const ColoredBox(color: Color(0x4204160F)), // dark veil
            // Like in the design, these stay at the same place in both
            // languages (the close button on the left).
            Positioned(
              top: system.top + 28,
              left: 20,
              child: Semantics(
                button: true,
                label: l10n.a11yClose,
                child: GestureDetector(
                  onTap: () => goToTab(context, AppTab.home),
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xD9FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Text('×', style: AppTextStyles.of(34)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: system.top + 42,
              left: 80,
              right: 80,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      l10n.photographLeaf,
                      textAlign: TextAlign.center,
                      softWrap: false,
                      style: AppTextStyles.of(
                        20,
                        FontWeight.w800,
                      ).copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 6),
                    const BetaTag(),
                  ],
                ),
              ),
            ),
            // How to take the photo.
            Positioned(
              top: system.top + 124,
              left: 12,
              right: 12,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PhotoTip(icon: AppIcon.leaf, text: l10n.photoTipOneLeaf),
                  PhotoTip(icon: AppIcon.ruler, text: l10n.photoTipClose),
                  PhotoTip(icon: AppIcon.sun, text: l10n.photoTipLight),
                ],
              ),
            ),
            Positioned(
              top: system.top + 220,
              left: frameLeft,
              width: frame.width,
              height: frame.height,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.leaf, width: 5),
                  borderRadius: blobRadius(frame, [0.48, 0.52, 0.45, 0.55]),
                ),
                child: const LoozIcon(
                  AppIcon.leaf,
                  size: 100,
                  color: Color(0xB3FFFFFF),
                ),
              ),
            ),
            // The message (if any), the photos left, the privacy note.
            Positioned(
              left: 20,
              right: 20,
              bottom: system.bottom + 80 + 92 + 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null) ...[
                    CameraNote(text: message),
                    const SizedBox(height: 10),
                  ] else if (quota != null) ...[
                    Text(
                      l10n.photosLeftToday(quota.left),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.of(
                        16,
                        FontWeight.w800,
                      ).copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    l10n.photoPrivacyNote,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(
                      13,
                      FontWeight.w600,
                    ).copyWith(color: AppColors.white84),
                  ),
                ],
              ),
            ),
            // The design's round button: the camera (web: the photos).
            Positioned(
              bottom: system.bottom + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  enabled: !_blocked,
                  label: camera ? l10n.takePhoto : l10n.choosePhoto,
                  child: GestureDetector(
                    onTap: () => _pick(
                      camera ? PhotoSource.camera : PhotoSource.gallery,
                    ),
                    child: Opacity(
                      opacity: _blocked ? 0.45 : 1,
                      child: Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // On a phone: the photos too.
            if (camera)
              Positioned(
                bottom: system.bottom + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GalleryPill(
                    label: l10n.choosePhoto,
                    onTap: _blocked ? null : () => _pick(PhotoSource.gallery),
                  ),
                ),
              ),
            if (_preparing)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xB304160F),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.leaf),
                        const SizedBox(height: 16),
                        Text(
                          l10n.preparingPhoto,
                          style: AppTextStyles.of(
                            18,
                            FontWeight.w800,
                          ).copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
