import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/transcript/timeline_transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:cutline/transcript/whisper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final speech = Platform.environment['SPEECH_VIDEO'];
  final model = Platform.environment['WHISPER_MODEL'];

  testWidgets(
    'transcribe with the bundled whisper, then cut by what was said',
    (tester) async {
      expect(findWhisper(), contains('Contents/Resources/bin/whisper-cli'));

      // A fresh support folder with the model already "downloaded".
      final support = Directory.systemTemp.createTempSync('cutline_support');
      addTearDown(() => support.deleteSync(recursive: true));
      Directory(p.join(support.path, 'models')).createSync();
      File(model!).copySync(p.join(support.path, 'models', 'ggml-base.bin'));

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
                'partial_json': '{"start": 4.23, "end": 6.08}',
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
        ScriptedHttp.ok(sseText('Removed "um, let me restart".')),
      ]);
      final container = ProviderContainer(
        overrides: [
          supportDirProvider.overrideWith((_) async => support.path),
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

      final asset = (await tester.runAsync(() => probeVideo(speech!)))!;
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
      await tester.tap(find.byKey(const Key('tab-transcript')));

      // Import starts transcription by itself because the model is present.
      final watch = Stopwatch()..start();
      for (var i = 0; i < 600; i++) {
        final status = container.read(transcriptsProvider)[speech];
        if (status?.phase == TranscriptPhase.done ||
            status?.phase == TranscriptPhase.failed) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      final status = container.read(transcriptsProvider)[speech]!;
      expect(status.error, isNull);
      // ignore: avoid_print
      print(
        'TRANSCRIBED in ${watch.elapsed}: '
        '${status.transcript!.words.map((w) => w.text).join(' ')}',
      );
      final words = status.transcript!.words.map((w) => w.text).join(' ');
      expect(words, contains('restart'));
      expect(words.toLowerCase(), contains('deadlines'));
      await tester.pumpAndSettle();
      expect(find.textContaining('restart'), findsOneWidget);
      await saveScreenshot(tester, 'transcript');

      // The assistant gets the transcript and cuts by it.
      await tester.runAsync(
        () => container
            .read(chatProvider.notifier)
            .send('Remove the part where I say um, let me restart'),
      );
      final state = (http.requests.first['messages'] as List).last as Map;
      final projectState = ((state['content'] as List).first as Map)['text'];
      expect(projectState, contains('"transcript"'));
      expect(projectState, contains('let me restart'));

      await tester.pumpAndSettle();
      final lines = container.read(timelineTranscriptProvider);
      expect(lines.map((l) => l.text).join(' '), isNot(contains('restart')));
      expect(find.textContaining('restart'), findsNothing);
    },
    skip: speech == null || model == null,
  );
}
