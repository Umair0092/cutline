import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';

import '../model/overlay_item.dart';

/// How long the enter and exit animations take.
const overlayAnimationTime = 0.35;

/// Where an overlay sits on a frame of [frame] size, before any animation
/// or rotation. [aspect] is the overlay's width / height.
ui.Rect overlayRect(ui.Size frame, double aspect, OverlayTransform t) {
  final w = t.scale * frame.width;
  final h = w / (aspect > 0 ? aspect : 1);
  return ui.Rect.fromCenter(
    center: ui.Offset(t.x * frame.width, t.y * frame.height),
    width: w,
    height: h,
  );
}

/// 0 when the overlay is fully out, 1 when it's fully in, for local time
/// [t] seconds of an overlay [total] seconds long.
double overlayPresence(double t, double total) {
  final ramp = math.min(overlayAnimationTime, total / 2);
  if (ramp <= 0) return 1;
  return math.min(t / ramp, (total - t) / ramp).clamp(0.0, 1.0);
}

/// Draws [image] as overlay [item] at local time [t] seconds.
void paintOverlay(
  ui.Canvas canvas,
  ui.Size frame,
  ui.Image image,
  OverlayItem item,
  double t, {
  OverlayTransform? transform,
}) {
  final tr = transform ?? item.transform;
  final rect = overlayRect(frame, image.width / image.height, tr);
  final total = item.duration.inMicroseconds / 1e6;
  final p = overlayPresence(t, total);
  var scale = 1.0;
  var opacity = tr.opacity;
  var dy = 0.0;
  switch (item.animation) {
    case OverlayAnimation.none:
      break;
    case OverlayAnimation.pop:
      scale = Curves.easeOutBack.transform(p);
    case OverlayAnimation.fade:
      opacity *= p;
    case OverlayAnimation.slide:
      // Up from below the bottom edge.
      dy =
          (1 - Curves.easeOutCubic.transform(p)) *
          (frame.height - rect.top + rect.height * 0.2);
  }
  if (scale <= 0 || opacity <= 0) return;
  canvas
    ..save()
    ..translate(rect.center.dx, rect.center.dy + dy)
    ..rotate(tr.rotation * math.pi / 180)
    ..scale(scale);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromCenter(
      center: ui.Offset.zero,
      width: rect.width,
      height: rect.height,
    ),
    ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = ui.Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
  );
  canvas.restore();
}

/// [point] in the overlay's own unrotated frame, so hit tests work on a
/// rotated overlay.
ui.Offset unrotate(ui.Offset point, ui.Rect rect, double degrees) {
  final a = -degrees * math.pi / 180;
  final d = point - rect.center;
  return rect.center +
      ui.Offset(
        d.dx * math.cos(a) - d.dy * math.sin(a),
        d.dx * math.sin(a) + d.dy * math.cos(a),
      );
}

/// [point] rotated around the overlay's centre by its rotation, the
/// opposite of [unrotate].
ui.Offset rotateAround(ui.Offset point, ui.Rect rect, double degrees) =>
    unrotate(point, rect, -degrees);
