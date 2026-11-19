// The microphone and the loudspeaker of the voice assistant "لوز".
// - The microphone: 16-bit PCM at 16 kHz, mono, with echo cancelling and
//   noise suppression (package record; Android and the browser).
// - The loudspeaker: the voice of "لوز" played while it arrives (16-bit PCM
//   at 24 kHz, package flutter_soloud; on web: the script in web/index.html).
// Nothing is recorded in a file: the sound only goes to Google and back.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'gemini_live.dart';

abstract class VoiceMic {
  /// Asks the phone / the browser (the first time). false = refused.
  Future<bool> allowed();

  /// The sound of the microphone, piece by piece.
  Future<Stream<Uint8List>> start();

  Future<void> stop();
}

abstract class VoiceSpeaker {
  Future<void> open();

  /// Plays a piece of the voice (after the pieces already given).
  void play(Uint8List pcm);

  /// Stops at once and forgets what was not played yet (the farmer speaks).
  Future<void> cut();

  Future<void> close();
}

/// The microphone and the loudspeaker of a conversation (the tests put fakes).
typedef VoiceDevices = ({VoiceMic mic, VoiceSpeaker speaker});

VoiceDevices realVoiceDevices() => (mic: RecordMic(), speaker: SoloudSpeaker());

class RecordMic implements VoiceMic {
  AudioRecorder? _recorder;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  @override
  Future<bool> allowed() => _rec.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _rec.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: micSampleRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
    ),
  );

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } finally {
      await recorder.dispose();
    }
  }
}

class SoloudSpeaker implements VoiceSpeaker {
  AudioSource? _stream;
  SoundHandle? _handle;

  SoLoud get _soloud => SoLoud.instance;

  @override
  Future<void> open() async {
    if (!_soloud.isInitialized) await _soloud.init();
    final stream = _soloud.setBufferStream(
      // Played pieces are freed; a short wait before playing a new answer.
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.25,
      sampleRate: voiceSampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    _stream = stream;
    _handle = _soloud.play(stream);
  }

  @override
  void play(Uint8List pcm) {
    final stream = _stream;
    if (stream != null && pcm.isNotEmpty) {
      _soloud.addAudioDataStream(stream, pcm);
    }
  }

  @override
  Future<void> cut() async {
    final stream = _stream;
    if (stream != null) _soloud.resetBufferStream(stream);
  }

  @override
  Future<void> close() async {
    final stream = _stream;
    final handle = _handle;
    _stream = null;
    _handle = null;
    if (handle != null) await _soloud.stop(handle);
    if (stream != null) await _soloud.disposeSource(stream);
  }
}
