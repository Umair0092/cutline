import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../model/media_asset.dart';
import '../storage/project_store.dart';

const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'];

class ImageImportException implements Exception {
  ImageImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copies a picture into the project's `assets/` folder (so the project
/// keeps working if the original moves) and returns its media entry, with
/// its size read from the file.
Future<MediaAsset> importImage(String source, String workPath) async {
  final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
  if (!imageExtensions.contains(ext)) {
    throw ImageImportException(
      '${p.basename(source)} isn\'t a picture (${imageExtensions.join(', ')}).',
    );
  }
  final bytes = await File(source).readAsBytes();
  final int width;
  final int height;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    width = frame.image.width;
    height = frame.image.height;
    frame.image.dispose();
  } on Object {
    throw ImageImportException('${p.basename(source)} can\'t be read.');
  }
  final id = newId();
  final rel = '${ProjectStore.assetsDir}/img-$id.$ext';
  final file = File(p.join(workPath, rel));
  file.parent.createSync(recursive: true);
  await file.writeAsBytes(bytes);
  return MediaAsset(
    id: id,
    path: rel,
    kind: MediaKind.image,
    width: width,
    height: height,
    name: p.basenameWithoutExtension(source),
  );
}
