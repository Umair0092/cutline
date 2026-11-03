import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../media/media_previews.dart';
import '../model/audio_item.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../titles/templates.dart';
import '../ui/editor/timecode.dart';
import '../ui/time_format.dart';
import '../ui/tokens.dart';
import 'timeline_geometry.dart';
import 'timeline_layout.dart';

/// Short text for a title on the timeline: its main text, else its type.
String titleLabel(TitleSpec spec) {
  final template = templateById(spec.templateId);
  final text = spec.fields['title'] ?? spec.fields['name'];
  return text ?? template?.name ?? 'Title';
}

/// An overlay or audio item being moved or stretched: where it would start
/// and how long it would be.
typedef SpanDrag = ({bool audio, String id, Duration start, Duration duration});

/// Vertical layout of the timeline rows. The video and its sound sit
/// together at the top; the lanes for things layered on top follow.
abstract final class TimelineRows {
  static const ruler = Rect.fromLTRB(0, 0, 0, 28);
  static const videoTop = 34.0;
  static const videoHeight = 54.0;
  static const waveTop = videoTop + videoHeight + 3;
  static const waveHeight = 30.0;
  static const titleTop = waveTop + waveHeight + 8;
  static const rowHeight = 24.0;
  static const gap = 4.0;
  static const overlayTop = titleTop + rowHeight + gap;
  static const audioTop = overlayTop + rowHeight + gap;
  static const musicTop = audioTop + rowHeight + gap;
  static const height = musicTop + rowHeight + 10;

  /// Every row with its colour and label, top to bottom, for the track
  /// headers and the lane backgrounds.
  static const tracks = <TrackRow>[
    (top: videoTop, height: videoHeight, color: Cut.trackVideo, label: 'Video'),
    (top: waveTop, height: waveHeight, color: Cut.trackWave, label: 'Audio'),
    (top: titleTop, height: rowHeight, color: Cut.trackTitle, label: 'Titles'),
    (
      top: overlayTop,
      height: rowHeight,
      color: Cut.trackOverlay,
      label: 'Overlays',
    ),
    (top: audioTop, height: rowHeight, color: Cut.trackVoice, label: 'Voice'),
    (top: musicTop, height: rowHeight, color: Cut.trackMusic, label: 'Music'),
  ];
}

typedef TrackRow = ({double top, double height, Color color, String label});

/// The timeline's colours, all from the design tokens.
class TimelineColors {
  const TimelineColors();

  Color get background => Cut.surface1;
  Color get lane => const Color(0x06FFFFFF);
  Color get rulerBackground => Cut.base;
  Color get tick => Cut.strokeDefault;
  Color get tickMajor => Cut.strokeStrong;
  Color get rulerText => Cut.textTertiary;
  Color get selected => Cut.textPrimary.withValues(alpha: 0.9);
  Color get handle => Cut.accent;
  Color get playhead => Cut.marker;
  Color get guide => Cut.accent;
}

/// A clip fill: the track colour at 20% over a card surface.
Color _fill(Color track, [double alpha = 0.2]) =>
    Color.alphaBlend(track.withValues(alpha: alpha), Cut.surface2);

/// Text in a clip: the track colour, lifted towards white so it reads.
Color _ink(Color track) => Color.lerp(track, Colors.white, 0.45)!;

/// Draws the ruler, clips with thumbnails, the waveform, overlays and audio.
class TracksPainter extends CustomPainter {
  TracksPainter({
    required this.geometry,
    required this.boxes,
    required this.previews,
    required this.selectedClipId,
    required this.dropX,
    required this.visible,
    this.colors = const TimelineColors(),
    this.selectedTitleId,
    this.titleDrag,
    this.selectedOverlayId,
    this.spanDrag,
    this.selectedAudioId,
    this.trim,
    this.guideX,
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

  /// A trim in progress: where the edge is and how far it moved, for the
  /// little "−0.8 s" bubble.
  final ({double x, Duration delta})? trim;

  /// A snap guide to flash, where a dragged edge just snapped.
  final double? guideX;

  Project get project => geometry.project;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLanes(canvas);
    _paintRuler(canvas, size);
    for (final box in boxes) {
      if (box.right < visible.left || box.left > visible.right) continue;
      _paintClip(canvas, box);
    }
    _paintTitles(canvas);
    _paintOverlays(canvas);
    _paintAudio(canvas);
    if (dropX != null) {
      _paintGuide(
        canvas,
        dropX!,
        TimelineRows.videoTop - 4,
        TimelineRows.waveTop + TimelineRows.waveHeight + 4,
        width: 3,
      );
    }
    if (guideX != null) {
      _paintGuide(
        canvas,
        guideX!,
        TimelineRows.ruler.bottom,
        TimelineRows.height - 6,
        width: 1,
      );
    }
    if (trim != null) _paintTrimBubble(canvas, trim!);
  }

  /// A faint band behind each row, so the rows read without lines.
  void _paintLanes(Canvas canvas) {
    final paint = Paint()..color = colors.lane;
    for (final row in TimelineRows.tracks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            visible.left,
            row.top,
            visible.right - visible.left,
            row.height,
          ),
          const Radius.circular(CutRadii.xs),
        ),
        paint,
      );
    }
  }

  void _paintRuler(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      visible.left,
      0,
      visible.right,
      TimelineRows.ruler.bottom,
    );
    canvas
      ..drawRect(rect, Paint()..color = colors.rulerBackground)
      ..drawLine(
        rect.bottomLeft,
        rect.bottomRight,
        Paint()..color = Cut.strokeSubtle,
      );
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
    final major = steps.firstWhere((s) => s * pps >= 84, orElse: () => 3600);
    final minor = major / 5;
    final tick = Paint()
      ..color = colors.tick
      ..strokeWidth = 1;
    final majorTick = Paint()
      ..color = colors.tickMajor
      ..strokeWidth = 1;
    final bottom = TimelineRows.ruler.bottom;
    final firstMinor =
        (geometry.timeAt(visible.left).inMicroseconds / 1e6 / minor).floor();
    for (var i = math.max(0, firstMinor); ; i++) {
      final seconds = i * minor;
      final x = geometry.xOf(Duration(microseconds: (seconds * 1e6).round()));
      if (x > visible.right) break;
      final isMajor = (i % 5) == 0;
      canvas.drawLine(
        Offset(x, isMajor ? bottom - 10 : bottom - 5),
        Offset(x, bottom),
        isMajor ? majorTick : tick,
      );
      if (isMajor) {
        final label = TextPainter(
          text: TextSpan(
            text: _rulerLabel(seconds, major),
            style: TextStyle(
              fontFamily: CutFonts.mono,
              fontSize: 10.5,
              height: 1,
              color: colors.rulerText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x + 4, 6));
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
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(CutRadii.xs),
    );
    final selected = box.clip.id == selectedClipId;
    final preview = previews[box.clip.mediaId];
    final media = project.mediaById(box.clip.mediaId);
    final intro = media?.title != null;
    final color = intro ? Cut.trackTitle : Cut.trackVideo;

    if (box.floating) {
      // The dragged clip floats above the others, a little see-through.
      canvas
        ..drawRRect(
          rrect.shift(const Offset(0, 4)),
          Paint()
            ..color = const Color(0x80000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        )
        ..saveLayer(rect.inflate(2), Paint()..color = const Color(0xC0000000));
    }
    canvas.drawRRect(rrect, Paint()..color = _fill(color));

    // A filmstrip of thumbnails, inset from the border.
    final strip = rect.deflate(2);
    if (preview != null && preview.thumbnails.isNotEmpty && strip.width > 2) {
      canvas
        ..save()
        ..clipRRect(
          RRect.fromRectAndRadius(
            strip,
            const Radius.circular(CutRadii.xs - 2),
          ),
        );
      final aspect = media != null && media.height > 0
          ? media.width / media.height
          : 16 / 9;
      final tileW = strip.height * aspect;
      final first = math.max(strip.left, visible.left - tileW);
      final firstTile =
          strip.left + ((first - strip.left) / tileW).floor() * tileW;
      for (
        var x = firstTile;
        x < math.min(strip.right, visible.right);
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
          rect: Rect.fromLTWH(x, strip.top, tileW, strip.height),
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        );
      }
      // A soft shade at the top so the label reads over any picture.
      canvas
        ..drawRect(
          strip,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8C000000), Color(0x00000000)],
              stops: [0, 0.55],
            ).createShader(strip),
        )
        ..restore();
    }

    if (rect.width > 44) {
      final name = intro
          ? titleLabel(media!.title!)
          : formatPlayerTime(box.clip.duration);
      _label(
        canvas,
        name,
        Offset(rect.left + (selected ? 13 : 7), rect.top + 4),
        rect.width - (selected ? 26 : 14),
        intro ? _ink(color) : Cut.textPrimary,
        mono: !intro,
      );
    }

    canvas.drawRRect(
      selected ? rrect.deflate(0.5) : rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = selected ? colors.selected : color.withValues(alpha: 0.55),
    );
    if (selected) _paintHandles(canvas, rect, left: true);
    if (box.floating) canvas.restore();

    if (media?.hasAudio ?? false) _paintWave(canvas, box, preview?.peaks);
  }

  /// Accent tabs on a selected clip's edges with a grip, saying "drag me".
  void _paintHandles(Canvas canvas, Rect rect, {required bool left}) {
    const w = 8.0;
    final paint = Paint()..color = colors.handle;
    final grip = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final (isLeft, x) in [
      if (left) (true, rect.left),
      (false, rect.right - w),
    ]) {
      final tab = Rect.fromLTWH(x, rect.top, w, rect.height);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          tab,
          topLeft: Radius.circular(isLeft ? CutRadii.xs : 2),
          bottomLeft: Radius.circular(isLeft ? CutRadii.xs : 2),
          topRight: Radius.circular(isLeft ? 2 : CutRadii.xs),
          bottomRight: Radius.circular(isLeft ? 2 : CutRadii.xs),
        ),
        paint,
      );
      final cy = tab.center.dy;
      final h = math.min(5.0, tab.height / 4);
      for (final dx in [-1.5, 1.5]) {
        canvas.drawLine(
          Offset(tab.center.dx + dx, cy - h),
          Offset(tab.center.dx + dx, cy + h),
          grip,
        );
      }
    }
  }

  void _paintWave(Canvas canvas, ClipBox box, List<double>? peaks) {
    final rect = Rect.fromLTRB(
      box.left + 1,
      TimelineRows.waveTop,
      box.right - 1,
      TimelineRows.waveTop + TimelineRows.waveHeight,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(CutRadii.xs),
    );
    canvas
      ..drawRRect(rrect, Paint()..color = _fill(Cut.trackWave, 0.12))
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Cut.trackWave.withValues(alpha: 0.3),
      );
    if (peaks == null || peaks.isEmpty) return;
    // Rounded bars, mirrored around the middle: 2 px wide, 1 px apart.
    final mid = rect.center.dy;
    final from = math.max(rect.left + 3, visible.left);
    final to = math.min(rect.right - 3, visible.right);
    const step = 3.0;
    final pps = geometry.pixelsPerSecond;
    final bars = Paint()
      ..color = Cut.trackWave.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final maxH = rect.height / 2 - 4;
    final start = (from / step).ceil() * step;
    for (var x = start; x < to; x += step) {
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
      final h = math.max(0.5, peak * maxH);
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), bars);
    }
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
        Cut.trackTitle,
        titleLabel(title.spec),
        selected: title.id == selectedTitleId,
        stretchable: false,
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
        Cut.trackOverlay,
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
        music ? Cut.trackMusic : Cut.trackVoice,
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
    Color color,
    String text, {
    required bool selected,
    bool stretchable = true,
  }) {
    if (rect.right < visible.left || rect.left > visible.right) return;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(CutRadii.xs),
    );
    canvas
      ..drawRRect(rrect, Paint()..color = _fill(color))
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1
          ..color = selected ? colors.selected : color.withValues(alpha: 0.55),
      );
    // A coloured tick at the start, like a tab on a file folder.
    if (rect.width > 14) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 5, rect.center.dy - 5, 2.5, 10),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }
    final handle = selected && stretchable;
    final room = rect.width - 22 - (handle ? 10 : 0);
    if (room > 8) {
      _label(
        canvas,
        text,
        Offset(rect.left + 13, rect.center.dy - 7),
        room,
        _ink(color),
      );
    }
    if (handle) _paintHandles(canvas, rect, left: false);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double maxWidth,
    Color color, {
    bool mono = false,
  }) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: mono ? CutFonts.mono : CutFonts.ui,
          fontSize: mono ? 10.5 : 11.5,
          height: 14 / 11.5,
          fontWeight: FontWeight.w500,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: mono
              ? const [Shadow(color: Color(0x99000000), blurRadius: 3)]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, maxWidth));
    label.paint(canvas, at);
  }

  void _paintGuide(
    Canvas canvas,
    double x,
    double top,
    double bottom, {
    required double width,
  }) {
    final r = Rect.fromLTRB(x - width / 2, top, x + width / 2, bottom);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(4)),
        Paint()
          ..color = colors.guide.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(width / 2)),
        Paint()..color = colors.guide,
      );
  }

  void _paintTrimBubble(Canvas canvas, ({double x, Duration delta}) trim) {
    final ms = trim.delta.inMilliseconds;
    final sign = ms > 0 ? '+' : (ms < 0 ? '−' : '±');
    final text = '$sign${(ms.abs() / 1000).toStringAsFixed(1)} s';
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: CutFonts.mono,
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w600,
          color: Cut.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = label.width + 14;
    const h = 20.0;
    final left = (trim.x - w / 2).clamp(
      visible.left + 2,
      visible.right - w - 2,
    );
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, TimelineRows.videoTop + 16, w, h),
      const Radius.circular(h / 2),
    );
    canvas
      ..drawRRect(
        r.shift(const Offset(0, 2)),
        Paint()
          ..color = const Color(0x99000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawRRect(r, Paint()..color = Cut.surface4)
      ..drawRRect(
        r.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Cut.strokeStrong,
      );
    label.paint(canvas, Offset(left + 7, r.top + (h - label.height) / 2));
  }

  // Only rebuilt when the project, zoom, scroll, selection or a drag
  // changes, and each of those needs a repaint.
  @override
  bool shouldRepaint(TracksPainter old) => true;
}

/// Just the playhead, repainted on every position update without redrawing
/// the tracks: a pink line with a rounded flag on the ruler and a soft glow.
/// While [scrubbing], the flag grows into a timecode.
class PlayheadPainter extends CustomPainter {
  PlayheadPainter({
    required this.geometry,
    required this.position,
    this.color = Cut.marker,
    this.scrubbing = false,
  }) : super(repaint: position);

  final TimelineGeometry geometry;
  final ValueNotifier<Duration> position;
  final Color color;
  final bool scrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final x = geometry.xOf(position.value);
    final paint = Paint()..color = color;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Rect.fromLTWH(x - 1, 8, 2, size.height - 8);
    canvas
      ..drawRect(line.inflate(1.5), glow)
      ..drawRect(line, paint);

    if (scrubbing) {
      final label = TextPainter(
        text: TextSpan(
          text: formatTimecode(position.value),
          style: const TextStyle(
            fontFamily: CutFonts.mono,
            fontSize: 10.5,
            height: 1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = label.width + 12;
      final flag = RRect.fromRectAndRadius(
        Rect.fromLTWH(math.max(0, x - w / 2), 2, w, 18),
        const Radius.circular(6),
      );
      canvas
        ..drawRRect(flag.inflate(1), glow)
        ..drawRRect(flag, paint);
      label.paint(
        canvas,
        Offset(flag.left + 6, flag.top + (18 - label.height) / 2),
      );
      return;
    }
    // A 12 × 16 flag: rounded at the top, pointing down at the line.
    final flag = Path()
      ..moveTo(x - 6, 6)
      ..arcToPoint(Offset(x - 2, 2), radius: const Radius.circular(4))
      ..lineTo(x + 2, 2)
      ..arcToPoint(Offset(x + 6, 6), radius: const Radius.circular(4))
      ..lineTo(x + 6, 12)
      ..quadraticBezierTo(x + 6, 14, x + 4.5, 15)
      ..lineTo(x + 1, 17.5)
      ..quadraticBezierTo(x, 18, x - 1, 17.5)
      ..lineTo(x - 4.5, 15)
      ..quadraticBezierTo(x - 6, 14, x - 6, 12)
      ..close();
    canvas
      ..drawPath(flag, glow)
      ..drawPath(flag, paint);
  }

  @override
  bool shouldRepaint(PlayheadPainter old) =>
      old.geometry.pixelsPerSecond != geometry.pixelsPerSecond ||
      old.geometry.project != geometry.project ||
      old.position != position ||
      old.color != color ||
      old.scrubbing != scrubbing;
}
