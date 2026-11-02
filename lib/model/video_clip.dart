import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';
import 'voice_effect.dart';

part 'video_clip.freezed.dart';
part 'video_clip.g.dart';

/// A piece of a source video on the main track.
///
/// The main track is "magnetic": clips play one after another in list order,
/// so a clip has no start time of its own. Removing a clip closes the gap.
@freezed
abstract class VideoClip with _$VideoClip {
  const VideoClip._();

  const factory VideoClip({
    required String id,
    required String mediaId,
    @DurationConverter() required Duration sourceStart,
    @DurationConverter() required Duration sourceEnd,
    @Default(1.0) double volume,
    @Default(VoiceEffect()) VoiceEffect effect,
  }) = _VideoClip;

  factory VideoClip.fromJson(Map<String, dynamic> json) =>
      _$VideoClipFromJson(json);

  Duration get duration => sourceEnd - sourceStart;
}
