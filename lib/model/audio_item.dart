import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';
import 'voice_effect.dart';

part 'audio_item.freezed.dart';
part 'audio_item.g.dart';

/// How the tracks are mixed: the video's own sound, the voiceover track,
/// background music, and what gets quieter when someone talks.
@freezed
abstract class AudioMix with _$AudioMix {
  const factory AudioMix({
    /// The main track's sound (0 mutes it).
    @Default(1.0) double original,
    @Default(1.0) double voiceover,

    /// The music track. Music is evened out first (see audio_mix.dart), so
    /// 1 sits a little under normal speech and the default is a quiet bed.
    @Default(0.6) double music,

    /// Lower the original sound while a voiceover plays ("ducking").
    @Default(true) bool duck,

    /// Lower the music while anyone talks: you in the video or a voiceover.
    @Default(true) bool duckMusic,
  }) = _AudioMix;

  factory AudioMix.fromJson(Map<String, dynamic> json) =>
      _$AudioMixFromJson(json);
}

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
    @DurationConverter() @Default(Duration.zero) Duration fadeIn,
    @DurationConverter() @Default(Duration.zero) Duration fadeOut,
    @Default(VoiceEffect()) VoiceEffect effect,
  }) = _AudioItem;

  factory AudioItem.fromJson(Map<String, dynamic> json) =>
      _$AudioItemFromJson(json);

  /// The part of the file that plays.
  Duration get sourceLength => sourceEnd - sourceStart;

  /// How long it plays on the timeline (shorter when sped up).
  Duration get duration => effect.speed == 1
      ? sourceLength
      : Duration(
          microseconds: (sourceLength.inMicroseconds / effect.speed).round(),
        );
  Duration get end => start + duration;
}
