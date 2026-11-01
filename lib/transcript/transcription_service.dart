import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../media/ffmpeg.dart';
import '../media/media_cache.dart';
import 'transcript.dart';
import 'whisper.dart';

/// What the app needs to make transcripts. Tests swap in a fake.
abstract class SpeechEngine {
  /// Null if transcription can't work here at all (tools missing).
  String? get unavailableReason;
  bool get modelReady;
  Future<void> downloadModel(void Function(double) onProgress);
  Future<Transcript> transcribe(String path, void Function(double) onProgress);
}

class WhisperEngine implements SpeechEngine {
  WhisperEngine(this.supportDir);

  final String supportDir;
  final _model = WhisperModel.base;
  String get _modelsDir => p.join(supportDir, 'models');

  @override
  String? get unavailableReason {
    if (const FfmpegLocator().find() == null) return 'FFmpeg is missing.';
    if (findWhisper() == null) return 'whisper.cpp is missing.';
    return null;
  }

  @override
  bool get modelReady => _model.isDownloaded(_modelsDir);

  @override
  Future<void> downloadModel(void Function(double) onProgress) =>
      _model.download(_modelsDir, onProgress: onProgress);

  @override
  Future<Transcript> transcribe(
    String path,
    void Function(double) onProgress,
  ) => Transcriber(
    ffmpeg: const FfmpegLocator().find()!,
    whisper: findWhisper()!,
    modelPath: _model.pathIn(_modelsDir),
  ).transcribe(path, onProgress: onProgress);
}

final supportDirProvider = FutureProvider<String>(
  (_) async => (await getApplicationSupportDirectory()).path,
);

final speechEngineProvider = FutureProvider<SpeechEngine>(
  (ref) async => WhisperEngine(await ref.watch(supportDirProvider.future)),
);

enum TranscriptPhase { waiting, downloadingModel, transcribing, done, failed }

class TranscriptStatus {
  const TranscriptStatus(
    this.phase, {
    this.progress,
    this.transcript,
    this.error,
  });

  final TranscriptPhase phase;
  final double? progress;
  final Transcript? transcript;
  final String? error;
}

final transcriptsProvider =
    NotifierProvider<TranscriptsController, Map<String, TranscriptStatus>>(
      TranscriptsController.new,
    );

/// Transcripts by absolute media path. Finished transcripts are cached in
/// the app's support folder, keyed by the file, so they're only made once
/// per file, whatever project it's in.
class TranscriptsController extends Notifier<Map<String, TranscriptStatus>> {
  final _queue = <String>[];
  bool _running = false;

  @override
  Map<String, TranscriptStatus> build() => const {};

  Map<String, Transcript> get ready => {
    for (final MapEntry(:key, :value) in state.entries)
      if (value.transcript != null) key: value.transcript!,
  };

  /// Loads cached transcripts for [paths] and transcribes the rest.
  /// Downloads the speech model first only if [allowDownload] is true;
  /// otherwise files wait until the user asks.
  Future<void> ensure(
    Iterable<String> paths, {
    bool allowDownload = false,
  }) async {
    final SpeechEngine engine;
    final String supportDir;
    try {
      engine = await ref.read(speechEngineProvider.future);
      supportDir = await ref.read(supportDirProvider.future);
    } on Object catch (e) {
      for (final path in paths) {
        _set(path, TranscriptStatus(TranscriptPhase.failed, error: '$e'));
      }
      return;
    }
    for (final path in paths) {
      final current = state[path];
      if (current != null &&
          current.phase != TranscriptPhase.failed &&
          current.phase != TranscriptPhase.waiting) {
        continue;
      }
      final cached = _readCache(supportDir, path);
      if (cached != null) {
        _set(path, TranscriptStatus(TranscriptPhase.done, transcript: cached));
        continue;
      }
      if (engine.unavailableReason != null) {
        _set(
          path,
          TranscriptStatus(
            TranscriptPhase.failed,
            error: engine.unavailableReason,
          ),
        );
        continue;
      }
      if (!engine.modelReady && !allowDownload) {
        _set(path, const TranscriptStatus(TranscriptPhase.waiting));
        continue;
      }
      if (!_queue.contains(path)) _queue.add(path);
      _set(path, const TranscriptStatus(TranscriptPhase.waiting, progress: 0));
    }
    await _drain(engine, supportDir);
  }

  Future<void> _drain(SpeechEngine engine, String supportDir) async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final path = _queue.removeAt(0);
        try {
          if (!engine.modelReady) {
            await engine.downloadModel(
              (p) => _set(
                path,
                TranscriptStatus(TranscriptPhase.downloadingModel, progress: p),
              ),
            );
          }
          _set(
            path,
            const TranscriptStatus(TranscriptPhase.transcribing, progress: 0),
          );
          final transcript = await engine.transcribe(
            path,
            (p) => _set(
              path,
              TranscriptStatus(TranscriptPhase.transcribing, progress: p),
            ),
          );
          _writeCache(supportDir, path, transcript);
          _set(
            path,
            TranscriptStatus(TranscriptPhase.done, transcript: transcript),
          );
        } on Object catch (e) {
          _set(
            path,
            TranscriptStatus(
              TranscriptPhase.failed,
              error: e is TranscribeException ? e.message : '$e',
            ),
          );
        }
      }
    } finally {
      _running = false;
    }
  }

  void _set(String path, TranscriptStatus status) =>
      state = {...state, path: status};

  String _cacheFile(String supportDir, String path) =>
      p.join(supportDir, 'transcripts', '${mediaCacheKey(path)}.json');

  Transcript? _readCache(String supportDir, String path) {
    if (!File(path).existsSync()) return null;
    final f = File(_cacheFile(supportDir, path));
    if (!f.existsSync()) return null;
    try {
      return Transcript.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  void _writeCache(String supportDir, String path, Transcript t) {
    if (!File(path).existsSync()) return;
    final f = File(_cacheFile(supportDir, path))
      ..parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(t.toJson()));
  }
}
