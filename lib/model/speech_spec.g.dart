// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpeechSpec _$SpeechSpecFromJson(Map<String, dynamic> json) => _SpeechSpec(
  text: json['text'] as String,
  engine:
      $enumDecodeNullable(_$VoiceEngineEnumMap, json['engine']) ??
      VoiceEngine.system,
  voice: json['voice'] as String? ?? '',
  speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$SpeechSpecToJson(_SpeechSpec instance) =>
    <String, dynamic>{
      'text': instance.text,
      'engine': _$VoiceEngineEnumMap[instance.engine]!,
      'voice': instance.voice,
      'speed': instance.speed,
    };

const _$VoiceEngineEnumMap = {
  VoiceEngine.system: 'system',
  VoiceEngine.groq: 'groq',
};
