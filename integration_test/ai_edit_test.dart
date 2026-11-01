import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'screenshot.dart';
import '../test/ai/fake_claude.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('typing an edit in chat cuts the real video, Undo restores it', (
    tester,
  ) async {
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final http = ScriptedHttp([
      ScriptedHttp.ok(
        sse([
          {
            'type': 'message_start',
            'message': {'model': 'claude-opus-5-5'},
          },
          {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'tool_use',
              'id': 't1',
              'name': 'cut_range',
              'input': {},
            },
          },
          {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {
              'type': 'input_json_delta',
              'partial_json': '{"start": 0, "end": 5}',
            },
          },
          {'type': 'content_block_stop', 'index': 0},
          {
            'type': 'message_delta',
            'delta': {'stop_reason': 'tool_use'},
          },
          {'type': 'message_stop'},
        ]),
      ),
      ScriptedHttp.ok(sseText('Removed the first 5 seconds.')),
    ]);
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('sk-ant-demo')),
        claudeClientFactoryProvider.overrideWithValue(
          (k) => ClaudeClient(apiKey: k, httpClient: http.client),
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
    container.read(projectEditorProvider.notifier).runAll('Import video', [
      AddMedia(asset),
      AddClip(
        VideoClip(
          id: 'c1',
          mediaId: asset.id,
          sourceStart: Duration.zero,
          sourceEnd: asset.duration,
        ),
      ),
    ]);
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('chat-input'));
    await tester.tap(input);
    await tester.enterText(input, 'Cut the first 5 seconds');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 30 && container.read(chatProvider).busy; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final project = container.read(projectEditorProvider).project;
    expect(project.duration.inMilliseconds, closeTo(15000, 50));
    expect(find.text('Cut 0:00.00–0:05.00'), findsOneWidget);
    expect(find.text('Removed the first 5 seconds.'), findsOneWidget);

    // The real player picks up the shorter timeline.
    final player =
        (container.read(previewProvider) as MpvPreviewController).player;
    bool fifteen(Duration d) => (d.inMilliseconds - 15000).abs() < 100;
    if (!fifteen(player.state.duration)) {
      await tester.runAsync(
        () => player.stream.duration
            .firstWhere(fifteen)
            .timeout(const Duration(seconds: 10)),
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await saveScreenshot(tester, 'ai-edit');

    await tester.tap(find.textContaining('Undo').last);
    await tester.pumpAndSettle();
    expect(
      container.read(projectEditorProvider).project.duration.inMilliseconds,
      closeTo(20000, 50),
    );
    expect(find.text('Undone'), findsOneWidget);
  }, skip: sample == null);
}
