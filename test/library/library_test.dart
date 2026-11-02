import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/library/dashboard.dart';
import 'package:cutline/library/project_library.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/startup/startup.dart';
import 'package:cutline/storage/project_store.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../fixtures.dart';

void main() {
  late Directory support;
  setUp(() => support = Directory.systemTemp.createTempSync('cutline_lib'));
  tearDown(() => support.deleteSync(recursive: true));

  test('timeAgo reads like a person would say it', () {
    final now = DateTime(2026, 11, 2, 18);
    expect(timeAgo(now, now: now), 'Just now');
    expect(timeAgo(DateTime(2026, 11, 2, 17, 40), now: now), '20 min ago');
    expect(timeAgo(DateTime(2026, 11, 2, 9), now: now), '9 h ago');
    expect(timeAgo(DateTime(2026, 11, 1, 9), now: now), 'Yesterday');
    expect(timeAgo(DateTime(2026, 10, 30), now: now), '3 days ago');
    expect(timeAgo(DateTime(2026, 9, 3), now: now), '3 Sep');
    expect(timeAgo(DateTime(2025, 9, 3), now: now), '3 Sep 2025');
  });

  test(
    'the library lists its edits and remembered ones, newest first',
    () async {
      final library = ProjectLibrary(p.join(support.path, 'Projects'));
      final a = library.newPath('Rails tips: ep 1!');
      expect(p.basename(a), startsWith('Rails tips ep 1-'));
      await const ProjectStore().save(threeClips().copyWith(name: 'A'), a);
      final outside = p.join(support.path, 'Elsewhere.cutline');
      await const ProjectStore().save(
        threeClips().copyWith(name: 'B'),
        outside,
      );
      library.remember(outside);
      expect([for (final x in await library.list()) x.name], ['B', 'A']);

      library.delete(outside);
      expect(Directory(outside).existsSync(), isTrue, reason: 'only forgotten');
      library.delete(a);
      expect(Directory(a).existsSync(), isFalse);
      expect(await library.list(), isEmpty);
    },
  );

  testWidgets('dashboard: past edits open in the editor, which saves itself', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final root = p.join(support.path, 'Projects');
    final path = p.join(root, 'Talk-1.cutline');
    await tester.runAsync(
      () =>
          const ProjectStore().save(threeClips().copyWith(name: 'Talk'), path),
    );
    File(p.join(support.path, 'preferences.json'))
        .writeAsStringSync('{"onboarded":true}');
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        previewProvider.overrideWithValue(FakePreviewController()),
        startupTasksProvider.overrideWithValue(const []),
        splashMinimumProvider.overrideWithValue(Duration.zero),
        supportDirProvider.overrideWith((_) async => support.path),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(showSplash: true),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    await settle();
    expect(find.byKey(const Key('dashboard')), findsOneWidget);
    expect(find.text('Talk'), findsOneWidget);
    expect(find.byType(EditFingerprint), findsOneWidget);

    await tester.tap(find.text('Talk'));
    await settle();
    expect(find.byKey(const Key('timeline')), findsOneWidget);
    expect(container.read(projectEditorProvider).projectPath, path);

    // An edit saves itself, with no "Edited" warning.
    container
        .read(projectEditorProvider.notifier)
        .run(const RenameProject('Talk, cut down'));
    await tester.pump();
    expect(find.byKey(const Key('edited')), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await tester.pump(const Duration(seconds: 1));
    await settle();
    final saved = await tester.runAsync(() => const ProjectStore().load(path));
    expect(saved!.name, 'Talk, cut down');

    // Back to the dashboard, which shows the new name.
    // Leaving saves to disk, which needs real time in a widget test.
    await tester.tap(find.byKey(const Key('back-to-edits')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle();
    expect(find.byKey(const Key('dashboard')), findsOneWidget);
    expect(find.text('Talk, cut down'), findsOneWidget);
  });
}
