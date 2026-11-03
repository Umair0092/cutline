import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/chat_controller.dart';
import '../editing/project_editor.dart';
import '../storage/chat_store.dart';
import '../storage/project_store.dart';
import 'dialogs/dialog_kit.dart';
import 'navigation.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

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
    await showEditor();
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
      return;
    }
    await showEditor();
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
        previousPath: _state.workPath,
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
  Future<bool> confirmDiscard() => _confirmDiscard();

  Future<bool> _confirmDiscard() async {
    if (!_state.hasUnsavedChanges) return true;
    final choice = await showDialog<_DiscardChoice>(
      context: context,
      builder: (context) => CutDialog(
        width: 460,
        icon: CutIcons.warning,
        title: 'Save your changes?',
        subtitle:
            '"${_state.project.name}" has edits that aren\'t saved yet. '
            'They\'ll be lost if you don\'t save.',
        actions: [
          QuietButton(
            label: 'Don\'t Save',
            danger: true,
            transparent: true,
            onPressed: () => Navigator.pop(context, _DiscardChoice.discard),
          ),
          QuietButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, _DiscardChoice.cancel),
          ),
          PrimaryButton(
            key: const Key('discard-save'),
            label: 'Save',
            onPressed: () => Navigator.pop(context, _DiscardChoice.save),
          ),
        ],
        child: const SizedBox.shrink(),
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
