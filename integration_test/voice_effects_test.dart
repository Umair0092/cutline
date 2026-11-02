import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/model/voice_effect.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// The sample video's sound is a 440 Hz tone, so a pitch change shows up
/// as energy moving to a lower frequency.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];
  final key = Platform.environment['GROQ_API_KEY'];

  testWidgets('lower the voice from the inspector and from chat', (
    tester,
  ) async {
    final ffmpeg = const FfmpegLocator().find()!;
    final support = Directory.systemTemp.createTempSync('cutline_support');
    final scratch = Directory.systemTemp.createTempSync('cutline_fx');
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

    /// Mean level (dB) at [hz] in [file] from [from] for 2 s.
    Future<double> level(String file, int hz, {double from = 3}) async {
      final r = await Process.run(ffmpeg, [
        '-hide_banner',
        '-ss',
        '$from',
        '-t',
        '2',
        '-i',
        file,
        '-af',
        'bandpass=f=$hz:width_type=q:w=40,volumedetect',
        '-f',
        'null',
        '-',
      ]);
      return double.parse(
        RegExp(r'mean_volume: (-?[\d.]+)')
            .firstMatch(r.stderr as String)!
            .group(1)!,
      );
    }

    final preview = container.read(previewProvider) as MpvPreviewController;

    // Inspector: click the clip, pick "Deeper" (-3 semitones: 440 -> 370 Hz).
    final tracks = tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
    await tester.tapAt(tracks + const Offset(200, 60));
    await wait(300);
    expect(find.byKey(const Key('clip-inspector')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-preset')));
    await wait(300);
    await tester.tap(find.text('Deeper').last);
    await wait(300);
    expect(
      container.read(projectEditorProvider).project.clips.single.effect.pitch,
      -3,
    );
    // The preview plays the processed sound instead of the video's own.
    for (var i = 0; i < 100 && preview.extraAudioPath == null; i++) {
      await wait(100);
    }
    expect(preview.extraAudioPath, isNotNull);
    expect(preview.player.state.volume, 0);
    await tester.runAsync(() async {
      final mix = preview.extraAudioPath!;
      final low = await level(mix, 370);
      final high = await level(mix, 440);
      // ignore: avoid_print
      print('PREVIEW MIX 370 Hz $low dB, 440 Hz $high dB');
      expect(low, greaterThan(high + 6));
    });
    await saveScreenshot(tester, 'voice_effect_inspector');

    // Undo puts the video's own sound back.
    editor.undo();
    for (var i = 0; i < 50 && preview.extraAudioPath != null; i++) {
      await wait(100);
    }
    expect(preview.extraAudioPath, isNull);
    expect(preview.player.state.volume, 100);

    if (key != null) {
      await tester.runAsync(
        () => container
            .read(chatProvider.notifier)
            .send('Make my voice 2 semitones lower'),
      );
      final entries = container.read(chatProvider).entries;
      // ignore: avoid_print
      print(
        'LIVE effect -> ${entries.skip(entries.lastIndexWhere((e) => e.role == ChatRole.user) + 1).map((e) => '${e.role.name}: ${e.text} ${e.changes}').join(' | ')}',
      );
      expect(
        container.read(projectEditorProvider).project.clips.single.effect.pitch,
        -2,
      );
    } else {
      editor.run(const SetClipEffect(VoiceEffect(pitch: -2)));
    }

    // Export: 2 semitones down is 392 Hz.
    await tester.runAsync(() async {
      final out = p.join(scratch.path, 'out.mp4');
      final job = await Exporter(ffmpeg).start(
        project: container.read(projectEditorProvider).project,
        projectPath: scratch.path,
        preset: ExportPreset.hd1080,
        outputPath: out,
      );
      expect(await job.done, isTrue);
      final result = await probeVideo(out);
      expect(result.duration.inMilliseconds, closeTo(20000, 150));
      final low = await level(out, 392);
      final high = await level(out, 440);
      // ignore: avoid_print
      print('EXPORT 392 Hz $low dB, 440 Hz $high dB');
      expect(low, greaterThan(high + 6));
    });
  }, skip: sample == null);
}
