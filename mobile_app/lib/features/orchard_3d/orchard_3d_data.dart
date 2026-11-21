// What the 3D page (assets/orchard_3d/index.html) gets: the farmer's REAL
// orchard from Supabase (lib/data/orchard_service.dart), as JSON:
//   - the outline he drew (the ground of the scene follows it),
//   - the zones: colour and type from the designer, name in both languages,
//     health from the sensors (a tree's health = its zone's health),
//   - one sensor node per zone (installed, or waiting for the technician),
//   - the trees in rows, with the status of their latest photo.
// Everything is moved so the middle of the orchard is at (0, 0).
// The new texts of the page come from the ARB files (lib/l10n), in both
// languages, so the page can switch without new data.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;

import '../../core/theme/app_theme.dart';
import '../../core/zone_letters.dart';
import '../../data/ml_service.dart';
import '../../data/orchard_service.dart';
import '../../l10n/app_localizations.dart';
import 'zone_live_texts.dart';

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The name of a zone in a language ('ar' or 'fr'): its own name, or
/// "المنطقة أ" / "Zone A" (the abjad letters in Arabic).
String zoneName(OrchardZone zone, String languageCode) => zone.name.isNotEmpty
    ? zone.name
    : lookupAppLocalizations(Locale(languageCode))
          .zoneName(zoneLetterIn(zone.letter, languageCode));

/// The name of a zone type, in the language of [l10n].
String zoneTypeName(AppLocalizations l10n, ZoneType type) => switch (type) {
  ZoneType.youngTrees => l10n.zoneTypeYoungTrees,
  ZoneType.oldTrees => l10n.zoneTypeOldTrees,
  ZoneType.sandySoil => l10n.zoneTypeSandySoil,
  ZoneType.irrigated => l10n.zoneTypeIrrigated,
  ZoneType.rainfed => l10n.zoneTypeRainfed,
  ZoneType.other => l10n.zoneTypeOther,
};

/// The texts of the page that come from the app (not in the page itself).
Map<String, Object> _pageTexts(String code) {
  final l10n = lookupAppLocalizations(Locale(code));
  return {
    'types': {
      for (final type in ZoneType.values)
        zoneTypeDbName(type): zoneTypeName(l10n, type),
    },
    'nodeWaiting': l10n.nodeWaiting,
    'soon': l10n.soon,
  };
}

/// Everything the 3D page needs, as JSON text.
/// language = the app's language: the page shows its texts in it.
String orchard3dJson(MyOrchard orchard, {String language = 'ar'}) {
  // The middle of the outline goes to (0, 0) (the scene turns around it).
  final points = orchard.outline.isNotEmpty
      ? orchard.outline
      : [for (final z in orchard.zones) ...z.boundary];
  var minX = 0.0, maxX = 0.0, minZ = 0.0, maxZ = 0.0;
  if (points.isNotEmpty) {
    minX = points.map((p) => p.x).reduce(math.min);
    maxX = points.map((p) => p.x).reduce(math.max);
    minZ = points.map((p) => p.z).reduce(math.min);
    maxZ = points.map((p) => p.z).reduce(math.max);
  }
  final cx = (minX + maxX) / 2;
  final cz = (minZ + maxZ) / 2;
  double r(double v) => (v * 100).roundToDouble() / 100;
  Map<String, double> point(OrchardPoint p) => {
    'x': r(p.x - cx),
    'z': r(p.z - cz),
  };

  return jsonEncode({
    'live': true,
    // A real orchard: the page hides the old planner tools.
    'real': true,
    'lang': language,
    // Same green / orange / red as the rest of the app.
    'colors': {
      'good': _hex(AppColors.good.toARGB32()),
      'warning': _hex(AppColors.warning.toARGB32()),
      'danger': _hex(AppColors.danger.toARGB32()),
    },
    'texts': {
      for (final code in ['ar', 'fr']) code: _pageTexts(code),
    },
    'orchard': {
      'width': r(math.max(maxX - minX, 10)),
      'length': r(math.max(maxZ - minZ, 10)),
      'area_ha': orchard.areaHa,
      'outline': [for (final p in orchard.outline) point(p)],
    },
    'zones': [
      for (final zone in orchard.zones)
        {
          'id': zone.id,
          'name': zoneName(zone, language),
          // Both languages, so the page can switch without new data.
          'names': {
            for (final code in ['ar', 'fr']) code: zoneName(zone, code),
          },
          'health': zone.health.name,
          'color': zone.color,
          'type': zone.type == null ? null : zoneTypeDbName(zone.type!),
          'tree_count': zone.treeCount,
          'boundary': [for (final p in zone.boundary) point(p)],
        },
    ],
    'nodes': [
      for (final node in orchard.nodes)
        {
          'id': node.id,
          'zone_id': node.zoneId,
          'position_x': r(node.x - cx),
          'position_z': r(node.z - cz),
          'installed': node.installed,
          'battery': node.battery,
          'status': node.online ? 'online' : 'offline',
          'last_seen': node.lastSeen?.toUtc().toIso8601String(),
          // The readings will come from the readings database: "قريبًا".
          'soil_moisture': null,
          'temperature': null,
        },
    ],
    'trees': [
      for (final tree in orchard.trees)
        {
          'id': tree.number,
          'x': r(tree.x - cx),
          'z': r(tree.z - cz),
          'zone_id': tree.zoneId,
          'variety': tree.variety,
          // Status of the latest photo diagnosis (null = no photo yet).
          'photo_status': tree.photo?.name,
        },
    ],
  });
}


/// The live state of each zone for the 3D page (window.loozSetLive): its
/// colour, its short words in both languages, and the readings of its box.
/// Sent again at each change (Supabase Realtime): the page recolours the
/// zones without loading again.
String orchardLiveJson(MyOrchard orchard, OrchardLive live) {
  final byZone = {for (final n in orchard.nodes) n.zoneId: n};
  final texts = {
    for (final code in ['ar', 'fr']) code: lookupAppLocalizations(Locale(code)),
  };
  return jsonEncode({
    'zones': {
      for (final zone in orchard.zones)
        zone.id: () {
          final node = byZone[zone.id];
          final z = live.zone(node?.id, installed: node?.installed ?? false);
          return {
            'state': z.state.name,
            'color': _hex(zoneStateColor(z.state).toARGB32()),
            'problem': problemStates.contains(z.state),
            'labels': {
              for (final e in texts.entries) e.key: zoneStateName(e.value, z.state),
            },
            'soil_moisture': z.node?.soilMoisture,
            'temperature': z.node?.airTemp,
            'online': z.node != null && z.node!.status != 'offline' && z.node!.status != 'waiting',
          };
        }(),
    },
  });
}
