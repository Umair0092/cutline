import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/api_key_store.dart';
import '../ai/assistant_client.dart';
import '../media/ffmpeg.dart';
import '../model/speech_spec.dart';

class SpeechException implements Exception {
  SpeechException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Groq's Orpheus voices.
const groqVoices = ['troy', 'hannah', 'austin', 'diana', 'daniel', 'autumn'];

/// Groq takes at most this many characters per request.
const groqMaxChars = 200;

/// Splits [text] into pieces of at most [max] characters, at sentence ends
/// where possible, then at commas, then at spaces.
List<String> splitForSpeech(String text, int max) {
  final out = <String>[];
  void add(String piece) {
    piece = piece.trim();
    if (piece.isEmpty) return;
    if (piece.length <= max) {
      out.add(piece);
      return;
    }
    for (final sep in [RegExp(r'(?<=[,;:])\s+'), RegExp(r'\s+')]) {
      final parts = piece.split(sep);
      if (parts.length > 1) {
        var current = '';
        for (final part in parts) {
          final joined = current.isEmpty ? part : '$current $part';
          if (joined.length > max && current.isNotEmpty) {
            add(current);
            current = part;
          } else {
            current = joined;
          }
        }
        add(current);
        return;
      }
    }
    // One enormous word: cut it.
    for (var i = 0; i < piece.length; i += max) {
      out.add(
        piece.substring(i, i + max > piece.length ? piece.length : i + max),
      );
    }
  }

  var current = '';
  for (final sentence in text.trim().split(RegExp(r'(?<=[.!?])\s+'))) {
    final joined = current.isEmpty ? sentence : '$current $sentence';
    if (joined.length > max && current.isNotEmpty) {
      add(current);
      current = sentence;
    } else {
      current = joined;
    }
  }
  add(current);
  return out;
}

/// Turns text into a WAV file.
abstract class Speaker {
  /// Voices to choose from (the first is the default).
  Future<List<String>> voices();

  /// Writes [spec] spoken to [outWav]: 48 kHz mono, at the spec's speed.
  Future<void> speak(SpeechSpec spec, String outWav);
}

/// Joins [parts] (any audio files), applies [speed], and writes a 48 kHz
/// mono WAV.
Future<void> _finish(
  String ffmpeg,
  List<String> parts,
  double speed,
  String outWav,
) async {
  final filters = <String>[
    '${[for (var i = 0; i < parts.length; i++) '[$i:a:0]'].join()}'
        'concat=n=${parts.length}:v=0:a=1'
        '${speed != 1 ? ',atempo=${speed.clamp(0.5, 2.0).toStringAsFixed(3)}' : ''}'
        '[out]',
  ];
  final r = await Process.run(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    for (final part in parts) ...['-i', part],
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[out]',
    '-ar',
    '48000',
    '-ac',
    '1',
    '-c:a',
    'pcm_s16le',
    outWav,
  ]);
  if (r.exitCode != 0) {
    throw SpeechException('Couldn\'t make the audio: ${r.stderr}');
  }
}

/// The computer's own voices: `say` on macOS, the speech synthesizer that
/// comes with Windows.
class SystemSpeaker implements Speaker {
  SystemSpeaker(this.ffmpeg);

  final String ffmpeg;

  @override
  Future<List<String>> voices() async {
    if (Platform.isMacOS) {
      final r = await Process.run('say', ['-v', '?']);
      // "Samantha            en_US    # Hello! My name is Samantha."
      final english = <String>[];
      for (final line in LineSplitter.split(r.stdout as String)) {
        final m = RegExp(r'^(.+?)\s{2,}(en_\w+)\s+#').firstMatch(line);
        if (m != null) english.add(m.group(1)!.trim());
      }
      // Put the clearest standard voices first.
      const preferred = ['Samantha', 'Daniel', 'Karen', 'Moira', 'Alex'];
      english.sort((a, b) {
        final ia = preferred.indexOf(a);
        final ib = preferred.indexOf(b);
        if (ia >= 0 || ib >= 0) {
          return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
        }
        return a.compareTo(b);
      });
      return english;
    }
    if (Platform.isWindows) {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Speech; '
            '(New-Object System.Speech.Synthesis.SpeechSynthesizer)'
            '.GetInstalledVoices() | ForEach-Object { \$_.VoiceInfo.Name }',
      ]);
      return LineSplitter.split(r.stdout as String)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Future<void> speak(SpeechSpec spec, String outWav) async {
    final tmp = Directory.systemTemp.createTempSync('cutline_say');
    try {
      final raw = p.join(tmp.path, Platform.isMacOS ? 'say.aiff' : 'say.wav');
      final textFile = File(p.join(tmp.path, 'text.txt'))
        ..writeAsStringSync(spec.text);
      final ProcessResult r;
      if (Platform.isMacOS) {
        r = await Process.run('say', [
          if (spec.voice.isNotEmpty) ...['-v', spec.voice],
          '-o',
          raw,
          '-f',
          textFile.path,
        ]);
      } else if (Platform.isWindows) {
        String quote(String s) => "'${s.replaceAll("'", "''")}'";
        r = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Speech; '
              '\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
              '${spec.voice.isNotEmpty ? '\$s.SelectVoice(${quote(spec.voice)}); ' : ''}'
              '\$s.SetOutputToWaveFile(${quote(raw)}); '
              '\$s.Speak([IO.File]::ReadAllText(${quote(textFile.path)})); '
              '\$s.Dispose()',
        ]);
      } else {
        throw SpeechException('System voices aren\'t available here.');
      }
      if (r.exitCode != 0 || !File(raw).existsSync()) {
        throw SpeechException('The system voice failed: ${r.stderr}');
      }
      await _finish(ffmpeg, [raw], spec.speed, outWav);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }
}

/// Groq's Orpheus voices, with your Groq key. Text is sent in pieces of up
/// to 200 characters and joined.
class GroqSpeaker implements Speaker {
  GroqSpeaker(this.ffmpeg, this.apiKey, {http.Client? client})
    : _http = client ?? http.Client();

  final String ffmpeg;
  final String apiKey;
  final http.Client _http;

  static const model = 'canopylabs/orpheus-v1-english';

  @override
  Future<List<String>> voices() async => groqVoices;

  @override
  Future<void> speak(SpeechSpec spec, String outWav) async {
    final tmp = Directory.systemTemp.createTempSync('cutline_groq');
    try {
      final parts = <String>[];
      final pieces = splitForSpeech(spec.text, groqMaxChars);
      for (var i = 0; i < pieces.length; i++) {
        final http.Response r;
        try {
          r = await _http
              .post(
                Uri.parse('https://api.groq.com/openai/v1/audio/speech'),
                headers: {
                  'Authorization': 'Bearer $apiKey',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'model': model,
                  'voice': spec.voice.isEmpty ? groqVoices.first : spec.voice,
                  'input': pieces[i],
                  'response_format': 'wav',
                }),
              )
              .timeout(const Duration(seconds: 60));
        } on Exception {
          throw SpeechException('Couldn\'t reach Groq. Check your internet.');
        }
        if (r.statusCode != 200) throw SpeechException(_groqError(r));
        final part = p.join(tmp.path, 'part$i.wav');
        File(part).writeAsBytesSync(r.bodyBytes);
        parts.add(part);
      }
      if (parts.isEmpty) throw SpeechException('There\'s nothing to say.');
      await _finish(ffmpeg, parts, spec.speed, outWav);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }

  String _groqError(http.Response r) {
    String? code;
    try {
      code =
          ((jsonDecode(r.body) as Map<String, dynamic>)['error']
                  as Map<String, dynamic>)['code']
              as String?;
    } on Object {
      code = null;
    }
    if (code == 'model_terms_required') {
      return 'Groq voices need a one-time step: accept the model\'s terms at '
          'console.groq.com/playground?model=canopylabs%2Forpheus-v1-english '
          '(signed in to Groq), then try again. System voices work meanwhile.';
    }
    return switch (r.statusCode) {
      401 || 403 => 'Groq didn\'t accept the API key.',
      429 => 'Groq\'s free limit is used up for now. Try again in a minute.',
      _ => 'Groq speech failed (${r.statusCode}).',
    };
  }
}

/// Makes the speaker for an engine. Tests override this.
final speakerFactoryProvider =
    Provider<Future<Speaker> Function(VoiceEngine engine)>(
      (ref) => (engine) async {
        final ffmpeg = const FfmpegLocator().find();
        if (ffmpeg == null) throw SpeechException('FFmpeg is missing.');
        if (engine == VoiceEngine.system) return SystemSpeaker(ffmpeg);
        final key = await ref.read(apiKeyStoreProvider).read(AiProvider.groq);
        if (key == null || key.isEmpty) {
          throw SpeechException(
            'Groq voices use your Groq key. Add one in Settings (choose '
            'Groq), or use a system voice.',
          );
        }
        return GroqSpeaker(ffmpeg, key);
      },
    );
