// One conversation with the voice assistant "لوز" (Bêta, paid pack): the
// steps the screen shows, and what happens between the microphone, Google
// (gemini_live.dart), the loudspeaker and the tools.
//
//   checking -> consent (first time) -> ready -> connecting -> listening
//   <-> thinking (a tool runs) <-> speaking -> ended / failed
//
// The microphone is PAUSED while "لوز" speaks (it must not hear itself in the
// loudspeaker); a tap on the orb stops its voice and listens again.
// Nothing is saved: the texts stay on the screen only; the database keeps
// the times and the counts (voice_end).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/gemini_live.dart';
import '../../data/voice_audio.dart';
import '../../data/voice_service.dart';
import '../../data/voice_tools.dart';

enum VoiceStage {
  checking, // the quota is loading
  consent, // the first-time message
  ready, // the big microphone: "اضغط وقل سؤالك"
  connecting, // "لحظة…"
  listening, // "يسمع…"
  thinking, // a tool runs / waiting for the answer: "يفكّر…"
  speaking, // "يحكي…"
  ended, // "انتهت المحادثة"
  failed, // a message (VoiceSession.failure)
}

/// A line of the conversation on the screen (never saved).
class VoiceLine {
  VoiceLine({required this.fromFarmer, this.text = ''});

  final bool fromFarmer;
  String text;
}

/// How the conversations reach Google, and the microphone / loudspeaker
/// (the tests put fakes).
LiveConnector liveConnector = connectLive;
VoiceDevices Function() voiceDevices = realVoiceDevices;

/// The voice played per byte: 24 000 samples of 2 bytes each second.
Duration voiceLength(int bytes) =>
    Duration(microseconds: bytes * 1000000 ~/ (voiceSampleRate * 2));

class VoiceSession extends ChangeNotifier {
  VoiceSession({
    VoiceService? service,
    VoiceTools? tools,
    LiveConnector? connect,
    VoiceDevices Function()? devices,
    required this.language,
  }) : _service = service ?? voiceService,
       _tools = tools ?? voiceTools,
       _connect = connect ?? liveConnector,
       _devices = devices ?? voiceDevices;

  final VoiceService _service;
  final VoiceTools _tools;
  final LiveConnector _connect;
  final VoiceDevices Function() _devices;

  /// The language of the app ('ar' or 'fr'): Google is told.
  final String Function() language;

  /// The time to wait for Google's "ready".
  static const readyTimeout = Duration(seconds: 15);

  /// The loudspeaker starts a moment after the first piece of an answer
  /// (it buffers): the microphone waits this much more after its end, so
  /// it never hears the last words of "لوز".
  static const playbackMargin = Duration(milliseconds: 500);

  VoiceStage stage = VoiceStage.checking;
  VoiceFailure? failure;
  VoiceQuota? quota;

  /// Seconds left today (null = not known yet).
  int? leftToday;

  /// Seconds left in this conversation.
  int secondsLeft = 0;

  /// The tool running ("get_my_orchard"), for "ينظر في بستانك…".
  String? lookingAt;

  final List<VoiceLine> lines = [];

  VoiceTicket? _ticket;
  VoiceDevices? _io;
  LiveChannel? _channel;
  StreamSubscription<Object?>? _messages;
  StreamSubscription<Uint8List>? _mic;
  Timer? _clock;
  Timer? _player;
  Completer<void>? _ready;
  VoiceUsage _usage = VoiceUsage();
  int _turnIn = 0;
  int _turnOut = 0;
  bool _answered = false; // this turn had a voice or a text of "لوز"
  bool _turnDone = false;
  bool _micPaused = false;
  int _toolsRunning = 0;
  bool _ending = false;
  bool _disposed = false;

  /// Voice given to the loudspeaker and not played yet.
  Duration _toPlay = Duration.zero;

  /// A conversation is running (the stop button is shown).
  bool get talking => const {
    VoiceStage.connecting,
    VoiceStage.listening,
    VoiceStage.thinking,
    VoiceStage.speaking,
  }.contains(stage);

  /// The usage of the last conversation (for the tests).
  VoiceUsage get usage => _usage;

  void _set(VoiceStage next, {VoiceFailure? failure}) {
    stage = next;
    this.failure = failure;
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // -------------------------------------------------------------------
  // Before the conversation
  // -------------------------------------------------------------------

  /// Is it on, does he pay, did he say yes, minutes left.
  Future<void> load() async {
    _set(VoiceStage.checking);
    try {
      final q = await _service.loadQuota();
      quota = q;
      leftToday = q.leftSeconds;
      _set(_stageOf(q), failure: _failureOf(q));
    } on VoiceError catch (error) {
      _set(VoiceStage.failed, failure: error.failure);
    }
  }

  VoiceStage _stageOf(VoiceQuota q) {
    if (_failureOf(q) != null) return VoiceStage.failed;
    return q.consent ? VoiceStage.ready : VoiceStage.consent;
  }

  VoiceFailure? _failureOf(VoiceQuota q) {
    if (!q.paid) return VoiceFailure.notPaid;
    if (!q.enabled) return VoiceFailure.off;
    if (!q.consent) return null;
    if (!q.canTalk) return VoiceFailure.limitDay;
    if (!q.appOpen) return VoiceFailure.busy;
    return null;
  }

  /// "موافق" on the first-time message.
  Future<void> accept() async {
    _set(VoiceStage.checking);
    try {
      await _service.setConsent(true);
      await load();
    } on VoiceError catch (error) {
      _set(VoiceStage.failed, failure: error.failure);
    }
  }

  // -------------------------------------------------------------------
  // The conversation
  // -------------------------------------------------------------------

  /// The farmer taps the microphone.
  Future<void> start() async {
    if (talking || _ending) return;
    lines.clear();
    lookingAt = null;
    _usage = VoiceUsage();
    _set(VoiceStage.connecting);

    // 1. The loudspeaker first (the browser allows sound after a tap) and
    //    the microphone.
    final io = _io = _devices();
    try {
      if (!await io.mic.allowed()) {
        await _fail(VoiceFailure.micDenied);
        return;
      }
      await io.speaker.open();
    } catch (_) {
      await _fail(VoiceFailure.micDenied);
      return;
    }
    if (stage != VoiceStage.connecting) return; // stopped meanwhile

    // 2. The ticket: paid pack, "yes", minutes; Google's locked token.
    final VoiceTicket ticket;
    try {
      ticket = await _service.start(language());
    } on VoiceError catch (error) {
      if (stage != VoiceStage.connecting) return;
      if (error.failure == VoiceFailure.consent) {
        await _closeDevices();
        _set(VoiceStage.consent);
      } else {
        await _fail(error.failure);
      }
      return;
    }
    if (_disposed || stage != VoiceStage.connecting) {
      // Stopped while waiting: the conversation is closed at once.
      unawaited(_service.end(ticket.id, VoiceEndReason.farmer, _usage));
      return;
    }
    _ticket = ticket;
    secondsLeft = ticket.seconds;

    // 3. Google.
    try {
      final channel = await _connect(liveUri(ticket.token));
      if (_ticket != ticket) {
        unawaited(channel.close());
        return;
      }
      _channel = channel;
      final ready = _ready = Completer<void>();
      _messages = channel.messages.listen(
        _onMessage,
        onError: (_) => _lost(),
        onDone: _lost,
        cancelOnError: true,
      );
      channel.send(setupMessage(ticket.model));
      await ready.future.timeout(readyTimeout);
    } catch (_) {
      if (_ticket == ticket) {
        await _stopWith(VoiceEndReason.error, VoiceFailure.unavailable);
      }
      return;
    }
    if (_ticket != ticket) return;

    // 4. The microphone: its sound goes to Google while "لوز" listens.
    try {
      final sound = await io.mic.start();
      _mic = sound.listen((pcm) {
        if (stage == VoiceStage.listening) _channel?.send(audioMessage(pcm));
      });
    } catch (_) {
      await _stopWith(VoiceEndReason.error, VoiceFailure.micDenied);
      return;
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _player = Timer.periodic(const Duration(milliseconds: 100), (_) => _play());
    _listen();
  }

  void _listen() {
    _micPaused = false;
    lookingAt = null;
    _set(VoiceStage.listening);
  }

  /// The microphone is paused (Google is told: the end of what he said).
  void _pauseMic() {
    if (_micPaused) return;
    _micPaused = true;
    _channel?.send(audioEndMessage());
  }

  void _onMessage(Object? raw) {
    for (final event in parseLiveMessage(raw)) {
      if (!talking) return;
      switch (event) {
        case LiveReady():
          _ready?.complete();
        case LiveHeard(:final text):
          _addText(fromFarmer: true, text);
        case LiveSaid(:final text):
          _answered = true;
          _addText(fromFarmer: false, text);
        case LiveAudio(:final pcm):
          _answered = true;
          _turnDone = false;
          _pauseMic();
          _io?.speaker.play(pcm);
          if (stage != VoiceStage.speaking) _toPlay += playbackMargin;
          _toPlay += voiceLength(pcm.length);
          if (stage != VoiceStage.speaking) _set(VoiceStage.speaking);
        case LiveToolCalls(:final calls):
          _runTools(calls);
        case LiveToolCancel():
          break; // the tools only read: nothing to undo
        case LiveInterrupted():
          _io?.speaker.cut();
          _toPlay = Duration.zero;
          _listen();
        case LiveUsage(:final input, :final output):
          _turnIn = input;
          _turnOut = output;
        case LiveTurnDone():
          _turnDone = true;
          if (_answered) _usage.questions++;
          _answered = false;
          _usage.tokensIn = (_usage.tokensIn ?? 0) + _turnIn;
          _usage.tokensOut = (_usage.tokensOut ?? 0) + _turnOut;
          _turnIn = _turnOut = 0;
          if (stage != VoiceStage.speaking && _toolsRunning == 0) _listen();
        case LiveGoAway():
          break; // a conversation (3 minutes) ends long before
      }
    }
  }

  void _addText(String text, {required bool fromFarmer}) {
    final last = lines.isEmpty ? null : lines.last;
    if (last != null && last.fromFarmer == fromFarmer) {
      last.text += text;
    } else {
      lines.add(VoiceLine(fromFarmer: fromFarmer, text: text.trimLeft()));
    }
    _changed();
  }

  Future<void> _runTools(List<LiveToolCall> calls) async {
    _pauseMic();
    lookingAt = calls.first.name;
    _set(VoiceStage.thinking);
    _usage.toolCalls += calls.length;
    _toolsRunning++;
    final results = <LiveToolResult>[];
    try {
      for (final call in calls) {
        results.add(
          LiveToolResult(
            call.id,
            call.name,
            await _tools.run(call.name, call.args),
          ),
        );
      }
    } finally {
      _toolsRunning--;
    }
    if (talking) _channel?.send(toolResponseMessage(results));
  }

  /// Every 100 ms: the voice played; back to listening at its end.
  void _play() {
    if (_toPlay > Duration.zero) {
      _toPlay -= const Duration(milliseconds: 100);
      if (_toPlay < Duration.zero) _toPlay = Duration.zero;
    }
    if (stage == VoiceStage.speaking && _toPlay == Duration.zero && _turnDone) {
      _listen();
    }
  }

  /// Every second: the time left of the conversation.
  void _tick() {
    if (!talking) return;
    secondsLeft = secondsLeft > 0 ? secondsLeft - 1 : 0;
    if (secondsLeft == 0) {
      _stopWith(VoiceEndReason.timeUp, null);
    } else {
      _changed();
    }
  }

  /// A tap on the orb while "لوز" speaks: its voice stops, it listens.
  Future<void> interrupt() async {
    if (stage != VoiceStage.speaking) return;
    await _io?.speaker.cut();
    _toPlay = Duration.zero;
    _turnDone = true;
    _listen();
  }

  /// The stop button (or the screen closed, the app hidden).
  Future<void> stop() => _stopWith(VoiceEndReason.farmer, null);

  /// The connection closed by Google or the network.
  void _lost() {
    if (!talking || _ending) return;
    if (secondsLeft <= 1) {
      _stopWith(VoiceEndReason.timeUp, null);
    } else {
      _stopWith(VoiceEndReason.error, VoiceFailure.unavailable);
    }
  }

  Future<void> _fail(VoiceFailure failure) async {
    await _closeDevices();
    _set(VoiceStage.failed, failure: failure);
  }

  Future<void> _stopWith(VoiceEndReason reason, VoiceFailure? failure) async {
    if (_ending) return;
    _ending = true;
    final ticket = _ticket;
    _ticket = null;
    _toolsRunning = 0;
    // The tokens of an answer not finished yet count too.
    if (_turnIn + _turnOut > 0) {
      _usage.tokensIn = (_usage.tokensIn ?? 0) + _turnIn;
      _usage.tokensOut = (_usage.tokensOut ?? 0) + _turnOut;
      _turnIn = _turnOut = 0;
    }
    _clock?.cancel();
    _player?.cancel();
    _clock = _player = null;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(const VoiceError(VoiceFailure.unavailable));
      ready.future.ignore();
    }
    // (Not awaited: nothing to wait for, and the tests' clock never ends it.)
    unawaited(_messages?.cancel());
    _messages = null;
    final channel = _channel;
    _channel = null;
    await channel?.close().catchError((_) {});
    await _closeDevices();
    lookingAt = null;
    // The screen changes at once; the database is told after.
    _set(
      failure == null ? VoiceStage.ended : VoiceStage.failed,
      failure: failure,
    );
    if (ticket != null) {
      final left = await _service.end(ticket.id, reason, _usage);
      leftToday = left ?? ticket.leftSeconds;
      _changed();
    }
    _ending = false;
  }

  Future<void> _closeDevices() async {
    unawaited(_mic?.cancel());
    _mic = null;
    final io = _io;
    _io = null;
    if (io == null) return;
    try {
      await io.mic.stop();
    } catch (_) {}
    try {
      await io.speaker.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (talking) stop();
    _disposed = true;
    super.dispose();
  }
}
