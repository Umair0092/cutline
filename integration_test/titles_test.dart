import 'dart:io';
import 'dart:ui' as ui;

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/titles/templates.dart';
import 'package:cutline/titles/title_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

const lowerThird = TitleSpec(
  templateId: 'lower-third',
  fields: {
    'name': 'Umair Hassan',
    'role': 'Software Engineer',
    'barColor': '#6C5CE7',
  },
  duration: Duration(seconds: 4),
);

/// One RGB pixel of a video frame at [seconds], decoded by ffmpeg.
Future<List<int>> videoPixel(
  String ffmpeg,
  String video,
  double seconds,
  int x,
  int y,
) async {
  final r = await Process.run(ffmpeg, [
    '-v',
    'error',
    '-ss',
    '$seconds',
    '-i',
    video,
    '-frames:v',
    '1',
    '-vf',
    'format=rgb24,crop=1:1:$x:$y',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgb24',
    '-',
  ], stdoutEncoding: null);
  return (r.stdout as List<int>).take(3).toList();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('every template, rendered offscreen', (tester) async {
    final dir = Platform.environment['SCREENSHOT_DIR'];
    await tester.runAsync(() async {
      for (final tpl in titleTemplates) {
        final spec = TitleSpec(
          templateId: tpl.id,
          fields: const {
            'title': 'Weekly Rails Tips',
            'name': 'Umair Hassan',
            'subtitle': 'Episode 3',
          },
          duration: tpl.defaultDuration,
        );
        final image = await renderTitleFrame(spec, 960, 540, 2.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (dir != null) {
          File('$dir/template-${tpl.id}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        }
      }
    });
  });

  testWidgets('intro before the video, lower third over it, both exported', (
    tester,
  ) async {
    final ffmpeg = const FfmpegLocator().find()!;
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final container = ProviderContainer(
      overrides: [apiKeyStoreProvider.overrideWithValue(MemoryKeyStore())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    final editor = container.read(projectEditorProvider.notifier);
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

    // An intro card before the video, rendered to a clip by the real ffmpeg.
    const card = TitleSpec(
      templateId: 'clean-card',
      fields: {'title': 'Weekly Rails Tips', 'subtitle': 'by Umair'},
      duration: Duration(seconds: 3),
    );
    final state = container.read(projectEditorProvider);
    final introPath = p.join(state.workPath!, 'assets', 'intro-test.mp4');
    Directory(p.dirname(introPath)).createSync(recursive: true);
    await tester.runAsync(
      () =>
          TitleRenderer(ffmpeg)
              .renderClip(card, introPath, width: 1280, height: 720, fps: 30),
    );
    final introAsset = (await tester.runAsync(() => probeVideo(introPath)))!;
    expect(introAsset.duration.inMilliseconds, closeTo(3000, 100));
    editor.runAll('Add intro', [
      AddMedia(introAsset.copyWith(title: card)),
      AddClip(
        VideoClip(
          id: 'intro',
          mediaId: introAsset.id,
          sourceStart: Duration.zero,
          sourceEnd: introAsset.duration,
        ),
        index: 0,
      ),
    ]);

    // A lower third over the video from 5 s (2 s into the video itself).
    editor.run(
      AddTitle(
        TitleItem(
          id: 'lt',
          spec: lowerThird,
          start: const Duration(seconds: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Preview at 6.2 s: the lower third is fully in, over the video.
    final preview = container.read(previewProvider);
    await tester.runAsync(() async {
      await preview.seek(const Duration(milliseconds: 6200));
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('title-lt')), findsOneWidget);
    await saveScreenshot(tester, 'title-preview');

    // Export, then compare against the offscreen render of the same frame.
    final out = p.join(
      Directory.systemTemp.createTempSync('cutline_titles').path,
      'out.mp4',
    );
    await tester.runAsync(() async {
      final job = await Exporter(ffmpeg).start(
        project: container.read(projectEditorProvider).project,
        projectPath: container.read(projectEditorProvider).workPath,
        preset: ExportPreset.hd1080,
        outputPath: out,
      );
      expect(await job.done, isTrue);
    });
    final result = (await tester.runAsync(() => probeVideo(out)))!;
    expect(
      result.duration.inMilliseconds,
      closeTo(23000, 150),
      reason: '3 s intro + 20 s video',
    );

    final frame = (await tester.runAsync(
      () => renderTitleFrame(lowerThird, 1920, 1080, 1.2),
    ))!;
    final rgba = (await tester.runAsync(
      () => frame.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final bar = parseHexColor('#6C5CE7')!;
    // A pixel that is solid bar colour in the offscreen render.
    int? bx, by;
    for (var y = 700; y < 1080 && bx == null; y += 4) {
      for (var x = 80; x < 900; x += 4) {
        final i = (y * 1920 + x) * 4;
        final c = rgba.buffer.asUint8List(rgba.offsetInBytes);
        if (c[i + 3] > 220 &&
            (c[i] - (bar.r * 255)).abs() < 8 &&
            (c[i + 2] - (bar.b * 255)).abs() < 8) {
          bx = x + 6;
          by = y + 6;
          break;
        }
      }
    }
    expect(bx, isNotNull);
    final inside = (await tester.runAsync(
      () => videoPixel(ffmpeg, out, 6.2, bx!, by!),
    ))!;
    final before = (await tester.runAsync(
      () => videoPixel(ffmpeg, out, 4.0, bx!, by!),
    ))!;
    // ignore: avoid_print
    print('PIXEL at ($bx,$by): with title $inside, before title $before');
    final expected = [bar.r * 255, bar.g * 255, bar.b * 255];
    for (var k = 0; k < 3; k++) {
      expect(inside[k], closeTo(expected[k], 40), reason: 'channel $k');
    }
    expect(
      [for (var k = 0; k < 3; k++) (before[k] - expected[k]).abs()]
          .reduce((a, b) => a + b),
      greaterThan(60),
      reason: 'no bar before the title starts',
    );
    final introFrame = '${p.dirname(out)}/intro.png';
    await tester.runAsync(
      () => Process.run(ffmpeg, [
        '-v',
        'error',
        '-y',
        '-ss',
        '1.5',
        '-i',
        out,
        '-frames:v',
        '1',
        introFrame,
      ]),
    );
    final exportFrame = '${p.dirname(out)}/lt.png';
    await tester.runAsync(
      () => Process.run(ffmpeg, [
        '-v',
        'error',
        '-y',
        '-ss',
        '6.2',
        '-i',
        out,
        '-frames:v',
        '1',
        exportFrame,
      ]),
    );
    final dir = Platform.environment['SCREENSHOT_DIR'];
    if (dir != null) {
      File(introFrame).copySync('$dir/title-export-intro.png');
      File(exportFrame).copySync('$dir/title-export-lowerthird.png');
    }
  }, skip: sample == null);
}
