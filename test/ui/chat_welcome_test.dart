import 'package:cutline/ui/assistant/chat_welcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no video yet: lead with photos, no transcript-only ideas', () {
    final s = suggestionsFor(
      hasClips: false,
      hasTranscript: false,
      hasMusic: false,
    );
    expect(s.first, _byTitle('Video from photos'));
    expect(s, isNot(contains(_byTitle('Cut the silences'))));
    expect(s, isNot(contains(_byTitle('Funny memes'))));
  });

  test('with a transcript, transcript-powered ideas come first', () {
    final s = suggestionsFor(
      hasClips: true,
      hasTranscript: true,
      hasMusic: false,
    );
    expect(s.take(2), containsAll([
      _byTitle('Cut the silences'),
      _byTitle('Funny memes'),
    ]));
  });

  test('music already added: the music idea is dropped', () {
    final s = suggestionsFor(
      hasClips: true,
      hasTranscript: true,
      hasMusic: true,
    );
    expect(s, isNot(contains(_byTitle('Background music'))));
  });

  test('a clip but no transcript: no silence/meme ideas, still has cards', () {
    final s = suggestionsFor(
      hasClips: true,
      hasTranscript: false,
      hasMusic: false,
    );
    expect(s, isNot(contains(_byTitle('Cut the silences'))));
    expect(s, isNot(contains(_byTitle('Funny memes'))));
    expect(s.length, greaterThanOrEqualTo(3));
  });

  test('no duplicates in any state', () {
    for (final clips in [true, false]) {
      for (final tr in [true, false]) {
        for (final music in [true, false]) {
          final s = suggestionsFor(
            hasClips: clips,
            hasTranscript: tr,
            hasMusic: music,
          );
          expect(s.toSet().length, s.length, reason: '$clips $tr $music');
        }
      }
    }
  });
}

ChatSuggestion _byTitle(String title) =>
    chatSuggestions.firstWhere((s) => s.title == title);
