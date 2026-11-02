import 'package:cutline/ai/meme_tools.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  test('memeTransform keeps the meme inside the frame', () {
    final br = memeTransform('bottom-right', 0.2);
    expect(br.x, closeTo(0.87, 1e-9));
    expect(br.y, 0.78);
    expect(br.scale, 0.2);
    final tl = memeTransform('top-left', 0.3);
    expect(tl.x, closeTo(0.18, 1e-9));
    expect(tl.y, 0.22);
    final c = memeTransform('center', 0.45);
    expect((c.x, c.y), (0.5, 0.5));
  });

  group('findPhrase', () {
    final lines = [
      TranscriptLine(s(0), s(3), 'Hello and welcome.'),
      TranscriptLine(s(3), s(6), "Today we're talking about"),
      TranscriptLine(s(6), s(9), 'deadlines, which I hate.'),
    ];

    test('finds a line by its words, ignoring case and punctuation', () {
      expect(findPhrase(lines, 'Deadlines')!.start, s(6));
      expect(findPhrase(lines, 'welcome hello')!.start, s(0));
    });

    test('a phrase over two lines starts at the first', () {
      expect(findPhrase(lines, 'talking about deadlines')!.start, s(3));
    });

    test('nothing said is null', () {
      expect(findPhrase(lines, 'pizza'), isNull);
      expect(findPhrase(lines, '  '), isNull);
    });
  });

  test('a suggestion survives a save and load', () {
    final suggestion = MemeSuggestion(
      meme: const Meme(
        id: 'abc',
        title: 'This is fine',
        preview: 'https://g/s.gif',
        source: 'https://g/m.gif',
        width: 480,
        height: 270,
      ),
      start: s(12.5),
      position: 'bottom-right',
      size: 0.2,
      reason: 'You mention deadlines',
      status: SuggestionStatus.accepted,
    );
    final back = MemeSuggestion.fromJson(suggestion.toJson());
    expect(back.meme.source, 'https://g/m.gif');
    expect(back.meme.width, 480);
    expect(back.start, s(12.5));
    expect(back.status, SuggestionStatus.accepted);
    expect(back.reason, 'You mention deadlines');
  });
}
