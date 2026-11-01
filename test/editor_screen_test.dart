import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  testWidgets('title bar shows the project name and unsaved changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(projectEditorProvider.notifier)
        .opened(threeClips().copyWith(name: 'Talk'), '/tmp/Talk.cutline');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    expect(find.text('Talk'), findsOneWidget);
    expect(find.byKey(const Key('edited')), findsNothing);

    container.read(projectEditorProvider.notifier).run(const RemoveClip('a'));
    await tester.pump();
    expect(find.byKey(const Key('edited')), findsOneWidget);

    container.read(projectEditorProvider.notifier).undo();
    await tester.pump();
    expect(find.byKey(const Key('edited')), findsNothing);
  });
}
