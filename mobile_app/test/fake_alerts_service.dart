// Fake regional alerts for the tests: kept in memory, with the same rules
// as the database (migration 015): "Moi aussi" once per user, an ended
// alert can't be opened, "تمّ" can be taken back. No internet needed.
import 'dart:async';

import 'package:looz_mobile/data/alerts_service.dart';

class FakeAlertsService implements AlertsService {
  /// No alert in the region.
  FakeAlertsService([List<RegionalAlert>? alerts]) : alerts = [...?alerts];

  /// 3 alerts of the region, in Arabic AND French (like the dashboard writes
  /// them): frost (danger, 2 steps, 3 said "Moi aussi", new), heat
  /// (warning, one sentence of advice, opened) and rain (info, no advice,
  /// no end date, new).
  factory FakeAlertsService.sample() =>
      FakeAlertsService([sampleFrost(), sampleHeat(), sampleRain()]);

  /// The alerts the farmer sees, in the order of the database.
  final List<RegionalAlert> alerts;

  /// Every call fails with "no internet".
  bool offline = false;

  /// The next call fails with this error (once).
  AlertsFailure? failNext;

  /// Not null = the next loading waits for it.
  Completer<void>? holdLoad;

  /// The methods called, in order (e.g. "meToo frost true").
  final List<String> calls = [];

  void _maybeFail() {
    if (offline) throw const AlertsError(AlertsFailure.noInternet);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw AlertsError(failure);
    }
  }

  int _index(String id) {
    final i = alerts.indexWhere((a) => a.id == id);
    if (i < 0) throw const AlertsError(AlertsFailure.gone);
    return i;
  }

  /// An admin ends the alert: it is gone from the list and can't be used.
  void end(String id) => alerts.removeWhere((a) => a.id == id);

  /// An admin publishes a new alert.
  void publish(RegionalAlert alert) => alerts.insert(0, alert);

  @override
  Future<List<RegionalAlert>> loadAlerts() async {
    calls.add('load');
    await holdLoad?.future;
    _maybeFail();
    return List.of(alerts);
  }

  @override
  Future<void> markRead(String alertId) async {
    calls.add('read $alertId');
    _maybeFail();
    final i = _index(alertId);
    alerts[i] = alerts[i].copyWith(isNew: false);
  }

  @override
  Future<void> setDone(String alertId, bool done) async {
    calls.add('done $alertId $done');
    _maybeFail();
    final i = _index(alertId);
    alerts[i] = alerts[i].copyWith(done: done, isNew: false);
  }

  @override
  Future<int> setMeToo(String alertId, bool on) async {
    calls.add('meToo $alertId $on');
    _maybeFail();
    final i = _index(alertId);
    final a = alerts[i];
    final count = a.seenCount + (on == a.meToo ? 0 : (on ? 1 : -1));
    alerts[i] = a.copyWith(meToo: on, seenCount: count, isNew: false);
    return count;
  }
}

final _now = DateTime.now();

RegionalAlert sampleFrost() => RegionalAlert(
  id: 'frost',
  kind: AlertKind.frost,
  severity: AlertSeverity.danger,
  titleAr: 'صقيع الليلة',
  titleFr: 'Gel cette nuit',
  bodyAr: 'برد شديد بعد منتصف الليل. الأزهار والأشجار الصغيرة في خطر.',
  bodyFr: 'Froid fort après minuit. Les fleurs et les jeunes arbres sont en danger.',
  adviceAr: 'غطّ الأشجار الصغيرة\nاسقِ قبل الليل',
  adviceFr: 'Couvrez les jeunes arbres\nArrosez avant la nuit',
  startsAt: _now.subtract(const Duration(hours: 1)),
  endsAt: DateTime(2026, 11, 16, 8),
  updatedAt: _now.subtract(const Duration(hours: 1)),
  seenCount: 3,
);

RegionalAlert sampleHeat() => RegionalAlert(
  id: 'heat',
  kind: AlertKind.heat,
  severity: AlertSeverity.warning,
  titleAr: 'موجة حرّ',
  titleFr: 'Vague de chaleur',
  bodyAr: 'حرارة فوق 38 درجة لثلاثة أيام.',
  bodyFr: 'Plus de 38 degrés pendant trois jours.',
  adviceAr: 'اسقِ في الصباح الباكر. لا تسقِ في الظهر.',
  adviceFr: "Arrosez tôt le matin. N'arrosez pas à midi.",
  startsAt: _now.subtract(const Duration(days: 1)),
  endsAt: DateTime(2026, 11, 18, 20),
  updatedAt: _now.subtract(const Duration(days: 1)),
  isNew: false,
);

RegionalAlert sampleRain() => RegionalAlert(
  id: 'rain',
  kind: AlertKind.rain,
  severity: AlertSeverity.info,
  titleAr: 'أمطار غزيرة غدًا',
  titleFr: 'Fortes pluies demain',
  bodyAr: 'لا تسقِ غدًا: المطر يكفي.',
  bodyFr: "N'arrosez pas demain : la pluie suffit.",
  startsAt: _now.subtract(const Duration(hours: 3)),
  updatedAt: _now.subtract(const Duration(hours: 3)),
  seenCount: 12,
);
