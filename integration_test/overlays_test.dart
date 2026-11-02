import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/overlays/overlay_actions.dart';
import 'package:cutline/overlays/overlay_media.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:cutline/ui/preview_pane.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('drop a GIF, put it in a corner, export it', (tester) async {
    final ffmpeg = const FfmpegLocator().find()!;
    final dir = Directory.systemTemp.createTempSync('cutline_overlay');
    // A magenta GIF and a yellow video sticker with a beep.
    final gif = p.join(dir.path, 'meme.gif');
    final sticker = p.join(dir.path, 'beep.mp4');
    await tester.runAsync(() async {
      final a = await Process.run(ffmpeg, [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=magenta:s=200x150:d=1:r=10',
        gif,
      ]);
      expect(a.exitCode, 0, reason: a.stderr as String);
      final b = await Process.run(ffmpeg, [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=yellow:s=160x90:d=2:r=30',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:d=2',
        '-c:v',
        'mpeg4',
        '-c:a',
        'aac',
        '-shortest',
        sticker,
      ]);
      expect(b.exitCode, 0, reason: b.stderr as String);
    });

    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final container = ProviderContainer();
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
    await tester.pump();

    // Drop both files on the preview with the playhead at 0:05: the GIF
    // goes on top, the .mp4 is a video so it joins the main track.
    // Wait for the player to load the video so the seek sticks.
    final preview = container.read(previewProvider);
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() async {
        await preview.seek(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      if (preview.position == const Duration(seconds: 5)) break;
    }
    expect(preview.position, const Duration(seconds: 5));
    final ref = tester.element(find.byType(PreviewPane)) as WidgetRef;
    await tester.runAsync(
      () => dropFiles(ref, tester.element(find.byType(PreviewPane)), [gif]),
    );
    await tester.pump();
    var project = container.read(projectEditorProvider).project;
    final meme = project.overlays.single;
    expect(meme.start, const Duration(seconds: 5));
    expect(meme.duration, const Duration(seconds: 3), reason: '3 loops');
    expect(container.read(timelineUiProvider).selectedOverlayId, meme.id);

    // Into the bottom-right corner, smaller (what dragging does).
    container
        .read(projectEditorProvider.notifier)
        .run(
          UpdateOverlay(
            meme.id,
            transform: const OverlayTransform(x: 0.85, y: 0.78, scale: 0.2),
          ),
        );
    // The video sticker, added through the overlay picker's code path.
    await tester.runAsync(() async {
      final media = await probeOverlayMedia(ffmpeg, sticker);
      expect(media.hasAudio, isTrue);
      container
          .read(projectEditorProvider.notifier)
          .runAll(
            'Add overlay',
            overlayCommands(
              container.read(projectEditorProvider).project,
              media,
              const Duration(seconds: 12),
            ),
          );
    });
    project = container.read(projectEditorProvider).project;
    expect(project.overlays, hasLength(2));

    // Let the preview frames load, then look at it.
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => container.read(previewProvider).seek(const Duration(seconds: 6)),
    );
    await tester.pump();
    await saveScreenshot(tester, 'overlay_preview');

    await tester.runAsync(() async {
      final out = p.join(dir.path, 'out.mp4');
      final job = await Exporter(ffmpeg).start(
        project: project,
        projectPath: null,
        preset: ExportPreset.hd1080,
        outputPath: out,
      );
      final watch = Stopwatch()..start();
      expect(await job.done, isTrue);
      // ignore: avoid_print
      print('OVERLAY EXPORT took ${watch.elapsed}');
      final result = await probeVideo(out);
      expect(result.duration.inMilliseconds, closeTo(20000, 150));

      Future<List<int>> pixel(double at, int x, int y) async {
        final r = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-ss',
          '$at',
          '-i',
          out,
          '-frames:v',
          '1',
          '-vf',
          'crop=8:8:$x:$y,scale=1:1,format=rgb24',
          '-f',
          'rawvideo',
          '-',
        ], stdoutEncoding: null);
        return r.stdout as List<int>;
      }

      // Bottom-right: magenta while it's on.
      // 0.2 * 1920 = 384 wide, centred at (1632, 842); its right part.
      final on = await pixel(6.5, 1780, 842);
      expect(on[0], greaterThan(200), reason: 'red in $on');
      expect(on[1], lessThan(60), reason: 'green in $on');
      expect(on[2], greaterThan(200), reason: 'blue in $on');
      // Gone after 0:08.
      final off = await pixel(9, 1780, 842);
      expect(off, isNot(equals(on)));
      // The sticker is yellow in the middle at 0:13.
      final yellow = await pixel(13, 956, 536);
      expect(yellow[0], greaterThan(200), reason: 'sticker $yellow');
      expect(yellow[1], greaterThan(200), reason: 'sticker $yellow');
      expect(yellow[2], lessThan(80), reason: 'sticker $yellow');

      // The beep is in the mix around 0:13.
      final beep = await Process.run(ffmpeg, [
        '-hide_banner',
        '-ss',
        '12.5',
        '-t',
        '1',
        '-i',
        out,
        '-af',
        'bandpass=f=880:width_type=q:w=20,volumedetect',
        '-f',
        'null',
        '-',
      ]);
      final before = await Process.run(ffmpeg, [
        '-hide_banner',
        '-ss',
        '10',
        '-t',
        '1',
        '-i',
        out,
        '-af',
        'bandpass=f=880:width_type=q:w=20,volumedetect',
        '-f',
        'null',
        '-',
      ]);
      double mean(ProcessResult r) => double.parse(
        RegExp(r'mean_volume: (-?[\d.]+)')
            .firstMatch(r.stderr as String)!
            .group(1)!,
      );
      // ignore: avoid_print
      print('880 Hz: ${mean(before)} dB before, ${mean(beep)} dB during');
      expect(mean(beep), greaterThan(mean(before) + 10));
    });
  }, skip: sample == null);
}
