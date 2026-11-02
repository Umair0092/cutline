import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// A microphone.
class Mic {
  const Mic(this.id, this.label);

  final String id;
  final String label;
}

/// Records from a microphone to a WAV file. Tests swap in a fake.
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<List<Mic>> microphones();
  Future<void> start(String path, {Mic? mic});

  /// Stops and returns the file, or null if nothing was recorded.
  Future<String?> stop();
  Future<void> cancel();

  /// Input level, 0 (silence) to 1 (loudest), a few times a second.
  Stream<double> get level;
  Future<void> dispose();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final r = RecordVoiceRecorder();
  ref.onDispose(r.dispose);
  return r;
});

/// The real recorder, through the `record` package (macOS, Windows, iOS).
class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<List<Mic>> microphones() async => [
    for (final d in await _recorder.listInputDevices()) Mic(d.id, d.label),
  ];

  @override
  Future<void> start(String path, {Mic? mic}) => _recorder.start(
    RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 48000,
      numChannels: 1,
      device: mic == null ? null : InputDevice(id: mic.id, label: mic.label),
      // Keep the voice as it is; effects come later (#16).
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<double> get level => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      // dBFS: -60 or quieter is silence, 0 is the loudest.
      .map((a) => ((a.current + 60) / 60).clamp(0.0, 1.0));

  @override
  Future<void> dispose() => _recorder.dispose();
}
