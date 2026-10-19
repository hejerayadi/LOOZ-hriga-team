// FAKE data for the orchard: one orchard, 4 zones, 1 sensor node per zone,
// trees assigned to zones, and photo diagnoses of a few trees.
//
// - Sensor data exists only per zone (its node), never per tree.
// - A tree's health = its zone's health.
// - The only tree-level information is a photo diagnosis (camera button).
//
// Used by the 3D page (orchard3dJson below) and the "Mon verger" tab.
// The classes use the same fields as the Supabase tables (zones, nodes,
// trees, tree_photos), so later we only replace the fake lists with real data.
import 'dart:convert';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';

/// One corner of a zone, in the 3D scene (meters). Table zones, column boundary.
class ZonePoint {
  const ZonePoint(this.x, this.z);

  final double x;
  final double z;
}

/// Table "zones": an area of the orchard with the same kind of soil.
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.boundary,
    required this.health,
    this.soilNotes = '',
  });

  final String id;
  final String name;
  final List<ZonePoint> boundary;
  final StatusLevel health;
  final String soilNotes;
}

/// Table "nodes": the sensor box of a zone (one per zone).
/// soilMoisture and temperature are the last readings: later they will come
/// from the readings database (not Supabase).
class SensorNode {
  const SensorNode({
    required this.id,
    required this.zoneId,
    required this.x,
    required this.z,
    required this.battery,
    required this.online,
    required this.lastSeen,
    required this.soilMoisture,
    required this.temperature,
  });

  final String id;
  final String zoneId;
  final double x; // position_x
  final double z; // position_z
  final int battery; // %
  final bool online; // status: 'online' | 'offline'
  final DateTime lastSeen;
  final double soilMoisture; // %
  final double temperature; // °C
}

/// Table "trees": one tree and its zone. No health of its own:
/// its health is its zone's health.
class OrchardTree {
  const OrchardTree({
    required this.number,
    required this.x,
    required this.z,
    required this.zoneId,
    required this.variety,
  });

  final int number; // shown as "#12"
  final double x; // pos_x
  final double z; // pos_z
  final String? zoneId;
  final String variety; // 'main' | 'pollinizer'
}

/// Table "tree_photos": the result of a photo taken with the camera button.
class TreePhoto {
  const TreePhoto({
    required this.treeNumber,
    required this.imagePath,
    required this.aiResult,
    required this.status,
    required this.createdAt,
  });

  final int treeNumber; // tree_id
  final String imagePath;
  final String aiResult; // what the AI found (short text here)
  final StatusLevel status;
  final DateTime createdAt;
}

// ------------------------------------------------------------------
// The fake orchard
// ------------------------------------------------------------------

/// Size of the plot (meters): x from -24 to 24, z from -18 to 18.
const double orchardWidth = 48;
const double orchardLength = 36;

/// 4 zones of different shapes that cover the whole plot.
const List<Zone> fakeZones = [
  Zone(
    id: 'zone-a',
    name: 'Zone A',
    health: StatusLevel.good,
    soilNotes: 'Sol limoneux, bien drainé',
    boundary: [
      ZonePoint(-24, -18),
      ZonePoint(2, -18),
      ZonePoint(-2, -2),
      ZonePoint(-24, 0),
    ],
  ),
  Zone(
    id: 'zone-b',
    name: 'Zone B',
    health: StatusLevel.warning,
    soilNotes: 'Sol sableux, sèche vite',
    boundary: [
      ZonePoint(2, -18),
      ZonePoint(24, -18),
      ZonePoint(24, 4),
      ZonePoint(8, 2),
      ZonePoint(-2, -2),
    ],
  ),
  Zone(
    id: 'zone-c',
    name: 'Zone C',
    health: StatusLevel.danger,
    soilNotes: 'Argile lourde, eau stagnante',
    boundary: [
      ZonePoint(-24, 0),
      ZonePoint(-2, -2),
      ZonePoint(4, 8),
      ZonePoint(0, 18),
      ZonePoint(-24, 18),
    ],
  ),
  Zone(
    id: 'zone-d',
    name: 'Zone D',
    health: StatusLevel.good,
    soilNotes: 'Sol profond',
    boundary: [
      ZonePoint(-2, -2),
      ZonePoint(8, 2),
      ZonePoint(24, 4),
      ZonePoint(24, 18),
      ZonePoint(0, 18),
      ZonePoint(4, 8),
    ],
  ),
];

/// 1 node per zone, placed between the trees. The node of zone C is offline.
List<SensorNode> fakeNodes() {
  final now = DateTime.now();
  return [
    SensorNode(
      id: 'node-a',
      zoneId: 'zone-a',
      x: -12,
      z: -12,
      battery: 82,
      online: true,
      lastSeen: now.subtract(const Duration(minutes: 4)),
      soilMoisture: 31,
      temperature: 24.5,
    ),
    SensorNode(
      id: 'node-b',
      zoneId: 'zone-b',
      x: 12,
      z: -12,
      battery: 18,
      online: true,
      lastSeen: now.subtract(const Duration(minutes: 12)),
      soilMoisture: 14,
      temperature: 27.1,
    ),
    SensorNode(
      id: 'node-c',
      zoneId: 'zone-c',
      x: -12,
      z: 12,
      battery: 6,
      online: false,
      lastSeen: now.subtract(const Duration(hours: 3, minutes: 10)),
      soilMoisture: 58,
      temperature: 22.8,
    ),
    SensorNode(
      id: 'node-d',
      zoneId: 'zone-d',
      x: 12,
      z: 12,
      battery: 64,
      online: true,
      lastSeen: now.subtract(const Duration(minutes: 2)),
      soilMoisture: 27,
      temperature: 25.0,
    ),
  ];
}

/// Photos taken with the camera button. Only the LATEST photo of a tree counts.
List<TreePhoto> fakePhotos() {
  final now = DateTime.now();
  TreePhoto photo(int tree, StatusLevel status, String result, int daysAgo) =>
      TreePhoto(
        treeNumber: tree,
        imagePath: 'photos/tree-$tree-$daysAgo.jpg',
        aiResult: result,
        status: status,
        createdAt: now.subtract(Duration(days: daysAgo)),
      );
  return [
    photo(4, StatusLevel.good, 'Sain', 20),
    photo(4, StatusLevel.danger, 'Tavelure', 1), // latest = danger: marker
    photo(46, StatusLevel.warning, 'Pucerons', 3), // marker
    photo(20, StatusLevel.warning, 'Feuilles jaunes', 15),
    photo(20, StatusLevel.good, 'Sain', 2), // latest = good: no marker
  ];
}

/// Latest photo of each tree (tree number -> photo).
Map<int, TreePhoto> latestPhotos() {
  final latest = <int, TreePhoto>{};
  for (final photo in fakePhotos()) {
    final current = latest[photo.treeNumber];
    if (current == null || photo.createdAt.isAfter(current.createdAt)) {
      latest[photo.treeNumber] = photo;
    }
  }
  return latest;
}

/// The zone with this id.
Zone zoneById(String id) => fakeZones.firstWhere((zone) => zone.id == id);

/// Trees: rows 6 m apart, trees 6 m apart, one pollinizer row out of 4.
/// Each tree gets the zone it stands in.
List<OrchardTree> fakeTrees() {
  final trees = <OrchardTree>[];
  var number = 1;
  for (var row = 0; row < 6; row++) {
    for (var col = 0; col < 8; col++) {
      final x = -21.0 + col * 6;
      final z = -15.0 + row * 6;
      trees.add(OrchardTree(
        number: number,
        x: x,
        z: z,
        zoneId: _zoneAt(x, z)?.id,
        variety: (row + 1) % 4 == 0 ? 'pollinizer' : 'main',
      ));
      number++;
    }
  }
  return trees;
}

/// The zone that contains the point (x, z), or null.
Zone? _zoneAt(double x, double z) {
  for (final zone in fakeZones) {
    if (_inside(zone.boundary, x, z)) return zone;
  }
  return null;
}

/// Is the point inside the polygon? (classic "ray crossing" test)
bool _inside(List<ZonePoint> polygon, double x, double z) {
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

// ------------------------------------------------------------------
// Sent to the 3D page (assets/orchard_3d/index.html)
// ------------------------------------------------------------------

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Everything the 3D page needs, as JSON text.
String orchard3dJson() {
  final photos = latestPhotos();
  return jsonEncode({
    // Same green / orange / red as the rest of the app.
    'colors': {
      'good': _hex(AppColors.good.toARGB32()),
      'warning': _hex(AppColors.warning.toARGB32()),
      'danger': _hex(AppColors.danger.toARGB32()),
    },
    'orchard': {'width': orchardWidth, 'length': orchardLength},
    'zones': [
      for (final zone in fakeZones)
        {
          'id': zone.id,
          'name': zone.name,
          'health': zone.health.name,
          'soil_notes': zone.soilNotes,
          'boundary': [
            for (final p in zone.boundary) {'x': p.x, 'z': p.z},
          ],
        },
    ],
    'nodes': [
      for (final node in fakeNodes())
        {
          'id': node.id,
          'zone_id': node.zoneId,
          'position_x': node.x,
          'position_z': node.z,
          'battery': node.battery,
          'status': node.online ? 'online' : 'offline',
          'last_seen': node.lastSeen.toUtc().toIso8601String(),
          'soil_moisture': node.soilMoisture,
          'temperature': node.temperature,
        },
    ],
    'trees': [
      for (final tree in fakeTrees())
        {
          'id': tree.number,
          'x': tree.x,
          'z': tree.z,
          'zone_id': tree.zoneId,
          'variety': tree.variety,
          // Status of the latest photo diagnosis (null = no photo yet).
          'photo_status': photos[tree.number]?.status.name,
        },
    ],
  });
}
