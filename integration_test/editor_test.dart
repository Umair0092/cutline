import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/storage/project_store.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// Screenshots of the editor (frame, preview, timeline, inspectors) at
/// desktop and phone sizes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('editor, desktop and phone', (tester) async {
    final support = Directory.systemTemp.createTempSync('cutline_editor');
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final project = Project(
      name: 'Weekly Rails Tips 12',
      media: [asset],
      clips: [
        for (final (i, (a, b)) in [(0, 6), (8, 14), (15, 20)].indexed)
          VideoClip(
            id: 'c$i',
            mediaId: asset.id,
            sourceStart: Duration(seconds: a),
            sourceEnd: Duration(seconds: b),
          ),
      ],
      overlays: [
        OverlayItem(
          id: 'o',
          mediaId: asset.id,
          start: const Duration(seconds: 4),
          duration: const Duration(seconds: 3),
          transform: const OverlayTransform(x: 0.72, y: 0.3, scale: 0.35),
        ),
      ],
      titles: [
        const TitleItem(
          id: 't',
          spec: TitleSpec(
            templateId: 'lower-third',
            duration: Duration(seconds: 3),
            fields: {'title': 'Weekly Rails Tips'},
          ),
          start: Duration(seconds: 1),
        ),
      ],
      audio: [
        AudioItem(
          id: 'v',
          mediaId: asset.id,
          role: AudioRole.voiceover,
          start: const Duration(seconds: 6),
          sourceStart: Duration.zero,
          sourceEnd: const Duration(seconds: 4),
        ),
        AudioItem(
          id: 'm',
          mediaId: asset.id,
          role: AudioRole.music,
          start: Duration.zero,
          sourceStart: Duration.zero,
          sourceEnd: const Duration(seconds: 15),
        ),
      ],
    );
    final path = p.join(support.path, 'Projects', '${project.name}.cutline');
    await tester.runAsync(() => const ProjectStore().save(project, path));
    File(p.join(support.path, 'preferences.json'))
        .writeAsStringSync('{"onboarded":true}');
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('gsk_test')),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(showSplash: true),
      ),
    );
    Future<void> wait(int ms) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    Future<void> seek(int ms) async {
      await tester.runAsync(
        () => container.read(previewProvider).seek(Duration(milliseconds: ms)),
      );
      await wait(600);
    }

    for (var i = 0; i < 80 && find.text(project.name).evaluate().isEmpty; i++) {
      await wait(100);
    }
    await tester.tap(find.text(project.name).first);
    await wait(3000);
    await seek(2500);
    await saveScreenshot(tester, 'editor_desktop', settle: false);

    // A selected clip: handles on the timeline, its inspector.
    final tracks = tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
    await tester.tapAt(tracks + const Offset(400, 60));
    await wait(800);
    await saveScreenshot(tester, 'editor_desktop_clip', settle: false);

    // A selected overlay, on the preview and in its inspector.
    await seek(5000);
    final overlayRow = tracks + const Offset(16 + 40.0 * 5, 172);
    await tester.tapAt(overlayRow);
    await wait(800);
    await saveScreenshot(tester, 'editor_desktop_overlay', settle: false);

    // The voiceover's inspector.
    await tester.tapAt(tracks + const Offset(16 + 40.0 * 7, 200));
    await wait(800);
    await saveScreenshot(tester, 'editor_desktop_audio', settle: false);

    // The sound levels popover.
    await tester.tap(find.byKey(const Key('audio-mix')));
    await wait(800);
    await saveScreenshot(tester, 'editor_desktop_mix', settle: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(500);

    // The recorder.
    await tester.tap(find.byKey(const Key('record-voiceover')));
    await wait(800);
    await saveScreenshot(tester, 'editor_desktop_record', settle: false);
    await tester.tap(find.byKey(const Key('record-voiceover')));
    await wait(500);

    // A narrow desktop window.
    tester.view.physicalSize = const Size(1900, 1500);
    await wait(1000);
    await saveScreenshot(tester, 'editor_desktop_narrow', settle: false);

    // Phone size (Pixel 8).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    await wait(1500);
    await saveScreenshot(tester, 'editor_phone', settle: false);
    final phoneTracks = tester.getTopLeft(
      find.byKey(const Key('timeline-tracks')),
    );
    await tester.tapAt(phoneTracks + const Offset(120, 60));
    await wait(800);
    await saveScreenshot(tester, 'editor_phone_clip', settle: false);
  }, skip: sample == null);
}
