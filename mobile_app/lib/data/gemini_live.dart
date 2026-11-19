// The conversation with Google (Gemini Live API, WebSocket): the messages the
// app sends and the ones it receives. The app connects with the short-lived
// token of "voice-token" (voice_service.dart): the model, the instructions
// and the tools of "لوز" are locked inside the token, so the "setup" sent
// here is ignored by Google (only the model name is sent).
//
// Sound: the microphone goes as 16-bit PCM at 16 kHz, the voice of "لوز"
// comes as 16-bit PCM at 24 kHz (both little-endian, mono).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// The address of Gemini Live for a short-lived token.
Uri liveUri(String token) => Uri(
  scheme: 'wss',
  host: 'generativelanguage.googleapis.com',
  path: '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained',
  queryParameters: {'access_token': token},
);

/// The sample rate of the microphone sent to Google.
const micSampleRate = 16000;

/// The sample rate of the voice of "لوز".
const voiceSampleRate = 24000;

// ---------------------------------------------------------------------
// The messages the app sends
// ---------------------------------------------------------------------

/// The first message (the rest of the setup is in the token).
String setupMessage(String model) => jsonEncode({
  'setup': {'model': 'models/$model'},
});

/// A piece of the microphone.
String audioMessage(Uint8List pcm) => jsonEncode({
  'realtimeInput': {
    'audio': {
      'data': base64Encode(pcm),
      'mimeType': 'audio/pcm;rate=$micSampleRate',
    },
  },
});

/// The microphone is paused (while "لوز" speaks).
String audioEndMessage() => jsonEncode({
  'realtimeInput': {'audioStreamEnd': true},
});

/// A typed question (the live test; the screen uses the voice).
String textMessage(String text) => jsonEncode({
  'realtimeInput': {'text': text},
});

/// The answers of the tools, matched by the id of each call.
String toolResponseMessage(List<LiveToolResult> results) => jsonEncode({
  'toolResponse': {
    'functionResponses': [
      for (final r in results)
        {'id': r.id, 'name': r.name, 'response': r.response},
    ],
  },
});

class LiveToolCall {
  const LiveToolCall(this.id, this.name, this.args);

  final String id;
  final String name;
  final Map<String, Object?> args;
}

class LiveToolResult {
  const LiveToolResult(this.id, this.name, this.response);

  final String id;
  final String name;
  final Map<String, Object?> response;
}

// ---------------------------------------------------------------------
// The messages the app receives
// ---------------------------------------------------------------------
sealed class LiveEvent {
  const LiveEvent();
}

/// Google accepted the setup: the microphone can start.
class LiveReady extends LiveEvent {
  const LiveReady();
}

/// A piece of the voice of "لوز" (24 kHz PCM).
class LiveAudio extends LiveEvent {
  const LiveAudio(this.pcm);

  final Uint8List pcm;
}

/// A piece of what the farmer said (transcription).
class LiveHeard extends LiveEvent {
  const LiveHeard(this.text);

  final String text;
}

/// A piece of what "لوز" said (transcription).
class LiveSaid extends LiveEvent {
  const LiveSaid(this.text);

  final String text;
}

/// "لوز" wants data: run the tools, send their answers.
class LiveToolCalls extends LiveEvent {
  const LiveToolCalls(this.calls);

  final List<LiveToolCall> calls;
}

/// Tool calls not needed any more.
class LiveToolCancel extends LiveEvent {
  const LiveToolCancel(this.ids);

  final List<String> ids;
}

/// The farmer spoke while "لوز" was speaking: stop its voice now.
class LiveInterrupted extends LiveEvent {
  const LiveInterrupted();
}

/// "لوز" finished its answer.
class LiveTurnDone extends LiveEvent {
  const LiveTurnDone();
}

/// The tokens Google counted for this answer.
class LiveUsage extends LiveEvent {
  const LiveUsage(this.input, this.output);

  final int input;
  final int output;
}

/// Google will close the connection soon.
class LiveGoAway extends LiveEvent {
  const LiveGoAway();
}

/// One message of Google -> its events, in order (a message may hold
/// several: a piece of voice and its text). Unknown parts are ignored.
List<LiveEvent> parseLiveMessage(Object? raw) {
  final Object? decoded;
  try {
    final text = raw is String
        ? raw
        : raw is List<int>
        ? utf8.decode(raw)
        : null;
    if (text == null) return const [];
    decoded = jsonDecode(text);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map) return const [];
  final m = decoded;
  final events = <LiveEvent>[];
  if (m['setupComplete'] != null) events.add(const LiveReady());

  final toolCall = m['toolCall'];
  if (toolCall is Map) {
    final calls = <LiveToolCall>[];
    for (final c in (toolCall['functionCalls'] as List? ?? const [])) {
      if (c is Map && c['name'] is String) {
        final args = c['args'];
        calls.add(
          LiveToolCall(
            '${c['id'] ?? ''}',
            c['name'] as String,
            args is Map ? Map<String, Object?>.from(args) : const {},
          ),
        );
      }
    }
    if (calls.isNotEmpty) events.add(LiveToolCalls(calls));
  }
  final cancel = m['toolCallCancellation'];
  if (cancel is Map) {
    events.add(
      LiveToolCancel([
        for (final id in cancel['ids'] as List? ?? const []) '$id',
      ]),
    );
  }

  // The tokens of this answer (before its end, so they count for it).
  final counts = m['usageMetadata'];
  LiveUsage? usage;
  if (counts is Map) {
    int n(String key) => (counts[key] as num?)?.toInt() ?? 0;
    usage = LiveUsage(
      n('promptTokenCount') + n('toolUsePromptTokenCount'),
      n('responseTokenCount') + n('thoughtsTokenCount'),
    );
  }

  final content = m['serverContent'];
  if (content is Map) {
    final heard = _text(content['inputTranscription']);
    if (heard != null) events.add(LiveHeard(heard));
    final turn = content['modelTurn'];
    if (turn is Map) {
      for (final part in (turn['parts'] as List? ?? const [])) {
        final inline = part is Map ? part['inlineData'] : null;
        if (inline is Map &&
            '${inline['mimeType']}'.startsWith('audio/pcm') &&
            inline['data'] is String) {
          try {
            events.add(LiveAudio(base64Decode(inline['data'] as String)));
          } on FormatException {
            // A broken piece is skipped.
          }
        }
      }
    }
    final said = _text(content['outputTranscription']);
    if (said != null) events.add(LiveSaid(said));
    if (content['interrupted'] == true) events.add(const LiveInterrupted());
    if (content['turnComplete'] == true) {
      if (usage != null) events.add(usage);
      events.add(const LiveTurnDone());
    }
  }

  if (usage != null && !events.contains(usage)) events.add(usage);
  if (m['goAway'] != null) events.add(const LiveGoAway());
  return events;
}

String? _text(Object? transcription) {
  if (transcription is! Map) return null;
  final text = transcription['text'];
  return text is String && text.isNotEmpty ? text : null;
}

// ---------------------------------------------------------------------
// The connection
// ---------------------------------------------------------------------
abstract class LiveChannel {
  /// The messages of Google (text or bytes). Ends when the connection closes.
  Stream<Object?> get messages;

  void send(String message);

  Future<void> close();
}

/// Opens the connection (the tests put a fake one).
typedef LiveConnector = Future<LiveChannel> Function(Uri uri);

Future<LiveChannel> connectLive(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready.timeout(const Duration(seconds: 15));
  return _WebSocketLive(channel);
}

class _WebSocketLive implements LiveChannel {
  _WebSocketLive(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();
}
