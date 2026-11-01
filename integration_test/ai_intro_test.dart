import 'dart:convert';
import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/settings/preferences.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// A scripted reply that calls one tool.
String toolCall(String name, Map<String, dynamic> input) => sse([
  {
    'type': 'message_start',
    'message': {'model': 'claude-opus-5-5'},
  },
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {
      'type': 'tool_use',
      'id': 't-$name',
      'name': name,
      'input': {},
    },
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'input_json_delta', 'partial_json': jsonEncode(input)},
  },
  {'type': 'content_block_stop', 'index': 0},
  {
    'type': 'message_delta',
    'delta': {'stop_reason': 'tool_use'},
  },
  {'type': 'message_stop'},
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('ask for an intro with my name, then make it shorter', (
    tester,
  ) async {
    final support = Directory.systemTemp.createTempSync('cutline_support');
    addTearDown(() => support.deleteSync(recursive: true));
    late ProviderContainer container;
    String introClipId() =>
        container.read(projectEditorProvider).project.clips.first.id;

    final http = ScriptedHttp([
      ScriptedHttp.ok(
        toolCall('add_title', {
          'template': 'clean-card',
          'placement': 'before',
          'fields': {
            'title': 'Weekly Rails Tips',
            'subtitle': 'by Umair Hassan',
          },
        }),
      ),
      ScriptedHttp.ok(sseText('Added a 4 second intro with your name.')),
      // Built when requested, so it can use the real intro clip id.
      () => ScriptedHttp.ok(
        toolCall('edit_title', {'clip_id': introClipId(), 'duration': 2}),
      )(),
      ScriptedHttp.ok(sseText('The intro is now 2 seconds.')),
    ]);
    container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('sk-ant-demo')),
        assistantClientFactoryProvider.overrideWithValue(
          (_, k) => ClaudeClient(apiKey: k, httpClient: http.client),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(preferencesProvider.notifier)
          .save(
            const Preferences(yourName: 'Umair Hassan', brandColor: '#00B894'),
          ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );

    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
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
    await tester.pump();

    await tester.runAsync(
      () => container
          .read(chatProvider.notifier)
          .send('Add an intro with my name and the title Weekly Rails Tips'),
    );
    // The saved name and brand colour went to Claude.
    final state =
        ((http.requests.first['messages'] as List).last as Map)['content']
            as List;
    expect(
      (state.first as Map)['text'],
      contains('"you":{"name":"Umair Hassan","brandColor":"#00B894"}'),
    );

    var project = container.read(projectEditorProvider).project;
    final intro = project.mediaById(project.clips.first.mediaId)!;
    expect(intro.title!.fields['accent'], '#00B894');
    expect(
      File('${container.read(projectEditorProvider).workPath}/${intro.path}')
          .existsSync(),
      isTrue,
      reason: 'rendered by the real ffmpeg into the work folder',
    );
    expect(project.duration.inMilliseconds, closeTo(24000, 150));

    await tester.runAsync(() async {
      await container.read(chatProvider.notifier).send('Make it shorter');
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    project = container.read(projectEditorProvider).project;
    expect(project.clips.first.duration.inMilliseconds, closeTo(2000, 50));
    expect(project.duration.inMilliseconds, closeTo(22000, 150));
    expect(
      container.read(projectEditorProvider).undoStack.map((e) => e.label),
      ['Import video', 'Assistant: Add intro', 'Assistant: Edit intro'],
    );
    await saveScreenshot(tester, 'ai-intro');
  }, skip: sample == null);
}
