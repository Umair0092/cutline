import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/preview_mix.dart';
import '../editing/project_editor.dart';
import '../media/ffmpeg.dart';
import '../media/edl.dart';

final previewProvider = Provider<PreviewController>((ref) {
  final controller = MpvPreviewController();
  ref.onDispose(controller.dispose);

  // Reload the player whenever the main track changes.
  String? lastEdl;
  void sync(EditorState state) {
    final edl = buildEdl(state.project, projectPath: state.workPath);
    if (edl == lastEdl) return;
    lastEdl = edl;
    unawaited(controller.load(edl));
  }

  // Voiceovers and other sounds are pre-mixed into one file a moment after
  // the last change, then played next to the video.
  Timer? mixTimer;
  var mixVersion = 0;
  void syncAudio(EditorState state) {
    unawaited(controller.setVolume(state.project.mix.original));
    mixTimer?.cancel();
    mixTimer = Timer(const Duration(milliseconds: 300), () async {
      final version = ++mixVersion;
      final ffmpeg = const FfmpegLocator().find();
      if (ffmpeg == null) return;
      final cache = p.join(
        (await getApplicationSupportDirectory()).path,
        'preview-cache',
        'mix',
      );
      final path = await renderPreviewMix(
        ffmpeg: ffmpeg,
        project: state.project,
        projectPath: state.workPath,
        cacheDir: cache,
      );
      if (version == mixVersion) await controller.setExtraAudio(path);
    });
  }

  ref.onDispose(() => mixTimer?.cancel());
  sync(ref.read(projectEditorProvider));
  syncAudio(ref.read(projectEditorProvider));
  ref.listen(projectEditorProvider, (prev, next) {
    sync(next);
    if (prev?.project != next.project || prev?.workPath != next.workPath) {
      syncAudio(next);
    }
  });
  return controller;
});

/// What the UI needs from the preview player. Tests swap in a fake.
abstract class PreviewController {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Duration get position;
  bool get isPlaying;

  Future<void> togglePlay();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration to);

  /// Volume of the video's own sound, 0..2 (1 is as recorded).
  Future<void> setVolume(double volume);
  Widget buildVideo();
}

/// The real preview, backed by mpv through media_kit. Plays the whole main
/// track as one video (see [buildEdl]), so its position is the timeline
/// position.
class MpvPreviewController implements PreviewController {
  MpvPreviewController() : player = Player() {
    _video = VideoController(player);
    // The extra sounds follow the video: play, pause and seek with it, and
    // get pulled back in line if they drift.
    _subs
      ..add(
        player.stream.playing.listen((playing) async {
          if (_extraPath == null) return;
          await _alignExtra(force: true);
          playing ? await extra.play() : await extra.pause();
        }),
      )
      ..add(player.stream.position.listen((_) => _alignExtra()));
  }

  final Player player;

  /// Plays the pre-mixed voiceovers and other sounds next to the video.
  final Player extra = Player(
    configuration: const PlayerConfiguration(vo: 'null'),
  );
  final _subs = <StreamSubscription<Object?>>[];
  String? _extraPath;
  final _sinceAlign = Stopwatch()..start();
  late final VideoController _video;
  String? _edl;

  /// The load in progress, so seeks and play wait for the file to be open
  /// instead of being dropped.
  Future<void> _loading = Future.value();

  @override
  Stream<Duration> get positionStream => player.stream.position;
  @override
  Stream<bool> get playingStream => player.stream.playing;
  @override
  Duration get position => player.state.position;
  @override
  bool get isPlaying => player.state.playing;

  /// Opens [edl], keeping the playhead where it was (clamped to the new
  /// length) and paused or playing as before.
  Future<void> load(String? edl) => _loading = _load(edl);

  Future<void> _load(String? edl) async {
    final wasPlaying = player.state.playing;
    final at = player.state.position;
    _edl = edl;
    if (edl == null) {
      await player.stop();
      return;
    }
    await player.open(Media(edl, start: at), play: wasPlaying);
    // open() returns before mpv knows the length; seeks before that are
    // ignored.
    if (player.state.duration == Duration.zero) {
      await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 10), onTimeout: () => Duration.zero);
    }
  }

  /// Plays [path] (a WAV as long as the video) along with the video, or
  /// nothing when null.
  Future<void> setExtraAudio(String? path) async {
    if (path == _extraPath) return;
    _extraPath = path;
    if (path == null) {
      await extra.stop();
      return;
    }
    await extra.open(Media(path, start: player.state.position), play: false);
    if (player.state.playing) await extra.play();
  }

  Future<void> _alignExtra({bool force = false}) async {
    if (_extraPath == null) return;
    if (!force && _sinceAlign.elapsed < const Duration(milliseconds: 500)) {
      return;
    }
    _sinceAlign.reset();
    final drift = (extra.state.position - player.state.position).abs();
    if (force || drift > const Duration(milliseconds: 120)) {
      await extra.seek(player.state.position);
    }
  }

  @override
  Future<void> play() async {
    await _loading;
    if (_edl == null || player.state.playing) return;
    if (player.state.completed) await player.seek(Duration.zero);
    await player.play();
  }

  @override
  Future<void> pause() async {
    await _loading;
    await player.pause();
  }

  @override
  Future<void> setVolume(double volume) =>
      player.setVolume((volume * 100).clamp(0, 200).toDouble());

  @override
  Future<void> togglePlay() async {
    await _loading;
    if (_edl == null) return;
    if (player.state.completed) await player.seek(Duration.zero);
    await player.playOrPause();
  }

  @override
  Future<void> seek(Duration to) async {
    await _loading;
    if (_edl == null) return;
    final at = to < Duration.zero ? Duration.zero : to;
    await player.seek(at);
    if (_extraPath != null) await extra.seek(at);
  }

  @override
  Widget buildVideo() => Video(
    key: const Key('video'),
    controller: _video,
    controls: null,
    fill: Colors.black,
  );

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await extra.dispose();
    await player.dispose();
  }
}
