import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  late ProviderContainer container;
  ProjectEditor editor() => container.read(projectEditorProvider.notifier);
  EditorState state() => container.read(projectEditorProvider);

  setUp(() {
    container = ProviderContainer();
    editor().opened(threeClips(), '/tmp/x.cutline');
  });
  tearDown(() => container.dispose());

  test('undo and redo a single command', () {
    editor().run(const RemoveClip('b'));
    expect(state().project.clips, hasLength(2));
    expect(state().undoLabel, 'Delete clip');
    expect(state().hasUnsavedChanges, isTrue);

    editor().undo();
    expect(state().project, threeClips());
    expect(state().hasUnsavedChanges, isFalse);
    expect(state().redoLabel, 'Delete clip');

    editor().redo();
    expect(state().project.clips, hasLength(2));
  });

  test('a group of commands undoes as one step', () {
    editor().runAll('AI edit', [const RemoveClip('a'), const MoveClip('c', 0)]);
    expect(state().project.clips.map((c) => c.id), ['c', 'b']);
    expect(state().undoStack, hasLength(1));

    editor().undo();
    expect(state().project, threeClips());
  });

  test('a failing command leaves the project and history untouched', () {
    expect(
      () => editor().runAll('AI edit', [
        const RemoveClip('a'),
        const RemoveClip('nope'),
      ]),
      throwsA(isA<EditException>()),
    );
    expect(state().project, threeClips());
    expect(state().canUndo, isFalse);
  });

  test('a new edit clears redo', () {
    editor().run(const RemoveClip('a'));
    editor().undo();
    editor().run(const RemoveClip('b'));
    expect(state().canRedo, isFalse);
  });

  test('saving marks the project clean', () {
    editor().run(const RemoveClip('a'));
    editor().saved('/tmp/y.cutline');
    expect(state().hasUnsavedChanges, isFalse);
    expect(state().projectPath, '/tmp/y.cutline');
  });
}
