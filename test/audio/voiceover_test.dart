import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/audio/audio_mix.dart';
import 'package:cutline/audio/recording.dart';
import 'package:cutline/audio/voice_recorder.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/timeline/timeline_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../fixtures.dart';

/// A mono 48 kHz WAV of silence, [seconds] long.
Uint8List silentWav(double seconds) {
  final samples = (seconds * 48000).round();
  final data = samples * 2;
  final b = ByteData(44 + data);
  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 48000, Endian.little)
    ..setUint32(28, 96000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, data, Endian.little);
  return b.buffer.asUint8List();
}

class FakeRecorder implements VoiceRecorder {
  bool allowed = true;
  String? path;
  Mic? mic;
  bool cancelled = false;
  final levels = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<List<Mic>> microphones() async => const [
    Mic('usb', 'USB Mic'),
    Mic('built-in', 'MacBook Microphone'),
  ];

  @override
  Future<void> start(String path, {Mic? mic}) async {
    this.path = path;
    this.mic = mic;
  }

  @override
  Future<String?> stop() async {
    File(path!).writeAsBytesSync(silentWav(2.5));
    return path;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    File(path!).writeAsBytesSync(silentWav(1));
  }

  @override
  Stream<double> get level => levels.stream;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('commands', () {
    Project withVoice() => threeClips().copyWith(
      media: [
        ...threeClips().media,
        MediaAsset(
          id: 'vo',
          path: 'assets/vo.wav',
          kind: MediaKind.audio,
          duration: s(10),
          hasAudio: true,
        ),
      ],
      audio: [
        AudioItem(
          id: 'a',
          mediaId: 'vo',
          role: AudioRole.voiceover,
          start: s(5),
          sourceStart: s(0),
          sourceEnd: s(10),
        ),
      ],
    );

    test('UpdateAudio moves, trims, fades; refuses nonsense', () {
      var p = UpdateAudio(
        'a',
        start: s(8),
        sourceEnd: s(6),
        fadeIn: s(1),
      ).apply(withVoice());
      final a = p.audio.single;
      expect((a.start, a.duration, a.fadeIn), (s(8), s(6), s(1)));
      expect(
        () => UpdateAudio('a', sourceEnd: s(12)).apply(p),
        throwsA(isA<EditException>()),
        reason: 'past the end of the file',
      );
      expect(
        () => UpdateAudio('a', fadeOut: s(5.5)).apply(p),
        throwsA(isA<EditException>()),
        reason: 'fades longer than the audio',
      );
      p = const SetAudioMix(AudioMix(original: 0, duck: false)).apply(p);
      expect(p.mix.original, 0);
    });

    test('extraAudioOf applies the voiceover track volume and skips muted '
        'sounds', () {
      final p = withVoice().copyWith(
        mix: const AudioMix(voiceover: 0.5),
        overlays: [
          OverlayItem(id: 'o', mediaId: 'm1', start: s(38), duration: s(5)),
        ],
      );
      final extras = extraAudioOf(p, '/proj');
      expect(extras, hasLength(2));
      expect(extras[0].path, '/proj/assets/vo.wav');
      expect(extras[0].volume, 0.5);
      expect(extras[0].voice, isTrue);
      expect(extras[1].length, s(2), reason: 'cut at the end of the video');

      final muted = p.copyWith(mix: const AudioMix(voiceover: 0));
      expect(extraAudioOf(muted, '/proj'), hasLength(1));
    });
  });

  group('recording', () {
    late FakePreviewController preview;
    late FakeRecorder recorder;
    late ProviderContainer container;
    late Directory work;
    EditorState editor() => container.read(projectEditorProvider);
    RecordingController rec() => container.read(recordingProvider.notifier);

    setUp(() {
      work = Directory.systemTemp.createTempSync('cutline_rec');
      preview = FakePreviewController();
      recorder = FakeRecorder();
      container = ProviderContainer(
        overrides: [
          previewProvider.overrideWithValue(preview),
          voiceRecorderProvider.overrideWithValue(recorder),
        ],
      );
      container
          .read(projectEditorProvider.notifier)
          .opened(threeClips(), work.path);
    });
    tearDown(() {
      container.dispose();
      work.deleteSync(recursive: true);
    });

    test('records from the playhead onto the voiceover track', () async {
      await rec().show();
      expect(container.read(recordingProvider).mics, hasLength(2));
      rec().pickMic(const Mic('usb', 'USB Mic'));
      await preview.seek(s(12));

      await rec().start();
      expect(container.read(recordingProvider).recording, isTrue);
      expect(recorder.mic?.id, 'usb');
      expect(recorder.path, startsWith(p.join(work.path, 'assets')));
      expect(preview.isPlaying, isTrue);
      expect(preview.volume, 0, reason: 'the video is quiet while recording');

      await rec().stop();
      expect(preview.isPlaying, isFalse);
      expect(preview.volume, 1);
      final item = editor().project.audio.single;
      expect(item.role, AudioRole.voiceover);
      expect(item.start, s(12));
      expect(item.duration.inMilliseconds, closeTo(2500, 30));
      final media = editor().project.mediaById(item.mediaId)!;
      expect(media.path, startsWith('assets/voiceover-'));
      expect(editor().undoLabel, 'Record voiceover');
      expect(container.read(timelineUiProvider).selectedAudioId, item.id);
    });

    test('wavLength reads the header', () {
      expect(wavLength(silentWav(2.5)), s(2.5));
      expect(wavLength([1, 2, 3]), isNull);
    });

    test('cancel throws the take away', () async {
      await rec().start();
      await rec().cancel();
      expect(recorder.cancelled, isTrue);
      expect(File(recorder.path!).existsSync(), isFalse);
      expect(editor().project.audio, isEmpty);
    });

    test('no microphone permission explains where to allow it', () async {
      recorder.allowed = false;
      await rec().start();
      expect(container.read(recordingProvider).recording, isFalse);
      expect(container.read(recordingProvider).error, contains('Microphone'));
    });
  });

  testWidgets('audio row: select, stretch to the file end, delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        previewProvider.overrideWithValue(FakePreviewController()),
      ],
    );
    addTearDown(container.dispose);
    final project = threeClips().copyWith(
      media: [
        ...threeClips().media,
        MediaAsset(
          id: 'vo',
          path: '/vo.wav',
          kind: MediaKind.audio,
          duration: s(6),
          hasAudio: true,
        ),
      ],
      audio: [
        AudioItem(
          id: 'a',
          mediaId: 'vo',
          role: AudioRole.voiceover,
          start: s(5),
          sourceStart: s(0),
          sourceEnd: s(4),
        ),
      ],
    );
    container.read(projectEditorProvider.notifier).opened(project, '/p');
    container.read(timelineUiProvider.notifier).setZoom(20);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byKey(const Key('timeline-tracks')));
    // 20 px/s, 16 px padding: x 116–196; the audio row is at y 182–204.
    const y = 193.0;
    await tester.tapAt(origin + const Offset(140, y));
    await tester.pump();
    expect(container.read(timelineUiProvider).selectedAudioId, 'a');
    expect(find.byKey(const Key('audio-inspector')), findsOneWidget);

    // Stretching stops where the file ends (6 s).
    await tester.dragFrom(origin + const Offset(195, y), const Offset(200, 0));
    await tester.pumpAndSettle();
    final a = container.read(projectEditorProvider).project.audio.single;
    expect(a.duration, s(6));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(container.read(projectEditorProvider).project.audio, isEmpty);
  });
}
