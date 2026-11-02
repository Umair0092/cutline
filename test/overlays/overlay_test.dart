import 'dart:ui' as ui;

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/overlays/overlay_actions.dart';
import 'package:cutline/overlays/overlay_frames.dart';
import 'package:cutline/overlays/overlay_media.dart';
import 'package:cutline/overlays/overlay_paint.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../fixtures.dart';

const gif = MediaAsset(
  id: 'g',
  path: '/memes/fine.gif',
  kind: MediaKind.gif,
  duration: Duration(milliseconds: 1200),
  width: 400,
  height: 200,
);

void main() {
  group('parseFfmpegInfo', () {
    test('reads a GIF', () {
      final info = parseFfmpegInfo('''
Input #0, gif, from 't.gif':
  Duration: 00:00:02.50, start: 0.000000, bitrate: 199 kb/s
  Stream #0:0: Video: gif, bgra, 200x150 [SAR 64:64 DAR 4:3], 10 fps, 10 tbr, 100 tbn
''')!;
      expect(info.duration, const Duration(milliseconds: 2500));
      expect((info.width, info.height), (200, 150));
      expect(info.fps, 10);
      expect(info.hasAudio, isFalse);
    });

    test('reads a video and skips the codec tag that looks like a size', () {
      final info = parseFfmpegInfo('''
  Duration: 00:01:02.04, start: 0.000000, bitrate: 2000 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(tv, bt709, progressive), 1280x720 [SAR 1:1 DAR 16:9], 29.97 fps, 30 tbr
  Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 128 kb/s
''')!;
      expect((info.width, info.height), (1280, 720));
      expect(
        info.duration,
        const Duration(minutes: 1, seconds: 2, milliseconds: 40),
      );
      expect(info.fps, 29.97);
      expect(info.hasAudio, isTrue);
    });

    test('no video stream is null', () {
      expect(parseFfmpegInfo('Stream #0:0: Audio: mp3, 44100 Hz'), isNull);
    });
  });

  test('overlayKindOf goes by extension', () {
    expect(overlayKindOf('/a/B.PNG'), MediaKind.image);
    expect(overlayKindOf('/a/b.gif'), MediaKind.gif);
    expect(overlayKindOf('/a/b.mov'), MediaKind.video);
    expect(overlayKindOf('/a/b.txt'), isNull);
  });

  test(
    'default length: 3 s for pictures, whole GIF loops, never past the end',
    () {
      final still = gif.copyWith(
        kind: MediaKind.image,
        duration: Duration.zero,
      );
      expect(defaultOverlayDuration(still, s(60)), s(3));
      expect(defaultOverlayDuration(gif, s(60)), s(3.6), reason: '3 loops');
      expect(defaultOverlayDuration(gif, s(2)), s(2));
      final clip = gif.copyWith(kind: MediaKind.video, duration: s(8));
      expect(defaultOverlayDuration(clip, s(60)), s(8));
    },
  );

  test('overlayCommands adds the media once and stacks on top', () {
    var p = threeClips();
    for (final c in overlayCommands(p, gif, s(5), id: 'o1')) {
      p = c.apply(p);
    }
    for (final c in overlayCommands(p, gif, s(6), id: 'o2')) {
      p = c.apply(p);
    }
    expect(p.media.where((m) => m.id == 'g'), hasLength(1));
    expect([for (final o in p.overlays) o.layer], [0, 1]);
    expect(p.overlays.first.duration, s(3.6));
  });

  test('preview frames loop', () async {
    final images = [
      for (var i = 0; i < 3; i++) await createTestImage(width: 2, height: 2),
    ];
    final f = OverlayFrames(images, 10);
    expect(f.frameAt(Duration.zero), images[0]);
    expect(f.frameAt(const Duration(milliseconds: 250)), images[2]);
    expect(f.frameAt(const Duration(milliseconds: 310)), images[0]);
    expect(OverlayFrames([images[1]], 10).frameAt(s(99)), images[1]);
  });

  group('overlay drawing', () {
    const frame = ui.Size(1000, 500);

    test('rect is centred on x, y and scale is a share of the width', () {
      final r = overlayRect(
        frame,
        2,
        const OverlayTransform(x: 0.8, y: 0.2, scale: 0.4),
      );
      expect(r.center, const Offset(800, 100));
      expect(r.size, const Size(400, 200));
    });

    test('presence ramps in and out', () {
      expect(overlayPresence(0, 3), 0);
      expect(overlayPresence(overlayAnimationTime, 3), 1);
      expect(overlayPresence(1.5, 3), 1);
      expect(overlayPresence(3, 3), 0);
      expect(overlayPresence(0.1, 0.2), 1, reason: 'short ones ramp faster');
    });

    test('unrotate undoes rotateAround', () {
      final rect = Rect.fromCenter(
        center: const Offset(100, 100),
        width: 50,
        height: 20,
      );
      final p = rotateAround(rect.bottomRight, rect, 30);
      final back = unrotate(p, rect, 30);
      expect(back.dx, closeTo(rect.right, 1e-9));
      expect(back.dy, closeTo(rect.bottom, 1e-9));
    });
  });

  group('in the editor', () {
    late FakePreviewController preview;
    late ProviderContainer container;
    OverlayItem overlay() =>
        container.read(projectEditorProvider).project.overlays.single;

    Future<void> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final image = await tester.runAsync(
        () => createTestImage(width: 40, height: 20),
      );
      preview = FakePreviewController();
      container = ProviderContainer(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
          previewProvider.overrideWithValue(preview),
          overlayFramesProvider.overrideWith(
            (ref, key) async => OverlayFrames([image!], 12),
          ),
        ],
      );
      addTearDown(container.dispose);
      var p = threeClips();
      for (final c in overlayCommands(p, gif, s(5), id: 'o')) {
        p = c.apply(p);
      }
      container.read(projectEditorProvider.notifier).opened(p, '/p');
      container.read(timelineUiProvider.notifier).setZoom(20);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CutlineApp(),
        ),
      );
      await preview.seek(s(6));
      await tester.pumpAndSettle();
    }

    testWidgets('drag to move, drag the corner to resize, one undo each', (
      tester,
    ) async {
      await pumpEditor(tester);
      final before = tester.getRect(find.byKey(const Key('overlay-layer')));

      // Click it to select; the inspector shows up (and the video gets a
      // little smaller to make room).
      await tester.tapAt(before.center);
      await tester.pump();
      final layer = tester.getRect(find.byKey(const Key('overlay-layer')));
      expect(container.read(timelineUiProvider).selectedOverlayId, 'o');
      expect(find.byKey(const Key('overlay-inspector')), findsOneWidget);

      await tester.dragFrom(layer.center, Offset(layer.width * 0.2, 0));
      await tester.pumpAndSettle();
      expect(overlay().transform.x, closeTo(0.7, 0.01));
      expect(container.read(projectEditorProvider).undoLabel, 'Change overlay');

      // The handle is the bottom-right corner of the 0.3-wide overlay.
      final w = layer.width * 0.3;
      final corner =
          layer.topLeft +
          Offset(layer.width * 0.7 + w / 2, layer.height * 0.5 + w / 4);
      final centre =
          layer.topLeft + Offset(layer.width * 0.7, layer.height / 2);
      await tester.dragFrom(corner, (corner - centre));
      await tester.pumpAndSettle();
      expect(overlay().transform.scale, closeTo(0.6, 0.02));

      container.read(projectEditorProvider.notifier).undo();
      expect(overlay().transform.scale, 0.3);
      expect(overlay().transform.x, closeTo(0.7, 0.01));
    });

    testWidgets('timeline: drag to move, stretch the end, Delete removes', (
      tester,
    ) async {
      await pumpEditor(tester);
      final origin = tester.getTopLeft(
        find.byKey(const Key('timeline-tracks')),
      );
      // 20 px/s with 16 px padding: the overlay spans x 116–188.
      const y = 167.0;
      await tester.tapAt(origin + const Offset(130, y));
      await tester.pump();
      expect(container.read(timelineUiProvider).selectedOverlayId, 'o');

      await tester.dragFrom(origin + const Offset(130, y), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(overlay().start, s(7));
      expect(overlay().duration, s(3.6));

      // Right edge now at 156 + 72 = 228.
      await tester.dragFrom(origin + const Offset(227, y), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(overlay().start, s(7));
      expect(overlay().duration.inMilliseconds, closeTo(5600, 60));

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(container.read(projectEditorProvider).project.overlays, isEmpty);
      expect(container.read(projectEditorProvider).project.clips, hasLength(3));
    });
  });
}
