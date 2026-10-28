// The page background of the design: cream to light mint, with a soft
// green glow at the top left and a mint glow at the right.
// It does not move when the page scrolls (like in the design).
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LoozBackground extends StatelessWidget {
  const LoozBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // From the bottom layer to the top one.
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.page),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.pageGlowRight),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.pageGlowLeft),
          child: child,
        ),
      ),
    );
  }
}
