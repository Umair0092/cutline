import 'dart:io';

import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:flutter/material.dart';
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
  final giphyKey = Platform.environment['GIPHY_API_KEY'];

  testWidgets('search "this is fine" and drop it on the timeline', (
    tester,
  ) async {
    final ffmpeg = const FfmpegLocator().find()!;
    final folder = Directory.systemTemp.createTempSync('cutline_memes');
    await tester.runAsync(() async {
      for (final (name, colour) in [
        ('this is fine', 'orange'),
        ('deadline panic', 'red'),
      ]) {
        final r = await Process.run(ffmpeg, [
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=c=$colour:s=240x180:d=1:r=10',
          p.join(folder.path, '$name.gif'),
        ]);
        expect(r.exitCode, 0, reason: r.stderr as String);
      }
    });

    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    final container = ProviderContainer(
      overrides: [
        memesFolderProvider.overrideWith((_) async => folder.path),
        if (giphyKey == null) giphyKeyProvider.overrideWith(_NoKey.new),
      ],
    );
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-memes')));
    await tester.pumpAndSettle();

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    await tester.enterText(
      find.byKey(const Key('meme-search')),
      'this is fine',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    final tile = find.byKey(
      Key('meme-${p.join(folder.path, 'this is fine.gif')}'),
    );
    expect(tile, findsOneWidget);
    await saveScreenshot(tester, 'memes_search');

    // Drag it onto the timeline at 0:10 (40 px/s, 16 px padding).
    final tracks = tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
    final target = tracks + const Offset(16 + 10 * 40, 170);
    final from = tester.getCenter(tile);
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    // Reading the GIF runs ffmpeg.
    await settle();

    final project = container.read(projectEditorProvider).project;
    final meme = project.overlays.single;
    expect(meme.start.inMilliseconds, closeTo(10000, 50));
    expect(
      p.basename(project.mediaById(meme.mediaId)!.path),
      'this is fine.gif',
    );
    expect(container.read(timelineUiProvider).selectedOverlayId, meme.id);
    expect(container.read(projectEditorProvider).undoLabel, 'Add meme');
    await saveScreenshot(tester, 'memes_dropped');

    if (giphyKey != null) {
      // Live GIPHY: search, click the first result, it downloads into the
      // project's assets.
      await tester.enterText(
        find.byKey(const Key('meme-search')),
        'this is fine',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      expect(find.text('GIPHY'), findsOneWidget);
      final first = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('meme-') &&
            !(w.key! as ValueKey<String>).value.contains(folder.path),
      );
      await tester.tap(first.first);
      for (var i = 0; i < 100; i++) {
        await settle();
        if (container.read(projectEditorProvider).project.overlays.length ==
            2) {
          break;
        }
      }
      final online = container
          .read(projectEditorProvider)
          .project
          .overlays
          .last;
      final path = container
          .read(projectEditorProvider)
          .project
          .mediaById(online.mediaId)!
          .path;
      expect(path, startsWith('assets/giphy-'));
      await saveScreenshot(tester, 'memes_giphy');
    }
  }, skip: sample == null);
}

class _NoKey extends GiphyKeyNotifier {
  @override
  Future<String?> build() async => null;
}
