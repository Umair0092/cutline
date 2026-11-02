import 'dart:convert';
import 'dart:io';

import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/speech_spec.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/voice/tts.dart';
import 'package:cutline/voice/voiceover_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../audio/voiceover_test.dart' show silentWav;
import '../fixtures.dart';

/// "Speaks" 0.1 s of silence per word, so lengths are predictable.
class FakeSpeaker implements Speaker {
  final said = <SpeechSpec>[];

  @override
  Future<List<String>> voices() async => ['Samantha', 'Daniel'];

  @override
  Future<void> speak(SpeechSpec spec, String outWav) async {
    said.add(spec);
    final words = spec.text.split(RegExp(r'\s+')).length;
    File(outWav).writeAsBytesSync(silentWav(words * 0.1 / spec.speed));
  }
}

void main() {
  late Directory work;
  late FakeSpeaker speaker;
  setUp(() {
    work = Directory.systemTemp.createTempSync('cutline_tts');
    speaker = FakeSpeaker();
  });
  tearDown(() => work.deleteSync(recursive: true));

  test('splitForSpeech keeps sentences together under the limit', () {
    final text =
        'This is the first sentence. ${'word ' * 30}end. '
        'Short one! And a question?';
    final parts = splitForSpeech(text, 60);
    expect(parts.every((p) => p.length <= 60), isTrue);
    expect(parts.first, 'This is the first sentence.');
    expect(parts.last, 'Short one! And a question?');
    expect(parts.join(' ').replaceAll(RegExp(r'\s+'), ' '), text.trim());
  });

  test('lines follow each other with a gap, unless timed', () async {
    final commands = await voiceoverCommands(
      project: threeClips(),
      workPath: work.path,
      speaker: speaker,
      lines: [
        (text: 'one two three four five', start: null),
        (text: 'six seven', start: null),
        (text: 'eight', start: s(30)),
      ],
      engine: VoiceEngine.system,
      voice: 'Daniel',
      from: s(10),
    );
    var p = threeClips();
    for (final c in commands) {
      p = c.apply(p);
    }
    expect([for (final a in p.audio) a.start], [s(10), s(10.9), s(30)]);
    expect(p.audio.first.duration, s(0.5));
    final media = p.mediaById(p.audio.first.mediaId)!;
    expect(media.speech!.voice, 'Daniel');
    expect(media.path, startsWith('assets/voice-'));
    expect(File('${work.path}/${media.path}').existsSync(), isTrue);

    expect(
      () => voiceoverCommands(
        project: threeClips(),
        workPath: work.path,
        speaker: speaker,
        lines: [(text: 'too late', start: s(41))],
        engine: VoiceEngine.system,
      ),
      throwsA(isA<SpeechException>()),
    );
  });

  test('re-making one line refits it and leaves the others', () async {
    var p = threeClips();
    for (final c in await voiceoverCommands(
      project: p,
      workPath: work.path,
      speaker: speaker,
      lines: [(text: 'a b c d', start: null), (text: 'e f', start: null)],
      engine: VoiceEngine.system,
    )) {
      p = c.apply(p);
    }
    final first = p.audio.first;
    final command = await regenerateLine(
      project: p,
      workPath: work.path,
      speaker: speaker,
      audioId: first.id,
      spec: p.mediaById(first.mediaId)!.speech!.copyWith(speed: 0.8),
    );
    final after = command.apply(p);
    expect(command.label, 'Re-make voiceover line');
    expect(after.audio.first.duration, s(0.5), reason: '0.4 s at 0.8×');
    expect(after.audio.first.start, first.start);
    expect(after.audio[1], p.audio[1]);
    expect(after.mediaById(first.mediaId)!.speech!.speed, 0.8);
  });

  group('assistant tools', () {
    const tools = EditToolbox();
    ToolContext ctx() => ToolContext(
      playhead: s(2),
      transcript: [TranscriptLine(s(12), s(16), 'This is the setup screen.')],
      voiceover: (project, lines, engine, voice, speed, from) =>
          voiceoverCommands(
            project: project,
            workPath: work.path,
            speaker: speaker,
            lines: lines,
            engine: engine,
            voice: voice,
            speed: speed,
            from: from,
          ),
      remakeLine: (project, id, spec) => regenerateLine(
        project: project,
        workPath: work.path,
        speaker: speaker,
        audioId: id,
        spec: spec,
      ),
    );

    test('"add a voiceover that explains this setup screen"', () async {
      final out = await tools.run(
        'add_voiceover',
        {
          'lines': [
            {'text': 'Here you pick a plan.', 'phrase': 'setup screen'},
            {'text': 'Then press continue.'},
          ],
          'engine': 'groq',
          'voice': 'troy',
        },
        threeClips(),
        context: ctx(),
      );
      expect(out.isError, isFalse, reason: out.result);
      expect([for (final a in out.project.audio) a.start], [s(12), s(12.9)]);
      expect(out.command!.label, 'AI voiceover');
      expect(speaker.said.first.engine, VoiceEngine.groq);
      expect(speaker.said.first.voice, 'troy');
      final summary = jsonDecode(out.result) as Map<String, dynamic>;
      final audio = (summary['project'] as Map)['audio'] as List;
      expect((audio.first as Map)['text'], 'Here you pick a plan.');
    });

    test('bad voices and remaking a line', () async {
      final bad = await tools.run(
        'add_voiceover',
        {
          'lines': [
            {'text': 'Hi'},
          ],
          'engine': 'groq',
          'voice': 'nobody',
        },
        threeClips(),
        context: ctx(),
      );
      expect(bad.isError, isTrue);
      expect(bad.result, contains('troy'));

      final added = await tools.run(
        'add_voiceover',
        {
          'lines': [
            {'text': 'one two three'},
          ],
        },
        threeClips(),
        context: ctx(),
      );
      final id = added.project.audio.single.id;
      final out = await tools.run(
        'remake_voiceover_line',
        {'audio_id': id, 'text': 'one two three four five six'},
        added.project,
        context: ctx(),
      );
      expect(out.isError, isFalse, reason: out.result);
      expect(out.project.audio.single.duration, s(0.6));
      expect(speaker.said.last.text, 'one two three four five six');
    });
  });

  group('GroqSpeaker', () {
    final ffmpeg = const FfmpegLocator().find();

    test('sends pieces of up to 200 characters and joins them', () async {
      final sent = <String>[];
      final groq = GroqSpeaker(
        ffmpeg!,
        'gsk_k',
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          sent.add(body['input'] as String);
          expect(body['model'], 'canopylabs/orpheus-v1-english');
          expect(r.headers['Authorization'], 'Bearer gsk_k');
          return http.Response.bytes(silentWav(1), 200);
        }),
      );
      final out = '${work.path}/out.wav';
      await groq.speak(
        SpeechSpec(
          text: '${'A fairly long sentence about the setup screen. ' * 6}End.',
          engine: VoiceEngine.groq,
        ),
        out,
      );
      expect(sent.length, greaterThan(1));
      expect(sent.every((s) => s.length <= groqMaxChars), isTrue);
      final bytes = File(out).readAsBytesSync();
      expect(bytes.length, greaterThan(48000 * 2 * sent.length - 1000));
    }, skip: ffmpeg == null ? 'needs ffmpeg' : null);

    test('explains the one-time terms step', () async {
      final groq = GroqSpeaker(
        ffmpeg ?? 'ffmpeg',
        'gsk_k',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 'model_terms_required', 'message': 'x'},
            }),
            400,
          ),
        ),
      );
      expect(
        () => groq.speak(const SpeechSpec(text: 'Hi'), '${work.path}/x.wav'),
        throwsA(
          isA<SpeechException>().having(
            (e) => e.message,
            'message',
            contains('accept the model\'s terms'),
          ),
        ),
      );
    });
  });

  test('a project with a voiceover line survives save and load', () async {
    var p = threeClips();
    for (final c in await voiceoverCommands(
      project: p,
      workPath: work.path,
      speaker: speaker,
      lines: [(text: 'hello there', start: null)],
      engine: VoiceEngine.groq,
      voice: 'hannah',
    )) {
      p = c.apply(p);
    }
    final back = Project.fromJson(
      jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
    );
    expect(back.media.last.speech, p.media.last.speech);
    expect(minClipDuration, isNotNull);
  });
}
