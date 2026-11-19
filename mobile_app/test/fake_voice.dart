// Fakes of the voice assistant "لوز" for the tests (no internet, no Google,
// no microphone): the Edge Function, the tools, the connection to Gemini
// Live (the test plays Google's part) and the microphone / loudspeaker.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:looz_mobile/data/gemini_live.dart';
import 'package:looz_mobile/data/voice_audio.dart';
import 'package:looz_mobile/data/voice_service.dart';
import 'package:looz_mobile/data/voice_tools.dart';
import 'package:looz_mobile/features/ask/voice_session.dart';

class FakeVoiceService implements VoiceService {
  /// Paid, said yes, 5 minutes a day, all left, 3 minutes a conversation.
  VoiceQuota quota = const VoiceQuota(
    enabled: true,
    paid: true,
    consent: true,
    perDaySeconds: 300,
    leftSeconds: 300,
    sessionSeconds: 180,
    appOpen: true,
  );

  /// The next loadQuota / start fails with this (once).
  VoiceError? failQuota;
  VoiceError? failStart;

  /// The seconds left today answered by end().
  int? leftAfterEnd = 120;

  /// "quota", "consent true", "start ar", "end c1 farmer".
  final List<String> calls = [];

  /// The counts given to end().
  final List<VoiceUsage> ended = [];
  int _n = 0;

  @override
  Future<VoiceQuota> loadQuota() async {
    calls.add('quota');
    final fail = failQuota;
    if (fail != null) {
      failQuota = null;
      throw fail;
    }
    return quota;
  }

  @override
  Future<void> setConsent(bool yes) async {
    calls.add('consent $yes');
    quota = VoiceQuota(
      enabled: quota.enabled,
      paid: quota.paid,
      consent: yes,
      perDaySeconds: quota.perDaySeconds,
      leftSeconds: quota.leftSeconds,
      sessionSeconds: quota.sessionSeconds,
      appOpen: quota.appOpen,
      googleFreeTier: quota.googleFreeTier,
    );
  }

  @override
  Future<VoiceTicket> start(String language) async {
    calls.add('start $language');
    final fail = failStart;
    if (fail != null) {
      failStart = null;
      throw fail;
    }
    _n++;
    return VoiceTicket(
      id: 'c$_n',
      token: 'auth_tokens/test-$_n',
      model: 'gemini-3.8-live',
      seconds: quota.sessionSeconds,
      leftSeconds: quota.leftSeconds - quota.sessionSeconds,
    );
  }

  @override
  Future<int?> end(String id, VoiceEndReason reason, VoiceUsage usage) async {
    calls.add('end $id ${reason.code}');
    ended.add(usage);
    return leftAfterEnd;
  }
}

class FakeVoiceTools implements VoiceTools {
  /// The answer of get_my_orchard (2 zones).
  Map<String, Object?> orchard = {
    'zones': [
      {
        'zone_ar': 'المنطقة أ',
        'zone_fr': 'Zone A',
        'box': 'online',
        'minutes_since_reading': 12,
        'soil_moisture_pct': 31.0,
        'level': 'ok',
      },
      {
        'zone_ar': 'المنطقة ب',
        'zone_fr': 'Zone B',
        'box': 'online',
        'minutes_since_reading': 12,
        'soil_moisture_pct': 18.0,
        'level': 'watch',
        'reasons': ['water_stress'],
      },
    ],
  };

  /// "get_my_orchard".
  final List<String> calls = [];

  /// Not null = the tool waits for it (to see "ينظر في بستانك…").
  Completer<void>? hold;

  @override
  Future<Map<String, Object?>> run(
    String name,
    Map<String, Object?> args,
  ) async {
    calls.add(name);
    await hold?.future;
    return name == 'get_my_orchard' ? orchard : {'error': 'unknown_tool'};
  }
}

/// The test plays Google: what the app sent, and Google's messages.
class FakeLive {
  FakeLiveChannel? channel;

  /// The addresses the app connected to.
  final List<Uri> connected = [];

  /// Google answers "ready" to the setup (false = it never answers).
  bool answerSetup = true;

  /// The connection can't be opened.
  bool unreachable = false;

  Future<LiveChannel> connect(Uri uri) async {
    connected.add(uri);
    if (unreachable) throw StateError('no connection');
    return channel = FakeLiveChannel(this);
  }

  /// The messages the app sent (decoded).
  List<Map<String, dynamic>> get sent => [
    for (final m in channel?.sent ?? const <String>[])
      jsonDecode(m) as Map<String, dynamic>,
  ];

  /// Pieces of microphone sent to Google.
  int get audioSent =>
      sent.where((m) => (m['realtimeInput'] as Map?)?['audio'] != null).length;

  /// Google sends a message.
  void says(Map<String, Object?> message) =>
      channel!.incoming.add(jsonEncode(message));

  void heard(String text) => says({
    'serverContent': {
      'inputTranscription': {'text': text},
    },
  });

  void toolCall(String id, String name) => says({
    'toolCall': {
      'functionCalls': [
        {'id': id, 'name': name, 'args': <String, Object?>{}},
      ],
    },
  });

  /// [ms] milliseconds of the voice of "لوز" and its text.
  void answers(String text, {int ms = 1000}) => says({
    'serverContent': {
      'modelTurn': {
        'parts': [
          {
            'inlineData': {
              'mimeType': 'audio/pcm;rate=24000',
              'data': base64Encode(Uint8List(48 * ms)),
            },
          },
        ],
      },
      'outputTranscription': {'text': text},
    },
  });

  void turnDone({int input = 900, int output = 300}) => says({
    'serverContent': {'turnComplete': true},
    'usageMetadata': {'promptTokenCount': input, 'responseTokenCount': output},
  });

  void interrupted() => says({
    'serverContent': {'interrupted': true},
  });

  /// Google (or the network) closes the connection.
  void hangUp() => channel!.incoming.close();
}

class FakeLiveChannel implements LiveChannel {
  FakeLiveChannel(this._live);

  final FakeLive _live;
  final StreamController<Object?> incoming = StreamController<Object?>();
  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<Object?> get messages => incoming.stream;

  @override
  void send(String message) {
    sent.add(message);
    if (_live.answerSetup && message.startsWith('{"setup"')) {
      scheduleMicrotask(() => incoming.add('{"setupComplete":{}}'));
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!incoming.isClosed) unawaited(incoming.close());
  }
}

class FakeMic implements VoiceMic {
  bool allow = true;
  bool started = false;
  bool stopped = false;
  StreamController<Uint8List> sound = StreamController<Uint8List>();

  /// The farmer speaks: a piece of microphone (100 ms of 16 kHz).
  void speak() => sound.add(Uint8List(3200));

  @override
  Future<bool> allowed() async => allow;

  @override
  Future<Stream<Uint8List>> start() async {
    started = true;
    return sound.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    // (Not awaited: a stream nobody listened to never says "done".)
    unawaited(sound.close());
    sound = StreamController<Uint8List>();
  }
}

class FakeSpeaker implements VoiceSpeaker {
  bool opened = false;
  bool closed = false;
  int bytes = 0;
  int cuts = 0;

  @override
  Future<void> open() async => opened = true;

  @override
  void play(Uint8List pcm) => bytes += pcm.length;

  @override
  Future<void> cut() async => cuts++;

  @override
  Future<void> close() async => closed = true;
}

/// All the fakes of the voice assistant, put in place.
class FakeVoice {
  FakeVoice() {
    voiceService = service;
    voiceTools = tools;
    liveConnector = live.connect;
    voiceDevices = () => (mic: mic, speaker: speaker);
  }

  final service = FakeVoiceService();
  final tools = FakeVoiceTools();
  final live = FakeLive();
  final mic = FakeMic();
  final speaker = FakeSpeaker();
}
