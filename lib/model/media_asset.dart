import 'package:freezed_annotation/freezed_annotation.dart';

import 'duration_converter.dart';

part 'media_asset.freezed.dart';
part 'media_asset.g.dart';

enum MediaKind { video, audio, image, gif }

/// A file the project uses.
///
/// Imported videos stay where they are and [path] is absolute. Files the app
/// creates or downloads (memes, recordings, generated voice) live inside the
/// project folder and [path] is relative to it, starting with `assets/`.
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
  }) = _MediaAsset;

  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetFromJson(json);
}
