import 'package:path/path.dart' as p;

import '../model/project.dart';
import '../transcript/transcript.dart';

/// Enough for well over an hour of speech.
const maxTranscriptLines = 1500;

double _s(Duration d) => (d.inMilliseconds / 1000 * 100).roundToDouble() / 100;

/// A compact JSON view of the project for the assistant. Times are timeline
/// seconds with two decimals; clip ids are what the tools take.
Map<String, dynamic> projectSummary(
  Project project, {
  Duration? playhead,
  List<TranscriptLine> transcript = const [],
}) {
  final starts = project.clipStarts;
  return {
    'name': project.name,
    'duration': _s(project.duration),
    if (playhead != null) 'playhead': _s(playhead),
    'clips': [
      for (var i = 0; i < project.clips.length; i++)
        {
          'id': project.clips[i].id,
          'start': _s(starts[i]),
          'end': _s(starts[i] + project.clips[i].duration),
          'file': p.basename(
            project.mediaById(project.clips[i].mediaId)?.path ?? '?',
          ),
          'sourceFrom': _s(project.clips[i].sourceStart),
          'sourceTo': _s(project.clips[i].sourceEnd),
          if (project.clips[i].volume != 1.0) 'volume': project.clips[i].volume,
        },
    ],
    if (project.overlays.isNotEmpty)
      'overlays': [
        for (final o in project.overlays)
          {'id': o.id, 'start': _s(o.start), 'end': _s(o.end)},
      ],
    if (project.audio.isNotEmpty)
      'audio': [
        for (final a in project.audio)
          {
            'id': a.id,
            'role': a.role.name,
            'start': _s(a.start),
            'end': _s(a.end),
          },
      ],
    if (transcript.isNotEmpty) ...{
      'transcript': [
        for (final line in transcript.take(maxTranscriptLines))
          {'start': _s(line.start), 'end': _s(line.end), 'text': line.text},
      ],
      if (transcript.length > maxTranscriptLines)
        'transcriptNote':
            'Only the first $maxTranscriptLines of ${transcript.length} '
            'lines are shown.',
    },
  };
}
