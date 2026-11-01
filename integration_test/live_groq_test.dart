import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
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

/// Talks to the real Groq API. Runs only with GROQ_API_KEY set; uses the
/// free tier, so it's kept to two short requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];
  final key = Platform.environment['GROQ_API_KEY'];

  testWidgets('live: Groq cuts the video and adds an intro', (tester) async {
    final support = Directory.systemTemp.createTempSync('cutline_support');
    addTearDown(() => support.deleteSync(recursive: true));
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(preferencesProvider.notifier)
          .save(const Preferences(yourName: 'Umair Hassan')),
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

    await say('Cut the first 5 seconds');
    var project = container.read(projectEditorProvider).project;
    expect(project.duration.inMilliseconds, closeTo(15000, 150));

    await say('Add an intro with my name and the title Weekly Rails Tips');
    project = container.read(projectEditorProvider).project;
    final intro = project.mediaById(project.clips.first.mediaId);
    expect(intro?.title, isNotNull, reason: 'an intro clip was added first');
    // ignore: avoid_print
    print('LIVE intro: ${intro!.title!.templateId} ${intro.title!.fields}');
    expect(intro.title!.fields.values.join(' '), contains('Weekly Rails Tips'));
    expect(container.read(projectEditorProvider).undoStack, hasLength(3));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'live-groq');
  }, skip: sample == null || key == null);
}
