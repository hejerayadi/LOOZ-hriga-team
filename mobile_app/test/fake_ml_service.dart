// A fake of the live orchard (readings, predictions, notifications) for the
// tests (no internet): the demo orchard of fake_orchard_service.dart, zone A
// fine, zone B short of water (a Groq text), zone C sensor offline... and a
// fake "Supabase Realtime" (push()).
import 'dart:async';

import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/ml_service.dart';

final _now = DateTime.now().toUtc();

MlPrediction prediction(
  String node,
  String model,
  String? state, {
  String status = 'ok',
  bool likely = true,
  String? textAr,
  String? textFr,
  String? actionAr,
  String? actionFr,
  List<MlFactor> factors = const [
    MlFactor(code: 'soil_water', level: 'low', share: 0.6),
    MlFactor(code: 'air_dryness', level: 'high', share: 0.4),
  ],
}) => MlPrediction(
  nodeId: node,
  zoneId: 'zone-${node.substring(5).toLowerCase()}',
  model: model,
  status: status,
  state: state,
  confidence: likely ? 0.9 : 0.5,
  likely: likely,
  factors: status == 'ok' ? factors : const [],
  explanationAr: textAr,
  explanationFr: textFr,
  actionAr: actionAr,
  actionFr: actionFr,
  measuredAt: _now.subtract(const Duration(minutes: 5)),
  predictedAt: _now.subtract(const Duration(minutes: 5)),
);

NodeLive nodeLive(String node, {String status = 'online'}) => NodeLive(
  nodeId: node,
  zoneId: 'zone-${node.substring(5).toLowerCase()}',
  status: status,
  measuredAt: _now.subtract(const Duration(minutes: 5)),
  receivedAt: _now.subtract(const Duration(minutes: 5)),
  soilMoisture: 14.6,
  soilTemp: 24.4,
  airTemp: 33.2,
  humidity: 41,
);

MlNotification notification(
  String id,
  String node,
  String model,
  String state, {
  bool danger = false,
  bool read = false,
  bool resolved = false,
  int minutesAgo = 3,
}) => MlNotification(
  id: id,
  nodeId: node,
  zoneId: 'zone-${node.substring(5).toLowerCase()}',
  zoneLetter: node.substring(5),
  model: model,
  state: state,
  danger: danger,
  read: read,
  resolved: resolved,
  createdAt: _now.subtract(Duration(minutes: minutesAgo)),
);

/// The demo orchard: A fine, B water deficit (with Groq texts), C offline.
OrchardLive sampleLive({List<MlNotification>? notifications}) => OrchardLive(
  nodes: {
    'node-A': nodeLive('node-A'),
    'node-B': nodeLive('node-B'),
    'node-C': nodeLive('node-C', status: 'offline'),
  },
  predictions: {
    'node-A': {
      'frost': prediction('node-A', 'frost', 'no_frost'),
      'stress': prediction(
        'node-A',
        'stress',
        'none',
        factors: const [MlFactor(code: 'soil_water', level: 'high', share: 1)],
      ),
    },
    'node-B': {
      'frost': prediction('node-B', 'frost', 'no_frost'),
      'stress': prediction(
        'node-B',
        'stress',
        'water_deficit',
        textAr: 'الشجر في المنطقة ب عطشان. التربة ناشفة.',
        textFr: 'Les arbres de la Zone B ont soif. Le sol est sec.',
        actionAr: 'شوف خط السقي واسقي الشجر.',
        actionFr: "Vérifiez l'irrigation et arrosez.",
      ),
    },
  },
  notifications:
      notifications ??
      [notification('n-1', 'node-B', 'stress', 'water_deficit')],
);

class FakeMlService implements MlService {
  FakeMlService([OrchardLive? live]) : live = live ?? sampleLive();

  OrchardLive live;

  /// The next load fails with this error (once).
  AuthFailure? failNext;
  int loads = 0;
  final List<String> marked = [];
  final StreamController<void> _realtime = StreamController<void>.broadcast();

  /// Is the app listening to "Realtime"?
  bool get listening => _realtime.hasListener;

  /// A change in the database: the app is told at once (Realtime).
  void push(OrchardLive next) {
    live = next;
    _realtime.add(null);
  }

  @override
  Future<OrchardLive> load() async {
    loads++;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw AuthError(failure);
    }
    return live;
  }

  @override
  Stream<void> changes() => _realtime.stream;

  /// Like the database: the notification is read from now on.
  @override
  Future<void> markRead(List<String> ids) async {
    marked.addAll(ids);
    live = live.copyWith(
      notifications: [
        for (final n in live.notifications)
          ids.contains(n.id) ? n.copyWith(read: true) : n,
      ],
    );
  }
}
