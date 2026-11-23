import 'package:freezed_annotation/freezed_annotation.dart';

import 'audio_item.dart';
import 'media_asset.dart';
import 'overlay_item.dart';
import 'title_item.dart';
import 'video_clip.dart';

part 'project.freezed.dart';
part 'project.g.dart';

/// The shape the finished video is exported (and previewed) in. [source]
/// keeps the footage's own shape; the others reframe it, letterboxing with
/// black bars when the footage doesn't fill the new shape.
enum ReframeAspect {
  source('Original', null),
  wide('16:9', 16 / 9),
  vertical('9:16', 9 / 16),
  square('1:1', 1);

  const ReframeAspect(this.label, this.ratio);

  final String label;

  /// Width ÷ height, or null to keep the source shape.
  final double? ratio;
}

/// The output width and height (short side at most [maxShort], even numbers)
/// for footage of [srcW]×[srcH] in the given [aspect]. Used for both export
/// and the preview frame, so they always match.
({int width, int height}) outputSize(
  int srcW,
  int srcH,
  ReframeAspect aspect, {
  int maxShort = 1080,
}) {
  final sw = (srcW > 0 ? srcW : 1920).toDouble();
  final sh = (srcH > 0 ? srcH : 1080).toDouble();
  double w;
  double h;
  final r = aspect.ratio;
  if (r == null) {
    final short = sw < sh ? sw : sh;
    final k = short > maxShort ? maxShort / short : 1.0;
    w = sw * k;
    h = sh * k;
  } else if (r >= 1) {
    h = maxShort.toDouble();
    w = h * r;
  } else {
    w = maxShort.toDouble();
    h = w / r;
  }
  int even(double v) {
    final n = v.round();
    return n.isOdd ? n + 1 : n;
  }

  return (width: even(w), height: even(h));
}

/// Everything about an edit. Immutable: every change makes a new [Project],
/// which is what makes undo and AI edits simple and safe.
@freezed
abstract class Project with _$Project {
  const Project._();

  static const currentSchemaVersion = 1;

  const factory Project({
    @Default(Project.currentSchemaVersion) int schemaVersion,
    @Default('Untitled') String name,
    @Default(<MediaAsset>[]) List<MediaAsset> media,
    @Default(<VideoClip>[]) List<VideoClip> clips,
    @Default(<OverlayItem>[]) List<OverlayItem> overlays,
    @Default(<AudioItem>[]) List<AudioItem> audio,
    @Default(<TitleItem>[]) List<TitleItem> titles,
    @Default(AudioMix()) AudioMix mix,
    @Default(ReframeAspect.source) ReframeAspect aspect,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);

  /// Length of the main track.
  Duration get duration =>
      clips.fold(Duration.zero, (total, clip) => total + clip.duration);

  /// Where each clip starts on the timeline, in the same order as [clips].
  List<Duration> get clipStarts {
    final starts = <Duration>[];
    var t = Duration.zero;
    for (final clip in clips) {
      starts.add(t);
      t += clip.duration;
    }
    return starts;
  }

  /// The clip playing at [time] on the timeline and the matching time inside
  /// its source file, or null past the end.
  ({int index, Duration sourceTime})? clipAt(Duration time) {
    var t = Duration.zero;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      if (time < t + clip.duration) {
        return (index: i, sourceTime: clip.sourceStart + (time - t));
      }
      t += clip.duration;
    }
    return null;
  }

  MediaAsset? mediaById(String id) =>
      media.where((m) => m.id == id).firstOrNull;

  int clipIndex(String id) => clips.indexWhere((c) => c.id == id);
}
