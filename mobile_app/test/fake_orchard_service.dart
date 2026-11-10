// A fake of the farmer's orchard for the tests (no internet): the same
// orchard as supabase/seed/orchard_demo.sql (2.37 ha, zones A-D, one node
// per zone, the trees in rows), or none, or a draft.
import 'dart:math' as math;

import 'package:looz_mobile/core/enums.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';

class FakeOrchardService implements OrchardService {
  FakeOrchardService([this.orchard]);

  /// The orchard of the user (null = none drawn).
  MyOrchard? orchard;

  /// The next call fails with this error (once).
  AuthFailure? failNext;

  /// How many times the orchard was read.
  int loads = 0;

  @override
  Future<MyOrchard?> loadMyOrchard() async {
    loads++;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw AuthError(failure);
    }
    return orchard;
  }
}

List<OrchardPoint> _points(List<List<double>> xz) => [
  for (final p in xz) OrchardPoint(p[0], p[1]),
];

/// The outline and zones of the demo seed (metres).
final demoOutline = _points([
  [-90, -60],
  [85, -70],
  [100, 40],
  [20, 75],
  [-95, 55],
]);

final demoZones = [
  OrchardZone(
    id: 'zone-a',
    letter: 'A',
    type: ZoneType.youngTrees,
    color: '#8BC34A',
    treeCount: 160,
    boundary: _points([
      [-90, -60],
      [-46.3, -62.5],
      [-46.3, 63.5],
      [-95, 55],
    ]),
  ),
  OrchardZone(
    id: 'zone-b',
    letter: 'B',
    type: ZoneType.oldTrees,
    color: '#4FC3F7',
    treeCount: 210,
    health: StatusLevel.warning,
    boundary: _points([
      [-46.3, -62.5],
      [9.0, -65.7],
      [9.0, 73.1],
      [-46.3, 63.5],
    ]),
  ),
  OrchardZone(
    id: 'zone-c',
    letter: 'C',
    name: 'الجنان القبلي',
    type: ZoneType.sandySoil,
    color: '#FFB74D',
    treeCount: 120,
    health: StatusLevel.danger,
    boundary: _points([
      [9.0, -65.7],
      [39.1, -67.4],
      [39.1, 66.6],
      [20, 75],
      [9.0, 73.1],
    ]),
  ),
  OrchardZone(
    id: 'zone-d',
    letter: 'D',
    color: '#BA68C8',
    treeCount: 190,
    boundary: _points([
      [39.1, -67.4],
      [85, -70],
      [100, 40],
      [39.1, 66.6],
    ]),
  ),
];

bool _inside(List<OrchardPoint> polygon, double x, double z) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.z > z) != (b.z > z) &&
        x < (b.x - a.x) * (z - a.z) / (b.z - a.z) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// The demo orchard: complete, its 4 zones and nodes (C offline, D not
/// installed yet), trees every [spacing] metres, tree 1 with a warning photo.
MyOrchard demoOrchard({double spacing = 6}) {
  final trees = <OrchardTree>[];
  var number = 0;
  for (final zone in demoZones) {
    final xs = zone.boundary.map((p) => p.x);
    final zs = zone.boundary.map((p) => p.z);
    for (
      var z = zs.reduce(math.min) + spacing / 2;
      z < zs.reduce(math.max);
      z += spacing
    ) {
      for (
        var x = xs.reduce(math.min) + spacing / 2;
        x < xs.reduce(math.max);
        x += spacing
      ) {
        if (!_inside(zone.boundary, x, z)) continue;
        number++;
        trees.add(
          OrchardTree(
            number: number,
            x: x,
            z: z,
            zoneId: zone.id,
            photo: number == 1 ? StatusLevel.warning : null,
          ),
        );
      }
    }
  }
  final now = DateTime.now();
  return MyOrchard(
    complete: true,
    areaHa: 2.3688,
    outline: demoOutline,
    zones: demoZones,
    nodes: [
      for (final zone in demoZones)
        SensorNode(
          id: 'node-${zone.letter}',
          zoneId: zone.id,
          x:
              zone.boundary.map((p) => p.x).reduce((a, b) => a + b) /
              zone.boundary.length,
          z:
              zone.boundary.map((p) => p.z).reduce((a, b) => a + b) /
              zone.boundary.length,
          installed: zone.letter != 'D',
          online: zone.letter == 'A' || zone.letter == 'B',
          battery: zone.letter == 'D' ? null : 64,
          lastSeen: zone.letter == 'D'
              ? null
              : now.subtract(const Duration(minutes: 5)),
        ),
    ],
    trees: trees,
  );
}
