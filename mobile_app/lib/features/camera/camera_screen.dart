// "صوّر الورقة": the camera, with an oval frame for the leaf.
//
// DEMO: the real camera is not used yet. The almond photo stands for the
// camera image; the round button "takes" the photo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import 'thinking_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    const frame = Size(270, 390);
    // Like in the design (85 px from the left), but always on the screen.
    final frameLeft = (width - frame.width - 14).clamp(0.0, 85.0);
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
            // The title lets taps through (the close button is under it).
            Positioned(
              top: system.top + 42,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  l10n.photographLeaf,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: AppTextStyles.of(
                    20,
                    FontWeight.w800,
                  ).copyWith(color: AppColors.white),
                ),
              ),
            ),
            Positioned(
              top: system.top + 190,
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
            Positioned(
              bottom: system.bottom + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: l10n.a11yCamera,
                  child: GestureDetector(
                    onTap: () => replaceWith(context, const ThinkingScreen()),
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
                          border: Border.all(color: AppColors.white, width: 4),
                        ),
                      ),
                    ),
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
