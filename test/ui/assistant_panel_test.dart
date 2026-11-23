import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/app.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';

/// Lets real file writes (preferences) finish, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late MemoryKeyStore keys;
  late ScriptedHttp http;

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    String? key,
    List<dynamic> responses = const [],
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    keys = MemoryKeyStore(key);
    http = ScriptedHttp([...responses].cast());
    final container = ProviderContainer(
      overrides: [
        previewProvider.overrideWithValue(FakePreviewController()),
        apiKeyStoreProvider.overrideWithValue(keys),
        supportDirProvider.overrideWith(
          (_) async => Directory.systemTemp.createTempSync('cutline_ui').path,
        ),
        assistantClientFactoryProvider.overrideWithValue(
          (_, k) => ClaudeClient(apiKey: k, httpClient: http.client),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('without a key it asks for one, and saving it unlocks chat', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Add API Key…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    // The AI settings page scrolls, so bring targets into view before tapping.
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
    }

    await tester.enterText(find.byKey(const Key('api-key')), 'not-a-key');
    await tap(find.byKey(const Key('save-key')));
    await tester.pumpAndSettle();
    // Groq (free) is the default service.
    expect(find.textContaining('start with gsk_'), findsOneWidget);

    // Switching to Claude asks for a Claude key instead.
    await tap(find.text('Claude'));
    await settle(tester);
    await tap(find.byKey(const Key('save-key')));
    await tester.pumpAndSettle();
    expect(find.textContaining('start with sk-ant-'), findsOneWidget);

    await tap(find.text('Groq (free)'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('api-key')),
      ' gsk_abcdefghijklmnopqrstuv ',
    );
    await tap(find.byKey(const Key('save-key')));
    await settle(tester);
    expect(keys.value, 'gsk_abcdefghijklmnopqrstuv');
    expect(find.text('What should we make?'), findsOneWidget);
  });

  testWidgets('Enter sends, the reply appears, Shift+Enter adds a line', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      key: 'sk-ant-api03-abcdefghijklmnop',
      responses: [ScriptedHttp.ok(sseText('Happy to help'))],
    );
    final input = find.byKey(const Key('chat-input'));
    await tester.tap(input);
    await tester.enterText(input, 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(http.requests, isEmpty, reason: 'Shift+Enter does not send');

    await tester.enterText(input, 'Cut the first 5 seconds');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (
      var i = 0;
      i < 50 && http.requests.isEmpty | container.read(chatProvider).busy;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Cut the first 5 seconds'), findsOneWidget);
    expect(find.text('Happy to help'), findsOneWidget);
    expect(container.read(chatProvider).busy, isFalse);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
  });

  testWidgets('typing a space or S in the chat box does not play or split', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      key: 'sk-ant-api03-abcdefghijklmnop',
    );
    final preview = container.read(previewProvider) as FakePreviewController;
    await tester.tap(find.byKey(const Key('chat-input')));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(preview.toggles, 0);
  });
}
