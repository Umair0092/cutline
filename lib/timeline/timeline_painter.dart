import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../media/media_previews.dart';
import '../model/audio_item.dart';
import '../model/project.dart';
import 'timeline_geometry.dart';
import 'timeline_layout.dart';
import '../model/title_item.dart';
import '../titles/templates.dart';

/// Short text for a title on the timeline: its main text, else its type.
String titleLabel(TitleSpec spec) {
  final template = templateById(spec.templateId);
  final text = spec.fields['title'] ?? spec.fields['name'];
  return text ?? template?.name ?? 'Title';
}

/// An overlay or audio item being moved or stretched: where it would start
/// and how long it would be.
typedef SpanDrag = ({bool audio, String id, Duration start, Duration duration});

/// Vertical layout of the timeline rows.
abstract final class TimelineRows {
  static const ruler = Rect.fromLTRB(0, 0, 0, 24);
  static const videoTop = 30.0;
  static const videoHeight = 60.0;
  static const waveTop = videoTop + videoHeight + 2;
  static const waveHeight = 30.0;
  static const titleTop = waveTop + waveHeight + 8;
  static const rowHeight = 22.0;
  static const overlayTop = titleTop + rowHeight + 4;
  static const audioTop = overlayTop + rowHeight + 4;
  static const musicTop = audioTop + rowHeight + 4;
  static const height = musicTop + rowHeight + 8;
}

class TimelineColors {
  const TimelineColors({
    required this.background,
    required this.ruler,
    required this.rulerText,
    required this.clip,
    required this.clipBorder,
    required this.selected,
    required this.wave,
    required this.overlay,
    required this.sticker,
    required this.audio,
    required this.music,
    required this.playhead,
  });

  factory TimelineColors.of(ColorScheme c) => TimelineColors(
    background: c.surfaceContainerLow,
    ruler: c.outlineVariant,
    rulerText: c.onSurfaceVariant,
    clip: c.surfaceContainerHighest,
    clipBorder: c.outline,
    selected: c.primary,
    wave: c.tertiary,
    overlay: c.secondaryContainer,
    sticker: c.primaryContainer,
    audio: c.tertiaryContainer,
    music: const Color(0xFF1F5C57),
    playhead: c.error,
  );

  final Color background;
  final Color ruler;
  final Color rulerText;
  final Color clip;
  final Color clipBorder;
  final Color selected;
  final Color wave;
  final Color overlay;
  final Color sticker;
  final Color audio;
  final Color music;
  final Color playhead;
}

/// Draws the ruler, clips with thumbnails, the waveform, overlays and audio.
class TracksPainter extends CustomPainter {
  TracksPainter({
    required this.geometry,
    required this.boxes,
    required this.previews,
    required this.colors,
    required this.selectedClipId,
    required this.dropX,
    required this.visible,
    this.selectedTitleId,
    this.titleDrag,
    this.selectedOverlayId,
    this.spanDrag,
    this.selectedAudioId,
  });

  final TimelineGeometry geometry;
  final List<ClipBox> boxes;

  /// By media id.
  final Map<String, MediaPreview> previews;
  final TimelineColors colors;
  final String? selectedClipId;

  /// Where a dragged clip would be dropped, or null.
  final double? dropX;

  /// The horizontal range that's on screen; nothing outside it is drawn.
  final ({double left, double right}) visible;

  final String? selectedTitleId;

  /// A title being dragged: its id and where it would start.
  final ({String id, Duration start})? titleDrag;

  final String? selectedOverlayId;

  final SpanDrag? spanDrag;

  final String? selectedAudioId;

  Project get project => geometry.project;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRuler(canvas, size);
    for (final box in boxes) {
      if (box.right < visible.left || box.left > visible.right) continue;
      _paintClip(canvas, box);
    }
    _paintTitles(canvas);
    _paintOverlays(canvas);
    _paintAudio(canvas);
    if (dropX != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          dropX! - 1.5,
          TimelineRows.videoTop - 4,
          3,
          TimelineRows.videoHeight + 8,
        ),
        Paint()..color = colors.selected,
      );
    }
  }

  void _paintRuler(Canvas canvas, Size size) {
    final pps = geometry.pixelsPerSecond;
    const steps = [
      0.1,
      0.5,
      1.0,
      2.0,
      5.0,
      10.0,
      15.0,
      30.0,
      60.0,
      120.0,
      300.0,
      600.0,
      1800.0,
      3600.0,
    ];
    final major = steps.firstWhere((s) => s * pps >= 80, orElse: () => 3600);
    final minor = major / 5;
    final tick = Paint()
      ..color = colors.ruler
      ..strokeWidth = 1;
    final firstMinor =
        (geometry.timeAt(visible.left).inMicroseconds / 1e6 / minor).floor();
    for (var i = math.max(0, firstMinor); ; i++) {
      final seconds = i * minor;
      final x = geometry.xOf(Duration(microseconds: (seconds * 1e6).round()));
      if (x > visible.right) break;
      final isMajor = (i % 5) == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 12 : 18),
        Offset(x, TimelineRows.ruler.bottom),
        tick,
      );
      if (isMajor) {
        final label = TextPainter(
          text: TextSpan(
            text: _rulerLabel(seconds, major),
            style: TextStyle(fontSize: 10, color: colors.rulerText),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x + 3, 0));
      }
    }
  }

  String _rulerLabel(double seconds, double step) {
    final m = seconds ~/ 60;
    final s = seconds - m * 60;
    final ss = step < 1
        ? s.toStringAsFixed(1).padLeft(4, '0')
        : s.round().toString().padLeft(2, '0');
    return '$m:$ss';
  }

  void _paintClip(Canvas canvas, ClipBox box) {
    final rect = Rect.fromLTRB(
      box.left + 1,
      TimelineRows.videoTop,
      box.right - 1,
      TimelineRows.videoTop + TimelineRows.videoHeight,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final selected = box.clip.id == selectedClipId;
    final preview = previews[box.clip.mediaId];
    final media = project.mediaById(box.clip.mediaId);

    if (box.floating) {
      // Draw the dragged clip at 70% opacity.
      canvas.saveLayer(
        rect.inflate(2),
        Paint()..color = const Color(0xB3000000),
      );
    }
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(rect, Paint()..color = colors.clip);

    // Thumbnails, tiled across the clip.
    if (preview != null && preview.thumbnails.isNotEmpty) {
      final aspect = media != null && media.height > 0
          ? media.width / media.height
          : 16 / 9;
      final tileW = TimelineRows.videoHeight * aspect;
      final first = math.max(rect.left, visible.left - tileW);
      final firstTile =
          rect.left + ((first - rect.left) / tileW).floor() * tileW;
      for (
        var x = firstTile;
        x < math.min(rect.right, visible.right);
        x += tileW
      ) {
        final t =
            box.clip.sourceStart +
            geometry.timeAt(x) -
            geometry.timeAt(rect.left);
        final image = preview.thumbnailAt(t);
        if (image == null) continue;
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(x, rect.top, tileW, rect.height),
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        );
      }
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1
        ..color = selected ? colors.selected : colors.clipBorder,
    );
    if (selected) _paintHandles(canvas, rect);
    if (box.floating) canvas.restore();

    if (media?.hasAudio ?? false) _paintWave(canvas, box, preview?.peaks);
  }

  void _paintHandles(Canvas canvas, Rect rect) {
    final paint = Paint()..color = colors.selected;
    for (final x in [rect.left, rect.right - 6]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, rect.top, 6, rect.height),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  void _paintWave(Canvas canvas, ClipBox box, List<double>? peaks) {
    final rect = Rect.fromLTRB(
      box.left + 1,
      TimelineRows.waveTop,
      box.right - 1,
      TimelineRows.waveTop + TimelineRows.waveHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = colors.wave.withValues(alpha: 0.15),
    );
    if (peaks == null || peaks.isEmpty) return;
    final path = Path();
    final mid = rect.center.dy;
    final from = math.max(rect.left, visible.left);
    final to = math.min(rect.right, visible.right);
    const step = 2.0;
    final pps = geometry.pixelsPerSecond;
    for (var x = from; x < to; x += step) {
      final source =
          box.clip.sourceStart +
          geometry.timeAt(x) -
          geometry.timeAt(rect.left);
      final i0 = (source.inMicroseconds / 1e6 * MediaPreview.peaksPerSecond)
          .floor();
      final i1 = math.max(
        i0 + 1,
        i0 + (step / pps * MediaPreview.peaksPerSecond).ceil(),
      );
      var peak = 0.0;
      for (var i = i0; i < i1 && i < peaks.length; i++) {
        if (i >= 0 && peaks[i] > peak) peak = peaks[i];
      }
      final h = math.max(0.5, peak * rect.height / 2);
      path.addRect(Rect.fromLTRB(x, mid - h, x + step - 0.5, mid + h));
    }
    canvas.drawPath(path, Paint()..color = colors.wave);
  }

  void _paintTitles(Canvas canvas) {
    for (final title in project.titles) {
      final start = titleDrag?.id == title.id ? titleDrag!.start : title.start;
      final rect = Rect.fromLTRB(
        geometry.xOf(start),
        TimelineRows.titleTop,
        geometry.xOf(start + title.spec.duration),
        TimelineRows.titleTop + TimelineRows.rowHeight,
      );
      _paintLabelledSpan(
        canvas,
        rect,
        colors.overlay,
        titleLabel(title.spec),
        selected: title.id == selectedTitleId,
      );
    }
  }

  void _paintOverlays(Canvas canvas) {
    for (final o in project.overlays) {
      final d = spanDrag?.id == o.id ? spanDrag : null;
      final start = d?.start ?? o.start;
      final rect = Rect.fromLTRB(
        geometry.xOf(start),
        TimelineRows.overlayTop,
        geometry.xOf(start + (d?.duration ?? o.duration)),
        TimelineRows.overlayTop + TimelineRows.rowHeight,
      );
      final media = project.mediaById(o.mediaId);
      _paintLabelledSpan(
        canvas,
        rect,
        colors.sticker,
        media == null ? 'Overlay' : p.basename(media.path),
        selected: o.id == selectedOverlayId,
      );
    }
  }

  void _paintAudio(Canvas canvas) {
    for (final a in project.audio) {
      final d = spanDrag?.id == a.id ? spanDrag : null;
      final start = d?.start ?? a.start;
      final music = a.role == AudioRole.music;
      final top = music ? TimelineRows.musicTop : TimelineRows.audioTop;
      final rect = Rect.fromLTRB(
        geometry.xOf(start),
        top,
        geometry.xOf(start + (d?.duration ?? a.duration)),
        top + TimelineRows.rowHeight,
      );
      final media = project.mediaById(a.mediaId);
      _paintLabelledSpan(
        canvas,
        rect,
        music ? colors.music : colors.audio,
        media?.speech?.text ??
            (music ? '♪ ${media?.name ?? 'Music'}' : null) ??
            media?.name ??
            '${a.role.name[0].toUpperCase()}${a.role.name.substring(1)}',
        selected: a.id == selectedAudioId,
      );
    }
  }

  void _paintLabelledSpan(
    Canvas canvas,
    Rect rect,
    Color fill,
    String text, {
    required bool selected,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = fill);
    if (selected) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.selected,
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 11, color: colors.rulerText),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (rect.width - 10).clamp(0, double.infinity));
    label.paint(
      canvas,
      Offset(rect.left + 5, rect.center.dy - label.height / 2),
    );
  }

  // Only rebuilt when the project, zoom, scroll, selection or a drag
  // changes, and each of those needs a repaint.
  @override
  bool shouldRepaint(TracksPainter old) => true;
}

/// Just the playhead line, repainted on every position update without
/// redrawing the tracks.
class PlayheadPainter extends CustomPainter {
  PlayheadPainter({
    required this.geometry,
    required this.position,
    required this.color,
  }) : super(repaint: position);

  final TimelineGeometry geometry;
  final ValueNotifier<Duration> position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = geometry.xOf(position.value);
    final paint = Paint()..color = color;
    canvas
      ..drawRect(Rect.fromLTWH(x - 0.75, 0, 1.5, size.height), paint)
      ..drawPath(
        Path()
          ..moveTo(x - 6, 0)
          ..lineTo(x + 6, 0)
          ..lineTo(x, 8)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(PlayheadPainter old) =>
      old.geometry.pixelsPerSecond != geometry.pixelsPerSecond ||
      old.position != position ||
      old.color != color;
}
