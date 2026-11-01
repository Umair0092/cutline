// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VideoClip _$VideoClipFromJson(Map<String, dynamic> json) => _VideoClip(
  id: json['id'] as String,
  mediaId: json['mediaId'] as String,
  sourceStart: const DurationConverter().fromJson(
    (json['sourceStart'] as num).toInt(),
  ),
  sourceEnd: const DurationConverter().fromJson(
    (json['sourceEnd'] as num).toInt(),
  ),
  volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$VideoClipToJson(_VideoClip instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mediaId': instance.mediaId,
      'sourceStart': const DurationConverter().toJson(instance.sourceStart),
      'sourceEnd': const DurationConverter().toJson(instance.sourceEnd),
      'volume': instance.volume,
    };
