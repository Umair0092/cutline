import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/transcript/timeline_transcript.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// The assistant places memes using the real Groq API, your memes folder
/// and the bundled FFmpeg. Runs only with GROQ_API_KEY set. The transcript
/// is given (the transcription test covers whisper).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];
  final key = Platform.environment['GROQ_API_KEY'];

  testWidgets('live: "add this is fine when I talk about deadlines"', (
    tester,
  ) async {
    final support = Directory.systemTemp.createTempSync('cutline_support');
    final memes = Directory(p.join(support.path, 'Memes'))..createSync();
    addTearDown(() => support.deleteSync(recursive: true));
    final ffmpeg = const FfmpegLocator().find()!;
    await tester.runAsync(() async {
      for (final (name, colour) in [
        ('this is fine', 'orange'),
        ('deadline panic', 'red'),
        ('celebration party', 'green'),
      ]) {
        await Process.run(ffmpeg, [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=c=$colour:s=240x180:d=1:r=10',
          p.join(memes.path, '$name.gif'),
        ]);
      }
    });
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
        giphyKeyProvider.overrideWith(_NoGiphy.new),
        timelineTranscriptProvider.overrideWithValue([
          TranscriptLine(
            Duration.zero,
            const Duration(seconds: 4),
            'Hey everyone, welcome back to the channel.',
          ),
          TranscriptLine(
            const Duration(seconds: 4),
            const Duration(seconds: 9),
            'This week I shipped the new billing page.',
          ),
          TranscriptLine(
            const Duration(seconds: 12),
            const Duration(seconds: 16),
            'But honestly, the deadlines were brutal.',
          ),
          TranscriptLine(
            const Duration(seconds: 16),
            const Duration(seconds: 19),
            'Anyway, it launched, so we celebrated!',
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);
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

    Future<void> say(String text) async {
      await tester.runAsync(
        () => container.read(chatProvider.notifier).send(text),
      );
      final entries = container.read(chatProvider).entries;
      // ignore: avoid_print
      print(
        'LIVE "$text" -> ${entries.skip(entries.lastIndexWhere((e) => e.role == ChatRole.user) + 1).map((e) => '${e.role.name}: ${e.text} ${e.changes}').join(' | ')}',
      );
    }

    await say(
      "Add the 'this is fine' meme when I talk about deadlines, bottom right",
    );
    var project = container.read(projectEditorProvider).project;
    final meme = project.overlays.single;
    // ignore: avoid_print
    print('LIVE meme: ${meme.start} ${meme.transform}');
    expect(meme.start.inMilliseconds, closeTo(12000, 1000));
    expect(meme.transform.x, greaterThan(0.6));
    expect(meme.transform.y, greaterThan(0.6));
    expect(
      p.basename(project.mediaById(meme.mediaId)!.path),
      'this is fine.gif',
    );

    await say('Suggest a couple more memes for this video');
    final chat = container.read(chatProvider);
    final suggestions = [
      for (var i = 0; i < chat.entries.length; i++)
        if (chat.entries[i].role == ChatRole.suggestion) i,
    ];
    expect(suggestions, isNotEmpty);
    await tester.tap(find.byKey(const Key('tab-assistant')));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'live-memes');
    await tester.runAsync(
      () => container
          .read(chatProvider.notifier)
          .acceptSuggestion(suggestions.first),
    );
    project = container.read(projectEditorProvider).project;
    expect(project.overlays, hasLength(2));
  }, skip: sample == null || key == null);
}

class _NoGiphy extends GiphyKeyNotifier {
  @override
  Future<String?> build() async => null;
}
