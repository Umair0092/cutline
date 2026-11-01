import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';

part 'audio_item.freezed.dart';
part 'audio_item.g.dart';

enum AudioRole { voiceover, music, effect }

/// A sound placed on the timeline at [start]: a voiceover, music, or a meme
/// sound. [sourceStart]..[sourceEnd] is the part of the file that plays.
@freezed
abstract class AudioItem with _$AudioItem {
  const AudioItem._();

  const factory AudioItem({
    required String id,
    required String mediaId,
    required AudioRole role,
    @DurationConverter() required Duration start,
    @DurationConverter() required Duration sourceStart,
    @DurationConverter() required Duration sourceEnd,
    @Default(1.0) double volume,
  }) = _AudioItem;

  factory AudioItem.fromJson(Map<String, dynamic> json) =>
      _$AudioItemFromJson(json);

  Duration get duration => sourceEnd - sourceStart;
  Duration get end => start + duration;
}
