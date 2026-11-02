import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../model/title_item.dart';
import '../storage/project_store.dart';
import 'templates.dart';

/// Pictures used by title templates (a logo, a photo), decoded once and
/// kept by file path. Templates paint synchronously, so the picture must
/// be loaded first: renderers wait for [ensure]; live previews ask with
/// [get] and repaint when it's ready (this is a [Listenable]).
class TitleImages extends ChangeNotifier {
  TitleImages._();

  static final instance = TitleImages._();

  final _images = <String, ui.Image>{};
  final _loading = <String, Future<void>>{};
  final _failed = <String>{};

  /// The decoded picture at [path], or null while it loads (or if it
  /// can't be read). Starts loading it if needed.
  ui.Image? get(String path) {
    final image = _images[path];
    if (image == null && !_failed.contains(path)) unawaited(_load(path));
    return image;
  }

  Future<void> ensure(Iterable<String> paths) =>
      Future.wait([for (final p in paths) _load(p)]);

  Future<void> _load(String path) => _loading[path] ??= () async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _images[path] = frame.image;
      notifyListeners();
    } on Object catch (e) {
      _failed.add(path);
      debugPrint('Could not load title image $path: $e');
    }
  }();

  /// Forget a picture, e.g. after it was replaced on disk.
  void evict(String path) {
    _images.remove(path)?.dispose();
    _loading.remove(path);
    _failed.remove(path);
  }
}

/// Paths of the pictures [spec] uses, resolved against the project folder.
List<String> titleImagePaths(TitleSpec spec, String? projectPath) {
  final template = templateById(spec.templateId);
  if (template == null) return const [];
  return [
    for (final f in template.fields)
      if (f.kind == FieldKind.image && (spec.fields[f.key] ?? '').isNotEmpty)
        ProjectStore.resolve(spec.fields[f.key]!, projectPath),
  ];
}

/// Field values for [spec] that can look up its pictures.
TitleValues titleValues(TitleSpec spec, String? projectPath) {
  final template = templateById(spec.templateId)!;
  return TitleValues(
    template,
    spec.fields,
    image: (value) =>
        TitleImages.instance.get(ProjectStore.resolve(value, projectPath)),
  );
}
