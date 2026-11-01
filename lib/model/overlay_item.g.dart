// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OverlayTransform _$OverlayTransformFromJson(Map<String, dynamic> json) =>
    _OverlayTransform(
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 0.3,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$OverlayTransformToJson(_OverlayTransform instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'scale': instance.scale,
      'rotation': instance.rotation,
      'opacity': instance.opacity,
    };

_OverlayItem _$OverlayItemFromJson(Map<String, dynamic> json) => _OverlayItem(
  id: json['id'] as String,
  mediaId: json['mediaId'] as String,
  start: const DurationConverter().fromJson((json['start'] as num).toInt()),
  duration: const DurationConverter().fromJson(
    (json['duration'] as num).toInt(),
  ),
  transform: json['transform'] == null
      ? const OverlayTransform()
      : OverlayTransform.fromJson(json['transform'] as Map<String, dynamic>),
  layer: (json['layer'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$OverlayItemToJson(_OverlayItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mediaId': instance.mediaId,
      'start': const DurationConverter().toJson(instance.start),
      'duration': const DurationConverter().toJson(instance.duration),
      'transform': instance.transform.toJson(),
      'layer': instance.layer,
    };
