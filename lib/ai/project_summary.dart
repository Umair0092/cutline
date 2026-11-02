import 'package:path/path.dart' as p;

import '../model/project.dart';
import '../model/title_item.dart';
import '../model/voice_effect.dart';
import '../settings/preferences.dart';
import '../titles/templates.dart';
import '../transcript/transcript.dart';

/// Enough for well over an hour of speech.
const maxTranscriptLines = 1500;

double _s2(double v) => (v * 100).roundToDouble() / 100;

double _s(Duration d) => (d.inMilliseconds / 1000 * 100).roundToDouble() / 100;

/// A compact JSON view of the project for the assistant. Times are timeline
/// seconds with two decimals; clip ids are what the tools take.
Map<String, dynamic> projectSummary(
  Project project, {
  Duration? playhead,
  List<TranscriptLine> transcript = const [],
  Preferences preferences = const Preferences(),
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
          if (!project.clips[i].effect.isNone)
            'effect': _effect(project.clips[i].effect),
          if (project.mediaById(project.clips[i].mediaId)?.title
              case final intro?)
            'intro': _titleInfo(intro),
        },
    ],
    if (project.overlays.isNotEmpty)
      'overlays': [
        for (final o in project.overlays)
          {
            'id': o.id,
            'start': _s(o.start),
            'end': _s(o.end),
            'file': p.basename(project.mediaById(o.mediaId)?.path ?? '?'),
            'x': _s2(o.transform.x),
            'y': _s2(o.transform.y),
            'width': _s2(o.transform.scale),
            'animation': o.animation.name,
          },
      ],
    if (project.audio.isNotEmpty)
      'audio': [
        for (final a in project.audio)
          {
            'id': a.id,
            'role': a.role.name,
            'start': _s(a.start),
            'end': _s(a.end),
            if (!a.effect.isNone) 'effect': _effect(a.effect),
            if (project.mediaById(a.mediaId)?.speech case final speech?) ...{
              'text': speech.text,
              'engine': speech.engine.name,
              if (speech.voice.isNotEmpty) 'voice': speech.voice,
              if (speech.speed != 1) 'speed': speech.speed,
            },
          },
      ],
    if (project.titles.isNotEmpty)
      'titles': [
        for (final t in project.titles)
          {
            'id': t.id,
            'start': _s(t.start),
            'end': _s(t.end),
            ..._titleInfo(t.spec),
          },
      ],
    if (!preferences.isEmpty)
      'you': {
        if (preferences.yourName.isNotEmpty) 'name': preferences.yourName,
        if (preferences.brandColor.isNotEmpty)
          'brandColor': preferences.brandColor,
      },
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

Map<String, dynamic> _effect(VoiceEffect e) => {
  if (e.pitch != 0) 'pitch': e.pitch,
  if (e.speed != 1) 'speed': e.speed,
  if (e.robot) 'robot': true,
  if (e.denoise) 'denoise': true,
  if (e.normalize) 'normalize': true,
};

/// Template and every field value (defaults filled in), so the assistant
/// knows exactly what the title says.
Map<String, dynamic> _titleInfo(TitleSpec spec) {
  final template = templateById(spec.templateId);
  return {
    'template': spec.templateId,
    'duration': _s(spec.duration),
    if (template != null)
      'fields': {
        for (final f in template.fields)
          f.key: TitleValues(template, spec.fields).text(f.key),
      },
  };
}
