// A fake of the farmer's orchard for the tests (no internet): the same
// orchard as supabase/seed/orchard_demo.sql (2.37 ha, zones A-D, one node
// per zone, the trees in rows), or none, or a draft of the designer.
// Like the database: a complete draft is what the bill is made from (see
// FakePaymentService.orchard), and it is built only once the pack covers
// it (else the error of PT402).
import 'dart:async';
import 'dart:math' as math;

import 'package:looz_mobile/core/enums.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/orchard_design.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/features/orchard_designer/geometry.dart';

import 'fake_payment_service.dart';

class FakeOrchardService implements OrchardService {
  FakeOrchardService([this.orchard]);

  /// The orchard of the user (null = none drawn).
  MyOrchard? orchard;

  /// The draft of the designer (null = none).
  OrchardDesign? design;

  /// The next call fails with this error (once).
  AuthFailure? failNext;

  /// How many times the orchard was read.
  int loads = 0;

  /// The calls, e.g. "save zones", "build".
  final List<String> calls = [];

  /// Not null = building waits for it.
  Completer<void>? holdBuild;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw AuthError(failure);
    }
  }

  /// The fake bill follows the draft (like orchard_quote()).
  void _bill() {
    final payments = paymentService;
    if (payments is! FakePaymentService) return;
    final draft = design;
    if (draft != null && draft.complete) {
      payments.drawOrchard(draft.zones.length, areaHa: hectares(draft.outline));
    } else if (!(orchard?.complete ?? false)) {
      payments.orchard = null;
    }
  }

  @override
  Future<MyOrchard?> loadMyOrchard() async {
    loads++;
    _maybeFail();
    return orchard;
  }

  @override
  Future<DesignState> loadDesign() async {
    calls.add('load design');
    _maybeFail();
    return DesignState(built: orchard?.complete ?? false, draft: design);
  }

  @override
  Future<void> saveDesign(OrchardDesign design) async {
    calls.add('save ${design.step.name}');
    _maybeFail();
    this.design = design;
    orchard ??= const MyOrchard(complete: false);
    _bill();
  }

  @override
  Future<void> discardDesign() async {
    calls.add('discard');
    _maybeFail();
    design = null;
    if (!(orchard?.complete ?? false)) orchard = null;
    _bill();
  }

  @override
  Future<void> buildOrchard() async {
    calls.add('build');
    await holdBuild?.future;
    _maybeFail();
    final draft = design;
    if (draft == null || !draft.complete) {
      throw const AuthError(AuthFailure.unknown); // PT409: nothing to build
    }
    final payments = paymentService;
    if (payments is FakePaymentService &&
        payments.quote().kind != QuoteKind.covered) {
      throw const AuthError(AuthFailure.unknown); // PT402: pay first
    }
    orchard = builtFrom(draft);
    design = null;
  }
}

/// The orchard the database builds from a draft (orchard_apply_design):
/// the zones, one sensor per zone (waiting for the technician), the trees.
MyOrchard builtFrom(OrchardDesign draft) {
  final zones = [
    for (final z in draft.zones)
      OrchardZone(
        id: 'zone-${z.letter}',
        letter: z.letter,
        name: z.name,
        type: z.type,
        color: z.color,
        treeCount: z.treeCount,
        boundary: z.boundary,
      ),
  ];
  var number = 0;
  return MyOrchard(
    complete: true,
    areaHa: hectares(draft.outline),
    outline: draft.outline,
    zones: zones,
    nodes: [
      for (final z in zones)
        SensorNode(
          id: 'node-${z.letter}',
          zoneId: z.id,
          x: labelPoint(z.boundary).x,
          z: labelPoint(z.boundary).z,
          installed: false,
        ),
    ],
    trees: [
      for (final z in zones)
        for (final t in layoutTrees(z.boundary, z.treeCount))
          OrchardTree(number: ++number, x: t.x, z: t.z, zoneId: z.id),
    ],
  );
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
