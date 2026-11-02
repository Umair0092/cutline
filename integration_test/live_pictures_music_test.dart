import 'dart:io';
import 'dart:ui' as ui;

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/titles/title_renderer.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import '../test/ai/fake_claude.dart';

/// Talks to the real Groq API (and the music libraries). Runs only with
/// GROQ_API_KEY set.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];
  final key = Platform.environment['GROQ_API_KEY'];
  final shots = Platform.environment['SCREENSHOT_DIR'];

  testWidgets('live: a logo intro from an attached picture, then music', (
    tester,
  ) async {
    final support = Directory.systemTemp.createTempSync('cutline_support');
    addTearDown(() => support.deleteSync(recursive: true));
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
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

    Future<void> say(String text, [List<String> files = const []]) async {
      await tester.runAsync(
        () => container
            .read(chatProvider.notifier)
            .send(text, attachments: files),
      );
      final entries = container.read(chatProvider).entries;
      // ignore: avoid_print
      print(
        'LIVE "$text" -> ${entries.skip(entries.lastIndexWhere((e) => e.role == ChatRole.user) + 1).map((e) => '${e.role.name}: ${e.text} ${e.changes}').join(' | ')}',
      );
    }

    await say(
      'This is my channel logo. Make a cool intro with it where it spins in. '
      'My channel is Umair Codes.',
      ['${Directory.current.path}/test_media/logo.png'],
    );
    var project = container.read(projectEditorProvider).project;
    final image = project.media.where((m) => m.kind == MediaKind.image);
    expect(image, hasLength(1));
    // ignore: avoid_print
    print('LIVE description: ${image.single.description}');
    final intro = project.mediaById(project.clips.first.mediaId);
    expect(intro?.title?.templateId, startsWith('logo-'));
    expect(intro!.title!.fields.values, contains(image.single.path));
    if (shots != null) {
      final frame = await tester.runAsync(
        () => renderTitleFrame(
          intro.title!,
          1280,
          720,
          2.2,
          projectPath: container.read(projectEditorProvider).workPath,
        ),
      );
      final png = await tester.runAsync(
        () => frame!.toByteData(format: ui.ImageByteFormat.png),
      );
      File('$shots/live-logo-intro.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }

    // Groq's free tier limits tokens per minute.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 65)),
    );
    await say('Add some calm background music, not too loud');
    project = container.read(projectEditorProvider).project;
    final music = project.audio.where((a) => a.role == AudioRole.music);
    expect(music, isNotEmpty);
    // The model may round the end to two decimals.
    expect(
      music.last.end.inMilliseconds,
      closeTo(project.duration.inMilliseconds, 50),
    );
  }, skip: key == null || sample == null);
}
