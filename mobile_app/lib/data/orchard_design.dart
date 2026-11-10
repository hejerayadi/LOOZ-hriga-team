// The DRAFT of the orchard designer. It is saved in orchards.design
// (orchard_save_design() of migration 011) after every step, so the farmer
// goes on where he stopped, even on another phone:
//   {"step": "outline"|"zones"|"review", "mode": "grid", "name": "",
//    "outline": [{"x", "z"}...] (metres), "origin": null, "spacing": 7,
//    "zone_method": "auto"|"draw",
//    "zones": [{"letter", "name", "type", "color", "boundary", "tree_count"}],
//    "cuts": [[{"x","z"}, {"x","z"}]...]}
// "cuts" (the dividing lines the farmer drew) is only for the app: the
// database does not read it. Once paid, orchard_apply_design() builds the
// orchard from it (zones, one sensor per zone, the trees in rows).
//
// "mode" is always "grid" for now. The satellite map (Phase 5) will write
// "map" and "origin" = the GPS point of (0, 0); the corners stay in metres.
import 'orchard_service.dart';

/// The steps of the designer (the database knows the same 3).
enum DesignStep { outline, zones, review }

/// How the zones were made.
enum ZoneMethod {
  /// The farmer said how many zones and trees: cut automatically.
  auto,

  /// The farmer drew the dividing lines himself.
  draw,
}

/// The colours a zone can have (the same 10 as the database's default).
const zoneColors = [
  '#8BC34A',
  '#4FC3F7',
  '#FFB74D',
  '#BA68C8',
  '#4DB6AC',
  '#F06292',
  '#AED581',
  '#7986CB',
  '#FFD54F',
  '#A1887F',
];

/// At most 20 zones (letters A to T), like the database.
const maxZones = 20;

/// The letter of the zone number [index] (0 = "A").
String zoneLetter(int index) => String.fromCharCode(0x41 + index);

List<Map<String, double>> _pointsJson(List<OrchardPoint> points) => [
  for (final p in points) {'x': _cm(p.x), 'z': _cm(p.z)},
];

/// Rounded to the centimetre (smaller to save, enough for an orchard).
double _cm(double v) => (v * 100).roundToDouble() / 100;

class DesignZone {
  const DesignZone({
    required this.letter,
    required this.boundary,
    required this.color,
    this.name = '',
    this.type,
    this.treeCount,
  });

  final String letter;
  final List<OrchardPoint> boundary;

  /// "#8BC34A" (one of zoneColors).
  final String color;

  /// The farmer's own name (empty = "المنطقة A").
  final String name;
  final ZoneType? type;

  /// About how many trees (at least 1 before building).
  final int? treeCount;

  DesignZone copyWith({
    String? letter,
    List<OrchardPoint>? boundary,
    String? color,
    String? name,
    ZoneType? type,
    bool clearType = false,
    int? treeCount,
  }) => DesignZone(
    letter: letter ?? this.letter,
    boundary: boundary ?? this.boundary,
    color: color ?? this.color,
    name: name ?? this.name,
    type: clearType ? null : type ?? this.type,
    treeCount: treeCount ?? this.treeCount,
  );

  Map<String, Object?> toJson() => {
    'letter': letter,
    'name': name,
    'type': type == null ? null : zoneTypeDbName(type!),
    'color': color,
    'boundary': _pointsJson(boundary),
    'tree_count': treeCount,
  };

  static DesignZone fromJson(Map<String, dynamic> json, int index) {
    final type = json['type'] as String?;
    return DesignZone(
      letter: json['letter'] as String? ?? zoneLetter(index),
      boundary: OrchardPoint.listFrom(json['boundary']),
      color: json['color'] as String? ?? zoneColors[index % zoneColors.length],
      name: json['name'] as String? ?? '',
      type: type == null ? null : zoneTypeFromDbName(type),
      treeCount: (json['tree_count'] as num?)?.toInt(),
    );
  }
}

class OrchardDesign {
  const OrchardDesign({
    this.step = DesignStep.outline,
    this.outline = const [],
    this.zoneMethod,
    this.zones = const [],
    this.cuts = const [],
    this.spacing = 7,
  });

  /// The step to open when the farmer comes back.
  final DesignStep step;

  /// The corners of the orchard, in metres (empty = not drawn yet).
  final List<OrchardPoint> outline;
  final ZoneMethod? zoneMethod;
  final List<DesignZone> zones;

  /// The dividing lines drawn (ZoneMethod.draw), to undo them.
  final List<(OrchardPoint, OrchardPoint)> cuts;

  /// Metres between two trees (when a zone has no number of trees).
  final double spacing;

  /// Everything the database needs to build the orchard.
  bool get complete => outline.length >= 3 && zones.isNotEmpty;

  OrchardDesign copyWith({
    DesignStep? step,
    List<OrchardPoint>? outline,
    ZoneMethod? zoneMethod,
    List<DesignZone>? zones,
    List<(OrchardPoint, OrchardPoint)>? cuts,
  }) => OrchardDesign(
    step: step ?? this.step,
    outline: outline ?? this.outline,
    zoneMethod: zoneMethod ?? this.zoneMethod,
    zones: zones ?? this.zones,
    cuts: cuts ?? this.cuts,
    spacing: spacing,
  );

  Map<String, Object?> toJson() => {
    'step': step.name,
    'mode': 'grid',
    'name': '',
    'outline': outline.isEmpty ? null : _pointsJson(outline),
    'origin': null,
    'spacing': spacing,
    if (zoneMethod != null) 'zone_method': zoneMethod!.name,
    'zones': [for (final z in zones) z.toJson()],
    'cuts': [
      for (final (a, b) in cuts) _pointsJson([a, b]),
    ],
  };

  /// A draft read back (null = not one the app can open).
  static OrchardDesign? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      final zones = json['zones'] as List<dynamic>? ?? const [];
      return OrchardDesign(
        step: DesignStep.values.firstWhere(
          (s) => s.name == json['step'],
          orElse: () => DesignStep.outline,
        ),
        outline: OrchardPoint.listFrom(json['outline']),
        zoneMethod: switch (json['zone_method']) {
          'auto' => ZoneMethod.auto,
          'draw' => ZoneMethod.draw,
          _ => null,
        },
        zones: [
          for (final (i, z) in zones.indexed)
            DesignZone.fromJson(z as Map<String, dynamic>, i),
        ],
        cuts: [
          for (final line in json['cuts'] as List<dynamic>? ?? const [])
            if (OrchardPoint.listFrom(line) case [final a, final b]) (a, b),
        ],
        spacing: (json['spacing'] as num?)?.toDouble() ?? 7,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where the farmer is with his orchard.
class DesignState {
  const DesignState({required this.built, this.draft});

  /// true = the orchard is built (the 3D shows it).
  final bool built;

  /// The draft of the designer (null = none).
  final OrchardDesign? draft;
}
