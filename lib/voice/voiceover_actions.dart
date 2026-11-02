import 'dart:io';

import 'package:path/path.dart' as p;

import '../audio/recording.dart';
import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../model/audio_item.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../model/speech_spec.dart';
import '../storage/project_store.dart';
import 'tts.dart';

/// The pause left between lines placed one after another.
const lineGap = Duration(milliseconds: 400);

/// Speaks [spec] into a new WAV in the project's `assets/` and returns its
/// media entry (same [id] when re-making a line).
Future<MediaAsset> renderSpeechMedia(
  Speaker speaker,
  SpeechSpec spec,
  String workPath, {
  String? id,
}) async {
  if (spec.text.trim().isEmpty) throw SpeechException('The line is empty.');
  final name = 'voice-${newId()}.wav';
  final dir = Directory(p.join(workPath, ProjectStore.assetsDir))
    ..createSync(recursive: true);
  final path = p.join(dir.path, name);
  await speaker.speak(spec, path);
  final length = wavLength(File(path).readAsBytesSync());
  if (length == null || length < minClipDuration) {
    throw SpeechException('The voice came back empty.');
  }
  return MediaAsset(
    id: id ?? newId(),
    path: '${ProjectStore.assetsDir}/$name',
    kind: MediaKind.audio,
    duration: length,
    hasAudio: true,
    speech: spec,
  );
}

/// One line of a voiceover script, with an optional fixed start.
typedef ScriptLine = ({String text, Duration? start});

/// Speaks every line and returns the commands that put them on the
/// voiceover track. Lines without a start follow the previous one (the
/// first starts at [from]).
Future<List<EditCommand>> voiceoverCommands({
  required Project project,
  required String workPath,
  required Speaker speaker,
  required List<ScriptLine> lines,
  required VoiceEngine engine,
  String voice = '',
  double speed = 1,
  Duration from = Duration.zero,
}) async {
  final commands = <EditCommand>[];
  var next = from;
  for (final line in lines) {
    if (line.text.trim().isEmpty) continue;
    final start = line.start ?? next;
    if (start >= project.duration) {
      throw SpeechException(
        '"${_short(line.text)}" would start after the video ends '
        '(${formatTime(project.duration)}).',
      );
    }
    final media = await renderSpeechMedia(
      speaker,
      SpeechSpec(
        text: line.text.trim(),
        engine: engine,
        voice: voice,
        speed: speed,
      ),
      workPath,
    );
    commands
      ..add(AddMedia(media))
      ..add(
        AddAudio(
          AudioItem(
            id: newId(),
            mediaId: media.id,
            role: AudioRole.voiceover,
            start: start,
            sourceStart: Duration.zero,
            sourceEnd: media.duration,
          ),
        ),
      );
    next = start + media.duration + lineGap;
  }
  if (commands.isEmpty) throw SpeechException('The script is empty.');
  return commands;
}

/// Re-makes one line with new words, voice or speed. Lines before and after
/// it stay as they are.
Future<EditCommand> regenerateLine({
  required Project project,
  required String workPath,
  required Speaker speaker,
  required String audioId,
  required SpeechSpec spec,
}) async {
  final item = project.audio.where((a) => a.id == audioId).firstOrNull;
  final media = item == null ? null : project.mediaById(item.mediaId);
  if (media?.speech == null) {
    throw SpeechException('That isn\'t a generated voiceover line.');
  }
  final updated = await renderSpeechMedia(
    speaker,
    spec,
    workPath,
    id: media!.id,
  );
  return ReplaceGeneratedMedia(updated, label: 'Re-make voiceover line');
}

String _short(String s) => s.length <= 30 ? s : '${s.substring(0, 30)}…';
