import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/startup/startup.dart';
import 'package:cutline/storage/project_store.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// Screenshots of everything before the editor: the splash, the first-run
/// guide, and the dashboard (empty and with edits) on desktop and phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
  }

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
  }

  testWidgets('splash, guide and empty dashboard', (tester) async {
    desktop(tester);
    addTearDown(tester.view.reset);
    final support = Directory.systemTemp.createTempSync('cutline_home');
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        splashMinimumProvider.overrideWithValue(const Duration(seconds: 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(showSplash: true),
      ),
    );
    // Mid-animation, then the settled splash.
    await tester.pump(const Duration(milliseconds: 380));
    await saveScreenshot(tester, 'home_splash_mid', settle: false);
    await wait(tester, 1500);
    await saveScreenshot(tester, 'home_splash_desktop', settle: false);

    await wait(tester, 2500);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    await wait(tester, 4200); // the loop is mid-edit
    await saveScreenshot(tester, 'home_onboarding_1', settle: false);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await wait(tester, 600);
    await saveScreenshot(tester, 'home_onboarding_2', settle: false);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await wait(tester, 600);
    await saveScreenshot(tester, 'home_onboarding_3', settle: false);

    // Phone guide.
    phone(tester);
    await wait(tester, 600);
    await saveScreenshot(tester, 'home_onboarding_phone_3', settle: false);
    await tester.tap(find.text('Back'));
    await wait(tester, 600);
    await saveScreenshot(tester, 'home_onboarding_phone_2', settle: false);
    await tester.tap(find.byKey(const Key('onboarding-done')));
    await wait(tester, 800);
    await saveScreenshot(tester, 'home_empty_phone', settle: false);

    desktop(tester);
    await wait(tester, 800);
    await saveScreenshot(tester, 'home_empty_desktop', settle: false);
  });

  testWidgets('dashboard with edits, desktop and phone', (tester) async {
    final support = Directory.systemTemp.createTempSync('cutline_home2');
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
      'Launch teaser': edit('Launch teaser', [(3, 9), (11, 16)]),
      'Office hours Q&A': edit('Office hours Q&A', [(0, 20)]),
      'Photo story': const Project(name: 'Photo story'),
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
        .writeAsStringSync('{"onboarded":true,"yourName":"Umair"}');
    desktop(tester);
    addTearDown(tester.view.reset);
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
    await wait(tester, 4500);
    expect(find.byKey(const Key('dashboard')), findsOneWidget);
    await saveScreenshot(tester, 'home_dashboard_desktop', settle: false);

    // Hover a card part-way across: it lifts and scrubs.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final card = find.text('Deadline rant');
    final box = tester.getRect(
      find.ancestor(of: card, matching: find.byType(MouseRegion)).last,
    );
    await mouse.moveTo(Offset(box.left + box.width * 0.6, box.top + 60));
    await wait(tester, 600);
    await saveScreenshot(tester, 'home_dashboard_hover', settle: false);
    // Its menu.
    await tester.tap(find.byTooltip('More').at(1));
    await wait(tester, 500);
    await saveScreenshot(tester, 'home_dashboard_menu', settle: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 400);
    await mouse.moveTo(Offset.zero);

    // Narrow desktop window.
    tester.view.physicalSize = const Size(1600, 1800);
    await wait(tester, 800);
    await saveScreenshot(tester, 'home_dashboard_narrow', settle: false);

    phone(tester);
    await wait(tester, 800);
    await saveScreenshot(tester, 'home_dashboard_phone', settle: false);
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -500),
      kind: PointerDeviceKind.touch,
    );
    await wait(tester, 800);
    await saveScreenshot(
      tester,
      'home_dashboard_phone_scrolled',
      settle: false,
    );
    await tester.longPress(find.text('Setup tour'));
    await wait(tester, 800);
    await saveScreenshot(tester, 'home_dashboard_phone_sheet', settle: false);
  }, skip: sample == null);
}
