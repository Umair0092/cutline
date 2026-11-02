import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../export/exporter.dart';

/// Draws frames with Flutter and pipes the raw pixels into FFmpeg, which
/// writes them to [outputPath] with the [output] encoding arguments.
///
/// [paint] draws frame [i] (at `i / fps` seconds) on a transparent canvas
/// of [width] x [height].
Future<void> pipeFramesToFfmpeg({
  required String ffmpeg,
  required String outputPath,
  required int width,
  required int height,
  required double fps,
  required int frames,
  required Future<void> Function(ui.Canvas canvas, int i) paint,
  List<String> extraInputs = const [],
  List<String> output = const [],
  String what = 'the title',
}) async {
  final process = await Process.start(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgba',
    '-s',
    '${width}x$height',
    '-r',
    fps.toStringAsFixed(3),
    '-i',
    'pipe:0',
    ...extraInputs,
    ...output,
    outputPath,
  ]);
  final errors = StringBuffer();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .forEach(errors.write);
  unawaited(process.stdout.drain<void>());
  try {
    for (var i = 0; i < frames; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      await paint(canvas, i);
      final image = await recorder.endRecording().toImage(width, height);
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      image.dispose();
      process.stdin.add(bytes!.buffer.asUint8List());
      await process.stdin.flush();
    }
  } finally {
    await process.stdin.close();
  }
  final code = await process.exitCode;
  await stderrDone;
  if (code != 0) {
    throw ExportException(
      'Rendering $what failed (ffmpeg exit code $code).',
      details: errors.toString(),
    );
  }
}

/// Decodes a media file into RGBA frames of a fixed size and rate with
/// FFmpeg, one at a time. GIFs and videos loop.
class FrameReader {
  FrameReader._(this._process, this.width, this.height) {
    _frames = StreamIterator(_chunk(_process.stdout));
    unawaited(_process.stderr.drain<void>());
  }

  /// Starts reading [path] for [duration], scaled to [width] x [height].
  static Future<FrameReader> open({
    required String ffmpeg,
    required String path,
    required bool still,
    required int width,
    required int height,
    required double fps,
    required Duration duration,
  }) async {
    final process = await Process.start(ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      // A still image is one frame; next() keeps returning it.
      if (!still) ...['-stream_loop', '-1'],
      '-i',
      path,
      if (!still) ...['-t', (duration.inMicroseconds / 1e6).toStringAsFixed(3)],
      '-an',
      '-vf',
      'fps=${fps.toStringAsFixed(3)},scale=$width:$height,format=rgba',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      'pipe:1',
    ]);
    return FrameReader._(process, width, height);
  }

  final Process _process;
  final int width;
  final int height;
  late final StreamIterator<Uint8List> _frames;
  ui.Image? _last;

  Stream<Uint8List> _chunk(Stream<List<int>> bytes) async* {
    final size = width * height * 4;
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      buffer.add(chunk);
      while (buffer.length >= size) {
        final all = buffer.takeBytes();
        yield Uint8List.sublistView(all, 0, size);
        if (all.length > size) buffer.add(Uint8List.sublistView(all, size));
      }
    }
  }

  /// The next frame, or the last one again once the file runs out.
  Future<ui.Image?> next() async {
    if (await _frames.moveNext()) {
      _last?.dispose();
      _last = await imageFromPixels(_frames.current, width, height);
    }
    return _last;
  }

  /// The next frame as an image the caller owns, or null at the end.
  Future<ui.Image?> nextOwned() async {
    if (!await _frames.moveNext()) return null;
    return imageFromPixels(_frames.current, width, height);
  }

  Future<void> close() async {
    await _frames.cancel();
    _process.kill();
    _last?.dispose();
    _last = null;
  }
}

/// Wraps raw RGBA bytes in an image.
Future<ui.Image> imageFromPixels(Uint8List rgba, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}
