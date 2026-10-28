// Tab 1 — Home ("الرئيسية"): good morning, the weather, today's alert,
// and 3 big tiles (ask, journal, map).
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/fake_data.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/orchard_scene.dart';
import '../../shared/widgets/screen_title.dart';
import '../../shared/widgets/shell.dart';
import '../../shared/widgets/speaker_button.dart';
import '../../core/plans.dart';
import '../alerts/alert_screen.dart';
import '../ask/ask_screen.dart';
import '../journal/journal_screen.dart';
import '../map/map_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShellContent(
      children: [
        const LoozHeader(),
        ScreenTitle(
          title: l10n.homeTitle,
          subtitle: l10n.homeSubtitle(l10n.demoFirstName),
        ),
        const _WeatherCard(),
        const SizedBox(height: 16),
        AlertCard(
          level: fakeHomeAlertLevel,
          title: l10n.drySoil,
          text: l10n.waterToday,
          icon: AppIcon.arrow,
          onTap: () => openScreen(context, const AlertScreen()),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Tile(
                color: AppColors.softGreen,
                icon: AppIcon.mic,
                label: l10n.quickAsk,
                onTap: () => openScreen(context, const AskScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                color: AppColors.yellow,
                icon: AppIcon.book,
                label: l10n.quickJournal,
                onTap: () => openScreen(context, const JournalScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                color: AppColors.mint,
                icon: AppIcon.map,
                label: l10n.quickMap,
                // The map is a Premium feature.
                onTap: () =>
                    openFeature(context, Feature.orchard3d, const MapScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The orchard drawing, with today's temperature and advice on frosted glass.
class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    return CssBox(
      color: AppColors.white78,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      shadows: AppShadows.card,
      clip: true,
      child: Stack(
        children: [
          const OrchardScene(height: 210, radius: 0),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 82),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: AppColors.white84,
                  child: Row(
                    children: [
                      const LoozIcon(AppIcon.sun, size: 44),
                      const SizedBox(width: 12),
                      Text(
                        '$fakeTemperature°',
                        style: AppTextStyles.temperature,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.goodDayToWater,
                          style: AppTextStyles.weatherText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SpeakerButton(iconSize: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the 3 big colored tiles.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final AppIcon icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const blob = Size.square(62);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          height: 126,
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CssBox(
                width: blob.width,
                height: blob.height,
                color: AppColors.white60,
                borderRadius: blobRadius(blob, BlobShapes.tile),
                alignment: Alignment.center,
                child: LoozIcon(icon, size: 38),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: AppTextStyles.tileLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
