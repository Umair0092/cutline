import '../audio/audio_mix.dart';
import '../model/project.dart';
import '../storage/project_store.dart';
import 'export_settings.dart';

/// H.264 encoders we know how to drive, best first per platform.
enum VideoEncoder {
  videotoolbox('h264_videotoolbox'),
  nvenc('h264_nvenc'),
  qsv('h264_qsv'),
  amf('h264_amf'),
  openh264('libopenh264'),
  x264('libx264');

  const VideoEncoder(this.ffmpegName);

  final String ffmpegName;

  List<String> args(int bitrate) => switch (this) {
    videotoolbox => ['-b:v', '$bitrate', '-allow_sw', '1', '-realtime', '0'],
    nvenc => ['-preset', 'p5', '-rc', 'vbr', '-cq', '21', '-b:v', '$bitrate'],
    qsv => ['-preset', 'slow', '-b:v', '$bitrate'],
    amf => ['-quality', 'quality', '-rc', 'vbr_peak', '-b:v', '$bitrate'],
    openh264 => ['-b:v', '$bitrate'],
    x264 => ['-preset', 'medium', '-crf', '20'],
  };
}

String _sec(Duration d) =>
    (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);

/// Turns a project into ffmpeg arguments.
///
/// Each clip is its own input with `-ss`/`-t`, which seeks straight to the
/// clip instead of decoding the file from the start. Every clip is scaled
/// and padded to the output size, its audio normalised to 48 kHz stereo and
/// padded or cut to exactly the clip length so sound never drifts, and then
/// everything is joined with `concat`. Clips without sound get silence.
List<String> buildExportArgs({
  required Project project,
  required String? projectPath,
  required ExportFormat format,
  required VideoEncoder encoder,
  required String outputPath,
  List<({String path, Duration start})> titleOverlays = const [],
}) {
  if (project.clips.isEmpty) {
    throw ArgumentError('Nothing to export.');
  }
  final w = format.width;
  final h = format.height;
  final fps = format.frameRate.toStringAsFixed(3);
  final inputs = <String>[];
  final filters = <String>[];
  final concatInputs = StringBuffer();

  for (var i = 0; i < project.clips.length; i++) {
    final clip = project.clips[i];
    final media = project.mediaById(clip.mediaId)!;
    final path = ProjectStore.resolve(media.path, projectPath);
    final length = _sec(clip.duration);
    inputs.addAll(['-ss', _sec(clip.sourceStart), '-t', length, '-i', path]);

    filters.add(
      '[$i:v:0]scale=$w:$h:force_original_aspect_ratio=decrease,'
      'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,'
      'fps=$fps,format=yuv420p,setpts=PTS-STARTPTS[v$i]',
    );
    if (media.hasAudio) {
      filters.add(clipAudioFilter(i, clip, length));
    } else {
      filters.add(
        'anullsrc=r=48000:cl=stereo,atrim=duration=$length,'
        'aformat=sample_fmts=fltp:channel_layouts=stereo[a$i]',
      );
    }
    concatInputs.write('[v$i][a$i]');
  }
  filters.add(
    '${concatInputs}concat=n=${project.clips.length}:v=1:a=1[vmain][amain]',
  );

  // Titles drawn over the video: pre-rendered see-through clips, shifted to
  // their start time and laid on top.
  var video = 'vmain';
  for (var k = 0; k < titleOverlays.length; k++) {
    final input = project.clips.length + k;
    inputs.addAll(['-i', titleOverlays[k].path]);
    filters
      ..add(
        '[$input:v:0]setpts=PTS-STARTPTS+${_sec(titleOverlays[k].start)}/TB'
        '[title$k]',
      )
      ..add('[$video][title$k]overlay=0:0:eof_action=pass[vt$k]');
    video = 'vt$k';
  }
  filters.add('[$video]null[vout]');

  // Voiceovers, music and overlay sounds start at their time and are mixed
  // over the main audio (see audio_mix.dart).
  final extras = extraAudioGraph(
    extraAudioOf(project, projectPath),
    project.clips.length + titleOverlays.length,
  );
  inputs.addAll(extras.inputs);
  filters
    ..addAll(extras.filters)
    ..addAll(
      finalMixFilters(project.mix, (
        voice: extras.voice,
        music: extras.music,
        other: extras.other,
      )),
    );

  return [
    '-hide_banner',
    '-y',
    ...inputs,
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[vout]',
    '-map',
    '[aout]',
    '-c:v',
    encoder.ffmpegName,
    ...encoder.args(format.videoBitrate),
    '-pix_fmt',
    'yuv420p',
    '-r',
    fps,
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-movflags',
    '+faststart',
    '-progress',
    'pipe:1',
    '-nostats',
    outputPath,
  ];
}

/// Reads `out_time_us=` lines from `ffmpeg -progress` output and returns the
/// latest time written, or null if the chunk has none.
Duration? parseProgress(String chunk) {
  Duration? last;
  for (final line in chunk.split('\n')) {
    if (line.startsWith('out_time_us=')) {
      final us = int.tryParse(line.substring('out_time_us='.length).trim());
      if (us != null && us >= 0) last = Duration(microseconds: us);
    }
  }
  return last;
}
