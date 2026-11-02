// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AudioMix _$AudioMixFromJson(Map<String, dynamic> json) => _AudioMix(
  original: (json['original'] as num?)?.toDouble() ?? 1.0,
  voiceover: (json['voiceover'] as num?)?.toDouble() ?? 1.0,
  duck: json['duck'] as bool? ?? true,
);

Map<String, dynamic> _$AudioMixToJson(_AudioMix instance) => <String, dynamic>{
  'original': instance.original,
  'voiceover': instance.voiceover,
  'duck': instance.duck,
};

_AudioItem _$AudioItemFromJson(Map<String, dynamic> json) => _AudioItem(
  id: json['id'] as String,
  mediaId: json['mediaId'] as String,
  role: $enumDecode(_$AudioRoleEnumMap, json['role']),
  start: const DurationConverter().fromJson((json['start'] as num).toInt()),
  sourceStart: const DurationConverter().fromJson(
    (json['sourceStart'] as num).toInt(),
  ),
  sourceEnd: const DurationConverter().fromJson(
    (json['sourceEnd'] as num).toInt(),
  ),
  volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
  fadeIn: json['fadeIn'] == null
      ? Duration.zero
      : const DurationConverter().fromJson((json['fadeIn'] as num).toInt()),
  fadeOut: json['fadeOut'] == null
      ? Duration.zero
      : const DurationConverter().fromJson((json['fadeOut'] as num).toInt()),
  effect: json['effect'] == null
      ? const VoiceEffect()
      : VoiceEffect.fromJson(json['effect'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AudioItemToJson(_AudioItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mediaId': instance.mediaId,
      'role': _$AudioRoleEnumMap[instance.role]!,
      'start': const DurationConverter().toJson(instance.start),
      'sourceStart': const DurationConverter().toJson(instance.sourceStart),
      'sourceEnd': const DurationConverter().toJson(instance.sourceEnd),
      'volume': instance.volume,
      'fadeIn': const DurationConverter().toJson(instance.fadeIn),
      'fadeOut': const DurationConverter().toJson(instance.fadeOut),
      'effect': instance.effect.toJson(),
    };

const _$AudioRoleEnumMap = {
  AudioRole.voiceover: 'voiceover',
  AudioRole.music: 'music',
  AudioRole.effect: 'effect',
};
