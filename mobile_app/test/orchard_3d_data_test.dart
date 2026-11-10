// Checks what the 3D page gets from the farmer's REAL orchard (here the
// demo orchard of the seed, fake_orchard_service.dart): the outline, the
// zones (colour, type, names in both languages), one node per zone, every
// tree in a zone, the photos, the texts from the ARB files.
// Run it with: flutter test
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_3d_data.dart';

import 'fake_orchard_service.dart';

Map<String, dynamic> page([MyOrchard? orchard, String language = 'ar']) =>
    jsonDecode(orchard3dJson(orchard ?? demoOrchard(), language: language))
        as Map<String, dynamic>;

bool inside(List<dynamic> polygon, num x, num z) {
  var c = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i] as Map;
    final b = polygon[j] as Map;
    if (((a['z'] as num) > z) != ((b['z'] as num) > z) &&
        x <
            ((b['x'] as num) - (a['x'] as num)) *
                    (z - (a['z'] as num)) /
                    ((b['z'] as num) - (a['z'] as num)) +
                (a['x'] as num)) {
      c = !c;
    }
  }
  return c;
}

void main() {
  test('A real orchard: "real", the outline, its size and area', () {
    final data = page();
    expect(data['real'], isTrue);
    expect(data['live'], isTrue);
    final orchard = data['orchard'] as Map;
    expect((orchard['outline'] as List).length, 5);
    expect(orchard['width'], 195); // -95 .. 100 m
    expect(orchard['length'], 145); // -70 .. 75 m
    expect(orchard['area_ha'], 2.3688);
  });

  test('Everything is moved so the middle of the orchard is at (0, 0)', () {
    final outline = (page()['orchard'] as Map)['outline'] as List;
    final xs = outline.map((p) => (p as Map)['x'] as num);
    final zs = outline.map((p) => (p as Map)['z'] as num);
    expect(xs.reduce(math.min) + xs.reduce(math.max), 0);
    expect(zs.reduce(math.min) + zs.reduce(math.max), 0);
  });

  test(
    '4 zones: colour and type from the designer, names in both languages',
    () {
      final zones = page()['zones'] as List;
      expect(zones.map((z) => z['color']), [
        '#8BC34A',
        '#4FC3F7',
        '#FFB74D',
        '#BA68C8',
      ]);
      expect(zones.map((z) => z['type']), [
        'young_trees',
        'old_trees',
        'sandy_soil',
        null,
      ]);
      expect(zones.map((z) => z['health']), [
        'good',
        'warning',
        'danger',
        'good',
      ]);
      expect(zones[0]['names'], {'ar': 'المنطقة A', 'fr': 'Zone A'});
      // A zone with its own name keeps it in both languages.
      expect(zones[2]['names'], {'ar': 'الجنان القبلي', 'fr': 'الجنان القبلي'});
      expect(page(null, 'fr')['zones'][0]['name'], 'Zone A');
    },
  );

  test('One node per zone, inside its zone; installed or waiting; no '
      'readings yet', () {
    final data = page();
    final zones = {for (final z in data['zones'] as List) z['id']: z};
    final nodes = data['nodes'] as List;
    expect(nodes.map((n) => n['zone_id']).toSet(), zones.keys.toSet());
    for (final n in nodes) {
      expect(
        inside(
          zones[n['zone_id']]['boundary'] as List,
          n['position_x'],
          n['position_z'],
        ),
        isTrue,
        reason: '${n['id']}',
      );
      expect(n['soil_moisture'], isNull);
      expect(n['temperature'], isNull);
    }
    expect(nodes.map((n) => n['installed']), [true, true, true, false]);
    expect(nodes.map((n) => n['status']), [
      'online',
      'online',
      'offline',
      'offline',
    ]);
  });

  test('Every tree stands inside its zone, with its number', () {
    final data = page();
    final zones = {for (final z in data['zones'] as List) z['id']: z};
    final trees = data['trees'] as List;
    expect(trees.length, demoOrchard().trees.length);
    expect(trees.length, greaterThan(500));
    for (final t in trees) {
      expect(
        inside(zones[t['zone_id']]['boundary'] as List, t['x'], t['z']),
        isTrue,
        reason: '#${t['id']}',
      );
    }
    expect(trees.map((t) => t['id']).toSet().length, trees.length);
  });

  test('Only the latest photo of a tree counts (here tree #1: warning)', () {
    final status = {
      for (final t in page()['trees'] as List) t['id']: t['photo_status'],
    };
    expect(status[1], 'warning');
    expect(status[2], isNull);
    // No other health value per tree.
    expect((page()['trees'] as List).first.containsKey('status'), isFalse);
  });

  test('The new texts of the page come from the ARB files, in both '
      'languages', () {
    final texts = page()['texts'] as Map;
    expect((texts['ar'] as Map)['types'], {
      'young_trees': 'أشجار صغيرة',
      'old_trees': 'أشجار كبيرة',
      'sandy_soil': 'تربة رملية',
      'irrigated': 'مسقية',
      'rainfed': 'بعلية',
      'other': 'أخرى',
    });
    expect((texts['ar'] as Map)['nodeWaiting'], 'في انتظار التركيب');
    expect((texts['ar'] as Map)['soon'], 'قريبًا');
    expect((texts['fr'] as Map)['nodeWaiting'], "En attente d'installation");
    expect((texts['fr'] as Map)['soon'], 'Bientôt');
    expect(
      ((texts['fr'] as Map)['types'] as Map)['young_trees'],
      'Jeunes arbres',
    );
  });
}
