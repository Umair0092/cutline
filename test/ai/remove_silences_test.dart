import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

/// One 30s clip.
Project oneClip() => Project(
  media: const [
    MediaAsset(
      id: 'm1',
      path: '/videos/talk.mp4',
      kind: MediaKind.video,
      duration: Duration(seconds: 30),
      width: 1920,
      height: 1080,
      hasAudio: true,
    ),
  ],
  clips: [VideoClip(id: 'a', mediaId: 'm1', sourceStart: s(0), sourceEnd: s(30))],
);

void main() {
  const tools = EditToolbox();

  // Speech at 0–3 and 8–12; a 5s gap (3–8) and an 18s tail (12–30).
  final transcript = [
    const TranscriptLine(Duration.zero, Duration(seconds: 3), 'hello there'),
    const TranscriptLine(
      Duration(seconds: 8),
      Duration(seconds: 12),
      'back again',
    ),
  ];

  test('cuts the mid gap and the tail, leaving a short breath', () async {
    final out = await tools.run(
      'remove_silences',
      const {},
      oneClip(),
      context: ToolContext(transcript: transcript),
    );
    expect(out.isError, isFalse, reason: out.result);
    // gap 3–8 → cut 3.25–8 (4.75s); tail 12–30 → cut 12.25–30 (17.75s).
    // 30 − 4.75 − 17.75 = 7.5s.
    expect(out.project.duration, s(7.5));
    expect(out.command!.label, 'Remove silences');
  });

  test('leave and min_gap are respected', () async {
    final out = await tools.run(
      'remove_silences',
      const {'leave': 0.5, 'min_gap': 6, 'trim_ends': false},
      oneClip(),
      context: ToolContext(transcript: transcript),
    );
    // Only gaps > 6s qualify, and ends aren't trimmed: the 5s mid gap is kept,
    // so nothing qualifies.
    expect(out.isError, isTrue);
    expect(out.result, contains('No silences'));
  });

  test('without a transcript it asks to transcribe first', () async {
    final out = await tools.run(
      'remove_silences',
      const {},
      oneClip(),
      context: const ToolContext(),
    );
    expect(out.isError, isTrue);
    expect(out.result, contains('transcript'));
  });

  test('trim_ends false keeps the leading and trailing silence', () async {
    final out = await tools.run(
      'remove_silences',
      const {'trim_ends': false},
      oneClip(),
      context: ToolContext(transcript: transcript),
    );
    // Only the 5s mid gap is cut (3.25–8 = 4.75s): 30 − 4.75 = 25.25s.
    expect(out.project.duration, s(25.25));
  });
}
