import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/storage/project_store.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// Screenshots of the dashboard and editor at desktop and phone sizes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('dashboard and editor, desktop and phone', (tester) async {
    final support = Directory.systemTemp.createTempSync('cutline_dash');
    final asset = (await tester.runAsync(() => probeVideo(sample!)))!;
    Project edit(String name, List<(int, int)> keep) => Project(
      name: name,
      media: [asset],
      clips: [
        for (final (i, (a, b)) in keep.indexed)
          VideoClip(
            id: 'c$i',
            mediaId: asset.id,
            sourceStart: Duration(seconds: a),
            sourceEnd: Duration(seconds: b),
          ),
      ],
    );
    final projects = {
      'Weekly Rails Tips 12':
          edit('Weekly Rails Tips 12', [(0, 6), (8, 14), (15, 20)]).copyWith(
            overlays: [
              OverlayItem(
                id: 'o',
                mediaId: asset.id,
                start: const Duration(seconds: 4),
                duration: const Duration(seconds: 2),
              ),
            ],
            titles: [
              const TitleItem(
                id: 't',
                spec: TitleSpec(
                  templateId: 'lower-third',
                  duration: Duration(seconds: 3),
                ),
                start: Duration(seconds: 1),
              ),
            ],
          ),
      'Deadline rant': edit('Deadline rant', [(2, 18)]),
      'Setup tour': edit('Setup tour', [(0, 4), (5, 9), (10, 12), (13, 20)]),
    };
    await tester.runAsync(() async {
      for (final MapEntry(:key, :value) in projects.entries) {
        await const ProjectStore().save(
          value,
          p.join(support.path, 'Projects', '$key.cutline'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    File(p.join(support.path, 'preferences.json'))
        .writeAsStringSync('{"onboarded":true}');
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('gsk_test')),
      ],
    );
    addTearDown(container.dispose);
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

    await wait(4000);
    expect(find.byKey(const Key('dashboard')), findsOneWidget);
    await saveScreenshot(tester, 'dashboard_desktop', settle: false);
    await tester.tap(find.text('Weekly Rails Tips 12'));
    await wait(2500);
    await saveScreenshot(tester, 'editor_desktop', settle: false);
    await tester.tap(find.byKey(const Key('back-to-edits')));
    await wait(1500);

    // Phone size (Pixel 8).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await wait(800);
    await saveScreenshot(tester, 'dashboard_phone', settle: false);
    await tester.tap(find.text('Weekly Rails Tips 12'));
    await wait(2500);
    await saveScreenshot(tester, 'editor_phone', settle: false);
    await tester.tap(find.byKey(const Key('action-ask')));
    await wait(800);
    await saveScreenshot(tester, 'assistant_phone', settle: false);
  }, skip: sample == null);
}
