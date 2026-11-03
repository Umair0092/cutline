import 'dart:async';
import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/music/music_library.dart';
import 'package:cutline/music/music_panel.dart';
import 'package:cutline/titles/title_editor_dialog.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:cutline/ui/dialogs/dialog_kit.dart';
import 'package:cutline/ui/export_dialog.dart';
import 'package:cutline/ui/navigation.dart';
import 'package:cutline/ui/settings_dialog.dart';
import 'package:cutline/voice/voiceover_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;

import '../test/ai/fake_claude.dart';
import 'screenshot.dart';

/// An export that reports the progress it's told to.
class _FakeJob implements ExportJob {
  _FakeJob(this.outputPath);

  final _progress = StreamController<double>.broadcast();
  final _done = Completer<bool>();

  @override
  final String outputPath;

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Future<bool> get done => _done.future;

  @override
  void cancel() => _done.complete(false);

  void report(double p) => _progress.add(p);
  void finish() => _done.complete(true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tracks = [
  Track(
    id: 't1',
    title: 'Sunday Morning Coffee',
    source: '/nonexistent/a.mp3',
    artist: 'Lofi Lane',
    duration: Duration(minutes: 2, seconds: 41),
    license: 'CC BY 4.0',
    genres: ['lofi'],
  ),
  Track(
    id: 't2',
    title: 'Rainy Window',
    source: '/nonexistent/b.mp3',
    artist: 'Kawa',
    duration: Duration(minutes: 3, seconds: 5),
    license: 'CC BY-SA 4.0',
    genres: ['chill'],
  ),
  Track(
    id: 't3',
    title: 'Late Night Study Session With a Very Long Title',
    source: '/nonexistent/c.mp3',
    artist: 'Moonbeam',
    duration: Duration(minutes: 1, seconds: 58),
    license: 'CC0',
    genres: ['ambient'],
  ),
  Track(
    id: 't4',
    title: 'Paper Planes',
    source: '/nonexistent/d.mp3',
    artist: 'The Quiet Hours',
    duration: Duration(minutes: 2, seconds: 12),
    license: 'CC BY 4.0',
    genres: ['acoustic'],
  ),
  Track(
    id: 't5',
    title: 'Golden Hour',
    source: '/nonexistent/e.mp3',
    artist: 'Saffron',
    duration: Duration(minutes: 4, seconds: 2),
    license: 'CC BY 3.0',
    genres: ['pop'],
  ),
  Track(
    id: 't6',
    title: 'Drift',
    source: '/nonexistent/f.mp3',
    artist: 'Novak',
    duration: Duration(minutes: 2, seconds: 30),
    license: 'CC BY 4.0',
    genres: ['electronic'],
  ),
];

/// Screenshots of every dialog and sheet, desktop and phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('dialogs, desktop and phone', (tester) async {
    final support = Directory.systemTemp.createTempSync('cutline_dialogs');
    final scratch = Directory.systemTemp.createTempSync('cutline_dlgwork');
    File('${support.path}/preferences.json')
        .writeAsStringSync('{"onboarded":true,"yourName":"Umair Hassan"}');
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('gsk_test')),
        trackFinderProvider.overrideWithValue(
          (query, {kind = TrackKind.music}) async => _tracks,
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
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

    await wait(500);
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
    await showEditor();
    await wait(2500);

    BuildContext ctx() => appNavigatorKey.currentContext!;
    final ffmpeg = const FfmpegLocator().find() ?? 'ffmpeg';
    final project = container
        .read(projectEditorProvider)
        .project
        .copyWith(
          name: 'Weekly Rails Tips 12',
          media: [
            ...container.read(projectEditorProvider).project.media,
            const MediaAsset(
              id: 'm1',
              path: 'assets/music.mp3',
              kind: MediaKind.audio,
              credit:
                  '"Sunday Morning Coffee" by Lofi Lane (CC BY 4.0) '
                  'https://openverse.org/audio/1',
            ),
          ],
          audio: [
            const AudioItem(
              id: 'a1',
              mediaId: 'm1',
              role: AudioRole.music,
              start: Duration.zero,
              sourceStart: Duration.zero,
              sourceEnd: Duration(seconds: 20),
            ),
          ],
        );
    Future<void> close() async {
      Navigator.of(ctx()).pop();
      await wait(600);
    }

    Future<void> shots(String size) async {
      // Export: choose, progress, done.
      _FakeJob? job;
      unawaited(
        showCutModal<void>(
          ctx(),
          builder: (_) => ExportDialog(
            project: project,
            projectPath: scratch.path,
            ffmpeg: ffmpeg,
            frameAt: const Duration(seconds: 6),
            chooseLocation: (name) async => '/Users/you/Movies/$name',
            startJob: (preset, path) async => job = _FakeJob(path),
          ),
        ),
      );
      await wait(1200);
      await saveScreenshot(tester, 'dialogs_export_$size', settle: false);
      await tester.tap(find.byKey(const Key('export-next')));
      await wait(300);
      job!.report(0.42);
      await wait(1500);
      await saveScreenshot(
        tester,
        'dialogs_export_progress_$size',
        settle: false,
      );
      job!.finish();
      await wait(1200);
      await saveScreenshot(tester, 'dialogs_export_done_$size', settle: false);
      await close();

      // Settings, on the AI page and the intros page.
      unawaited(showSettings(ctx()));
      await wait(800);
      await saveScreenshot(tester, 'dialogs_settings_$size', settle: false);
      if (size == 'phone') {
        await tester.tap(find.text('AI assistant').first);
      } else {
        await tester.tap(find.byKey(const Key('settings-shortcuts')));
      }
      await wait(600);
      await saveScreenshot(tester, 'dialogs_settings_2_$size', settle: false);
      await close();

      // Title editor with a picture template and with the clean card.
      unawaited(
        showTitleEditor(
          ctx(),
          projectPath: scratch.path,
          templateId: 'logo-reveal',
        ),
      );
      await wait(1800);
      await saveScreenshot(tester, 'dialogs_title_$size', settle: false);
      if (size == 'phone') {
        await tester.tap(find.text('Style'));
        await wait(600);
        await saveScreenshot(
          tester,
          'dialogs_title_style_$size',
          settle: false,
        );
      }
      await close();

      // Voiceover.
      unawaited(showVoiceoverDialog(ctx()));
      await wait(1800);
      await tester.enterText(
        find.byKey(const Key('voiceover-script')),
        'Welcome to the tour.\nNext, we set up your account.',
      );
      await wait(300);
      await saveScreenshot(tester, 'dialogs_voiceover_$size', settle: false);
      await close();

      // Music browser.
      unawaited(showMusicBrowser(ctx()));
      await wait(1500);
      await saveScreenshot(tester, 'dialogs_music_$size', settle: false);
      await tester.tap(find.text('Rainy Window'));
      await wait(800);
      await saveScreenshot(
        tester,
        'dialogs_music_playing_$size',
        settle: false,
      );
      await close();

      // Sound levels.
      if (size == 'phone') {
        unawaited(showMixSheet(ctx()));
      } else {
        unawaited(
          showCutModal<void>(
            ctx(),
            builder: (_) => const CutModalPreview(child: MixControls()),
          ),
        );
      }
      await wait(1000);
      await saveScreenshot(tester, 'dialogs_mix_$size', settle: false);
      await close();
    }

    await shots('desktop');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    await wait(1200);
    await shots('phone');
  }, skip: sample == null);
}

/// The mix controls in a popover-sized card, as the editor shows them.
class CutModalPreview extends StatelessWidget {
  const CutModalPreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CutModal(width: 360, title: 'Sound levels', body: child);
}
