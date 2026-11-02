import 'dart:async';
import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/startup/startup.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    List<StartupTask> tasks, {
    Duration minimum = const Duration(milliseconds: 1200),
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
          previewProvider.overrideWithValue(FakePreviewController()),
          startupTasksProvider.overrideWithValue(tasks),
          splashMinimumProvider.overrideWithValue(minimum),
          supportDirProvider.overrideWith(
            (_) async => Directory.systemTemp.createTempSync('cutline_s').path,
          ),
        ],
        child: const CutlineApp(showSplash: true),
      ),
    );
  }

  testWidgets('shows the splash with progress, then fades into the dashboard', (
    tester,
  ) async {
    await pumpApp(tester, [
      (label: 'Loading your settings', run: (_) async => null),
      (label: 'Checking video tools', run: (_) async => null),
    ]);
    expect(find.byKey(const Key('splash')), findsOneWidget);
    expect(find.text('Cutline'), findsOneWidget);
    expect(find.byKey(const Key('splash-progress')), findsOneWidget);

    // Still on the splash before the minimum time is up.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('splash')), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('splash')), findsNothing);
    expect(find.byKey(const Key('dashboard')), findsOneWidget);
  });

  testWidgets('a missing tool is mentioned once the editor opens', (
    tester,
  ) async {
    await pumpApp(tester, [
      (
        label: 'Checking video tools',
        run: (_) async => 'Missing FFmpeg (export).',
      ),
    ], minimum: Duration.zero);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Missing FFmpeg (export).'), findsOneWidget);
  });

  testWidgets('a step that fails or hangs never blocks the app', (
    tester,
  ) async {
    await pumpApp(tester, [
      (label: 'Broken', run: (_) async => throw Exception('boom')),
      (label: 'Hangs', run: (_) => Completer<String?>().future),
    ], minimum: Duration.zero);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('splash')), findsNothing);
  });
}
