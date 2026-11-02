import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/project_editor.dart';
import '../model/audio_item.dart';
import '../model/media_asset.dart';
import '../preview/preview_controller.dart';
import '../storage/project_store.dart';
import '../timeline/timeline_state.dart';
import 'voice_recorder.dart';

class RecordingState {
  const RecordingState({
    this.open = false,
    this.mics = const [],
    this.mic,
    this.hearVideo = false,
    this.recording = false,
    this.elapsed = Duration.zero,
    this.level = 0,
    this.error,
  });

  /// The record bar is showing.
  final bool open;
  final List<Mic> mics;

  /// Null means the system's default microphone.
  final Mic? mic;

  /// Play the video's sound while recording (use headphones, or it ends up
  /// in the recording).
  final bool hearVideo;
  final bool recording;
  final Duration elapsed;
  final double level;
  final String? error;

  RecordingState copyWith({
    bool? open,
    List<Mic>? mics,
    Mic? Function()? mic,
    bool? hearVideo,
    bool? recording,
    Duration? elapsed,
    double? level,
    String? Function()? error,
  }) => RecordingState(
    open: open ?? this.open,
    mics: mics ?? this.mics,
    mic: mic != null ? mic() : this.mic,
    hearVideo: hearVideo ?? this.hearVideo,
    recording: recording ?? this.recording,
    elapsed: elapsed ?? this.elapsed,
    level: level ?? this.level,
    error: error != null ? error() : this.error,
  );
}

final recordingProvider = NotifierProvider<RecordingController, RecordingState>(
  RecordingController.new,
);

/// Records a voiceover while the video plays from the playhead. When you
/// stop, the recording lands on the voiceover track where it started, as
/// one undo step.
class RecordingController extends Notifier<RecordingState> {
  Duration _startedAt = Duration.zero;
  String? _path;
  final _clock = Stopwatch();
  Timer? _tick;
  StreamSubscription<double>? _levels;

  @override
  RecordingState build() {
    ref.onDispose(() {
      _tick?.cancel();
      unawaited(_levels?.cancel());
    });
    return const RecordingState();
  }

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  Future<void> show() async {
    state = state.copyWith(open: true, error: () => null);
    try {
      final mics = await _recorder.microphones();
      state = state.copyWith(mics: mics);
    } on Object {
      // Listing can fail before permission is given; the default mic
      // still works.
    }
  }

  Future<void> hide() async {
    if (state.recording) await cancel();
    state = state.copyWith(open: false);
  }

  void pickMic(Mic? mic) => state = state.copyWith(mic: () => mic);

  void setHearVideo(bool hear) => state = state.copyWith(hearVideo: hear);

  Future<void> start() async {
    if (state.recording) return;
    final editor = ref.read(projectEditorProvider);
    final work = editor.workPath;
    if (editor.project.clips.isEmpty || work == null) {
      state = state.copyWith(error: () => 'Import a video first.');
      return;
    }
    if (!await _recorder.hasPermission()) {
      state = state.copyWith(
        error: () =>
            'Cutline isn\'t allowed to use the microphone. Allow it in '
            'System Settings → Privacy & Security → Microphone.',
      );
      return;
    }
    final preview = ref.read(previewProvider);
    _startedAt = preview.position;
    if (_startedAt >= editor.project.duration - minClipDuration) {
      _startedAt = Duration.zero;
      await preview.seek(Duration.zero);
    }
    final dir = Directory(p.join(work, ProjectStore.assetsDir))
      ..createSync(recursive: true);
    _path = p.join(dir.path, 'voiceover-${newId()}.wav');
    try {
      await _recorder.start(_path!, mic: state.mic);
    } on Object catch (e) {
      state = state.copyWith(error: () => 'Couldn\'t start recording: $e');
      return;
    }
    if (!state.hearVideo) await preview.setVolume(0);
    await preview.play();
    _clock
      ..reset()
      ..start();
    _tick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => state = state.copyWith(elapsed: _clock.elapsed),
    );
    _levels = _recorder.level.listen((l) => state = state.copyWith(level: l));
    state = state.copyWith(
      recording: true,
      elapsed: Duration.zero,
      error: () => null,
    );
  }

  /// Stops and puts the recording on the voiceover track.
  Future<void> stop() async {
    if (!state.recording) return;
    final elapsed = _clock.elapsed;
    final path = await _finish();
    if (path == null || !File(path).existsSync()) {
      state = state.copyWith(error: () => 'Nothing was recorded.');
      return;
    }
    final length = wavLength(File(path).readAsBytesSync()) ?? elapsed;
    if (length < minClipDuration) {
      File(path).deleteSync();
      return;
    }
    final editor = ref.read(projectEditorProvider);
    final work = editor.workPath!;
    final media = MediaAsset(
      id: newId(),
      path: p.relative(path, from: work).replaceAll(r'\', '/'),
      kind: MediaKind.audio,
      duration: length,
      hasAudio: true,
    );
    final id = newId();
    ref.read(projectEditorProvider.notifier).runAll('Record voiceover', [
      AddMedia(media),
      AddAudio(
        AudioItem(
          id: id,
          mediaId: media.id,
          role: AudioRole.voiceover,
          start: _startedAt,
          sourceStart: Duration.zero,
          sourceEnd: length,
        ),
      ),
    ]);
    ref.read(timelineUiProvider.notifier).selectAudio(id);
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    if (!state.recording) return;
    final path = await _finish(cancel: true);
    if (path != null && File(path).existsSync()) File(path).deleteSync();
  }

  Future<String?> _finish({bool cancel = false}) async {
    _tick?.cancel();
    await _levels?.cancel();
    _clock.stop();
    final preview = ref.read(previewProvider);
    await preview.pause();
    await preview.setVolume(
      ref.read(projectEditorProvider).project.mix.original,
    );
    String? path;
    if (cancel) {
      await _recorder.cancel();
      path = _path;
    } else {
      path = await _recorder.stop() ?? _path;
    }
    state = state.copyWith(recording: false, level: 0);
    return path;
  }
}

/// The length of a PCM WAV file from its header, or null if it isn't one.
Duration? wavLength(List<int> bytes) {
  if (bytes.length < 44) return null;
  final b = ByteData.sublistView(Uint8List.fromList(bytes));
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  int? byteRate;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    var size = b.getUint32(at + 4, Endian.little);
    if (id == 'fmt ') byteRate = b.getUint32(at + 16, Endian.little);
    if (id == 'data') {
      if (byteRate == null || byteRate == 0) return null;
      // A recorder that was stopped hard may leave the size unset.
      final available = bytes.length - at - 8;
      if (size == 0 || size > available) size = available;
      return Duration(microseconds: size * 1000000 ~/ byteRate);
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  return null;
}
