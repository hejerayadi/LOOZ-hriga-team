// "من صورة": before the outline step, the photo of a sketch of the orchard
// drawn on paper (like the camera screen of the photo diagnosis): how to
// take it, the round button (the camera; on web: the photos), "اختر من
// الصور" on a phone. Then "نبحث عن حدود البستان…" (on the phone itself, see
// sketch_detect.dart) and:
//   - found → the outline step with the photo behind the grid;
//   - not found → a short message, then: the corners tapped on the photo,
//     another photo, or drawing by hand.
// The photo is never sent and never saved.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_photos.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../camera/diagnosis_widgets.dart';
import '../community/community_texts.dart';
import 'design_session.dart';
import 'outline_screen.dart';
import 'sketch_reader.dart';

class SketchScreen extends StatefulWidget {
  const SketchScreen({super.key, required this.session});

  final DesignSession session;

  @override
  State<SketchScreen> createState() => _SketchScreenState();
}

class _SketchScreenState extends State<SketchScreen> {
  /// The photo is being read ("نبحث…").
  bool _looking = false;

  /// The camera or the gallery refused (or the photo can't be read).
  CommunityFailure? _failure;

  /// Read, but no outline found: the message and its 3 choices.
  SketchPhoto? _notFound;

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
  }

  @override
  void dispose() {
    _notFound?.image?.dispose();
    super.dispose();
  }

  /// Android may close the app while the camera is open: the photo taken
  /// then comes back here.
  Future<void> _recoverLostPhoto() async {
    try {
      final bytes = await Future.sync(photoPicker.lostPhoto);
      if (bytes != null && mounted) await _read(bytes);
    } catch (_) {
      // Nothing to get back.
    }
  }

  Future<void> _pick(PhotoSource source) async {
    if (_looking) return;
    setState(() => _failure = null);
    final Uint8List? bytes;
    try {
      bytes = await photoPicker.pick(source);
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
      return;
    }
    // null = closed without a photo: nothing changes.
    if (bytes != null && mounted) await _read(bytes);
  }

  Future<void> _read(Uint8List bytes) async {
    setState(() => _looking = true);
    try {
      final photo = await sketchReader.read(bytes, side: designerStartSide());
      if (!mounted) {
        photo.image?.dispose();
        return;
      }
      if (photo.found) {
        _open(photo);
      } else {
        setState(() {
          _notFound = photo;
          _looking = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = communityFailureOf(error);
          _looking = false;
        });
      }
    }
  }

  /// The outline step, with the photo (or without: drawing by hand).
  void _open(SketchPhoto? photo) {
    if (photo == null) _notFound?.image?.dispose();
    _notFound = null; // the outline step owns the photo now
    replaceWith(context, OutlineScreen(session: widget.session, sketch: photo));
  }

  void _otherPhoto() {
    _notFound?.image?.dispose();
    setState(() => _notFound = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final failure = _failure;
    final notFound = _notFound;
    final camera = photoPicker.hasCamera;
    final white = AppTextStyles.of(
      20,
      FontWeight.w800,
    ).copyWith(color: AppColors.white);
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
            const ColoredBox(color: Color(0x5904160F)), // dark veil
            // One column: the title and the tips take the room they need
            // (French is longer), the frame gets what is left.
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                system.top + 24,
                12,
                system.bottom + 16,
              ),
              child: Column(
                children: [
                  // The close button on the left in both languages (like
                  // the camera of the photo diagnosis).
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l10n.a11yClose,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
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
                      Expanded(
                        child: Text(
                          l10n.sketchTitle,
                          textAlign: TextAlign.center,
                          style: white,
                        ),
                      ),
                      const SizedBox(width: 62),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // How to draw and take the photo.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PhotoTip(icon: AppIcon.pen, text: l10n.sketchTipPen),
                      PhotoTip(icon: AppIcon.book, text: l10n.sketchTipPaper),
                      PhotoTip(icon: AppIcon.camera, text: l10n.sketchTipAbove),
                      PhotoTip(icon: AppIcon.check, text: l10n.sketchTipWhole),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, room) {
                        if (room.maxHeight < 90) return const SizedBox.shrink();
                        final frame = Size(
                          (room.maxWidth - 28).clamp(0.0, 270.0),
                          room.maxHeight.clamp(0.0, 340.0),
                        );
                        return Center(
                          child: Container(
                            width: frame.width,
                            height: frame.height,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.leaf,
                                width: 5,
                              ),
                              borderRadius: blobRadius(frame, [
                                0.48,
                                0.52,
                                0.45,
                                0.55,
                              ]),
                            ),
                            child: LoozIcon(
                              AppIcon.map,
                              size: (frame.height * 0.4).clamp(40.0, 100.0),
                              color: const Color(0xB3FFFFFF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // A failure of the camera / the photo, and where the photo goes.
                  if (failure != null) ...[
                    CameraNote(text: communityFailureMessage(l10n, failure)),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    l10n.sketchPrivacy,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(
                      14,
                      FontWeight.w700,
                    ).copyWith(color: AppColors.white84),
                  ),
                  const SizedBox(height: 14),
                  // The round button: the camera (web: the photos).
                  Semantics(
                    button: true,
                    label: camera ? l10n.takePhoto : l10n.choosePhoto,
                    child: GestureDetector(
                      onTap: () => _pick(
                        camera ? PhotoSource.camera : PhotoSource.gallery,
                      ),
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
                  // On a phone: the photos too.
                  if (camera) ...[
                    const SizedBox(height: 12),
                    GalleryPill(
                      label: l10n.choosePhoto,
                      onTap: () => _pick(PhotoSource.gallery),
                    ),
                  ],
                ],
              ),
            ),
            if (_looking)
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
                          l10n.sketchLooking,
                          textAlign: TextAlign.center,
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
            if (notFound != null) ...[
              const Positioned.fill(
                child: ColoredBox(color: Color(0x8004160F)),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: system.bottom + 16,
                child: _NotFoundCard(
                  onCorners: () => _open(notFound),
                  onOtherPhoto: _otherPhoto,
                  onByHand: () => _open(null),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "لم نجد حدود البستان في الصورة." and the 3 choices.
class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({
    required this.onCorners,
    required this.onOtherPhoto,
    required this.onByHand,
  });

  final VoidCallback onCorners;
  final VoidCallback onOtherPhoto;
  final VoidCallback onByHand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: CssBox(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        shadows: AppShadows.card,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const LoozIcon(AppIcon.warning, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.sketchNotFound,
                    style: AppTextStyles.of(18, FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.sketchNotFoundHelp, style: AppTextStyles.of(16)),
            const SizedBox(height: 14),
            ActionButton(label: l10n.sketchTapCorners, onPressed: onCorners),
            const SizedBox(height: 10),
            ActionButton(
              label: l10n.sketchOtherPhoto,
              secondary: true,
              onPressed: onOtherPhoto,
            ),
            const SizedBox(height: 10),
            ActionButton(
              label: l10n.sketchDrawByHand,
              secondary: true,
              onPressed: onByHand,
            ),
          ],
        ),
      ),
    );
  }
}
