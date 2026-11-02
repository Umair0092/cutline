import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/settings/preferences.dart';
import 'package:cutline/startup/startup.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';

void main() {
  late Directory support;
  setUp(() => support = Directory.systemTemp.createTempSync('cutline_onb'));
  tearDown(() => support.deleteSync(recursive: true));

  Future<ProviderContainer> launch(WidgetTester tester, {String? key}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
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
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }
    return container;
  }

  testWidgets('shows once on first launch; skipping remembers it', (
    tester,
  ) async {
    final container = await launch(tester);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(find.text('Edit video by talking to it.'), findsOneWidget);

    // "Get started" moves on to picking the AI.
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Connect the assistant'), findsOneWidget);
    expect(find.text('Add key'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-done')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('onboarding')), findsNothing);
    final prefs = await tester.runAsync(
      () => container.read(preferencesProvider.future),
    );
    expect(prefs!.onboarded, isTrue);
  });

  testWidgets('not shown again once seen; a saved key shows as done', (
    tester,
  ) async {
    File('${support.path}/preferences.json')
        .writeAsStringSync('{"provider":"groq","onboarded":true}');
    await launch(tester, key: 'gsk_x');
    expect(find.byKey(const Key('onboarding')), findsNothing);
  });
}
