// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
    };

const _$AudioRoleEnumMap = {
  AudioRole.voiceover: 'voiceover',
  AudioRole.music: 'music',
  AudioRole.effect: 'effect',
};
