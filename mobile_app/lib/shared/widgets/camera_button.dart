// Big round camera button: opens the camera screen
// (to take a photo of a tree, a leaf or a fruit).
import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../features/camera/camera_screen.dart';

class CameraButton extends StatelessWidget {
  const CameraButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      // heroTag must be unique when there are several buttons on a page.
      heroTag: 'camera',
      tooltip: AppStrings.camera,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        );
      },
      child: const Icon(Icons.photo_camera, size: 48),
    );
  }
}
