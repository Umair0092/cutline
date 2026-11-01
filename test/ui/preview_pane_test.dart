import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/ui/editor_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_preview.dart';
import '../fixtures.dart';

void main() {
  late FakePreviewController preview;
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    preview = FakePreviewController();
    container = ProviderContainer(
      overrides: [previewProvider.overrideWithValue(preview)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
  }

  testWidgets('empty project shows the drop zone', (tester) async {
    await pumpApp(tester);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(find.byKey(const Key('video')), findsNothing);
  });

  testWidgets('with clips it shows the video and total time', (tester) async {
    await pumpApp(tester);
    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    await tester.pump();

    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(find.text('0:00.0 / 0:40.0'), findsOneWidget);

    await preview.seek(s(12.3));
    await tester.pump();
    expect(find.text('0:12.3 / 0:40.0'), findsOneWidget);
  });

  testWidgets('space plays and pauses', (tester) async {
    await pumpApp(tester);
    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(preview.toggles, 1);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('space is left alone while typing in a text field', (
    tester,
  ) async {
    final preview = FakePreviewController();
    final field = FocusNode();
    addTearDown(field.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [previewProvider.overrideWithValue(preview)],
        child: MaterialApp(
          home: Material(
            child: EditorShortcuts(child: TextField(focusNode: field)),
          ),
        ),
      ),
    );
    field.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(preview.toggles, 0);
  });
}
