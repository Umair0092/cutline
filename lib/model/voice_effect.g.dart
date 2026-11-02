// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_effect.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VoiceEffect _$VoiceEffectFromJson(Map<String, dynamic> json) => _VoiceEffect(
  pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
  speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
  robot: json['robot'] as bool? ?? false,
  denoise: json['denoise'] as bool? ?? false,
  normalize: json['normalize'] as bool? ?? false,
);

Map<String, dynamic> _$VoiceEffectToJson(_VoiceEffect instance) =>
    <String, dynamic>{
      'pitch': instance.pitch,
      'speed': instance.speed,
      'robot': instance.robot,
      'denoise': instance.denoise,
      'normalize': instance.normalize,
    };
