// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Project _$ProjectFromJson(Map<String, dynamic> json) => _Project(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? Project.currentSchemaVersion,
  name: json['name'] as String? ?? 'Untitled',
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MediaAsset>[],
  clips:
      (json['clips'] as List<dynamic>?)
          ?.map((e) => VideoClip.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <VideoClip>[],
  overlays:
      (json['overlays'] as List<dynamic>?)
          ?.map((e) => OverlayItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <OverlayItem>[],
  audio:
      (json['audio'] as List<dynamic>?)
          ?.map((e) => AudioItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AudioItem>[],
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'name': instance.name,
  'media': instance.media.map((e) => e.toJson()).toList(),
  'clips': instance.clips.map((e) => e.toJson()).toList(),
  'overlays': instance.overlays.map((e) => e.toJson()).toList(),
  'audio': instance.audio.map((e) => e.toJson()).toList(),
};
