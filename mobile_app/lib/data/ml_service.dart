// The live state of the farmer's orchard (migrations 012 and 019): the latest
// reading of each sensor box, the 2 predictions of each box (frost tonight,
// stress of the trees) with their main reasons and their explanation, and the
// in-app notifications of the problems.
//
// Everything comes as CODES from Supabase (the database rules give a farmer
// only his own boxes, and only with the paid pack); the screens write the
// texts (ARB files). Only the explanation of Groq is a text (Derja + French).
// The app never writes a prediction: it only marks a notification read.
//
// Live: Supabase Realtime sends a signal as soon as node_latest, ml_latest or
// ml_notifications change (changes()); the store then reads again. If
// Realtime is not there, the store still reads every minute.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'auth_service.dart';

/// What a zone shows in the 3D, the panel and the alerts.
enum ZoneState {
  ok,
  waterDeficit,
  waterlogging,
  heat,
  frostDamage,
  rootzone,
  frostRisk,
  sensorProblem,
  notEnoughData,
  offline,
  waiting,
}

/// The problems a farmer is told about.
const problemStates = {
  ZoneState.waterDeficit,
  ZoneState.waterlogging,
  ZoneState.heat,
  ZoneState.frostDamage,
  ZoneState.rootzone,
  ZoneState.frostRisk,
};

/// A state code of the database -> ZoneState (null = unknown).
ZoneState? zoneStateOf(String? code) => switch (code) {
  'none' => ZoneState.ok,
  'no_frost' => ZoneState.ok,
  'water_deficit' => ZoneState.waterDeficit,
  'waterlogging' => ZoneState.waterlogging,
  'heat' => ZoneState.heat,
  'frost' => ZoneState.frostDamage,
  'rootzone' => ZoneState.rootzone,
  'frost_risk' => ZoneState.frostRisk,
  _ => null,
};

/// One main reason of a prediction: a code of the list of migration 019
/// (never a feature name), low / high, and its part of the push (0..1).
class MlFactor {
  const MlFactor({required this.code, this.level, this.share = 0});

  final String code;
  final String? level;
  final double share;

  static MlFactor? fromJson(Object? json) {
    if (json is! Map || json['code'] is! String) return null;
    return MlFactor(
      code: json['code'] as String,
      level: json['level'] as String?,
      share: (json['share'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A row of ml_latest: the last prediction of a box for one model.
class MlPrediction {
  const MlPrediction({
    required this.nodeId,
    required this.model,
    required this.status,
    required this.measuredAt,
    this.zoneId,
    this.state,
    this.confidence,
    this.likely = false,
    this.factors = const [],
    this.explanationAr,
    this.explanationFr,
    this.actionAr,
    this.actionFr,
    this.predictedAt,
  });

  final String nodeId;
  final String? zoneId;

  /// 'frost' or 'stress'.
  final String model;

  /// 'ok', 'not_enough_data' or 'sensor_problem'.
  final String status;
  final String? state;
  final double? confidence;

  /// "على الأرجح" (else "غير متأكد").
  final bool likely;
  final List<MlFactor> factors;
  final String? explanationAr;
  final String? explanationFr;
  final String? actionAr;
  final String? actionFr;
  final DateTime measuredAt;
  final DateTime? predictedAt;

  bool get ok => status == 'ok';

  /// The Groq text in [language] (null = the app writes its own).
  String? explanation(String language) =>
      language == 'fr' ? explanationFr : explanationAr;
  String? action(String language) => language == 'fr' ? actionFr : actionAr;

  static const columns =
      'node_id, zone_id, model, status, state, confidence, certainty, factors, '
      'explanation_ar, explanation_fr, action_ar, action_fr, measured_at, predicted_at';

  static MlPrediction fromRow(Map<String, dynamic> row) => MlPrediction(
    nodeId: row['node_id'] as String,
    zoneId: row['zone_id'] as String?,
    model: row['model'] as String,
    status: row['status'] as String,
    state: row['state'] as String?,
    confidence: (row['confidence'] as num?)?.toDouble(),
    likely: row['certainty'] == 'likely',
    factors: [
      for (final f in (row['factors'] as List<dynamic>? ?? const []))
        ?MlFactor.fromJson(f),
    ],
    explanationAr: row['explanation_ar'] as String?,
    explanationFr: row['explanation_fr'] as String?,
    actionAr: row['action_ar'] as String?,
    actionFr: row['action_fr'] as String?,
    measuredAt: DateTime.parse(row['measured_at'] as String),
    predictedAt: row['predicted_at'] == null
        ? null
        : DateTime.parse(row['predicted_at'] as String),
  );
}

/// The latest reading and the state of a sensor box (view iot_node_status).
class NodeLive {
  const NodeLive({
    required this.nodeId,
    required this.zoneId,
    required this.status,
    this.measuredAt,
    this.receivedAt,
    this.soilMoisture,
    this.soilTemp,
    this.airTemp,
    this.humidity,
  });

  final String nodeId;
  final String zoneId;

  /// waiting | installed | offline | sensor_problem | online.
  final String status;
  final DateTime? measuredAt;

  /// When Supabase received it (real time: "منذ 2 دقائق").
  final DateTime? receivedAt;
  final double? soilMoisture;
  final double? soilTemp;
  final double? airTemp;
  final double? humidity;

  static const columns =
      'node_id, zone_id, status, measured_at, received_at, soil_moisture_pct, '
      'soil_temp_c, air_temp_c, humidity_pct';

  static NodeLive fromRow(Map<String, dynamic> row) {
    DateTime? time(String key) =>
        row[key] == null ? null : DateTime.parse(row[key] as String);
    double? num_(String key) => (row[key] as num?)?.toDouble();
    return NodeLive(
      nodeId: row['node_id'] as String,
      zoneId: row['zone_id'] as String,
      status: row['status'] as String? ?? 'installed',
      measuredAt: time('measured_at'),
      receivedAt: time('received_at'),
      soilMoisture: num_('soil_moisture_pct'),
      soilTemp: num_('soil_temp_c'),
      airTemp: num_('air_temp_c'),
      humidity: num_('humidity_pct'),
    );
  }
}

/// A row of ml_notifications: one problem of one box (never repeated).
class MlNotification {
  const MlNotification({
    required this.id,
    required this.nodeId,
    required this.model,
    required this.state,
    required this.createdAt,
    this.zoneId,
    this.zoneLetter = '',
    this.zoneName = '',
    this.danger = false,
    this.read = false,
    this.resolved = false,
  });

  final String id;
  final String nodeId;
  final String? zoneId;

  /// "A".. (the database's letter: the screens show "المنطقة أ").
  final String zoneLetter;

  /// The farmer's own name of the zone (empty = none).
  final String zoneName;
  final String model;
  final String state;

  /// Frost: dark green "خطر" (else "انتباه").
  final bool danger;
  final bool read;

  /// The problem ended (kept a few days, not shown any more).
  final bool resolved;
  final DateTime createdAt;

  bool get unread => !read && !resolved;

  MlNotification copyWith({bool? read}) => MlNotification(
    id: id,
    nodeId: nodeId,
    zoneId: zoneId,
    zoneLetter: zoneLetter,
    zoneName: zoneName,
    model: model,
    state: state,
    createdAt: createdAt,
    danger: danger,
    read: read ?? this.read,
    resolved: resolved,
  );

  /// (zone = the zone of the box, embedded by Supabase through zone_id.)
  static const columns =
      'id, node_id, zone_id, model, state, severity, created_at, read_at, '
      'resolved_at, zone:zones(letter, name)';

  static MlNotification fromRow(Map<String, dynamic> row) => MlNotification(
    id: row['id'] as String,
    nodeId: row['node_id'] as String,
    zoneId: row['zone_id'] as String?,
    zoneLetter: (row['zone'] as Map?)?['letter'] as String? ?? '',
    zoneName: (row['zone'] as Map?)?['name'] as String? ?? '',
    model: row['model'] as String,
    state: row['state'] as String,
    danger: row['severity'] == 'danger',
    read: row['read_at'] != null,
    resolved: row['resolved_at'] != null,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

/// What the 3D, the panel and the alerts show for ONE zone.
class ZoneLive {
  const ZoneLive({
    required this.state,
    this.node,
    this.frost,
    this.stress,
  });

  final ZoneState state;
  final NodeLive? node;
  final MlPrediction? frost;
  final MlPrediction? stress;

  /// The prediction behind [state] (null for a sensor or data state).
  MlPrediction? get main => state == ZoneState.frostRisk
      ? frost
      : problemStates.contains(state) || state == ZoneState.ok
      ? stress ?? frost
      : null;
}

/// Everything live of the orchard.
class OrchardLive {
  const OrchardLive({
    this.nodes = const {},
    this.predictions = const {},
    this.notifications = const [],
  });

  /// By node id.
  final Map<String, NodeLive> nodes;

  /// By node id, then by model ('frost' / 'stress').
  final Map<String, Map<String, MlPrediction>> predictions;

  /// Newest first, the resolved ones included.
  final List<MlNotification> notifications;

  /// The open problems (not resolved): the alerts tab.
  List<MlNotification> get open => [
    for (final n in notifications)
      if (!n.resolved) n,
  ];

  /// The number on the bell.
  int get unreadCount => notifications.where((n) => n.unread).length;

  /// The state of the zone of the box [nodeId] (installed or not: [installed]).
  ZoneLive zone(String? nodeId, {bool installed = true}) {
    final node = nodeId == null ? null : nodes[nodeId];
    final preds = nodeId == null ? null : predictions[nodeId];
    final frost = preds?['frost'];
    final stress = preds?['stress'];
    ZoneState state;
    if (!installed || node == null && preds == null) {
      state = installed ? ZoneState.notEnoughData : ZoneState.waiting;
    } else if (node?.status == 'waiting') {
      state = ZoneState.waiting;
    } else if (node?.status == 'offline') {
      state = ZoneState.offline;
    } else if (node?.status == 'sensor_problem' ||
        frost?.status == 'sensor_problem' ||
        stress?.status == 'sensor_problem') {
      state = ZoneState.sensorProblem;
    } else if (frost != null && frost.ok && frost.state == 'frost_risk') {
      state = ZoneState.frostRisk;
    } else if (stress != null && stress.ok) {
      state = zoneStateOf(stress.state) ?? ZoneState.notEnoughData;
    } else {
      state = ZoneState.notEnoughData;
    }
    return ZoneLive(state: state, node: node, frost: frost, stress: stress);
  }

  OrchardLive copyWith({List<MlNotification>? notifications}) => OrchardLive(
    nodes: nodes,
    predictions: predictions,
    notifications: notifications ?? this.notifications,
  );
}

/// What the app needs. The app uses SupabaseMlService; the tests a fake one.
abstract class MlService {
  /// The live state of the logged-in farmer's orchard. Errors: AuthError.
  Future<OrchardLive> load();

  /// A signal each time something of the farmer's orchard changes in the
  /// database (Supabase Realtime). Listening starts it, cancelling stops it.
  Stream<void> changes();

  /// "Read" (the farmer saw it in the app).
  Future<void> markRead(List<String> ids);
}

MlService? _mlService;

/// The predictions: Supabase in the app (the tests put a fake one).
MlService get mlService => _mlService ??= SupabaseMlService(supabase);
set mlService(MlService service) => _mlService = service;

class SupabaseMlService implements MlService {
  SupabaseMlService(this._client);

  final SupabaseClient _client;
  static const timeout = Duration(seconds: 30);

  @override
  Future<OrchardLive> load() async {
    try {
      final results = await Future.wait([
        _client.from('iot_node_status').select(NodeLive.columns),
        _client.from('ml_latest').select(MlPrediction.columns),
        _client
            .from('ml_notifications')
            .select(MlNotification.columns)
            .gte(
              'created_at',
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 30))
                  .toIso8601String(),
            )
            .order('created_at', ascending: false)
            .limit(50),
      ]).timeout(timeout);
      final predictions = <String, Map<String, MlPrediction>>{};
      for (final row in results[1]) {
        final p = MlPrediction.fromRow(row);
        (predictions[p.nodeId] ??= {})[p.model] = p;
      }
      return OrchardLive(
        nodes: {
          for (final row in results[0])
            row['node_id'] as String: NodeLive.fromRow(row),
        },
        predictions: predictions,
        notifications: [for (final r in results[2]) MlNotification.fromRow(r)],
      );
    } catch (error) {
      throw AuthError(failureOf(error), error);
    }
  }

  @override
  Stream<void> changes() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        final uid = _client.auth.currentUser?.id ?? 'me';
        var c = _client.channel('looz-orchard-$uid');
        for (final table in ['node_latest', 'ml_latest', 'ml_notifications']) {
          c = c.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              if (!controller.isClosed) controller.add(null);
            },
          );
        }
        channel = c..subscribe();
      },
      onCancel: () {
        final c = channel;
        channel = null;
        if (c != null) _client.removeChannel(c);
      },
    );
    return controller.stream;
  }

  @override
  Future<void> markRead(List<String> ids) async {
    try {
      for (final id in ids) {
        await _client
            .rpc('ml_notification_mark', params: {'p_id': id, 'p_action': 'read'})
            .timeout(timeout);
      }
    } catch (error) {
      throw AuthError(failureOf(error), error);
    }
  }
}
