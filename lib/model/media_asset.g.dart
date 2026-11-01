// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaAsset _$MediaAssetFromJson(Map<String, dynamic> json) => _MediaAsset(
  id: json['id'] as String,
  path: json['path'] as String,
  kind: $enumDecode(_$MediaKindEnumMap, json['kind']),
  duration: json['duration'] == null
      ? Duration.zero
      : const DurationConverter().fromJson((json['duration'] as num).toInt()),
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
  hasAudio: json['hasAudio'] as bool? ?? false,
  frameRate: (json['frameRate'] as num?)?.toDouble() ?? 30.0,
);

Map<String, dynamic> _$MediaAssetToJson(_MediaAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'kind': _$MediaKindEnumMap[instance.kind]!,
      'duration': const DurationConverter().toJson(instance.duration),
      'width': instance.width,
      'height': instance.height,
      'hasAudio': instance.hasAudio,
      'frameRate': instance.frameRate,
    };

const _$MediaKindEnumMap = {
  MediaKind.video: 'video',
  MediaKind.audio: 'audio',
  MediaKind.image: 'image',
  MediaKind.gif: 'gif',
};
