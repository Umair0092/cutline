import 'package:flutter/foundation.dart';

import '../editing/commands.dart';
import '../model/project.dart';
import '../model/video_clip.dart';
import 'timeline_geometry.dart';

/// A drag in progress. Nothing is committed to the project until the drag
/// ends, so a drag is one undo step.
sealed class TimelineDrag {
  const TimelineDrag();
}

/// Dragging a clip's edge. [edgeTime] is where the edge is now, on the
/// timeline as it was when the drag started.
class TrimDrag extends TimelineDrag {
  const TrimDrag({
    required this.index,
    required this.left,
    required this.edgeTime,
  });

  final int index;
  final bool left;
  final Duration edgeTime;
}

/// Dragging a clip to a new place. [dx] is how far it moved, in pixels.
class MoveDrag extends TimelineDrag {
  const MoveDrag({required this.index, required this.dx, required this.x});

  final int index;
  final double dx;

  /// Pointer position, used to work out the drop slot.
  final double x;
}

/// Where to draw a clip.
@immutable
class ClipBox {
  const ClipBox({
    required this.clip,
    required this.left,
    required this.right,
    required this.timelineStart,
    this.floating = false,
  });

  final VideoClip clip;
  final double left;
  final double right;

  /// Timeline time at [left]; with [clip.sourceStart] this maps x to a
  /// source time for thumbnails and waveforms.
  final Duration timelineStart;

  /// Being dragged to a new place: drawn translucent on top.
  final bool floating;

  double get width => right - left;
}

/// Works out the new source range for a trim drag, snapped and kept inside
/// the source file and the minimum clip length.
({Duration sourceStart, Duration sourceEnd}) trimResult(
  Project project,
  TrimDrag drag,
) {
  final clip = project.clips[drag.index];
  final media = project.mediaById(clip.mediaId)!;
  final clipStart = project.clipStarts[drag.index];
  if (drag.left) {
    var start = clip.sourceStart + (drag.edgeTime - clipStart);
    if (start < Duration.zero) start = Duration.zero;
    if (clip.sourceEnd - start < minClipDuration) {
      start = clip.sourceEnd - minClipDuration;
    }
    return (sourceStart: start, sourceEnd: clip.sourceEnd);
  }
  var end = clip.sourceStart + (drag.edgeTime - clipStart);
  if (end > media.duration) end = media.duration;
  if (end - clip.sourceStart < minClipDuration) {
    end = clip.sourceStart + minClipDuration;
  }
  return (sourceStart: clip.sourceStart, sourceEnd: end);
}

/// Lays out the main track, showing [drag] if one is in progress.
///
/// While trimming the left edge, the clip's left side follows the pointer
/// and the gap closes when the drag ends (the track is magnetic). While
/// trimming the right edge, clips after it slide along live.
List<ClipBox> layoutClips(TimelineGeometry g, {TimelineDrag? drag}) {
  final project = g.project;
  final boxes = <ClipBox>[];
  var t = Duration.zero;
  ClipBox? floating;
  for (var i = 0; i < project.clips.length; i++) {
    var clip = project.clips[i];
    var start = t;
    if (drag is TrimDrag && drag.index == i) {
      final r = trimResult(project, drag);
      if (drag.left) start = t + (r.sourceStart - clip.sourceStart);
      clip = clip.copyWith(sourceStart: r.sourceStart, sourceEnd: r.sourceEnd);
    }
    final box = ClipBox(
      clip: clip,
      left: g.xOf(start),
      right: g.xOf(start + clip.duration),
      timelineStart: start,
    );
    if (drag is MoveDrag && drag.index == i) {
      floating = ClipBox(
        clip: clip,
        left: box.left + drag.dx,
        right: box.right + drag.dx,
        timelineStart: start,
        floating: true,
      );
    }
    boxes.add(box);
    t = start + clip.duration;
  }
  return [...boxes, ?floating];
}
