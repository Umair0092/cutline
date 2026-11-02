import 'dart:io';

import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../media/media_probe.dart';
import '../model/media_asset.dart';

const imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];
const gifExtensions = ['gif'];

/// Files that can go on top of the video.
const overlayExtensions = [
  ...imageExtensions,
  ...gifExtensions,
  ...videoExtensions,
];

/// What kind of overlay a file would be, from its extension, or null.
MediaKind? overlayKindOf(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (imageExtensions.contains(ext)) return MediaKind.image;
  if (gifExtensions.contains(ext)) return MediaKind.gif;
  if (videoExtensions.contains(ext)) return MediaKind.video;
  return null;
}

/// Reads an image, GIF or video's size, length and sound from what
/// `ffmpeg -i` prints.
Future<MediaAsset> probeOverlayMedia(String ffmpeg, String path) async {
  final name = p.basename(path);
  final kind = overlayKindOf(path);
  if (kind == null) {
    throw MediaProbeException(
      '$name can\'t go on top of the video '
      '(use ${overlayExtensions.join(', ')}).',
    );
  }
  final r = await Process.run(ffmpeg, ['-hide_banner', '-i', path]);
  final info = parseFfmpegInfo(r.stderr as String);
  if (info == null) throw MediaProbeException('Could not read $name.');
  // A GIF with one frame is just a picture.
  final still = kind == MediaKind.image || info.duration <= Duration.zero;
  return MediaAsset(
    id: newId(),
    path: path,
    kind: still && kind == MediaKind.gif ? MediaKind.image : kind,
    duration: still ? Duration.zero : info.duration,
    width: info.width,
    height: info.height,
    hasAudio: kind == MediaKind.video && info.hasAudio,
    frameRate: info.fps,
  );
}

/// The parts of `ffmpeg -i` output we use, or null without a video stream.
({Duration duration, int width, int height, double fps, bool hasAudio})?
parseFfmpegInfo(String output) {
  final video = RegExp(r'Stream #\d+:\d+.*?: Video: (.*)')
      .firstMatch(output)
      ?.group(1);
  if (video == null) return null;
  final size = RegExp(r'(?:^|[ ,])(\d{2,5})x(\d{2,5})(?=[ ,]|$)')
      .firstMatch(video);
  if (size == null) return null;
  final fps = RegExp(r'([\d.]+) fps').firstMatch(video)?.group(1);
  final d = RegExp(r'Duration: (\d+):(\d+):(\d+)\.(\d+)').firstMatch(output);
  var duration = Duration.zero;
  if (d != null) {
    int g(int i) => int.parse(d.group(i)!);
    duration = Duration(
      hours: g(1),
      minutes: g(2),
      seconds: g(3),
      milliseconds: int.parse(d.group(4)!.padRight(3, '0').substring(0, 3)),
    );
  }
  return (
    duration: duration,
    width: int.parse(size.group(1)!),
    height: int.parse(size.group(2)!),
    fps: double.tryParse(fps ?? '') ?? 30.0,
    hasAudio: RegExp(r'Stream #\d+:\d+.*?: Audio:').hasMatch(output),
  );
}
