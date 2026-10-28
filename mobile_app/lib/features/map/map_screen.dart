// "خريطة البستان": the trees of the orchard as faces on a green map.
// Tap a tree to open its alert. The card below shows tree A-18.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/mood_face.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../alerts/alert_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  // Where the 9 trees are (like the design: a part of the map's size).
  // (left or right, top or bottom); not mirrored in Arabic.
  static const _places = [
    (left: 0.12, right: null, top: 0.08, bottom: null),
    (left: null, right: 0.15, top: 0.12, bottom: null),
    (left: 0.38, right: null, top: 0.35, bottom: null),
    (left: 0.12, right: null, top: 0.54, bottom: null),
    (left: null, right: 0.18, top: 0.62, bottom: null),
    (left: 0.38, right: null, top: null, bottom: 0.05),
    (left: null, right: 0.04, top: 0.30, bottom: null),
    (left: 0.65, right: null, top: 0.48, bottom: null),
    (left: 0.05, right: null, top: 0.72, bottom: null),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellPage(
      children: [
        ScreenTitle(
          title: l10n.orchardMap,
          subtitle: l10n.treeCount('$fakeTreeCount'),
        ),
        CssBox(
          height: 430,
          borderRadius: BorderRadius.circular(34),
          gradient: const CssLinearGradient(
            angle: 25,
            colors: [Color(0xFFA7CF82), Color(0xFF769A62)],
          ),
          shadows: AppShadows.card,
          clip: true,
          child: LayoutBuilder(
            builder: (context, size) {
              final w = size.maxWidth;
              final h = size.maxHeight;
              return Stack(
                children: [
                  // White stripes (a box 20% bigger than the map on each side).
                  Positioned(
                    left: -0.2 * w,
                    top: -0.2 * h,
                    width: 1.4 * w,
                    height: 1.4 * h,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: CssRepeatingLinearGradient(
                          angle: 35,
                          period: 45,
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x00FFFFFF),
                            Color(0x38FFFFFF),
                            Color(0x38FFFFFF),
                          ],
                          stops: [0, 40, 42, 45],
                        ),
                      ),
                    ),
                  ),
                  for (final (i, place) in _places.indexed)
                    Positioned(
                      left: place.left == null ? null : place.left! * w,
                      right: place.right == null ? null : place.right! * w,
                      top: place.top == null ? null : place.top! * h,
                      bottom: place.bottom == null ? null : place.bottom! * h,
                      child: Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => openScreen(context, const AlertScreen()),
                          child: MoodFace(
                            level: fakeMapTrees[i],
                            small: true,
                            ring: true,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // The card of tree A-18, over the bottom of the map.
        Transform.translate(
          offset: const Offset(0, -24),
          child: CssBox(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            shadows: AppShadows.card,
            padding: const EdgeInsets.all(16),
            // Like in the design, the free space is shared: before the face
            // and before the readings.
            child: Row(
              children: [
                const Spacer(),
                const MoodFace(level: StatusLevel.warning, small: true),
                const SizedBox(width: 12),
                Text(
                  l10n.treeName,
                  style: AppTextStyles.of(18, FontWeight.w700),
                ),
                const SizedBox(width: 12),
                const Spacer(),
                _Reading(icon: AppIcon.drop, text: '$fakeTreeMoisture%'),
                const SizedBox(width: 6),
                _Reading(icon: AppIcon.sun, text: '$fakeTreeTemperature°'),
                const SizedBox(width: 6),
                _Reading(icon: AppIcon.leaf, text: l10n.look),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small icon with its value under it.
class _Reading extends StatelessWidget {
  const _Reading({required this.icon, required this.text});

  final AppIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoozIcon(icon),
        Text(text, style: AppTextStyles.of(12)),
      ],
    );
  }
}
