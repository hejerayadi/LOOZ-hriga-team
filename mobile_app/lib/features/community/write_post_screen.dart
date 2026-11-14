// "انشر في المجتمع": write a post for the community, with a photo if you
// want (not in the design: the app's own screen, in its style). Opened by
// "＋ انشر" of the community, by "كتابة" on the Ask screen, and by "اسأل
// خبيرًا" of the photo diagnosis (with its photo and a question ready, that
// the farmer can change). After publishing, the community tab opens with
// the new post on top.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/validators.dart';
import '../../data/community_models.dart';
import '../../data/community_photos.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/soon_message.dart';
import 'community_widgets.dart';

class WritePostScreen extends StatefulWidget {
  const WritePostScreen({
    super.key,
    this.initialText,
    this.initialPhoto,
    this.onPublished,
  });

  /// A question already written (the farmer can change it).
  final String? initialText;

  /// A photo already chosen (e.g. the photo of the diagnosis).
  final PreparedPhoto? initialPhoto;

  /// Called with the new post, before the community opens (e.g. to link
  /// it to the diagnosis). Its errors are ignored: the post is published.
  final Future<void> Function(Post post)? onPublished;

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

/// What the "انشر" button is doing.
enum _Step { ready, uploadingPhoto, publishing }

class _WritePostScreenState extends State<WritePostScreen> {
  final _text = TextEditingController();
  TextProblem? _problem;
  CommunityFailure? _failure;

  /// The photo ready to upload (null = none).
  PreparedPhoto? _photo;

  /// The photo is being made smaller.
  bool _preparing = false;

  _Step _step = _Step.ready;

  bool get _busy => _preparing || _step != _Step.ready;

  @override
  void initState() {
    super.initState();
    _text.text = widget.initialText ?? '';
    _photo = widget.initialPhoto;
    if (_photo == null) _recoverLostPhoto();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Android may close the app while the camera is open (phones with little
  /// memory): the photo taken then comes back here.
  Future<void> _recoverLostPhoto() async {
    try {
      // (Future.sync: even an error at once arrives after initState.)
      final bytes = await Future.sync(() => photoPicker.lostPhoto());
      if (bytes != null && mounted) await _usePhoto(bytes);
    } catch (_) {
      // Nothing to get back.
    }
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() => _failure = null);
    final Uint8List? bytes;
    try {
      bytes = await photoPicker.pick(source);
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
      return;
    }
    // null = closed without a photo: nothing changes.
    if (bytes != null && mounted) await _usePhoto(bytes);
  }

  Future<void> _usePhoto(Uint8List bytes) async {
    setState(() {
      _preparing = true;
      _failure = null;
    });
    try {
      final photo = await photoPicker.prepare(bytes);
      if (mounted) setState(() => _photo = photo);
    } catch (error) {
      if (mounted) setState(() => _failure = communityFailureOf(error));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _changePhoto() async {
    if (!photoPicker.hasCamera) return _pick(PhotoSource.gallery);
    final source = await choosePhotoSource(context);
    if (source != null) await _pick(source);
  }

  void _removePhoto() => setState(() {
    _photo = null;
    _failure = null;
  });

  Future<void> _publish() async {
    final problem = checkText(_text.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final photo = _photo;
    setState(() {
      _step = photo == null ? _Step.publishing : _Step.uploadingPhoto;
      _failure = null;
    });
    try {
      final post = await communityService.writePost(
        _text.text,
        photo: photo,
        onPhotoUploaded: () {
          if (mounted) setState(() => _step = _Step.publishing);
        },
      );
      final onPublished = widget.onPublished;
      if (onPublished != null) {
        try {
          await onPublished(post);
        } catch (_) {
          // The question is published: that is what matters.
        }
      }
      communityChanges.value++;
      if (!mounted) return;
      if (onPublished != null) {
        showMessage(context, context.l10n.questionPublished);
      }
      goToTab(context, AppTab.community);
    } catch (error) {
      // The text and the photo stay: the farmer can try again.
      if (mounted) {
        setState(() {
          _failure = communityFailureOf(error);
          _step = _Step.ready;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = _failure;
    final photo = _photo;
    return ShellPage(
      children: [
        ScreenTitle(title: l10n.newPostTitle, subtitle: l10n.newPostSubtitle),
        CommunityTextBox(
          controller: _text,
          hint: l10n.writePostHint,
          problem: _problem,
          minLines: 5,
          maxLines: 12,
          onChanged: () {
            if (_problem != null) setState(() => _problem = null);
          },
        ),
        const SizedBox(height: 14),
        if (_preparing)
          const PhotoPreparing()
        else if (photo != null)
          PhotoPreview(
            photo: photo,
            onChange: _busy ? null : _changePhoto,
            onRemove: _busy ? null : _removePhoto,
          )
        else ...[
          // On web: the gallery only.
          if (photoPicker.hasCamera) ...[
            PhotoChoice(
              icon: AppIcon.camera,
              label: l10n.takePhoto,
              onTap: _busy ? null : () => _pick(PhotoSource.camera),
            ),
            const SizedBox(height: 14),
          ],
          PhotoChoice(
            icon: AppIcon.image,
            label: l10n.choosePhoto,
            onTap: _busy ? null : () => _pick(PhotoSource.gallery),
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: 12),
          CommunityNote(failure),
        ],
        const SizedBox(height: 14),
        ActionButton(
          label: switch (_step) {
            _Step.ready => l10n.publish,
            _Step.uploadingPhoto => l10n.uploadingPhoto,
            _Step.publishing => l10n.publishing,
          },
          onPressed: _busy ? null : _publish,
        ),
      ],
    );
  }
}
