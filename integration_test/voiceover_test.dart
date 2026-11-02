import 'dart:async';
import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/audio/voice_recorder.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import 'screenshot.dart';

/// Stands in for the microphone: "records" a speech file, so the test
/// doesn't need microphone permission.
class SpeechRecorder implements VoiceRecorder {
  SpeechRecorder(this.ffmpeg, this.speech);

  final String ffmpeg;
  final String speech;
  String? _path;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<List<Mic>> microphones() async => const [Mic('fake', 'Test Mic')];
  @override
  Future<void> start(String path, {Mic? mic}) async => _path = path;
  @override
  Future<String?> stop() async {
    // 4 s of the speech, as 48 kHz mono WAV like the real recorder.
    await Process.run(ffmpeg, [
      '-y',
      '-v',
      'error',
      '-i',
      speech,
      '-t',
      '4',
      '-ar',
      '48000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      _path!,
    ]);
    return _path;
  }

  @override
  Future<void> cancel() async {}
  @override
  Stream<double> get level =>
      Stream.periodic(const Duration(milliseconds: 100), (i) => (i % 10) / 10);
  @override
  Future<void> dispose() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];
  final speech = Platform.environment['SPEECH_VIDEO'];

  testWidgets('record a voiceover over the video and export it', (
    tester,
  ) async {
    final ffmpeg = const FfmpegLocator().find()!;
    final scratch = Directory.systemTemp.createTempSync('cutline_vo');
    final container = ProviderContainer(
      overrides: [
        voiceRecorderProvider.overrideWithValue(
          SpeechRecorder(ffmpeg, speech!),
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

    final preview = container.read(previewProvider) as MpvPreviewController;
    for (
      var i = 0;
      i < 100 && preview.position != const Duration(seconds: 6);
      i++
    ) {
      await tester.runAsync(() => preview.seek(const Duration(seconds: 6)));
      await wait(100);
    }

    // Open the record bar from the timeline, record, stop.
    await tester.tap(find.byKey(const Key('record-voiceover')));
    await wait(300);
    expect(find.byKey(const Key('record-bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-button')));
    await wait(1500);
    expect(
      preview.isPlaying,
      isTrue,
      reason: 'the video plays while recording',
    );
    expect(preview.player.state.volume, 0);
    // (No screenshot here: settling waits for the level meter, and the
    // video would play on to the end meanwhile.)
    await tester.tap(find.byKey(const Key('record-button')));
    await wait(500);
    expect(preview.isPlaying, isFalse, reason: 'stopping pauses the video');
    final state = container.read(projectEditorProvider);
    final vo = state.project.audio.single;
    expect(vo.start.inMilliseconds, closeTo(6000, 50));
    expect(
      preview.position.inMilliseconds,
      closeTo(7500, 700),
      reason: 'stopped where recording stopped',
    );
    expect(vo.duration.inMilliseconds, closeTo(4000, 50));
    expect(state.undoLabel, 'Record voiceover');
    expect(preview.player.state.volume, 100);

    // The preview plays the voiceover next to the video.
    for (
      var i = 0;
      i < 50 && preview.extra.state.duration == Duration.zero;
      i++
    ) {
      await wait(100);
    }
    expect(preview.extra.state.duration.inMilliseconds, closeTo(20000, 100));
    expect(preview.isPlaying, isFalse);
    await saveScreenshot(tester, 'voiceover_recorded');

    // Export with ducking on (the default).
    await tester.runAsync(() async {
      final out = p.join(scratch.path, 'out.mp4');
      final job = await Exporter(ffmpeg).start(
        project: container.read(projectEditorProvider).project,
        projectPath: container.read(projectEditorProvider).workPath,
        preset: ExportPreset.hd1080,
        outputPath: out,
      );
      expect(await job.done, isTrue);

      Future<double> level(double from, String filter) async {
        final r = await Process.run(ffmpeg, [
          '-hide_banner',
          '-ss',
          '$from',
          '-t',
          '1.5',
          '-i',
          out,
          '-af',
          '$filter,volumedetect',
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

      // The sample's 440 Hz tone, before and during the voiceover.
      const tone = 'bandpass=f=440:width_type=q:w=30';
      final toneBefore = await level(2, tone);
      final toneDuring = await level(7.5, tone);
      // Speech energy (around 1-3 kHz) only during the voiceover.
      const voice = 'highpass=f=900,lowpass=f=3000';
      final voiceBefore = await level(2, voice);
      final voiceDuring = await level(7.5, voice);
      // ignore: avoid_print
      print(
        'VOICEOVER tone $toneBefore -> $toneDuring dB, '
        'voice $voiceBefore -> $voiceDuring dB',
      );
      expect(voiceDuring, greaterThan(voiceBefore + 5));
      expect(toneDuring, lessThan(toneBefore - 3), reason: 'ducked');
    });
  }, skip: sample == null || speech == null);
}
