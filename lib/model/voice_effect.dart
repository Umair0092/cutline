import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_effect.freezed.dart';
part 'voice_effect.g.dart';

/// Changes to how a clip's sound plays: pitch, speed, and cleanup. Applied
/// the same way in the preview and the export.
@freezed
abstract class VoiceEffect with _$VoiceEffect {
  const VoiceEffect._();

  const factory VoiceEffect({
    /// Semitones up (positive) or down (negative), -12 to 12. Speed and
    /// length stay the same.
    @Default(0.0) double pitch,

    /// How fast it plays, 0.5 to 2, without changing pitch. Only for audio
    /// on the audio track (the main track's video can't change speed).
    @Default(1.0) double speed,

    /// A metallic, monotone "robot" sound.
    @Default(false) bool robot,

    /// Take out steady background noise (hiss, hum, fans).
    @Default(false) bool denoise,

    /// Even out the loudness to a standard level.
    @Default(false) bool normalize,
  }) = _VoiceEffect;

  factory VoiceEffect.fromJson(Map<String, dynamic> json) =>
      _$VoiceEffectFromJson(json);

  static const none = VoiceEffect();

  bool get isNone => this == none;
}

/// Ready-made effects.
enum VoicePreset {
  deeper('Deeper', VoiceEffect(pitch: -3)),
  higher('Higher', VoiceEffect(pitch: 3)),
  chipmunk('Chipmunk', VoiceEffect(pitch: 8)),
  robot('Robot', VoiceEffect(robot: true, pitch: -1));

  const VoicePreset(this.label, this.effect);

  final String label;
  final VoiceEffect effect;
}
