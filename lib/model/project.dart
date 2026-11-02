import 'package:freezed_annotation/freezed_annotation.dart';

import 'audio_item.dart';
import 'media_asset.dart';
import 'overlay_item.dart';
import 'title_item.dart';
import 'video_clip.dart';

part 'project.freezed.dart';
part 'project.g.dart';

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
