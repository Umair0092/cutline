import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/ffmpeg.dart';
import '../model/media_asset.dart';
import '../render/frame_pipe.dart';

/// Small decoded frames of an overlay file, for the preview.
class OverlayFrames {
  OverlayFrames(this.frames, this.fps);

  final List<ui.Image> frames;
  final double fps;

  /// The frame at local time [t]; animations loop.
  ui.Image frameAt(Duration t) {
    if (frames.length == 1) return frames.first;
    final i = (t.inMicroseconds / 1e6 * fps).floor();
    return frames[i % frames.length];
  }
}

/// The preview keeps at most this much of an animation (it loops after).
const previewFramesLimit = Duration(seconds: 15);
const _previewFps = 12.0;
const _previewLongSide = 480;

/// Overlay frames by (absolute path, media). Null while ffmpeg is missing.
final overlayFramesProvider =
    FutureProvider.family<OverlayFrames?, ({String path, MediaAsset media})>((
      ref,
      key,
    ) async {
      final ffmpeg = const FfmpegLocator().find();
      if (ffmpeg == null) return null;
      final m = key.media;
      final still = m.kind == MediaKind.image;
      final long = m.width > m.height ? m.width : m.height;
      final k = long > _previewLongSide ? _previewLongSide / long : 1.0;
      final w = ((m.width * k) / 2).round() * 2;
      final h = ((m.height * k) / 2).round() * 2;
      final length = m.duration < previewFramesLimit
          ? m.duration
          : previewFramesLimit;
      final reader = await FrameReader.open(
        ffmpeg: ffmpeg,
        path: key.path,
        still: still,
        width: w < 2 ? 2 : w,
        height: h < 2 ? 2 : h,
        fps: _previewFps,
        duration: length,
      );
      final frames = <ui.Image>[];
      final count = still
          ? 1
          : (length.inMicroseconds / 1e6 * _previewFps).ceil().clamp(1, 1000);
      try {
        for (var i = 0; i < count; i++) {
          final image = await reader.nextOwned();
          if (image == null) break;
          frames.add(image);
        }
      } finally {
        await reader.close();
      }
      if (frames.isEmpty) return null;
      ref.onDispose(() {
        for (final f in frames) {
          f.dispose();
        }
      });
      return OverlayFrames(frames, _previewFps);
    });
