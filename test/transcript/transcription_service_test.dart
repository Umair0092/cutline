import 'dart:io';

import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FakeEngine implements SpeechEngine {
  bool model = false;
  int downloads = 0;
  int runs = 0;
  String? fail;

  @override
  String? get unavailableReason => null;
  @override
  bool get modelReady => model;

  @override
  Future<void> downloadModel(void Function(double) onProgress) async {
    downloads++;
    onProgress(0.5);
    model = true;
  }

  @override
  Future<Transcript> transcribe(String path, void Function(double) p) async {
    runs++;
    if (fail != null) throw Exception(fail);
    p(1);
    return const Transcript(
      words: [Word('hi', Duration.zero, Duration(milliseconds: 300))],
    );
  }
}

void main() {
  late Directory support;
  late File media;
  late FakeEngine engine;
  late ProviderContainer container;
  TranscriptsController ctrl() => container.read(transcriptsProvider.notifier);
  TranscriptStatus? status() => container.read(transcriptsProvider)[media.path];

  setUp(() {
    support = Directory.systemTemp.createTempSync('cutline_support');
    media = File(p.join(support.path, 'v.mp4'))..writeAsStringSync('video');
    engine = FakeEngine();
    container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        speechEngineProvider.overrideWith((_) async => engine),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    support.deleteSync(recursive: true);
  });

  test('without the model it waits for the user', () async {
    await ctrl().ensure([media.path]);
    expect(status()!.phase, TranscriptPhase.waiting);
    expect(engine.runs, 0);
  });

  test('when asked, downloads the model once and transcribes', () async {
    await ctrl().ensure([media.path], allowDownload: true);
    expect(engine.downloads, 1);
    expect(status()!.phase, TranscriptPhase.done);
    expect(status()!.transcript!.words.single.text, 'hi');
  });

  test('a finished transcript is cached by file', () async {
    engine.model = true;
    await ctrl().ensure([media.path]);
    expect(engine.runs, 1);

    final fresh = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        speechEngineProvider.overrideWith((_) async => engine),
      ],
    );
    addTearDown(fresh.dispose);
    await fresh.read(transcriptsProvider.notifier).ensure([media.path]);
    expect(engine.runs, 1, reason: 'loaded from cache');
    expect(
      fresh.read(transcriptsProvider)[media.path]!.phase,
      TranscriptPhase.done,
    );
  });

  test('a failure is shown and can be retried', () async {
    engine
      ..model = true
      ..fail = 'boom';
    await ctrl().ensure([media.path]);
    expect(status()!.phase, TranscriptPhase.failed);
    expect(status()!.error, contains('boom'));
    engine.fail = null;
    await ctrl().ensure([media.path]);
    expect(status()!.phase, TranscriptPhase.done);
  });
}
