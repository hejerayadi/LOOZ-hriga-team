// The regional alerts in the database (migrations 013, 014 and 015): frost,
// heat, drought... written by the admins in the dashboard, in Arabic AND
// French, for some governorates.
//
// The app only uses the functions of migration 015. The database decides
// which alerts the farmer sees (active, of his governorate; a demo alert
// only for a demo account) and keeps "Moi aussi", "opened" and "done".
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'auth_service.dart';

/// The kinds of alerts (regional_alerts.kind).
enum AlertKind { frost, heat, drought, disease, pest, wind, rain }

/// How serious an alert is (regional_alerts.severity).
enum AlertSeverity { info, warning, danger }

class RegionalAlert {
  const RegionalAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.titleAr,
    required this.titleFr,
    required this.bodyAr,
    required this.bodyFr,
    required this.startsAt,
    required this.updatedAt,
    this.adviceAr,
    this.adviceFr,
    this.endsAt,
    this.seenCount = 0,
    this.meToo = false,
    this.isNew = true,
    this.done = false,
  });

  final String id;
  final AlertKind kind;
  final AlertSeverity severity;
  final String titleAr;
  final String titleFr;
  final String bodyAr;
  final String bodyFr;

  /// What to do, one step per line (null = no advice).
  final String? adviceAr;
  final String? adviceFr;
  final DateTime startsAt;

  /// null = until an admin ends it.
  final DateTime? endsAt;

  /// The last change by an admin (a change makes it new again).
  final DateTime updatedAt;

  /// How many said "أنا أيضًا / Moi aussi".
  final int seenCount;

  /// The farmer said "Moi aussi".
  final bool meToo;

  /// Not opened yet (or changed since).
  final bool isNew;

  /// The farmer tapped "تمّ / Fait".
  final bool done;

  /// Counts in the badge of the tab: new and not done.
  bool get unread => isNew && !done;

  String title(String language) => language == 'fr' ? titleFr : titleAr;
  String body(String language) => language == 'fr' ? bodyFr : bodyAr;

  /// The steps of "ماذا أفعل؟" (empty = no advice): one per line; a single
  /// line with several sentences is cut after each sentence.
  List<String> adviceSteps(String language) {
    final advice = (language == 'fr' ? adviceFr : adviceAr) ?? '';
    var steps = [
      for (final line in advice.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (steps.length == 1) {
      steps = [
        for (final part in steps.first.split(RegExp(r'(?<=[.!?؟؛])\s+')))
          if (part.trim().isNotEmpty) part.trim(),
      ];
    }
    return steps;
  }

  bool get hasAdvice => (adviceAr ?? '').trim().isNotEmpty;

  static RegionalAlert fromRow(Map<String, dynamic> row) => RegionalAlert(
    id: row['id'] as String,
    kind: AlertKind.values.firstWhere(
      (k) => k.name == row['kind'],
      orElse: () => AlertKind.drought,
    ),
    severity: AlertSeverity.values.firstWhere(
      (s) => s.name == row['severity'],
      orElse: () => AlertSeverity.info,
    ),
    titleAr: row['title_ar'] as String,
    titleFr: row['title_fr'] as String,
    bodyAr: row['body_ar'] as String,
    bodyFr: row['body_fr'] as String,
    adviceAr: row['advice_ar'] as String?,
    adviceFr: row['advice_fr'] as String?,
    startsAt: DateTime.parse(row['starts_at'] as String),
    endsAt: row['ends_at'] == null
        ? null
        : DateTime.parse(row['ends_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    seenCount: (row['seen_count'] as num?)?.toInt() ?? 0,
    meToo: row['me_too'] as bool? ?? false,
    isNew: row['is_new'] as bool? ?? true,
    done: row['done'] as bool? ?? false,
  );

  RegionalAlert copyWith({
    int? seenCount,
    bool? meToo,
    bool? isNew,
    bool? done,
  }) => RegionalAlert(
    id: id,
    kind: kind,
    severity: severity,
    titleAr: titleAr,
    titleFr: titleFr,
    bodyAr: bodyAr,
    bodyFr: bodyFr,
    adviceAr: adviceAr,
    adviceFr: adviceFr,
    startsAt: startsAt,
    endsAt: endsAt,
    updatedAt: updatedAt,
    seenCount: seenCount ?? this.seenCount,
    meToo: meToo ?? this.meToo,
    isNew: isNew ?? this.isNew,
    done: done ?? this.done,
  );
}

/// Why a call failed (each one has a message in Arabic and French).
enum AlertsFailure {
  noInternet,
  gone, // ended by an admin (or not for this farmer any more)
  sessionExpired,
  unknown,
}

class AlertsError implements Exception {
  const AlertsError(this.failure, [this.cause]);

  final AlertsFailure failure;
  final Object? cause;

  @override
  String toString() => 'AlertsError(${failure.name}, $cause)';
}

/// What the app needs. The app uses SupabaseAlertsService; the tests use a
/// fake one (no internet needed).
abstract class AlertsService {
  /// The alerts of the farmer's governorate: not done first, then the most
  /// serious, then the newest (the database sorts them).
  Future<List<RegionalAlert>> loadAlerts();

  /// The farmer opened the alert.
  Future<void> markRead(String alertId);

  /// "تمّ / Fait" (true) or taken back (false).
  Future<void> setDone(String alertId, bool done);

  /// "أنا أيضًا / Moi aussi" (true) or taken back (false): the new count.
  Future<int> setMeToo(String alertId, bool on);
}

AlertsService? _alertsService;

/// The alerts: Supabase in the app (the tests put a fake one).
AlertsService get alertsService =>
    _alertsService ??= SupabaseAlertsService(supabase);
set alertsService(AlertsService service) => _alertsService = service;

class SupabaseAlertsService implements AlertsService {
  SupabaseAlertsService(this._client);

  final SupabaseClient _client;

  /// Longest wait for an answer of the server.
  static const timeout = Duration(seconds: 20);

  @override
  Future<List<RegionalAlert>> loadAlerts() => _run(() async {
    final rows = await _client.rpc('my_regional_alerts') as List<dynamic>;
    return [
      for (final row in rows)
        RegionalAlert.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  });

  @override
  Future<void> markRead(String alertId) => _run(
    () => _client.rpc(
      'regional_alert_mark',
      params: {'p_alert': alertId, 'p_state': 'read'},
    ),
  );

  @override
  Future<void> setDone(String alertId, bool done) => _run(
    () => _client.rpc(
      'regional_alert_mark',
      params: {'p_alert': alertId, 'p_state': done ? 'done' : 'undone'},
    ),
  );

  @override
  Future<int> setMeToo(String alertId, bool on) => _run(() async {
    final count = await _client.rpc(
      'regional_alert_me_too',
      params: {'p_alert': alertId, 'p_on': on},
    );
    return (count as num).toInt();
  });

  /// Too slow = no internet, and every error becomes an AlertsError.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } catch (error) {
      throw AlertsError(alertsFailureOf(error), error);
    }
  }
}

/// Turns an error of Supabase into an AlertsFailure.
AlertsFailure alertsFailureOf(Object error) {
  if (error is AlertsError) return error.failure;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == 'P0002') return AlertsFailure.gone; // ended, other governorate
    if (code.startsWith('PGRST30')) return AlertsFailure.sessionExpired;
    if (code == '42501' && error.message.contains('Not logged in')) {
      return AlertsFailure.sessionExpired;
    }
    return AlertsFailure.unknown;
  }
  switch (failureOf(error)) {
    case AuthFailure.noInternet:
      return AlertsFailure.noInternet;
    case AuthFailure.sessionExpired:
      return AlertsFailure.sessionExpired;
    default:
      return AlertsFailure.unknown;
  }
}
