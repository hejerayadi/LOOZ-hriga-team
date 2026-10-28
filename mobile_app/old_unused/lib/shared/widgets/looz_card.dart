// The cards of the design:
//  - LoozCard: white, very round corners, soft green shadow.
//  - StatusCard: a LoozCard with a colored bar on the left (green / orange / red).
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';

class LoozCard extends StatelessWidget {
  const LoozCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.white,
    this.radius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final Widget child;

  /// null = the card cannot be tapped.
  final VoidCallback? onTap;
  final Color color;
  final double radius;

  /// Space inside the card.
  final EdgeInsetsGeometry padding;

  /// Space around the card.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: color,
          borderRadius: corners,
          clipBehavior: Clip.antiAlias, // the content follows the round corners
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A card with a colored bar on its left side, showing the urgency or health.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.level,
    required this.child,
    this.onTap,
  });

  final StatusLevel level;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LoozCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 7, color: AppColors.forLevel(level)),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 18, 14),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
