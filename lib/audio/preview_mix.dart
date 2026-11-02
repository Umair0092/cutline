import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../model/project.dart';
import 'audio_mix.dart';

/// Renders every extra sound (voiceovers, music, overlay sounds) into one
/// WAV as long as the video, so the preview can play it next to the video.
/// Returns null when there's nothing to play. The file is named after what
/// went into it, so an unchanged mix is never rendered twice.
Future<String?> renderPreviewMix({
  required String ffmpeg,
  required Project project,
  required String? projectPath,
  required String cacheDir,
}) async {
  final extras = extraAudioOf(project, projectPath);
  if (extras.isEmpty || project.duration <= Duration.zero) return null;
  final total = (project.duration.inMicroseconds / 1e6).toStringAsFixed(6);
  final key = sha1
      .convert(
        utf8.encode(
          jsonEncode([
            total,
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
              ],
          ]),
        ),
      )
      .toString();
  final out = File(p.join(cacheDir, 'mix-$key.wav'));
  if (out.existsSync()) return out.path;
  out.parent.createSync(recursive: true);

  final graph = extraAudioGraph(extras, 0);
  final layers = [?graph.voice, ?graph.other];
  final filters = [
    ...graph.filters,
    '${[for (final l in layers) '[$l]'].join()}'
        '${layers.length == 1 ? 'anull' : 'amix=inputs=${layers.length}:normalize=0:duration=longest:dropout_transition=0'},'
        'apad=whole_dur=$total,atrim=duration=$total[mix]',
  ];
  final part = '${out.path}.part.wav';
  final r = await Process.run(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    ...graph.inputs,
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
  return out.path;
}

/// Size and modified time, so a re-recorded file at the same path counts as
/// new.
String _stamp(String path) {
  final f = File(path);
  if (!f.existsSync()) return '';
  final s = f.statSync();
  return '${s.size}-${s.modified.microsecondsSinceEpoch}';
}
