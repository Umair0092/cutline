import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/project.dart';
import 'edit_command.dart';

/// One step in the undo history. A step can hold several commands (an AI
/// change is often more than one edit) and undoes as a whole.
class HistoryEntry {
  const HistoryEntry({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final Project before;
  final Project after;
}

class EditorState {
  const EditorState({
    required this.project,
    this.savedProject,
    this.projectPath,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  final Project project;

  /// The project as it was last saved or opened; null if never saved.
  final Project? savedProject;

  /// Folder of the open `.cutline` project, null until first saved.
  final String? projectPath;

  final List<HistoryEntry> undoStack;
  final List<HistoryEntry> redoStack;

  bool get hasUnsavedChanges => project != (savedProject ?? const Project());
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  String? get undoLabel => undoStack.lastOrNull?.label;
  String? get redoLabel => redoStack.lastOrNull?.label;

  EditorState copyWith({
    Project? project,
    Project? savedProject,
    String? projectPath,
    List<HistoryEntry>? undoStack,
    List<HistoryEntry>? redoStack,
  }) {
    return EditorState(
      project: project ?? this.project,
      savedProject: savedProject ?? this.savedProject,
      projectPath: projectPath ?? this.projectPath,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

final projectEditorProvider = NotifierProvider<ProjectEditor, EditorState>(
  ProjectEditor.new,
);

/// Owns the open project and its undo history. Every change, from the UI or
/// the AI, goes through [run] or [runAll].
class ProjectEditor extends Notifier<EditorState> {
  static const maxHistory = 200;

  @override
  EditorState build() => const EditorState(project: Project());

  /// Applies [command] as one undo step. Throws [EditException] and leaves
  /// the project unchanged if the command is invalid.
  void run(EditCommand command) => runAll(command.label, [command]);

  /// Applies [commands] in order as a single undo step labelled [label].
  /// If any command fails, none of them are applied.
  void runAll(String label, List<EditCommand> commands) {
    if (commands.isEmpty) return;
    final before = state.project;
    var after = before;
    for (final command in commands) {
      after = command.apply(after);
    }
    if (after == before) return;
    final undo = [
      ...state.undoStack,
      HistoryEntry(label: label, before: before, after: after),
    ];
    state = state.copyWith(
      project: after,
      undoStack: undo.length > maxHistory
          ? undo.sublist(undo.length - maxHistory)
          : undo,
      redoStack: const [],
    );
  }

  void undo() {
    final entry = state.undoStack.lastOrNull;
    if (entry == null) return;
    state = state.copyWith(
      project: entry.before,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, entry],
    );
  }

  void redo() {
    final entry = state.redoStack.lastOrNull;
    if (entry == null) return;
    state = state.copyWith(
      project: entry.after,
      undoStack: [...state.undoStack, entry],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
    );
  }

  /// Starts over with an empty project.
  void newProject() => state = const EditorState(project: Project());

  /// Replaces the state after opening a project from disk.
  void opened(Project project, String path) {
    state = EditorState(
      project: project,
      savedProject: project,
      projectPath: path,
    );
  }

  /// Records that the current project was written to [path] under [name].
  /// The name comes from the file name, so it isn't an undoable edit.
  void saved(String path, {String? name}) {
    final project = name == null
        ? state.project
        : state.project.copyWith(name: name);
    state = state.copyWith(
      project: project,
      savedProject: project,
      projectPath: path,
      undoStack: [
        for (final e in state.undoStack)
          HistoryEntry(
            label: e.label,
            before: e.before.copyWith(name: project.name),
            after: e.after.copyWith(name: project.name),
          ),
      ],
      redoStack: [
        for (final e in state.redoStack)
          HistoryEntry(
            label: e.label,
            before: e.before.copyWith(name: project.name),
            after: e.after.copyWith(name: project.name),
          ),
      ],
    );
  }
}
