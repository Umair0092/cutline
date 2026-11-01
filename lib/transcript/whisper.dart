import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'transcript.dart';

class TranscribeException implements Exception {
  TranscribeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Finds whisper.cpp's `whisper-cli`: bundled with the app first (see
/// tool/build_whisper_macos.sh and tool/fetch_whisper_windows.ps1), then
/// Homebrew and PATH.
String? findWhisper() {
  final exe = Platform.isWindows ? 'whisper-cli.exe' : 'whisper-cli';
  final appDir = p.dirname(Platform.resolvedExecutable);
  final candidates = [
    p.join(appDir, '..', 'Resources', 'bin', exe),
    p.join(appDir, 'bin', exe),
    if (!Platform.isWindows) ...[
      '/opt/homebrew/bin/whisper-cli',
      '/usr/local/bin/whisper-cli',
    ],
    ...?Platform.environment['PATH']
        ?.split(Platform.isWindows ? ';' : ':')
        .map((dir) => p.join(dir, exe)),
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return p.normalize(c);
  }
  return null;
}

/// A speech model, downloaded once into the app's support folder.
class WhisperModel {
  const WhisperModel(this.name, this.bytes, this.sha256);

  /// Multilingual, ~148 MB: good enough for clear speech, fast on any Mac.
  static const base = WhisperModel(
    'ggml-base.bin',
    147951465,
    '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
  );

  final String name;
  final int bytes;
  final String sha256;

  Uri get url => Uri.parse(
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$name',
  );

  String pathIn(String modelsDir) => p.join(modelsDir, name);

  bool isDownloaded(String modelsDir) {
    final f = File(pathIn(modelsDir));
    return f.existsSync() && f.lengthSync() == bytes;
  }

  /// Downloads to a temp file, checks the sha256, then moves it in place.
  /// [onProgress] gets 0..1.
  Future<void> download(
    String modelsDir, {
    required void Function(double) onProgress,
    http.Client? client,
  }) async {
    Directory(modelsDir).createSync(recursive: true);
    final http0 = client ?? http.Client();
    final tmp = File('${pathIn(modelsDir)}.part');
    try {
      final response = await http0.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        throw TranscribeException(
          'Could not download the speech model (HTTP ${response.statusCode}).',
        );
      }
      final sink = tmp.openWrite();
      final digest = _DigestSink();
      final hasher = sha256Hasher(digest);
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress(received / bytes);
      }
      await sink.close();
      hasher.close();
      if (digest.value.toString() != sha256) {
        tmp.deleteSync();
        throw TranscribeException(
          'The downloaded speech model is damaged. Try again.',
        );
      }
      tmp.renameSync(pathIn(modelsDir));
    } on SocketException {
      throw TranscribeException(
        'Can\'t download the speech model. Check your internet connection.',
      );
    } finally {
      if (client == null) http0.close();
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }
}

ByteConversionSink sha256Hasher(Sink<Digest> out) =>
    sha256.startChunkedConversion(out);

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Runs FFmpeg + whisper-cli on one file.
class Transcriber {
  const Transcriber({
    required this.ffmpeg,
    required this.whisper,
    required this.modelPath,
  });

  final String ffmpeg;
  final String whisper;
  final String modelPath;

  /// [onProgress] gets 0..1 while whisper works.
  Future<Transcript> transcribe(
    String mediaPath, {
    void Function(double)? onProgress,
  }) async {
    final work = Directory.systemTemp.createTempSync('cutline_whisper');
    try {
      final wav = p.join(work.path, 'audio.wav');
      final extract = await Process.run(ffmpeg, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        mediaPath,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        wav,
      ]);
      if (extract.exitCode != 0 || !File(wav).existsSync()) {
        throw TranscribeException(
          'Couldn\'t read the sound from ${p.basename(mediaPath)}.',
        );
      }

      final outBase = p.join(work.path, 'out');
      final process = await Process.start(whisper, [
        '-m', modelPath,
        '-f', wav,
        '-l', 'auto',
        // One word per segment, split on word boundaries: word timings.
        '-ml', '1', '-sow',
        '-oj', '-of', outBase,
        '-np', '-pp',
        '-t', '${Platform.numberOfProcessors.clamp(1, 8)}',
        // Metal on Intel Macs' GPUs gives garbage output (seen on this
        // project's Intel test Mac); the CPU is fast enough there.
        if (Abi.current() == Abi.macosX64) '-ng',
      ]);
      final errors = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((chunk) {
        errors.write(chunk);
        for (final m in RegExp(r'progress\s*=\s*(\d+)%').allMatches(chunk)) {
          onProgress?.call(int.parse(m.group(1)!) / 100);
        }
      });
      unawaited(process.stdout.drain<void>());
      if (await process.exitCode != 0) {
        final tail = errors.toString().split('\n').where((l) => l.isNotEmpty);
        throw TranscribeException(
          'Transcription failed: ${tail.isEmpty ? 'unknown error' : tail.last}',
        );
      }
      return parseWhisperJson(
        jsonDecode(File('$outBase.json').readAsStringSync())
            as Map<String, dynamic>,
      );
    } finally {
      work.deleteSync(recursive: true);
    }
  }
}

/// Turns whisper-cli's `-oj -ml 1` output into words. Drops markers like
/// `[BLANK_AUDIO]`, and glues stray punctuation onto the word before it.
Transcript parseWhisperJson(Map<String, dynamic> json) {
  final words = <Word>[];
  for (final seg in json['transcription'] as List<dynamic>? ?? const []) {
    final s = seg as Map<String, dynamic>;
    final text = (s['text'] as String? ?? '').trim();
    if (text.isEmpty || RegExp(r'^\[.*\]$|^\(.*\)$').hasMatch(text)) continue;
    final offsets = s['offsets'] as Map<String, dynamic>;
    final start = Duration(milliseconds: offsets['from'] as int);
    final end = Duration(milliseconds: offsets['to'] as int);
    if (RegExp(r'^[^\w]+$', unicode: true).hasMatch(text) && words.isNotEmpty) {
      final last = words.removeLast();
      words.add(Word('${last.text}$text', last.start, end));
      continue;
    }
    words.add(Word(text, start, end));
  }
  final result = json['result'] as Map<String, dynamic>?;
  return Transcript(words: words, language: result?['language'] as String?);
}
