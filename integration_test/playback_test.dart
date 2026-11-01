import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('import a video, play it, cut it', (tester) async {
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    expect(asset.duration.inMilliseconds, closeTo(20000, 100));
    expect((asset.width, asset.height), (1280, 720));
    expect(asset.hasAudio, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await saveScreenshot(tester, 'empty');

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
    await tester.pump();
    final player =
        (container.read(previewProvider) as MpvPreviewController).player;

    Future<Duration> playerDuration(int expectMs) async =>
        (await tester.runAsync(
          () => player.stream.duration
              .firstWhere((d) => (d.inMilliseconds - expectMs).abs() < 100)
              .timeout(const Duration(seconds: 10)),
        ))!;

    await playerDuration(20000);

    // Play for a moment and check time moves.
    await tester.tap(find.byKey(const Key('play')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(player.state.playing, isTrue);
    expect(player.state.position.inMilliseconds, greaterThan(1000));
    await tester.tap(find.byKey(const Key('play')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(player.state.playing, isFalse);
    await saveScreenshot(tester, 'playing');

    // Cutting 5s out of the middle makes the player 15s long.
    editor.run(const RemoveRange(Duration(seconds: 5), Duration(seconds: 10)));
    await tester.pump();
    await playerDuration(15000);
    expect(find.textContaining('/ 0:15.0'), findsOneWidget);

    // Undo brings the full 20s back.
    editor.undo();
    await tester.pump();
    await playerDuration(20000);
  }, skip: sample == null);
}
