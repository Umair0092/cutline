import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../model/media_asset.dart';

class MediaProbeException implements Exception {
  MediaProbeException(this.message);

  final String message;

  @override
  String toString() => message;
}

const videoExtensions = ['mp4', 'mov', 'm4v'];

/// Reads a video's length, size and whether it has sound, using a muted
/// player that never shows anything.
Future<MediaAsset> probeVideo(String path) async {
  final name = p.basename(path);
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (!videoExtensions.contains(ext)) {
    throw MediaProbeException(
      '$name is not a supported video (${videoExtensions.join(', ')}).',
    );
  }
  final player = Player(configuration: const PlayerConfiguration(vo: 'null'));
  try {
    await player.setVolume(0);
    await player.open(Media(path), play: false);

    final duration = await _waitFor(
      player.stream.duration,
      () => player.state.duration,
      (d) => d > Duration.zero,
      'Could not read $name.',
    );
    final tracks = await _waitFor(
      player.stream.tracks,
      () => player.state.tracks,
      (t) => t.video.any((v) => (v.w ?? 0) > 0),
      '$name has no video track.',
    );
    final video = tracks.video.firstWhere((t) => (t.w ?? 0) > 0);
    return MediaAsset(
      id: newId(),
      path: path,
      kind: MediaKind.video,
      duration: duration,
      width: video.w!,
      height: video.h ?? 0,
      hasAudio: tracks.audio.any((t) => t.id != 'auto' && t.id != 'no'),
    );
  } finally {
    await player.dispose();
  }
}

/// Returns the current value if it already passes [test], otherwise waits
/// for the stream. Checking the current value first avoids missing an event
/// that fired before we started listening.
Future<T> _waitFor<T>(
  Stream<T> stream,
  T Function() current,
  bool Function(T) test,
  String error,
) async {
  final now = current();
  if (test(now)) return now;
  try {
    return await stream.firstWhere(test).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    final last = current();
    if (test(last)) return last;
    throw MediaProbeException(error);
  }
}
