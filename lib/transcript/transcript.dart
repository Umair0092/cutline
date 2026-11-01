import '../model/project.dart';
import '../storage/project_store.dart';

/// One spoken word, with times in its source file.
class Word {
  const Word(this.text, this.start, this.end);

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    json['w'] as String,
    Duration(milliseconds: json['s'] as int),
    Duration(milliseconds: json['e'] as int),
  );

  final String text;
  final Duration start;
  final Duration end;

  Map<String, dynamic> toJson() => {
    'w': text,
    's': start.inMilliseconds,
    'e': end.inMilliseconds,
  };
}

/// Everything said in one source file.
class Transcript {
  const Transcript({required this.words, this.language});

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
    language: json['language'] as String?,
    words: [
      for (final w in json['words'] as List<dynamic>)
        Word.fromJson(w as Map<String, dynamic>),
    ],
  );

  final List<Word> words;
  final String? language;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'language': ?language,
    'words': [for (final w in words) w.toJson()],
  };
}

/// A line of speech on the timeline (after cuts), for the transcript view
/// and the assistant.
class TranscriptLine {
  const TranscriptLine(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;
}

/// Maps each source file's words onto the timeline through the clips, then
/// groups them into lines (at sentence ends, pauses, or commas once a line
/// has a few words). Words in cut-out parts disappear; a cut in the
/// middle of a sentence splits the line.
///
/// [transcripts] is keyed by absolute media path.
List<TranscriptLine> timelineLines(
  Project project,
  Map<String, Transcript> transcripts, {
  String? projectPath,
  Duration pause = const Duration(milliseconds: 700),
  int maxWords = 14,
}) {
  final lines = <TranscriptLine>[];
  final starts = project.clipStarts;
  for (var i = 0; i < project.clips.length; i++) {
    final clip = project.clips[i];
    final media = project.mediaById(clip.mediaId);
    if (media == null) continue;
    final transcript =
        transcripts[ProjectStore.resolve(media.path, projectPath)];
    if (transcript == null) continue;

    final words = <Word>[];
    void flush() {
      if (words.isEmpty) return;
      lines.add(
        TranscriptLine(
          words.first.start,
          words.last.end,
          words.map((w) => w.text).join(' '),
        ),
      );
      words.clear();
    }

    for (final w in transcript.words) {
      final mid = w.start + (w.end - w.start) ~/ 2;
      if (mid < clip.sourceStart || mid >= clip.sourceEnd) continue;
      final onTimeline = Word(
        w.text,
        starts[i] + (w.start - clip.sourceStart),
        starts[i] + (w.end - clip.sourceStart),
      );
      if (words.isNotEmpty &&
          (onTimeline.start - words.last.end > pause ||
              words.length >= maxWords ||
              RegExp(r'[.?!]$').hasMatch(words.last.text) ||
              (words.length >= 4 && words.last.text.endsWith(',')))) {
        flush();
      }
      words.add(onTimeline);
    }
    flush();
  }
  return lines;
}
