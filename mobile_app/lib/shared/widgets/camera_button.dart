// Big round camera button: opens the camera screen
// (to take a photo of a tree, a leaf or a fruit = photo diagnosis).
// Not in the plan: a small lock on the button, and it opens the locked screen.
import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../core/strings/app_strings.dart';
import '../../features/camera/camera_screen.dart';
import 'locked_feature.dart';

class CameraButton extends StatelessWidget {
  const CameraButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Plan>(
      valueListenable: currentPlan,
      builder: (context, plan, _) {
        final locked = !canUse(Feature.photoDiagnosis);
        return FloatingActionButton.large(
          // heroTag must be unique when there are several buttons on a page.
          heroTag: 'camera',
          tooltip: AppStrings.camera,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => locked
                    ? const LockedFeatureScreen(feature: Feature.photoDiagnosis)
                    : const CameraScreen(),
              ),
            );
          },
          child: Badge(
            isLabelVisible: locked,
            label: const Icon(Icons.lock, size: 14, color: Colors.white),
            child: const Icon(Icons.photo_camera, size: 48),
          ),
        );
      },
    );
  }
}
