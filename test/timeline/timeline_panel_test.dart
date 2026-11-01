import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_preview.dart';
import '../fixtures.dart';

void main() {
  late FakePreviewController preview;
  late ProviderContainer container;
  EditorState state() => container.read(projectEditorProvider);
  List<String> ids() => [for (final c in state().project.clips) c.id];

  /// Opens the three-clip project at 20 px/s, so the clips sit at
  /// x 16–216 (a), 216–616 (b), 616–816 (c) inside the tracks.
  Future<Offset> pumpTimeline(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    preview = FakePreviewController();
    container = ProviderContainer(
      overrides: [previewProvider.overrideWithValue(preview)],
    );
    addTearDown(container.dispose);
    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    container.read(timelineUiProvider.notifier).setZoom(20);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
  }

  const videoY = 60.0;

  testWidgets('clicking a clip selects it and moves the playhead', (
    tester,
  ) async {
    final origin = await pumpTimeline(tester);
    await tester.tapAt(origin + const Offset(316, videoY));
    await tester.pump();
    expect(container.read(timelineUiProvider).selectedClipId, 'b');
    expect(preview.position, s(15));

    await tester.tapAt(origin + const Offset(316, 5)); // ruler
    await tester.pump();
    expect(container.read(timelineUiProvider).selectedClipId, isNull);
  });

  testWidgets('S splits at the playhead, Delete removes the selection', (
    tester,
  ) async {
    final origin = await pumpTimeline(tester);
    await preview.seek(s(5));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(ids(), hasLength(4));
    expect(state().undoLabel, 'Split clip');

    await tester.tapAt(origin + const Offset(400, videoY)); // clip b
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(ids(), isNot(contains('b')));
    expect(state().project.duration, s(20));
  });

  testWidgets('dragging a right edge trims in one undo step', (tester) async {
    final origin = await pumpTimeline(tester);
    // Drag a's right edge (x 216) left by 100 px = 5 s.
    final gesture = await tester.startGesture(
      origin + const Offset(214, videoY),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    expect(state().project, threeClips(), reason: 'nothing committed mid-drag');
    await gesture.up();
    await tester.pump();

    final a = state().project.clips.first;
    expect(a.sourceEnd, s(5));
    expect(state().undoStack, hasLength(1));
  });

  testWidgets('trim snaps to the playhead', (tester) async {
    final origin = await pumpTimeline(tester);
    await preview.seek(s(7)); // x = 156
    await tester.pump();
    // Drop the edge 4 px from the playhead; it should land exactly on it.
    await tester.dragFrom(
      origin + const Offset(214, videoY),
      const Offset(-56, 0),
    );
    await tester.pump();
    expect(state().project.clips.first.sourceEnd, s(7));
  });

  testWidgets('dragging a clip body moves it', (tester) async {
    final origin = await pumpTimeline(tester);
    // Drag c (middle at x 716) to the far left.
    await tester.dragFrom(
      origin + const Offset(716, videoY),
      const Offset(-700, 0),
    );
    await tester.pump();
    expect(ids(), ['c', 'a', 'b']);
    expect(state().undoLabel, 'Move clip');
  });

  testWidgets('= and - zoom', (tester) async {
    await pumpTimeline(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    expect(container.read(timelineUiProvider).pixelsPerSecond, 30);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    expect(container.read(timelineUiProvider).pixelsPerSecond, 20);
  });
}
