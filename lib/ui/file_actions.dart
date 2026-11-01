import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/chat_controller.dart';
import '../editing/project_editor.dart';
import '../storage/chat_store.dart';
import '../storage/project_store.dart';

const _projectType = XTypeGroup(
  label: 'Cutline project',
  extensions: ['cutline'],
  uniformTypeIdentifiers: ['com.umair0092.cutline.project'],
);

/// New, Open, Save and Save As. Errors are shown in a snackbar.
class FileActions {
  FileActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;
  final _store = const ProjectStore();

  ProjectEditor get _editor => ref.read(projectEditorProvider.notifier);
  EditorState get _state => ref.read(projectEditorProvider);

  Future<void> newProject() async {
    if (!await _confirmDiscard()) return;
    _editor.newProject();
    ref.read(chatProvider.notifier).clear();
  }

  Future<void> open() async {
    if (!await _confirmDiscard()) return;
    final path = await _pickProjectToOpen();
    if (path == null) return;
    try {
      _editor.opened(await _store.load(path), path);
      ref.read(chatProvider.notifier).load(await const ChatStore().load(path));
    } on ProjectFileException catch (e) {
      _showError(e.message);
    }
  }

  /// Returns false if the user cancelled.
  Future<bool> save() async {
    final path = _state.projectPath;
    if (path == null) return saveAs();
    return _writeTo(path);
  }

  Future<bool> saveAs() async {
    final location = await getSaveLocation(
      suggestedName: '${_state.project.name}${ProjectStore.extension}',
      acceptedTypeGroups: [_projectType],
    );
    if (location == null) return false;
    var path = location.path;
    if (p.extension(path) != ProjectStore.extension) {
      path += ProjectStore.extension;
    }
    if (FileSystemEntity.isFileSync(path)) {
      _showError('${p.basename(path)} already exists and is not a project.');
      return false;
    }
    return _writeTo(path);
  }

  Future<bool> _writeTo(String path) async {
    final name = p.basenameWithoutExtension(path);
    try {
      await _store.save(
        _state.project.copyWith(name: name),
        path,
        previousPath: _state.projectPath,
      );
      await const ChatStore().save(path, ref.read(chatProvider));
    } on FileSystemException catch (e) {
      _showError('Could not save: ${e.message}');
      return false;
    }
    _editor.saved(path, name: name);
    return true;
  }

  Future<String?> _pickProjectToOpen() async {
    // On macOS a .cutline folder is a document package and shows up as a
    // single file. Windows has no packages, so pick the folder instead.
    if (Platform.isWindows) {
      final dir = await getDirectoryPath(confirmButtonText: 'Open');
      return dir;
    }
    final file = await openFile(acceptedTypeGroups: [_projectType]);
    return file?.path;
  }

  /// Asks to save unsaved changes. Returns false if the user cancelled.
  Future<bool> _confirmDiscard() async {
    if (!_state.hasUnsavedChanges) return true;
    final choice = await showDialog<_DiscardChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save changes to "${_state.project.name}"?'),
        content: const Text('Your changes will be lost if you don\'t save.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.discard),
            child: const Text('Don\'t Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.cancel),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return switch (choice) {
      _DiscardChoice.discard => true,
      _DiscardChoice.save => await save(),
      _DiscardChoice.cancel || null => false,
    };
  }

  void _showError(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _DiscardChoice { save, discard, cancel }
