import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';

part 'title_item.freezed.dart';
part 'title_item.g.dart';

/// Which template and what goes in it: the editable parts of an intro or
/// title (name, title, colours, font) and how long it lasts.
@freezed
abstract class TitleSpec with _$TitleSpec {
  const factory TitleSpec({
    required String templateId,
    @Default(<String, String>{}) Map<String, String> fields,
    @DurationConverter() required Duration duration,
  }) = _TitleSpec;

  factory TitleSpec.fromJson(Map<String, dynamic> json) =>
      _$TitleSpecFromJson(json);
}

/// A title drawn over the video from [start] for [spec.duration], e.g. an
/// intro over the first seconds or a lower third with your name.
@freezed
abstract class TitleItem with _$TitleItem {
  const TitleItem._();

  const factory TitleItem({
    required String id,
    required TitleSpec spec,
    @DurationConverter() required Duration start,
  }) = _TitleItem;

  factory TitleItem.fromJson(Map<String, dynamic> json) =>
      _$TitleItemFromJson(json);

  Duration get end => start + spec.duration;
}
