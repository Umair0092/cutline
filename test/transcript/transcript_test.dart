import 'dart:convert';
import 'dart:io';

import 'package:cutline/ai/project_summary.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/whisper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

/// Real whisper-cli output (-ml 1 -sow -oj) for a 13s clip made with `say`.
Transcript realTranscript() => parseWhisperJson(
  jsonDecode(File('test/transcript/whisper_output.json').readAsStringSync())
      as Map<String, dynamic>,
);

Project speechProject() => Project(
  media: const [
    MediaAsset(
      id: 'm',
      path: '/v/speech.mp4',
      kind: MediaKind.video,
      duration: Duration(seconds: 13),
      hasAudio: true,
    ),
  ],
  clips: [
    VideoClip(id: 'c', mediaId: 'm', sourceStart: s(0), sourceEnd: s(13)),
  ],
);

void main() {
  test('parses words with times and drops empty segments', () {
    final t = realTranscript();
    expect(t.language, 'en');
    expect(t.words.first.text, 'Hello');
    expect(t.words.first.start, const Duration(milliseconds: 50));
    final um = t.words.indexWhere((w) => w.text == 'um,');
    expect(t.words.sublist(um, um + 3).map((w) => w.text), [
      'um,',
      'let',
      'me',
    ]);
    expect(t.words[um].start, const Duration(milliseconds: 4230));
    expect(t.words.last.text, 'watching.');
  });

  test('stray punctuation and markers are cleaned up', () {
    final t = parseWhisperJson({
      'transcription': [
        {
          'offsets': {'from': 0, 'to': 100},
          'text': ' Hi',
        },
        {
          'offsets': {'from': 100, 'to': 150},
          'text': '!',
        },
        {
          'offsets': {'from': 200, 'to': 900},
          'text': ' [BLANK_AUDIO]',
        },
      ],
    });
    expect(t.words.single.text, 'Hi!');
    expect(t.words.single.end, const Duration(milliseconds: 150));
  });

  test('lines break at sentence ends and pauses', () {
    final lines = timelineLines(speechProject(), {
      '/v/speech.mp4': realTranscript(),
    });
    expect(lines.first.text, startsWith('Hello and welcome'));
    expect(lines.map((l) => l.text), contains('thanks for watching.'));
    expect(lines.every((l) => l.text.split(' ').length <= 14), isTrue);
  });

  test('cut parts disappear and later lines move earlier', () {
    final cut = const RemoveRange(
      Duration(milliseconds: 4230),
      Duration(milliseconds: 6080),
    ).apply(speechProject());
    final all = timelineLines(cut, {
      '/v/speech.mp4': realTranscript(),
    }).map((l) => l.text).join(' ');
    expect(all, isNot(contains('restart')));
    final okay = timelineLines(cut, {
      '/v/speech.mp4': realTranscript(),
    }).firstWhere((l) => l.text.startsWith('okay'));
    expect(okay.start, const Duration(milliseconds: 4230));
  });

  test('the assistant gets the transcript in timeline seconds', () {
    final lines = timelineLines(speechProject(), {
      '/v/speech.mp4': realTranscript(),
    });
    final summary = projectSummary(speechProject(), transcript: lines);
    final first = (summary['transcript'] as List).first as Map;
    expect(first['start'], 0.05);
    expect(first['text'], startsWith('Hello'));
  });
}
