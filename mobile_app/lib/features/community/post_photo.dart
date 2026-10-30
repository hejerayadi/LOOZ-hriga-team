// The photo of a post, at the top of its card (the design's feed card: 220
// high, round corners): the demo picture of the app, or the farmer's photo
// downloaded from the "community" bucket. Tapping it shows it on the whole
// screen (PhotoViewer).
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/community_models.dart';
import '../../data/community_service.dart';
import '../../shared/widgets/app_icon.dart';
import 'photo_viewer.dart';

class PostPhoto extends StatefulWidget {
  const PostPhoto({super.key, required this.post, this.height = 220});

  /// A post with a photo (photoAsset or photoPath).
  final Post post;
  final double height;

  @override
  State<PostPhoto> createState() => _PostPhotoState();
}

class _PostPhotoState extends State<PostPhoto> {
  /// The download of the farmer's photo (null = the demo picture).
  Future<Uint8List>? _download;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PostPhoto old) {
    super.didUpdateWidget(old);
    if (old.post.photo != widget.post.photo) _load();
  }

  void _load() {
    final path = widget.post.photoPath;
    _download = path == null ? null : communityService.loadPhoto(path);
  }

  void _open(ImageProvider image, String label) =>
      openScreen(context, PhotoViewer(image: image, label: label));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asset = widget.post.photoAsset;
    if (asset != null) {
      final label = widget.post.photo == 'demo:almond_blossoms'
          ? l10n.almondBlossoms
          : l10n.a11yPostPhoto;
      return _photo(AssetImage(asset), label);
    }
    return FutureBuilder<Uint8List>(
      future: _download,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return _photo(MemoryImage(bytes), l10n.a11yPostPhoto);
        }
        if (snapshot.hasError) {
          // Can't be downloaded now: tap to try again.
          return _box(
            label: l10n.photoUnavailable,
            onTap: () => setState(_load),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LoozIcon(AppIcon.image, size: 34),
                const SizedBox(height: 8),
                Text(
                  l10n.photoUnavailable,
                  style: AppTextStyles.of(16, FontWeight.w700),
                ),
              ],
            ),
          );
        }
        return _box(label: l10n.loading); // pale, like the loading card
      },
    );
  }

  Widget _photo(ImageProvider image, String label) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () => _open(image, label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image(
          image: image,
          height: widget.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    ),
  );

  Widget _box({required String label, VoidCallback? onTap, Widget? child}) =>
      Semantics(
        button: onTap != null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.mintWhite,
              borderRadius: BorderRadius.circular(25),
            ),
            child: child,
          ),
        ),
      );
}
