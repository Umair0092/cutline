import 'dart:math' as math;

import '../model/project.dart';

/// Which part of a clip the pointer is over.
enum ClipZone { leftEdge, body, rightEdge }

typedef ClipHit = ({int index, ClipZone zone});

/// Converts between timeline time and pixels, and answers "what's under the
/// pointer". Pure, so it's easy to test.
class TimelineGeometry {
  const TimelineGeometry({
    required this.project,
    required this.pixelsPerSecond,
    this.leftPadding = 16,
  });

  final Project project;
  final double pixelsPerSecond;
  final double leftPadding;

  /// How close (in pixels) the pointer must be to a clip edge to grab it.
  static const edgeGrabWidth = 8.0;

  /// How close (in pixels) a dragged edge must be to a snap target to snap.
  static const snapDistance = 8.0;

  double xOf(Duration t) =>
      leftPadding + t.inMicroseconds / 1e6 * pixelsPerSecond;

  Duration timeAt(double x) {
    final seconds = (x - leftPadding) / pixelsPerSecond;
    return Duration(microseconds: (math.max(0, seconds) * 1e6).round());
  }

  double get contentWidth => xOf(project.duration) + leftPadding;

  /// The clip under [x], and whether the pointer is on an edge.
  ClipHit? hitClip(double x) {
    final starts = project.clipStarts;
    for (var i = 0; i < project.clips.length; i++) {
      final left = xOf(starts[i]);
      final right = xOf(starts[i] + project.clips[i].duration);
      if (x < left - edgeGrabWidth / 2 || x > right + edgeGrabWidth / 2) {
        continue;
      }
      // Narrow clips: keep some body so they can still be moved.
      final grab = math.min(edgeGrabWidth, (right - left) / 3);
      if (x <= left + grab) return (index: i, zone: ClipZone.leftEdge);
      if (x >= right - grab) return (index: i, zone: ClipZone.rightEdge);
      return (index: i, zone: ClipZone.body);
    }
    return null;
  }

  /// Snaps [t] to the nearest of [targets] if it's within [snapDistance]
  /// pixels, otherwise returns [t].
  Duration snap(Duration t, Iterable<Duration> targets) {
    Duration? best;
    var bestPx = snapDistance;
    for (final target in targets) {
      final px = (xOf(target) - xOf(t)).abs();
      if (px <= bestPx) {
        best = target;
        bestPx = px;
      }
    }
    return best ?? t;
  }

  /// Where a clip dragged to [x] would land, as an index in the list
  /// without that clip.
  int dropIndex(double x, int draggedIndex) {
    final starts = project.clipStarts;
    var index = 0;
    for (var i = 0; i < project.clips.length; i++) {
      if (i == draggedIndex) continue;
      final mid = xOf(starts[i] + project.clips[i].duration ~/ 2);
      if (x > mid) index++;
    }
    return index;
  }
}

/// Keeps zoom within a sensible range: from a whole hour on screen to
/// individual frames.
double clampZoom(double pixelsPerSecond) =>
    pixelsPerSecond.clamp(0.5, 600).toDouble();
