import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ffmpeg.dart';
import 'media_cache.dart';

/// Thumbnails and a waveform for one source file, for drawing the timeline.
class MediaPreview {
  const MediaPreview({
    required this.thumbnails,
    required this.thumbnailInterval,
    required this.peaks,
  });

  static const empty = MediaPreview(
    thumbnails: [],
    thumbnailInterval: Duration(seconds: 1),
    peaks: null,
  );

  /// Frame `i` shows the video at `i * thumbnailInterval`.
  final List<ui.Image> thumbnails;
  final Duration thumbnailInterval;

  /// Loudest sample (0..1) in each 10 ms of audio, or null without audio.
  final Float32List? peaks;
  static const peaksPerSecond = 100;

  ui.Image? thumbnailAt(Duration t) {
    if (thumbnails.isEmpty) return null;
    final i = t.inMicroseconds ~/ thumbnailInterval.inMicroseconds;
    return thumbnails[i.clamp(0, thumbnails.length - 1)];
  }
}

/// Previews by absolute file path. Empty (no thumbnails, no waveform) when
/// ffmpeg isn't available, so the timeline still works.
final mediaPreviewProvider = FutureProvider.family<MediaPreview, String>((
  ref,
  path,
) async {
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null || !File(path).existsSync()) return MediaPreview.empty;
  final cacheRoot = p.join(
    (await getApplicationSupportDirectory()).path,
    'preview-cache',
  );
  return MediaPreviewGenerator(ffmpeg, cacheRoot).load(path);
});

class MediaPreviewGenerator {
  const MediaPreviewGenerator(this.ffmpeg, this.cacheRoot);

  final String ffmpeg;
  final String cacheRoot;

  static const thumbnailHeight = 120;

  /// At most this many thumbnails per file, so long videos stay cheap.
  static const maxThumbnails = 300;

  Future<MediaPreview> load(String path) async {
    final dir = Directory(p.join(cacheRoot, mediaCacheKey(path)));
    final done = File(p.join(dir.path, 'done'));
    if (!done.existsSync()) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      await _generate(path, dir.path);
      done.writeAsStringSync('');
    }
    return _read(dir.path);
  }

  Future<Duration> _duration(String path) async {
    // ffmpeg prints "Duration: 00:01:23.45" for the input.
    final r = await Process.run(ffmpeg, ['-hide_banner', '-i', path]);
    final m = RegExp(r'Duration: (\d+):(\d+):(\d+)\.(\d+)')
        .firstMatch(r.stderr as String);
    if (m == null) return Duration.zero;
    int g(int i) => int.parse(m.group(i)!);
    return Duration(
      hours: g(1),
      minutes: g(2),
      seconds: g(3),
      milliseconds: int.parse(m.group(4)!.padRight(3, '0').substring(0, 3)),
    );
  }

  Future<void> _generate(String path, String outDir) async {
    final duration = await _duration(path);
    final seconds = duration.inMilliseconds / 1000;
    final interval = seconds <= maxThumbnails ? 1.0 : seconds / maxThumbnails;
    File(p.join(outDir, 'interval')).writeAsStringSync('$interval');

    final thumbs = Process.run(ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-i',
      path,
      '-vf',
      'fps=1/$interval,scale=-2:$thumbnailHeight',
      '-q:v',
      '5',
      p.join(outDir, 'thumb_%05d.jpg'),
    ]);

    // Mono 16-bit PCM at 1 kHz is plenty for drawing a waveform.
    final audio = Process.run(ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      path,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '1000',
      '-f',
      's16le',
      '-',
    ], stdoutEncoding: null);

    final audioResult = await audio;
    final pcm = audioResult.stdout as List<int>;
    if (pcm.isNotEmpty) {
      File(p.join(outDir, 'peaks.f32')).writeAsBytesSync(
        computePeaks(Uint8List.fromList(pcm)).buffer.asUint8List(),
      );
    }
    await thumbs;
  }

  Future<MediaPreview> _read(String dir) async {
    final interval =
        double.tryParse(File(p.join(dir, 'interval')).readAsStringSync()) ??
        1.0;
    final files =
        Directory(dir)
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith('thumb_'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final thumbnails = <ui.Image>[];
    for (final f in files) {
      final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
      thumbnails.add((await codec.getNextFrame()).image);
    }
    final peaksFile = File(p.join(dir, 'peaks.f32'));
    return MediaPreview(
      thumbnails: thumbnails,
      thumbnailInterval: Duration(microseconds: (interval * 1e6).round()),
      peaks: peaksFile.existsSync()
          ? peaksFile.readAsBytesSync().buffer.asFloat32List()
          : null,
    );
  }
}

/// Turns 1 kHz signed 16-bit mono PCM into one peak (0..1) per 10 ms.
Float32List computePeaks(Uint8List pcm) {
  final samples = pcm.buffer.asInt16List(
    pcm.offsetInBytes,
    pcm.lengthInBytes ~/ 2,
  );
  const perPeak = 1000 ~/ MediaPreview.peaksPerSecond;
  final peaks = Float32List((samples.length / perPeak).ceil());
  for (var i = 0; i < samples.length; i++) {
    final v = samples[i].abs() / 32768;
    final j = i ~/ perPeak;
    if (v > peaks[j]) peaks[j] = v;
  }
  return peaks;
}
