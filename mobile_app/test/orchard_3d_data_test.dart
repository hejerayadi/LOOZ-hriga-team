// Checks the fake 3D orchard data: 4 zones, 1 node per zone, every tree in a zone.
// Run it with: flutter test
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/features/orchard_3d/orchard_3d_data.dart';

void main() {
  test('4 zones with one node each', () {
    final nodes = fakeNodes();
    expect(fakeZones.length, 4);
    expect(nodes.map((n) => n.zoneId).toSet(), fakeZones.map((z) => z.id).toSet());
  });

  test('every tree belongs to a zone', () {
    final trees = fakeTrees();
    expect(trees, isNotEmpty);
    expect(trees.where((t) => t.zoneId == null), isEmpty);
  });

  test('JSON for the 3D page has zones, nodes and trees', () {
    final data = jsonDecode(orchard3dJson()) as Map<String, dynamic>;
    expect((data['zones'] as List).length, 4);
    expect((data['nodes'] as List).length, 4);
    expect((data['trees'] as List).length, fakeTrees().length);
  });

  test('each node stands inside its own zone', () {
    final data = jsonDecode(orchard3dJson()) as Map<String, dynamic>;
    final trees = data['trees'] as List;
    for (final node in fakeNodes()) {
      // The tree closest to the node is in the same zone as the node.
      final closest = trees.reduce((a, b) {
        double d(dynamic t) =>
            ((t['x'] as num) - node.x).abs() + ((t['z'] as num) - node.z).abs();
        return d(a) <= d(b) ? a : b;
      });
      expect(closest['zone_id'], node.zoneId, reason: node.id);
    }
  });
}
