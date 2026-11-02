import '../memes/meme_search.dart';
import '../model/overlay_item.dart';
import '../transcript/transcript.dart';

/// Where on the frame a meme can go, by name.
const memePositions = [
  'center',
  'top-left',
  'top',
  'top-right',
  'left',
  'right',
  'bottom-left',
  'bottom',
  'bottom-right',
];

/// Meme widths (share of the frame width) by name.
const memeSizes = {'small': 0.2, 'medium': 0.3, 'large': 0.45};

/// The overlay placement for a named [position] and [width], keeping a
/// small margin from the edges.
OverlayTransform memeTransform(String position, double width) {
  const margin = 0.03;
  final left = width / 2 + margin;
  final right = 1 - width / 2 - margin;
  // Heights depend on the meme's shape; these keep most memes on screen.
  final x = position.endsWith('left')
      ? left
      : position.endsWith('right')
      ? right
      : 0.5;
  final y = position.startsWith('top')
      ? 0.22
      : position.startsWith('bottom')
      ? 0.78
      : 0.5;
  return OverlayTransform(x: x, y: y, scale: width);
}

/// The first transcript line that says [phrase] (case and punctuation
/// don't matter; every word must appear, in any order), or null.
TranscriptLine? findPhrase(List<TranscriptLine> lines, String phrase) {
  final words = nameWords(phrase);
  if (words.isEmpty) return null;
  for (final line in lines) {
    final said = nameWords(line.text);
    if (words.every((w) => said.any((s) => s.startsWith(w)))) return line;
  }
  // Allow a phrase that runs over two lines.
  for (var i = 0; i + 1 < lines.length; i++) {
    final said = nameWords('${lines[i].text} ${lines[i + 1].text}');
    if (words.every((w) => said.any((s) => s.startsWith(w)))) return lines[i];
  }
  return null;
}

enum SuggestionStatus { pending, accepted, rejected }

/// A meme the assistant suggests, which you accept or reject in the chat.
class MemeSuggestion {
  const MemeSuggestion({
    required this.meme,
    required this.start,
    required this.position,
    required this.size,
    required this.reason,
    this.status = SuggestionStatus.pending,
  });

  factory MemeSuggestion.fromJson(Map<String, dynamic> json) => MemeSuggestion(
    meme: Meme.fromJson(json['meme'] as Map<String, dynamic>),
    start: Duration(microseconds: json['start'] as int),
    position: json['position'] as String,
    size: (json['size'] as num).toDouble(),
    reason: json['reason'] as String,
    status: SuggestionStatus.values.byName(json['status'] as String),
  );

  final Meme meme;
  final Duration start;
  final String position;
  final double size;
  final String reason;
  final SuggestionStatus status;

  MemeSuggestion withStatus(SuggestionStatus s) => MemeSuggestion(
    meme: meme,
    start: start,
    position: position,
    size: size,
    reason: reason,
    status: s,
  );

  Map<String, dynamic> toJson() => {
    'meme': meme.toStoredJson(),
    'start': start.inMicroseconds,
    'position': position,
    'size': size,
    'reason': reason,
    'status': status.name,
  };
}
