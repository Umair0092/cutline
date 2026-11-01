import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';

part 'overlay_item.freezed.dart';
part 'overlay_item.g.dart';

/// Where an overlay sits on the frame. [x] and [y] are the centre of the
/// overlay as a fraction of the frame (0..1), [scale] is its width as a
/// fraction of the frame width.
@freezed
abstract class OverlayTransform with _$OverlayTransform {
  const factory OverlayTransform({
    @Default(0.5) double x,
    @Default(0.5) double y,
    @Default(0.3) double scale,
    @Default(0.0) double rotation,
    @Default(1.0) double opacity,
  }) = _OverlayTransform;

  factory OverlayTransform.fromJson(Map<String, dynamic> json) =>
      _$OverlayTransformFromJson(json);
}

/// Something drawn on top of the video for a while: an image, GIF or
/// video sticker (and later, titles).
@freezed
abstract class OverlayItem with _$OverlayItem {
  const OverlayItem._();

  const factory OverlayItem({
    required String id,
    required String mediaId,
    @DurationConverter() required Duration start,
    @DurationConverter() required Duration duration,
    @Default(OverlayTransform()) OverlayTransform transform,
    @Default(0) int layer,
  }) = _OverlayItem;

  factory OverlayItem.fromJson(Map<String, dynamic> json) =>
      _$OverlayItemFromJson(json);

  Duration get end => start + duration;
}
