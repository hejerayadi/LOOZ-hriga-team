// The round camera button of the assistant bar (the design's "camera-btn").
// Without the right plan (photo diagnosis), it shows the "locked" screen.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/theme/app_theme.dart';
import '../../features/camera/camera_screen.dart';
import 'app_icon.dart';

class CameraButton extends StatelessWidget {
  const CameraButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.a11yCamera,
      child: GestureDetector(
        onTap: () =>
            openFeature(context, Feature.photoDiagnosis, const CameraScreen()),
        child: Container(
          width: AppSizes.roundButton,
          height: AppSizes.roundButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.leaf,
            shape: BoxShape.circle,
            boxShadow: AppShadows.camera,
          ),
          child: const LoozIcon(AppIcon.camera, size: 30),
        ),
      ),
    );
  }
}
