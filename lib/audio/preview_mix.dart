import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../model/project.dart';
import '../storage/project_store.dart';
import 'audio_mix.dart';

/// What the preview should play next to the video.
class PreviewMix {
  const PreviewMix(this.path, {required this.replacesVideoSound});

  final String path;

  /// The mix has the video's own (processed) sound in it, so the video
  /// plays muted.
  final bool replacesVideoSound;
}

/// Renders the sound the preview can't make on its own into one WAV as long
/// as the video:
/// - just the extra sounds (voiceovers, music, overlay sounds), played over
///   the video's own sound; or
/// - when a main-track clip has a voice effect, the whole final mix (the
///   video's sound with its effects, ducking, and the extras), and the
///   video plays muted.
/// Returns null when there's nothing to add. The file is named after what
/// went into it, so an unchanged mix is never rendered twice.
Future<PreviewMix?> renderPreviewMix({
  required String ffmpeg,
  required Project project,
  required String? projectPath,
  required String cacheDir,
}) async {
  final extras = extraAudioOf(project, projectPath);
  // Music ducked under the video's own speech needs the video's sound in
  // the mix, so then the whole mix is rendered too.
  final full =
      project.clips.any((c) => !c.effect.isNone) ||
      (project.mix.duckMusic &&
          project.mix.original > 0 &&
          extras.any((e) => e.music));
  if ((extras.isEmpty && !full) || project.duration <= Duration.zero) {
    return null;
  }
  final total = _sec(project.duration);
  final key = sha1
      .convert(
        utf8.encode(
          jsonEncode([
            total,
            project.mix.toJson(),
            if (full) ...[
              for (final c in project.clips) ...[
                c.toJson(),
                project.mediaById(c.mediaId)?.path,
                project.mediaById(c.mediaId)?.hasAudio,
              ],
            ],
            for (final e in extras)
              [
                e.path,
                _stamp(e.path),
                e.start.inMicroseconds,
                e.sourceStart.inMicroseconds,
                e.length.inMicroseconds,
                e.volume,
                e.fadeIn.inMicroseconds,
                e.fadeOut.inMicroseconds,
                e.effect.toJson(),
                e.voice,
                e.music,
              ],
          ]),
        ),
      )
      .toString();
  final out = File(p.join(cacheDir, 'mix-$key.wav'));
  if (out.existsSync()) return PreviewMix(out.path, replacesVideoSound: full);
  out.parent.createSync(recursive: true);

  final inputs = <String>[];
  final filters = <String>[];
  if (full) {
    final concat = StringBuffer();
    for (var i = 0; i < project.clips.length; i++) {
      final clip = project.clips[i];
      final media = project.mediaById(clip.mediaId);
      final length = _sec(clip.duration);
      inputs.addAll([
        '-ss',
        _sec(clip.sourceStart),
        '-t',
        length,
        '-i',
        ProjectStore.resolve(media?.path ?? '', projectPath),
      ]);
      filters.add(
        media?.hasAudio ?? false
            ? clipAudioFilter(i, clip, length)
            : 'anullsrc=r=48000:cl=stereo,atrim=duration=$length,'
                  'aformat=sample_fmts=fltp:channel_layouts=stereo[a$i]',
      );
      concat.write('[a$i]');
    }
    filters.add('${concat}concat=n=${project.clips.length}:v=0:a=1[amain]');
  }
  final graph = extraAudioGraph(extras, inputs.where((a) => a == '-i').length);
  inputs.addAll(graph.inputs);
  filters.addAll(graph.filters);
  if (full) {
    filters
      ..addAll(
        finalMixFilters(project.mix, (
          voice: graph.voice,
          music: graph.music,
          other: graph.other,
        )),
      )
      ..add('[aout]apad=whole_dur=$total,atrim=duration=$total[mix]');
  } else {
    // Without the video's sound there's nothing to duck the music under
    // except voiceovers.
    final mixed = finalMixFilters(project.mix.copyWith(original: 0), (
      voice: graph.voice,
      music: graph.music,
      other: graph.other,
    ));
    filters.addAll([
      'anullsrc=r=48000:cl=stereo,atrim=duration=$total[amain]',
      ...mixed,
    ]);
    final layers = ['aout'];
    filters.add(
      '${[for (final l in layers) '[$l]'].join()}'
      '${layers.length == 1 ? 'anull' : 'amix=inputs=${layers.length}:normalize=0:duration=longest:dropout_transition=0'},'
      'apad=whole_dur=$total,atrim=duration=$total[mix]',
    );
  }
  final part = '${out.path}.part.wav';
  final r = await Process.run(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    ...inputs,
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[mix]',
    '-ar',
    '48000',
    '-ac',
    '2',
    part,
  ]);
  if (r.exitCode != 0) return null;
  File(part).renameSync(out.path);
  return PreviewMix(out.path, replacesVideoSound: full);
}

String _sec(Duration d) =>
    (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);

/// Size and modified time, so a re-recorded file at the same path counts as
/// new.
String _stamp(String path) {
  final f = File(path);
  if (!f.existsSync()) return '';
  final s = f.statSync();
  return '${s.size}-${s.modified.microsecondsSinceEpoch}';
}
