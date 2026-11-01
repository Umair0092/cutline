// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'title_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TitleSpec _$TitleSpecFromJson(Map<String, dynamic> json) => _TitleSpec(
  templateId: json['templateId'] as String,
  fields:
      (json['fields'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  duration: const DurationConverter().fromJson(
    (json['duration'] as num).toInt(),
  ),
);

Map<String, dynamic> _$TitleSpecToJson(_TitleSpec instance) =>
    <String, dynamic>{
      'templateId': instance.templateId,
      'fields': instance.fields,
      'duration': const DurationConverter().toJson(instance.duration),
    };

_TitleItem _$TitleItemFromJson(Map<String, dynamic> json) => _TitleItem(
  id: json['id'] as String,
  spec: TitleSpec.fromJson(json['spec'] as Map<String, dynamic>),
  start: const DurationConverter().fromJson((json['start'] as num).toInt()),
);

Map<String, dynamic> _$TitleItemToJson(_TitleItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'spec': instance.spec.toJson(),
      'start': const DurationConverter().toJson(instance.start),
    };
