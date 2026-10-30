// A photo of the community on the whole screen (not in the design: the
// app's own screen): pinch to zoom, × to close (the close button of the
// design's camera screen, at the same place in both languages).
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.image, required this.label});

  final ImageProvider image;

  /// What the photo is (for the screen reader).
  final String label;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF04160F), // the camera screen's veil
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                semanticLabel: label,
              ),
            ),
          ),
          Positioned(
            top: system.top + 28,
            left: 20,
            child: Semantics(
              button: true,
              label: context.l10n.a11yClose,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
        ],
      ),
    );
  }
}
