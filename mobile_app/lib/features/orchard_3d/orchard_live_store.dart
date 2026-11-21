// The live state of the orchard (readings, predictions, notifications) in ONE
// place: the 3D, the zone panel, the "بستاني" part of the alerts tab, the
// number on the bell and the in-app notifications all read it here.
//
// Paid farmers only (decision: only paid farmers see the ML predictions).
// Loaded when the app opens, at each signal of Supabase Realtime (a new
// reading or prediction), every minute while the app is open (in case
// Realtime is not there), when the farmer comes back to the app.
//
// In-app notifications (no push): a NEW problem (not seen in an earlier
// loading of this session) shows a banner at the top of the app, once.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/plans.dart';
import '../../core/session.dart';
import '../../data/ml_service.dart';

class OrchardLiveState {
  const OrchardLiveState({this.live, this.failed = false});

  /// null = not loaded yet.
  final OrchardLive? live;

  /// The last loading failed (the old state, if any, is kept).
  final bool failed;
}

final ValueNotifier<OrchardLiveState> orchardLive = ValueNotifier(
  const OrchardLiveState(),
);

/// A new problem to show as a banner (the shell listens).
final ValueNotifier<MlNotification?> mlBanner = ValueNotifier(null);

/// The 3D must show (and open the panel of) this zone: set by a tap on an
/// alert card or a banner.
final ValueNotifier<String?> focusZone = ValueNotifier(null);

Future<void>? _loading;
String? _loadedFor;
var _generation = 0;
StreamSubscription<void>? _changes;
Timer? _debounce;

/// Notifications already known in this session (no banner for them).
final Set<String> _known = {};
bool _firstLoad = true;

bool get _allowed => canUse(Feature.aiPredictions) && currentUser.value != null;

/// Loads again (one loading at a time).
Future<void> refreshOrchardLive() =>
    _loading ??= _load().whenComplete(() => _loading = null);

Future<void> _load() async {
  final user = currentUser.value;
  if (user == null || !canUse(Feature.aiPredictions)) return;
  if (_loadedFor != user.id) {
    // Another farmer logged in: never show the orchard of the last one.
    _resetData();
    _loadedFor = user.id;
  }
  final generation = _generation;
  try {
    final live = await mlService.load();
    if (generation != _generation || currentUser.value?.id != user.id) return;
    _announce(live);
    orchardLive.value = OrchardLiveState(live: live);
  } catch (_) {
    if (generation != _generation) return;
    orchardLive.value = OrchardLiveState(
      live: orchardLive.value.live,
      failed: true,
    );
  }
}

/// A banner for each problem that appeared since the last loading (never
/// for the ones there when the app opened: they are in the alerts tab).
void _announce(OrchardLive live) {
  final fresh = [
    for (final n in live.notifications)
      if (!_known.contains(n.id) && n.unread) n,
  ];
  _known.addAll(live.notifications.map((n) => n.id));
  if (_firstLoad) {
    _firstLoad = false;
    return;
  }
  if (fresh.isEmpty) return;
  // The most serious first (frost risk), then the newest.
  fresh.sort((a, b) {
    if (a.danger != b.danger) return a.danger ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  mlBanner.value = fresh.first;
}

/// Starts listening to Supabase Realtime (paid farmers), and loads.
void watchOrchardLive() {
  if (!_allowed) return;
  _changes ??= mlService.changes().listen((_) {
    // Several rows change together (4 boxes, 2 models): read once.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), refreshOrchardLive);
  }, onError: (Object _) {});
  refreshOrchardLive();
}

/// Stops Realtime (the app is hidden, or logged out).
void stopOrchardLive() {
  _debounce?.cancel();
  _debounce = null;
  _changes?.cancel();
  _changes = null;
}

/// The farmer saw these notifications (the alerts tab, a banner, the panel).
Future<void> markMlRead(Iterable<String> ids) async {
  final live = orchardLive.value.live;
  final todo = [
    for (final n in live?.notifications ?? const <MlNotification>[])
      if (ids.contains(n.id) && !n.read) n.id,
  ];
  if (live == null || todo.isEmpty) return;
  orchardLive.value = OrchardLiveState(
    live: live.copyWith(
      notifications: [
        for (final n in live.notifications)
          todo.contains(n.id) ? n.copyWith(read: true) : n,
      ],
    ),
  );
  try {
    await mlService.markRead(todo);
  } catch (_) {
    // Not saved (no internet): it will be read again later.
  }
}

/// After the log out (and in the tests).
void clearOrchardLive() {
  stopOrchardLive();
  _generation++;
  _loading = null;
  _loadedFor = null;
  _resetData();
}

void _resetData() {
  _known.clear();
  _firstLoad = true;
  orchardLive.value = const OrchardLiveState();
  mlBanner.value = null;
  focusZone.value = null;
}
