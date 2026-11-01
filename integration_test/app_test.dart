import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/storage/project_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app opens the editor', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CutlineApp()));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Untitled'), findsOneWidget);
    await saveScreenshot(tester, 'editor');
  });

  testWidgets('edit, save, reopen and undo', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(projectEditorProvider.notifier);
    final tmp = Directory.systemTemp.createTempSync('cutline_e2e');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = p.join(tmp.path, 'Demo.cutline');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );

    editor.runAll('Import', [
      const AddMedia(
        MediaAsset(
          id: 'm1',
          path: '/videos/demo.mp4',
          kind: MediaKind.video,
          duration: Duration(seconds: 30),
        ),
      ),
      const AddClip(
        VideoClip(
          id: 'c1',
          mediaId: 'm1',
          sourceStart: Duration.zero,
          sourceEnd: Duration(seconds: 30),
        ),
      ),
    ]);
    editor.run(SplitAt(const Duration(seconds: 12)));
    await tester.pumpAndSettle();
    expect(find.text('Edited'), findsOneWidget);
    await saveScreenshot(tester, 'edited');

    const store = ProjectStore();
    await tester.runAsync(
      () => store.save(
        container.read(projectEditorProvider).project.copyWith(name: 'Demo'),
        path,
      ),
    );
    editor.saved(path, name: 'Demo');
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Edited'), findsNothing);

    editor.newProject();
    final Project reopened = (await tester.runAsync(() => store.load(path)))!;
    editor.opened(reopened, path);
    await tester.pumpAndSettle();
    expect(container.read(projectEditorProvider).project.clips, hasLength(2));

    editor.run(const RemoveClip('c1'));
    editor.undo();
    expect(container.read(projectEditorProvider).project, reopened);
  });
}
