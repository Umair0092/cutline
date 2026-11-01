import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project.dart';

class ProjectFileException implements Exception {
  ProjectFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads and writes `.cutline` projects. A project is a folder:
///
///     My Video.cutline/
///       project.json
///       assets/        files the project owns (memes, recordings, voice)
class ProjectStore {
  const ProjectStore();

  static const extension = '.cutline';
  static const projectFile = 'project.json';
  static const assetsDir = 'assets';

  /// Writes [project] into the folder at [path], creating it if needed.
  /// When saving to a new place ([previousPath] differs), the assets folder is
  /// copied along so relative asset paths keep working.
  Future<void> save(
    Project project,
    String path, {
    String? previousPath,
  }) async {
    final dir = Directory(path);
    await Directory(p.join(path, assetsDir)).create(recursive: true);

    if (previousPath != null && !p.equals(previousPath, path)) {
      final oldAssets = Directory(p.join(previousPath, assetsDir));
      if (oldAssets.existsSync()) {
        await for (final entity in oldAssets.list()) {
          if (entity is File) {
            await entity.copy(p.join(path, assetsDir, p.basename(entity.path)));
          }
        }
      }
    }

    // Write to a temp file first so a crash mid-save can't corrupt the
    // existing project.json.
    final json = const JsonEncoder.withIndent('  ').convert(project.toJson());
    final tmp = File(p.join(dir.path, '$projectFile.tmp'));
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(p.join(dir.path, projectFile));
  }

  Future<Project> load(String path) async {
    final file = File(p.join(path, projectFile));
    if (!file.existsSync()) {
      throw ProjectFileException(
        '${p.basename(path)} is not a Cutline project.',
      );
    }
    final Object? json;
    try {
      json = jsonDecode(await file.readAsString());
    } on FormatException {
      throw ProjectFileException('${p.basename(path)} is damaged.');
    }
    if (json is! Map<String, dynamic>) {
      throw ProjectFileException('${p.basename(path)} is damaged.');
    }
    final version = json['schemaVersion'];
    if (version is int && version > Project.currentSchemaVersion) {
      throw ProjectFileException(
        '${p.basename(path)} was made with a newer version of Cutline. '
        'Update the app to open it.',
      );
    }
    try {
      return Project.fromJson(json);
    } on Object {
      throw ProjectFileException('${p.basename(path)} is damaged.');
    }
  }

  /// Absolute path of a media file, resolving project-relative asset paths.
  static String resolve(String mediaPath, String? projectPath) {
    if (p.isAbsolute(mediaPath) || projectPath == null) return mediaPath;
    return p.join(projectPath, mediaPath);
  }
}
