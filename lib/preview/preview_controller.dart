import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../editing/project_editor.dart';
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

  sync(ref.read(projectEditorProvider));
  ref.listen(projectEditorProvider, (_, next) => sync(next));
  return controller;
});

/// What the UI needs from the preview player. Tests swap in a fake.
abstract class PreviewController {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Duration get position;
  bool get isPlaying;

  Future<void> togglePlay();
  Future<void> seek(Duration to);
  Widget buildVideo();
}

/// The real preview, backed by mpv through media_kit. Plays the whole main
/// track as one video (see [buildEdl]), so its position is the timeline
/// position.
class MpvPreviewController implements PreviewController {
  MpvPreviewController() : player = Player() {
    _video = VideoController(player);
  }

  final Player player;
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
    await player.seek(to < Duration.zero ? Duration.zero : to);
  }

  @override
  Widget buildVideo() => Video(
    key: const Key('video'),
    controller: _video,
    controls: null,
    fill: Colors.black,
  );

  Future<void> dispose() => player.dispose();
}
