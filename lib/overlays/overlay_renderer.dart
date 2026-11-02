import 'dart:ui' as ui;

import '../model/media_asset.dart';
import '../model/overlay_item.dart';
import '../render/frame_pipe.dart';
import 'overlay_paint.dart';

/// Renders one overlay, animation included, to a see-through MOV the size
/// of the output frame, the same way titles are rendered. The preview and
/// the export draw it with the same [paintOverlay].
Future<void> renderOverlayClip({
  required String ffmpeg,
  required OverlayItem item,
  required MediaAsset media,
  required String sourcePath,
  required String outputPath,
  required int width,
  required int height,
  required double fps,
  Duration? length,
}) async {
  final duration = length ?? item.duration;
  final frames = (duration.inMicroseconds / 1e6 * fps).round();
  // Decode the source a little bigger than it's drawn, since popping in
  // overshoots its size for a moment.
  final rect = overlayRect(
    ui.Size(width.toDouble(), height.toDouble()),
    media.height == 0 ? 1 : media.width / media.height,
    item.transform,
  );
  int even(double v) => (v / 2).ceil().clamp(1, 4096) * 2;
  final reader = await FrameReader.open(
    ffmpeg: ffmpeg,
    path: sourcePath,
    still: media.kind == MediaKind.image,
    width: even(rect.width * 1.1),
    height: even(rect.height * 1.1),
    fps: fps,
    duration: duration,
  );
  final size = ui.Size(width.toDouble(), height.toDouble());
  try {
    await pipeFramesToFfmpeg(
      ffmpeg: ffmpeg,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      frames: frames,
      what: 'an overlay',
      output: ['-c:v', 'png', '-pix_fmt', 'rgba'],
      paint: (canvas, i) async {
        final image = await reader.next();
        if (image != null) paintOverlay(canvas, size, image, item, i / fps);
      },
    );
  } finally {
    await reader.close();
  }
}
