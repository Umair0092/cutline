import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_spec.freezed.dart';
part 'speech_spec.g.dart';

/// Which text-to-speech service made a line.
enum VoiceEngine {
  /// The computer's own voices: free, offline, sound differs by OS.
  system,

  /// Groq's Orpheus voices: more natural, uses your Groq key.
  groq,
}

/// What a generated voiceover line says and how, so it can be made again
/// after an edit.
@freezed
abstract class SpeechSpec with _$SpeechSpec {
  const factory SpeechSpec({
    required String text,
    @Default(VoiceEngine.system) VoiceEngine engine,

    /// A voice name for the engine; empty for its default.
    @Default('') String voice,

    /// 1 is normal; 0.75 to 1.5.
    @Default(1.0) double speed,
  }) = _SpeechSpec;

  factory SpeechSpec.fromJson(Map<String, dynamic> json) =>
      _$SpeechSpecFromJson(json);
}
