import 'dart:ui' as ui;

import '../export/exporter.dart';
import '../model/title_item.dart';
import '../render/frame_pipe.dart';
import 'templates.dart';

/// Draws one frame of [spec] at [t] seconds into an image.
Future<ui.Image> renderTitleFrame(
  TitleSpec spec,
  int width,
  int height,
  double t,
) {
  final template = templateById(spec.templateId)!;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  template.paint(
    canvas,
    ui.Size(width.toDouble(), height.toDouble()),
    t,
    spec.duration.inMicroseconds / 1e6,
    TitleValues(template, spec.fields),
  );
  return recorder.endRecording().toImage(width, height);
}

/// Renders a title to a video file by drawing every frame and piping the
/// raw pixels into FFmpeg.
class TitleRenderer {
  TitleRenderer(this.ffmpeg);

  final String ffmpeg;

  /// An H.264 MP4 with silent audio, for an intro placed before the video.
  Future<void> renderClip(
    TitleSpec spec,
    String outputPath, {
    required int width,
    required int height,
    required double fps,
  }) async {
    final encoder = await EncoderPicker(ffmpeg).pick();
    await _render(
      spec,
      outputPath,
      width,
      height,
      fps,
      extraInputs: ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo'],
      [
        // Exactly the title's length: -shortest alone leaves ~0.1 s of extra
        // AAC padding, which would shift everything after the intro.
        '-t',
        (spec.duration.inMicroseconds / 1e6).toStringAsFixed(3),
        '-c:v',
        encoder.ffmpegName,
        ...encoder.args(8000000),
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-movflags',
        '+faststart',
      ],
    );
  }

  /// A see-through MOV (PNG frames with alpha), for a title drawn over the
  /// video during export.
  Future<void> renderOverlay(
    TitleSpec spec,
    String outputPath, {
    required int width,
    required int height,
    required double fps,
  }) => _render(spec, outputPath, width, height, fps, [
    '-c:v',
    'png',
    '-pix_fmt',
    'rgba',
  ]);

  Future<void> _render(
    TitleSpec spec,
    String outputPath,
    int width,
    int height,
    double fps,
    List<String> output, {
    List<String> extraInputs = const [],
  }) async {
    final template = templateById(spec.templateId);
    if (template == null) {
      throw ExportException('Unknown title template "${spec.templateId}".');
    }
    final total = spec.duration.inMicroseconds / 1e6;
    final size = ui.Size(width.toDouble(), height.toDouble());
    await pipeFramesToFfmpeg(
      ffmpeg: ffmpeg,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      frames: (total * fps).round(),
      extraInputs: extraInputs,
      output: output,
      paint: (canvas, i) async => template.paint(
        canvas,
        size,
        i / fps,
        total,
        TitleValues(template, spec.fields),
      ),
    );
  }
}

/// Frame size and rate for titles in this project: the first clip's size,
/// at most 1080 tall, so intros match the video they sit in.
({int width, int height, double fps}) titleFormat(
  int sourceWidth,
  int sourceHeight,
  double sourceFps,
) {
  var w = sourceWidth > 0 ? sourceWidth : 1920;
  var h = sourceHeight > 0 ? sourceHeight : 1080;
  final shortSide = w < h ? w : h;
  if (shortSide > 1080) {
    final k = 1080 / shortSide;
    w = (w * k).round();
    h = (h * k).round();
  }
  w += w.isOdd ? 1 : 0;
  h += h.isOdd ? 1 : 0;
  return (width: w, height: h, fps: sourceFps.clamp(1, 60).toDouble());
}
