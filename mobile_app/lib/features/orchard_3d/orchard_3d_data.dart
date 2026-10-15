// FAKE data for the 3D orchard: where each tree stands and its health.
// It reuses the Home data, so both screens always agree:
//  - same number of trees (fakeTreeCount),
//  - same health for the trees listed on Home (fakeTrees: Arbre 3, 7, 12, 18).
import 'dart:convert';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_data.dart';

/// Number of trees in one row of the orchard.
const int treesPerRow = 12;

/// Distance between 2 trees in a row, and between 2 rows (meters).
/// Same default values as the old 3D web app.
const double treeSpacing = 6;
const double rowSpacing = 7;

/// A few more trees with problems (not shown on the Home list).
/// Key = tree number, value = health.
const Map<int, StatusLevel> extraProblemTrees = {
  31: StatusLevel.warning,
  44: StatusLevel.warning,
  45: StatusLevel.warning,
  97: StatusLevel.warning,
  98: StatusLevel.danger,
};

/// One tree in 3D: its name, its position (x, z in meters) and its health.
class Tree3d {
  const Tree3d({
    required this.name,
    required this.x,
    required this.z,
    required this.health,
  });

  final String name;
  final double x;
  final double z;
  final StatusLevel health;
}

/// Builds the list of trees: a simple grid, numbered row by row
/// ("Arbre 1", "Arbre 2", ...).
List<Tree3d> buildOrchardTrees() {
  // Health of the trees shown on the Home screen, by name.
  final homeHealth = {for (final tree in fakeTrees) tree.name: tree.health};

  final rows = (fakeTreeCount / treesPerRow).ceil();
  final trees = <Tree3d>[];
  for (var i = 0; i < fakeTreeCount; i++) {
    final number = i + 1;
    final name = 'Arbre $number';
    final row = i ~/ treesPerRow;
    final col = i % treesPerRow;
    trees.add(Tree3d(
      name: name,
      // Center the orchard around (0, 0).
      x: (col - (treesPerRow - 1) / 2) * treeSpacing,
      z: (row - (rows - 1) / 2) * rowSpacing,
      health: homeHealth[name] ?? extraProblemTrees[number] ?? StatusLevel.good,
    ));
  }
  return trees;
}

/// Converts a color to "#rrggbb" text, the format the 3D page understands.
String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Everything the 3D page needs, as JSON text.
String orchardJson() {
  return jsonEncode({
    // Same green / orange / red as the rest of the app.
    'colors': {
      'good': _hex(AppColors.good.toARGB32()),
      'warning': _hex(AppColors.warning.toARGB32()),
      'danger': _hex(AppColors.danger.toARGB32()),
    },
    'trees': [
      for (final t in buildOrchardTrees())
        {'name': t.name, 'x': t.x, 'z': t.z, 'health': t.health.name},
    ],
  });
}
