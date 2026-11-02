import 'dart:math' as math;

import '../model/audio_item.dart';
import '../model/project.dart';
import '../model/video_clip.dart';
import '../model/voice_effect.dart';
import '../storage/project_store.dart';

/// A sound laid over the main track: a voiceover, music, or an overlay's
/// own sound. [sourceStart] and [length] pick the part of the file;
/// [start] is where it plays on the timeline.
class ExtraAudio {
  const ExtraAudio({
    required this.path,
    required this.start,
    required this.length,
    this.sourceStart = Duration.zero,
    this.volume = 1,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.voice = false,
    this.effect = VoiceEffect.none,
  });

  final String path;
  final Duration start;
  final Duration sourceStart;
  final Duration length;
  final double volume;
  final Duration fadeIn;
  final Duration fadeOut;

  /// Voiceovers duck the original sound.
  final bool voice;
  final VoiceEffect effect;

  /// How much of the file plays: [length] on the timeline, times the speed.
  Duration get sourceLength => effect.speed == 1
      ? length
      : Duration(microseconds: (length.inMicroseconds * effect.speed).round());
}

String _n(double v) => v.toStringAsFixed(4);

/// FFmpeg audio filters for [e], for 48 kHz input. Pitch uses
/// asetrate + atempo (no extra libraries needed): playing the samples
/// faster raises the pitch, then atempo puts the speed back.
List<String> effectFilters(VoiceEffect e) {
  final out = <String>[];
  if (e.denoise) out.add('afftdn=nf=-25');
  if (e.pitch != 0) {
    final k = math.pow(2, e.pitch / 12).toDouble();
    out
      ..add('asetrate=${(48000 * k).round()}')
      ..add('aresample=48000')
      ..addAll(_atempo(1 / k));
  }
  if (e.speed != 1) out.addAll(_atempo(e.speed));
  if (e.robot) {
    // Robotize: keep each frequency's strength, flatten its phase.
    out.add("afftfilt=real='hypot(re,im)':imag='0':win_size=512:overlap=0.75");
  }
  if (e.normalize) {
    out
      ..add('loudnorm=I=-16:TP=-1.5:LRA=11')
      ..add('aresample=48000');
  }
  return out;
}

/// atempo takes 0.5 to 2 per filter; chain more for bigger changes.
List<String> _atempo(double factor) {
  final out = <String>[];
  var f = factor;
  while (f > 2) {
    out.add('atempo=2');
    f /= 2;
  }
  while (f < 0.5) {
    out.add('atempo=0.5');
    f /= 0.5;
  }
  out.add('atempo=${_n(f)}');
  return out;
}

/// The audio chain for one main-track clip from input [i]: 48 kHz stereo,
/// its volume and effect, padded or cut to exactly [length] so nothing
/// drifts. Shared by the export and the preview mix.
String clipAudioFilter(int i, VideoClip clip, String length) => [
  '[$i:a:0]aresample=48000',
  'aformat=sample_fmts=fltp:channel_layouts=stereo',
  'volume=${clip.volume.toStringAsFixed(3)}',
  ...effectFilters(clip.effect),
  'apad',
  'atrim=duration=$length',
  'asetpts=PTS-STARTPTS[a$i]',
].join(',');

/// Every extra sound in [project], with track volumes applied and lengths
/// cut at the end of the video. Muted ones are left out.
List<ExtraAudio> extraAudioOf(Project project, String? projectPath) {
  final total = project.duration;
  Duration cap(Duration start, Duration length) {
    final room = total - start;
    return length < room ? length : room;
  }

  final out = <ExtraAudio>[];
  for (final a in project.audio) {
    final media = project.mediaById(a.mediaId);
    final voice = a.role == AudioRole.voiceover;
    final volume = a.volume * (voice ? project.mix.voiceover : 1);
    if (media == null || volume <= 0 || a.start >= total) continue;
    out.add(
      ExtraAudio(
        path: ProjectStore.resolve(media.path, projectPath),
        start: a.start,
        sourceStart: a.sourceStart,
        length: cap(a.start, a.duration),
        volume: volume,
        fadeIn: a.fadeIn,
        fadeOut: a.fadeOut,
        voice: voice,
        effect: a.effect,
      ),
    );
  }
  for (final o in project.overlays) {
    final media = project.mediaById(o.mediaId);
    if (media == null || !media.hasAudio || o.volume <= 0) continue;
    if (o.start >= total) continue;
    var length = cap(o.start, o.duration);
    if (media.duration > Duration.zero && media.duration < length) {
      length = media.duration;
    }
    out.add(
      ExtraAudio(
        path: ProjectStore.resolve(media.path, projectPath),
        start: o.start,
        length: length,
        volume: o.volume,
      ),
    );
  }
  return out;
}

String _sec(Duration d) =>
    (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);

/// FFmpeg inputs and filters for [extras], numbered from [firstInput].
/// Each sound is cut from its file with `-ss`/`-t`, normalised to 48 kHz
/// stereo, faded and delayed to its start. The results are labelled
/// `[voice]` (voiceovers mixed) and `[other]` (everything else mixed);
/// either is null when there's nothing in it.
({List<String> inputs, List<String> filters, String? voice, String? other})
extraAudioGraph(List<ExtraAudio> extras, int firstInput) {
  final inputs = <String>[];
  final filters = <String>[];
  final voices = <String>[];
  final others = <String>[];
  for (var k = 0; k < extras.length; k++) {
    final e = extras[k];
    inputs.addAll([
      if (e.sourceStart > Duration.zero) ...['-ss', _sec(e.sourceStart)],
      '-t',
      _sec(e.sourceLength),
      '-i',
      e.path,
    ]);
    final len = e.length.inMicroseconds / 1e6;
    final fadeIn = e.fadeIn.inMicroseconds / 1e6;
    final fadeOut = e.fadeOut.inMicroseconds / 1e6;
    filters.add(
      '[${firstInput + k}:a:0]aresample=48000,'
      'aformat=sample_fmts=fltp:channel_layouts=stereo,'
      'asetpts=PTS-STARTPTS,'
      'volume=${e.volume.toStringAsFixed(3)}'
      '${[for (final f in effectFilters(e.effect)) ',$f'].join()}'
      '${fadeIn > 0 ? ',afade=t=in:st=0:d=${fadeIn.toStringAsFixed(3)}' : ''}'
      '${fadeOut > 0 ? ',afade=t=out:st=${(len - fadeOut).toStringAsFixed(3)}:d=${fadeOut.toStringAsFixed(3)}' : ''}'
      ',adelay=delays=${e.start.inMilliseconds}:all=1[x$k]',
    );
    (e.voice ? voices : others).add('[x$k]');
  }
  String? mix(List<String> labels, String out) {
    if (labels.isEmpty) return null;
    filters.add(
      labels.length == 1
          ? '${labels.single}anull[$out]'
          : '${labels.join()}amix=inputs=${labels.length}:normalize=0:'
                'duration=longest:dropout_transition=0[$out]',
    );
    return out;
  }

  return (
    inputs: inputs,
    filters: filters,
    voice: mix(voices, 'voice'),
    other: mix(others, 'other'),
  );
}

/// Filters that turn the main track's audio `[amain]` and the extra sounds
/// into the final `[aout]`: the original at its track volume, ducked under
/// voiceovers when [AudioMix.duck] is on, with everything mixed on top.
List<String> finalMixFilters(
  AudioMix mix,
  ({String? voice, String? other}) extras,
) {
  final filters = <String>[
    '[amain]volume=${mix.original.toStringAsFixed(3)}[aorig]',
  ];
  var original = 'aorig';
  final layers = <String>[];
  if (extras.voice != null) {
    if (mix.duck && mix.original > 0) {
      // The voiceover drives a compressor on the original sound, so it
      // dips while you talk and comes back in the pauses.
      filters
        ..add('[voice]asplit=2[vkey][vmix]')
        ..add(
          '[aorig][vkey]sidechaincompress=threshold=0.02:ratio=8:'
          'attack=20:release=400[aduck]',
        );
      original = 'aduck';
      layers.add('[vmix]');
    } else {
      layers.add('[voice]');
    }
  }
  if (extras.other != null) layers.add('[other]');
  filters.add(
    layers.isEmpty
        ? '[$original]anull[aout]'
        : '[$original]${layers.join()}amix=inputs=${layers.length + 1}:'
              'normalize=0:duration=first:dropout_transition=0[aout]',
  );
  return filters;
}
