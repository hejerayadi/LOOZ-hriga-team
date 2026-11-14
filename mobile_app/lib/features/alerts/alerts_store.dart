// The regional alerts of the logged-in farmer, in ONE place: the tab
// "التنبيهات", the number on its bell (the badge) and the card of Home all
// read them here.
//
// They are loaded again (refreshAlerts): when the app opens, every minute
// while it is open, when the farmer comes back to the app, when he opens
// the tab and when he pulls the list down (see MainShell in app.dart and
// AlertsPage). Nobody logged in = nothing is loaded.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/session.dart';
import '../../data/alerts_service.dart';

/// How often the alerts are loaded again while the app is open.
const alertsRefreshEvery = Duration(seconds: 60);

class AlertsState {
  const AlertsState({this.alerts, this.failure});

  /// null = not loaded yet.
  final List<RegionalAlert>? alerts;

  /// Why the last loading failed (the old list, if any, is kept).
  final AlertsFailure? failure;

  /// The number on the bell: new and not done.
  int get unreadCount => alerts?.where((a) => a.unread).length ?? 0;

  /// Not done yet (the subtitle of the tab).
  int get openCount => alerts?.where((a) => !a.done).length ?? 0;

  /// The most important alert not done (the list is sorted), for Home.
  RegionalAlert? get top {
    for (final alert in alerts ?? const <RegionalAlert>[]) {
      if (!alert.done) return alert;
    }
    return null;
  }
}

final ValueNotifier<AlertsState> regionalAlerts = ValueNotifier(
  const AlertsState(),
);

Future<void>? _loading;
String? _loadedFor;

/// Goes up at each clearAlerts(): a loading started before is then ignored.
var _generation = 0;

/// Loads the alerts again (one loading at a time).
Future<void> refreshAlerts() => _loading ??= _load().whenComplete(() {
  _loading = null;
});

Future<void> _load() async {
  final user = currentUser.value;
  if (user == null) return;
  if (_loadedFor != user.id) {
    // Another farmer logged in: never show the alerts of the last one.
    regionalAlerts.value = const AlertsState();
    _loadedFor = user.id;
  }
  final generation = _generation;
  bool stale() => generation != _generation || currentUser.value?.id != user.id;
  try {
    final alerts = await alertsService.loadAlerts();
    if (stale()) return;
    regionalAlerts.value = AlertsState(alerts: _sorted(alerts));
  } catch (error) {
    if (stale()) return;
    regionalAlerts.value = AlertsState(
      alerts: regionalAlerts.value.alerts,
      failure: alertsFailureOf(error),
    );
  }
}

/// Keeps a change made on the screen of an alert (opened, "Moi aussi",
/// done), without waiting for the next loading.
void updateAlert(RegionalAlert alert) {
  final alerts = regionalAlerts.value.alerts;
  if (alerts == null) return;
  regionalAlerts.value = AlertsState(
    alerts: _sorted([for (final a in alerts) a.id == alert.id ? alert : a]),
    failure: regionalAlerts.value.failure,
  );
}

/// The alert ended (or is not for this farmer any more).
void removeAlert(String id) {
  final alerts = regionalAlerts.value.alerts;
  if (alerts == null) return;
  regionalAlerts.value = AlertsState(
    alerts: [
      for (final a in alerts)
        if (a.id != id) a,
    ],
    failure: regionalAlerts.value.failure,
  );
}

/// After the log out (and in the tests).
void clearAlerts() {
  _generation++;
  _loading = null;
  regionalAlerts.value = const AlertsState();
  _loadedFor = null;
}

/// Like the database: not done first, then the most serious, then the newest.
List<RegionalAlert> _sorted(List<RegionalAlert> alerts) {
  final list = List.of(alerts);
  list.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final severity = b.severity.index.compareTo(a.severity.index);
    if (severity != 0) return severity;
    return b.startsAt.compareTo(a.startsAt);
  });
  return list;
}
