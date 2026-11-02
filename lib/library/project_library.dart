import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/chat_controller.dart';
import '../editing/commands.dart';
import '../editing/project_editor.dart';
import '../model/project.dart';
import '../storage/chat_store.dart';
import '../storage/project_store.dart';
import '../transcript/transcription_service.dart';

/// One past edit, as the dashboard shows it.
class ProjectSummary {
  const ProjectSummary({
    required this.path,
    required this.project,
    required this.modified,
  });

  final String path;
  final Project project;
  final DateTime modified;

  String get name => project.name;
  Duration get duration => project.duration;
}

/// Where edits live: a "Projects" folder in the app's support folder, plus
/// projects you saved somewhere else and opened again (remembered in
/// recent.json). Edits in the folder save themselves as you work.
class ProjectLibrary {
  ProjectLibrary(this.root);

  final String root;
  final _store = const ProjectStore();

  File get _recentFile => File(p.join(root, 'recent.json'));

  bool contains(String path) => p.isWithin(root, path);

  List<String> _recent() {
    try {
      return [
        for (final x in jsonDecode(_recentFile.readAsStringSync()) as List)
          x as String,
      ];
    } on Object {
      return [];
    }
  }

  /// Remembers a project saved outside the library, so it shows up too.
  void remember(String path) {
    if (contains(path)) return;
    Directory(root).createSync(recursive: true);
    final list = [path, ..._recent().where((x) => x != path)].take(30);
    _recentFile.writeAsStringSync(jsonEncode(list.toList()));
  }

  /// Every edit, newest first. Unreadable ones are skipped.
  Future<List<ProjectSummary>> list() async {
    final dir = Directory(root);
    final paths = <String>{
      if (dir.existsSync())
        for (final e in dir.listSync())
          if (e is Directory && e.path.endsWith(ProjectStore.extension)) e.path,
      ..._recent().where((x) => Directory(x).existsSync()),
    };
    final out = <ProjectSummary>[];
    for (final path in paths) {
      try {
        final file = File(p.join(path, ProjectStore.projectFile));
        out.add(
          ProjectSummary(
            path: path,
            project: await _store.load(path),
            modified: file.lastModifiedSync(),
          ),
        );
      } on Object {
        // A half-written or foreign folder: leave it out.
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  /// A new, empty project folder in the library for [name].
  String newPath(String name) {
    final safe = name
        .replaceAll(RegExp(r'[^\w\- ]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final stem = safe.isEmpty ? 'Untitled' : safe;
    return p.join(
      root,
      '$stem-${newId().substring(0, 8)}${ProjectStore.extension}',
    );
  }

  /// Deletes an edit in the library, or forgets one saved elsewhere (its
  /// files stay where you put them).
  void delete(String path) {
    if (contains(path)) {
      Directory(path).deleteSync(recursive: true);
    } else {
      _recentFile.writeAsStringSync(
        jsonEncode(_recent().where((x) => x != path).toList()),
      );
    }
  }
}

final projectLibraryProvider = FutureProvider<ProjectLibrary>(
  (ref) async => ProjectLibrary(
    p.join(await ref.watch(supportDirProvider.future), 'Projects'),
  ),
);

/// The dashboard's list. Refresh with `ref.invalidate(projectListProvider)`.
final projectListProvider = FutureProvider<List<ProjectSummary>>(
  (ref) async => (await ref.watch(projectLibraryProvider.future)).list(),
);

/// Saves edits in the library a moment after each change, chat included,
/// so there's no Save step. Projects saved elsewhere keep the usual
/// Save/Save As. Watch this provider to switch it on.
final autosaveProvider = Provider<Autosave>((ref) {
  final autosave = Autosave(ref);
  ref.onDispose(autosave.dispose);
  ref.listen(projectEditorProvider, (_, _) => autosave.schedule());
  ref.listen(chatProvider, (before, now) {
    if (before?.history != now.history) autosave.schedule(chat: true);
  });
  return autosave;
});

class Autosave {
  Autosave(this.ref);

  final Ref ref;
  Timer? _timer;
  bool _chatChanged = false;

  void schedule({bool chat = false}) {
    // Only edits in the library save themselves.
    final path = ref.read(projectEditorProvider).projectPath;
    final library = ref.read(projectLibraryProvider).value;
    if (path == null || library == null || !library.contains(path)) return;
    _chatChanged |= chat;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () => unawaited(flush()));
  }

  /// Saves now if anything changed (used when leaving the editor).
  Future<void> flush() async {
    _timer?.cancel();
    final state = ref.read(projectEditorProvider);
    final path = state.projectPath;
    if (path == null) return;
    final library = await ref.read(projectLibraryProvider.future);
    if (!library.contains(path)) return;
    if (!state.hasUnsavedChanges && !_chatChanged) return;
    final project = state.project;
    try {
      await const ProjectStore().save(project, path);
      await const ChatStore().save(path, ref.read(chatProvider));
      _chatChanged = false;
      // Only mark saved if nothing changed while writing.
      if (ref.read(projectEditorProvider).project == project) {
        ref.read(projectEditorProvider.notifier).saved(path);
      }
    } on FileSystemException {
      // Try again on the next change.
    }
  }

  void dispose() => _timer?.cancel();
}

/// Starts a new edit in the library from [project] (made in the scratch
/// folder), copying its generated files along, and returns its path.
Future<String> saveNewToLibrary(WidgetRef ref, Project project) async {
  final library = await ref.read(projectLibraryProvider.future);
  final path = library.newPath(project.name);
  final state = ref.read(projectEditorProvider);
  await const ProjectStore().save(project, path, previousPath: state.workPath);
  await const ChatStore().save(path, ref.read(chatProvider));
  ref.read(projectEditorProvider.notifier).saved(path, name: project.name);
  ref.invalidate(projectListProvider);
  return path;
}
