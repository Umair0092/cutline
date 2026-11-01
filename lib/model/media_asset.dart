import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';
import 'title_item.dart';

part 'media_asset.freezed.dart';
part 'media_asset.g.dart';

enum MediaKind { video, audio, image, gif }

/// A file the project uses.
///
/// Imported videos stay where they are and [path] is absolute. Files the app
/// creates or downloads (memes, recordings, generated voice) live inside the
/// project folder and [path] is relative to it, starting with `assets/`.
/// Intros placed before the video are made by the app, so they're assets.
@freezed
abstract class MediaAsset with _$MediaAsset {
  const factory MediaAsset({
    required String id,
    required String path,
    required MediaKind kind,
    @DurationConverter() @Default(Duration.zero) Duration duration,
    @Default(0) int width,
    @Default(0) int height,
    @Default(false) bool hasAudio,
    @Default(30.0) double frameRate,

    /// Set when the app made this file from a title template (an intro
    /// placed before the video), so it can be re-made after edits.
    TitleSpec? title,
  }) = _MediaAsset;

  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetFromJson(json);
}
