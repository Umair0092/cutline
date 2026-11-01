import 'dart:io';

import 'package:crypto/crypto.dart';

/// A key for caching things made from a media file (thumbnails, waveforms,
/// transcripts). Changes when the file is replaced or edited.
String mediaCacheKey(String path) {
  final stat = File(path).statSync();
  final key = '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  return sha1.convert(key.codeUnits).toString();
}
