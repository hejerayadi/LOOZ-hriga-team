// The farmer's orchard from Supabase (migration 011): its outline, its
// zones (one sensor node each), its trees and the latest photo of each tree.
//
// READ ONLY: the orchard is written only by the database's functions (the
// designer, phase 3). Zones, nodes and trees need the paid pack (RLS):
// on the free plan the "بستاني ★" tab shows the locked screen anyway.
// Archived zones and trees (removed by an edit, kept for their history) are
// not read here.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/enums.dart';
import '../core/supabase_config.dart';
import 'auth_service.dart';

/// A corner, in metres (x = east, z = south: the 3D scene's ground).
class OrchardPoint {
  const OrchardPoint(this.x, this.z);

  final double x;
  final double z;

  static List<OrchardPoint> listFrom(Object? json) => [
    for (final p in (json as List<dynamic>? ?? const []))
      OrchardPoint(
        ((p as Map)['x'] as num).toDouble(),
        (p['z'] as num).toDouble(),
      ),
  ];
}

/// The kind of a zone, chosen in the designer (optional).
enum ZoneType { youngTrees, oldTrees, sandySoil, irrigated, rainfed, other }

const _zoneTypeNames = {
  'young_trees': ZoneType.youngTrees,
  'old_trees': ZoneType.oldTrees,
  'sandy_soil': ZoneType.sandySoil,
  'irrigated': ZoneType.irrigated,
  'rainfed': ZoneType.rainfed,
  'other': ZoneType.other,
};

/// The name of a zone type in the database ('young_trees'...).
String zoneTypeDbName(ZoneType type) =>
    _zoneTypeNames.entries.firstWhere((e) => e.value == type).key;

/// Table "zones": a part of the orchard that differs from the others
/// (soil, age, watering...), with its own sensor node.
class OrchardZone {
  const OrchardZone({
    required this.id,
    required this.letter,
    required this.boundary,
    this.name = '',
    this.type,
    this.color,
    this.treeCount,
    this.health = StatusLevel.good,
  });

  final String id;

  /// "A", "B"...: called "المنطقة A" / "Zone A" when it has no name.
  final String letter;

  /// The farmer's own name (empty = "Zone A").
  final String name;
  final ZoneType? type;

  /// "#8BC34A" (chosen in the designer).
  final String? color;
  final List<OrchardPoint> boundary;

  /// The trees the farmer said (the rows are planted from it).
  final int? treeCount;

  /// From the sensors of its node: a tree's health = its zone's health.
  final StatusLevel health;

  static const columns =
      'id, letter, name, zone_type, color, boundary, tree_count, health';

  static OrchardZone fromRow(Map<String, dynamic> row) => OrchardZone(
    id: row['id'] as String,
    letter: row['letter'] as String? ?? '?',
    name: row['name'] as String? ?? '',
    type: _zoneTypeNames[row['zone_type']],
    color: row['color'] as String?,
    boundary: OrchardPoint.listFrom(row['boundary']),
    treeCount: (row['tree_count'] as num?)?.toInt(),
    health: StatusLevel.values.firstWhere(
      (s) => s.name == row['health'],
      orElse: () => StatusLevel.good,
    ),
  );
}

/// Table "nodes": the sensor box of a zone. Waiting = not installed yet.
/// (Its readings will come from the readings database, not Supabase.)
class SensorNode {
  const SensorNode({
    required this.id,
    required this.zoneId,
    required this.x,
    required this.z,
    required this.installed,
    this.online = false,
    this.battery,
    this.lastSeen,
  });

  final String id;
  final String zoneId;
  final double x;
  final double z;
  final bool installed;
  final bool online;
  final int? battery;
  final DateTime? lastSeen;

  static const columns =
      'id, zone_id, position_x, position_z, battery, status, last_seen, installed_at';

  static SensorNode fromRow(Map<String, dynamic> row) {
    final seen = row['last_seen'] as String?;
    return SensorNode(
      id: row['id'] as String,
      zoneId: row['zone_id'] as String,
      x: (row['position_x'] as num?)?.toDouble() ?? 0,
      z: (row['position_z'] as num?)?.toDouble() ?? 0,
      installed: row['installed_at'] != null,
      online: row['status'] == 'online',
      battery: (row['battery'] as num?)?.toInt(),
      lastSeen: seen == null ? null : DateTime.parse(seen),
    );
  }
}

/// Table "trees": one tree, its number ("#12") and its zone.
class OrchardTree {
  const OrchardTree({
    required this.number,
    required this.x,
    required this.z,
    required this.zoneId,
    this.variety = 'main',
    this.photo,
  });

  final int number;
  final double x;
  final double z;
  final String? zoneId;

  /// 'main' | 'pollinizer'.
  final String variety;

  /// The status of its latest photo diagnosis (null = no photo).
  final StatusLevel? photo;
}

/// The farmer's orchard: complete (built by the designer) or a draft.
class MyOrchard {
  const MyOrchard({
    required this.complete,
    this.areaHa,
    this.outline = const [],
    this.zones = const [],
    this.nodes = const [],
    this.trees = const [],
  });

  /// false = a draft of the designer (nothing to show in 3D yet).
  final bool complete;
  final double? areaHa;
  final List<OrchardPoint> outline;
  final List<OrchardZone> zones;
  final List<SensorNode> nodes;
  final List<OrchardTree> trees;
}

/// What the app needs to read the orchard. The app uses
/// SupabaseOrchardService; the tests use a fake one (no internet needed).
abstract class OrchardService {
  /// The orchard of the logged-in farmer (null = none, not even a draft).
  /// Errors: AuthError (no internet, session expired...).
  Future<MyOrchard?> loadMyOrchard();
}

OrchardService? _orchardService;

/// The orchard: Supabase in the app (the tests put a fake one).
OrchardService get orchardService =>
    _orchardService ??= SupabaseOrchardService(supabase);
set orchardService(OrchardService service) => _orchardService = service;

class SupabaseOrchardService implements OrchardService {
  SupabaseOrchardService(this._client);

  final SupabaseClient _client;

  /// Rows per request (Supabase gives at most 1000 at a time).
  static const page = 1000;
  static const timeout = Duration(seconds: 30);

  @override
  Future<MyOrchard?> loadMyOrchard() async {
    try {
      return await _load().timeout(timeout);
    } on AuthError {
      rethrow;
    } catch (error) {
      throw AuthError(failureOf(error), error);
    }
  }

  Future<MyOrchard?> _load() async {
    final row = await _client
        .from('orchards')
        .select('id, status, area, outline')
        .maybeSingle();
    if (row == null) return null;
    if (row['status'] != 'complete') return const MyOrchard(complete: false);
    final id = row['id'] as String;

    final zoneRows = await _client
        .from('zones')
        .select(OrchardZone.columns)
        .eq('orchard_id', id)
        .isFilter('archived_at', null)
        .order('letter', ascending: true);
    final zones = [for (final z in zoneRows) OrchardZone.fromRow(z)];
    final zoneIds = [for (final z in zones) z.id];

    final nodeRows = zoneIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('nodes')
              .select(SensorNode.columns)
              .inFilter('zone_id', zoneIds);

    final treeRows = await _all(
      (from, to) => _client
          .from('trees')
          .select('id, code, pos_x, pos_z, zone_id, variety')
          .eq('orchard_id', id)
          .isFilter('archived_at', null)
          .order('id', ascending: true)
          .range(from, to),
    );
    final photoRows = await _all(
      (from, to) => _client
          .from('tree_latest_photos')
          .select('tree_id, status')
          .order('tree_id', ascending: true)
          .range(from, to),
    );
    final photos = {
      for (final p in photoRows)
        p['tree_id'] as String: StatusLevel.values.firstWhere(
          (s) => s.name == p['status'],
          orElse: () => StatusLevel.good,
        ),
    };

    return MyOrchard(
      complete: true,
      areaHa: (row['area'] as num?)?.toDouble(),
      outline: OrchardPoint.listFrom(row['outline']),
      zones: zones,
      nodes: [for (final n in nodeRows) SensorNode.fromRow(n)],
      trees: [
        for (final t in treeRows)
          OrchardTree(
            number: int.tryParse(t['code'] as String? ?? '') ?? 0,
            x: (t['pos_x'] as num?)?.toDouble() ?? 0,
            z: (t['pos_z'] as num?)?.toDouble() ?? 0,
            zoneId: t['zone_id'] as String?,
            variety: t['variety'] == 'pollinizer' ? 'pollinizer' : 'main',
            photo: photos[t['id']],
          ),
      ],
    );
  }

  /// Every row of a query, [page] rows at a time.
  static Future<List<Map<String, dynamic>>> _all(
    Future<List<Map<String, dynamic>>> Function(int from, int to) query,
  ) async {
    final rows = <Map<String, dynamic>>[];
    while (true) {
      final part = await query(rows.length, rows.length + page - 1);
      rows.addAll(part);
      if (part.length < page) return rows;
    }
  }
}
