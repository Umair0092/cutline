import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/speech_spec.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/transcript/timeline_transcript.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];
  final key = Platform.environment['GROQ_API_KEY'];

  testWidgets('write a script, get a voiceover; ask the assistant for one', (
    tester,
  ) async {
    final support = Directory.systemTemp.createTempSync('cutline_support');
    final scratch = Directory.systemTemp.createTempSync('cutline_voice');
    addTearDown(() => support.deleteSync(recursive: true));
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
        timelineTranscriptProvider.overrideWithValue([
          TranscriptLine(
            Duration.zero,
            const Duration(seconds: 5),
            'Welcome to the app tour.',
          ),
          TranscriptLine(
            const Duration(seconds: 12),
            const Duration(seconds: 16),
            'This is the setup screen.',
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
    final editor = container.read(projectEditorProvider.notifier);
    editor.opened(container.read(projectEditorProvider).project, scratch.path);
    editor.runAll('Import video', [
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

    Future<void> wait(int ms) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    final preview = container.read(previewProvider);
    for (
      var i = 0;
      i < 100 && preview.position != const Duration(seconds: 2);
      i++
    ) {
      await tester.runAsync(() => preview.seek(const Duration(seconds: 2)));
      await wait(100);
    }

    // The dialog, with the Mac's own voice.
    await tester.tap(find.byKey(const Key('ai-voiceover')));
    await wait(1500); // voices load
    await tester.enterText(
      find.byKey(const Key('voiceover-script')),
      'Welcome to the tour.\nNext, we set up your account.',
    );
    await tester.pump();
    await saveScreenshot(tester, 'voiceover_dialog');
    await tester.tap(find.byKey(const Key('voiceover-generate')));
    for (var i = 0; i < 100; i++) {
      await wait(100);
      if (container.read(projectEditorProvider).project.audio.length == 2) {
        break;
      }
    }
    var project = container.read(projectEditorProvider).project;
    expect(project.audio, hasLength(2));
    expect(project.audio.first.start, const Duration(seconds: 2));
    expect(project.audio[1].start, greaterThan(project.audio.first.end));
    final first = project.mediaById(project.audio.first.mediaId)!;
    expect(first.speech!.engine, VoiceEngine.system);
    expect(first.speech!.voice, isNotEmpty);
    // ignore: avoid_print
    print(
      'SYSTEM VOICE ${first.speech!.voice}: '
      '${[for (final a in project.audio) '${a.start}+${a.duration}'].join(', ')}',
    );
    expect(container.read(projectEditorProvider).undoLabel, 'AI voiceover');
    await wait(500);
    await saveScreenshot(tester, 'voiceover_lines');

    if (key == null) return;
    // The assistant writes and places one.
    await tester.runAsync(
      () => container
          .read(chatProvider.notifier)
          .send('Add a short voiceover that explains the setup screen'),
    );
    final entries = container.read(chatProvider).entries;
    // ignore: avoid_print
    print(
      'LIVE voiceover -> ${entries.skip(entries.lastIndexWhere((e) => e.role == ChatRole.user) + 1).map((e) => '${e.role.name}: ${e.text} ${e.changes}').join(' | ')}',
    );
    project = container.read(projectEditorProvider).project;
    final added = project.audio.skip(2).toList();
    expect(added, isNotEmpty);
    for (final a in added) {
      // ignore: avoid_print
      print(
        'LIVE line at ${a.start}: ${project.mediaById(a.mediaId)!.speech!.text}',
      );
    }
    expect(added.first.start.inMilliseconds, closeTo(12000, 1500));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'voiceover_live');
  }, skip: sample == null);
}
