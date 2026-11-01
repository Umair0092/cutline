import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_previews.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('timeline shows thumbnails and waveform, edits work', (
    tester,
  ) async {
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final container = ProviderContainer();
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
    container.read(timelineUiProvider.notifier).setZoom(40);

    // Real thumbnails and waveform from ffmpeg.
    final preview = (await tester.runAsync(
      () => container.read(mediaPreviewProvider(sample!).future),
    ))!;
    expect(preview.thumbnails.length, inInclusiveRange(19, 21));
    expect(preview.peaks, isNotNull);
    expect(preview.peaks!.length, inInclusiveRange(1990, 2010));
    expect(preview.peaks!.reduce((a, b) => a > b ? a : b), greaterThan(0.1));
    await tester.pumpAndSettle();

    // Split at 8s with the S key, then trim the second half's right edge.
    final player = container.read(previewProvider);
    await tester.runAsync(() async {
      await player.seek(const Duration(seconds: 8));
      for (var i = 0; i < 50; i++) {
        if ((player.position - const Duration(seconds: 8)).abs() <
            const Duration(milliseconds: 50)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    expect(player.position.inMilliseconds, closeTo(8000, 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(container.read(projectEditorProvider).project.clips, hasLength(2));

    final origin = tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
    // Right edge of the last clip is at 16 + 20 s * 40 px = 816.
    await tester.dragFrom(
      origin + const Offset(814, 60),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    final project = container.read(projectEditorProvider).project;
    expect(project.duration.inMilliseconds, closeTo(16000, 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await saveScreenshot(tester, 'timeline');
  }, skip: sample == null);
}
