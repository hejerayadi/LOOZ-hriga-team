// Tab 1 — "Mon verger": summary, weather, and the list of trees.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/looz_page.dart';
import '../../shared/widgets/status_dot.dart';
import '../orchard_3d/orchard_3d_page.dart';
import 'home_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoozPage(
      title: AppStrings.tabHome,
      children: [
        _SummaryCard(treeCount: orchardTreeCount(), health: orchardHealth()),
        const _Orchard3dCard(),
        const _WeatherCard(weather: fakeWeather),
        const SizedBox(height: 12),
        Text(AppStrings.myTrees, style: Theme.of(context).textTheme.titleLarge),
        // One card per tree with a photo (the "..." spreads the list here).
        ...treesWithPhotos().map((tree) => _TreeTile(tree: tree)),
      ],
    );
  }
}

/// Big card: number of trees + overall health (weakest zone).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.treeCount, required this.health});

  final int treeCount;
  final StatusLevel health;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Left half: number of trees
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.park, size: 48, color: AppColors.olive),
                  Text('$treeCount', style: textTheme.headlineMedium),
                  Text(AppStrings.trees, style: textTheme.bodyLarge),
                ],
              ),
            ),
            // Right half: overall health
            Expanded(
              child: Column(
                children: [
                  StatusDot(level: health, size: 48),
                  const SizedBox(height: 8),
                  Text(AppStrings.level(health), style: textTheme.titleMedium),
                  Text(AppStrings.health, style: textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big olive card that opens the 3D orchard.
class _Orchard3dCard extends StatelessWidget {
  const _Orchard3dCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.olive,
      clipBehavior: Clip.antiAlias, // so the tap ripple follows the round corners
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const Orchard3dPage()),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.view_in_ar, size: 56, color: Colors.white),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppStrings.orchard3d,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 40, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weather card: icon, temperature, humidity.
class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              weather.sunny ? Icons.wb_sunny : Icons.cloud,
              size: 56,
              color: AppColors.warning,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.weather, style: textTheme.bodyLarge),
                  Text(
                    '${weather.temperature}°C',
                    style: textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Icons.water_drop, size: 36, color: Colors.blue),
                Text('${weather.humidity}%', style: textTheme.titleMedium),
                Text(AppStrings.humidity),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One line in the tree list: latest photo result + name + zone + what the AI saw.
class _TreeTile extends StatelessWidget {
  const _TreeTile({required this.tree});

  final TreeWithPhoto tree;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: StatusDot(level: tree.photo.status, size: 32),
        title: Text(tree.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${tree.zoneName} · ${tree.photo.aiResult}'),
        trailing: const Icon(Icons.photo_camera, size: 28, color: AppColors.olive),
      ),
    );
  }
}
