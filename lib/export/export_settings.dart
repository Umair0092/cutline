import '../model/project.dart';

enum ExportPreset {
  hd1080('1080p', 1080),
  uhd4k('4K', 2160),
  source('Same as source', null);

  const ExportPreset(this.label, this.height);

  final String label;

  /// Output height, or null to keep the first clip's size.
  final int? height;
}

/// The frame size and rate of an export.
class ExportFormat {
  const ExportFormat({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.videoBitrate,
  });

  /// Works out the output format from the first clip: its shape (so a
  /// vertical phone video stays vertical) and frame rate (capped at 60).
  factory ExportFormat.forProject(Project project, ExportPreset preset) {
    final first = project.clips.isEmpty
        ? null
        : project.mediaById(project.clips.first.mediaId);
    final srcW = (first?.width ?? 0) > 0 ? first!.width : 1920;
    final srcH = (first?.height ?? 0) > 0 ? first!.height : 1080;

    int width;
    int height;
    if (project.aspect != ReframeAspect.source) {
      // Reframe to the chosen aspect, short side at the preset (default 1080).
      final size = outputSize(
        srcW,
        srcH,
        project.aspect,
        maxShort: preset.height ?? 1080,
      );
      width = size.width;
      height = size.height;
    } else {
      // Keep the source shape; the preset sets the short side ("1080p" =
      // 1080 on the short side), so a vertical phone video stays vertical.
      final portrait = srcH > srcW;
      if (preset.height == null) {
        width = srcW;
        height = srcH;
      } else if (portrait) {
        width = preset.height!;
        height = (preset.height! * srcH / srcW).round();
      } else {
        height = preset.height!;
        width = (preset.height! * srcW / srcH).round();
      }
      width = _even(width);
      height = _even(height);
    }

    final fps = (first?.frameRate ?? 30).clamp(1, 60).toDouble();
    // About 12 Mbit/s for 1080p30, scaled by pixels and frame rate.
    final bitrate = (12e6 * (width * height) / (1920 * 1080) * (fps / 30))
        .clamp(4e6, 80e6)
        .round();
    return ExportFormat(
      width: width,
      height: height,
      frameRate: fps,
      videoBitrate: bitrate,
    );
  }

  final int width;
  final int height;
  final double frameRate;
  final int videoBitrate;

  // H.264 needs even dimensions.
  static int _even(int n) => n.isOdd ? n + 1 : n;
}
