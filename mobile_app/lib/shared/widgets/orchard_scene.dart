// The small drawing of an orchard from the design (its "hero"): a sky,
// a sun, 2 hills and 3 blossoming trees. Used at the top of big cards.
// Like in the design it is not mirrored in Arabic: the sun stays on the right.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'symbol_text.dart';

class OrchardScene extends StatelessWidget {
  const OrchardScene({
    super.key,
    this.height = 175,
    this.radius = AppRadius.lg,
  });

  final double height;

  /// Round corners (0 when the drawing fills the top of a card).
  final double radius;

  static final _tree = AppTextStyles.of(37).copyWith(
    color: AppColors.miniTree,
    shadows: const [
      Shadow(color: AppColors.miniTreeShadow, offset: Offset(0, 5)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.heroSky),
          // The hills and the trees are placed as a part of the width.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 24,
                    right: 45,
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.sun,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.sunGlow,
                      ),
                      child: const LoozIcon(
                        AppIcon.sun,
                        size: 34,
                        color: AppColors.sunIcon,
                      ),
                    ),
                  ),
                  _Hill(
                    color: AppColors.hillBack,
                    left: -0.15 * width,
                    bottom: -20,
                    width: 1.3 * width,
                    degrees: -4,
                  ),
                  _Hill(
                    color: AppColors.hillFront,
                    left: -0.28 * width,
                    bottom: -62,
                    width: 1.3 * width,
                    degrees: 7,
                  ),
                  Positioned(
                    left: 0.18 * width,
                    bottom: 25,
                    child: SymbolText('✿', style: _tree),
                  ),
                  Positioned(
                    left: 0.47 * width,
                    bottom: 12,
                    child: SymbolText('✿', style: _tree),
                  ),
                  Positioned(
                    right: 0.13 * width,
                    bottom: 30,
                    child: SymbolText('✿', style: _tree),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A big, slightly turned oval: only its top shows, like a hill.
class _Hill extends StatelessWidget {
  const _Hill({
    required this.color,
    required this.left,
    required this.bottom,
    required this.width,
    required this.degrees,
  });

  final Color color;
  final double left;
  final double bottom;
  final double width;
  final double degrees;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      bottom: bottom,
      width: width,
      height: 110,
      child: Transform.rotate(
        angle: degrees * math.pi / 180,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: color, shape: const OvalBorder()),
        ),
      ),
    );
  }
}
