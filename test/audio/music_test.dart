import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/audio/audio_mix.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/music/music_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../fixtures.dart';

const song = MediaAsset(
  id: 'song',
  path: 'assets/music-song.mp3',
  kind: MediaKind.audio,
  duration: Duration(seconds: 15),
  hasAudio: true,
  name: 'Sunny Day',
  credit: '"Sunny Day" by Someone (CC BY 4.0)',
);

Project _apply(Project p, List<EditCommand> commands) {
  var out = p;
  for (final c in commands) {
    out = c.apply(out);
  }
  return out;
}

void main() {
  group('musicCommands', () {
    test('repeats a short track to fill the video and fades the ends', () {
      final project = _apply(threeClips(), musicCommands(threeClips(), song));
      final music = project.audio.where((a) => a.role == AudioRole.music);
      // 40 s of video from a 15 s track: 15 + 15 + 10.
      expect([for (final a in music) a.duration], [s(15), s(15), s(10)]);
      expect([for (final a in music) a.start], [s(0), s(15), s(30)]);
      expect(music.first.fadeIn, greaterThan(Duration.zero));
      expect(music.last.fadeOut, greaterThan(Duration.zero));
      expect(music.elementAt(1).fadeIn, Duration.zero);
      expect(project.media.where((m) => m.id == 'song'), hasLength(1));
    });

    test('plays only between from and to, starting into the track', () {
      final project = _apply(
        threeClips(),
        musicCommands(
          threeClips(),
          song,
          from: s(5),
          to: s(12),
          sourceStart: s(3),
        ),
      );
      final a = project.audio.single;
      expect(a.start, s(5));
      expect(a.sourceStart, s(3));
      expect(a.duration, s(7));
    });
  });

  group('the mix graph', () {
    test('music is evened out and scaled by the music level', () {
      final project = _apply(
        threeClips().copyWith(mix: const AudioMix(music: 0.5)),
        musicCommands(threeClips(), song),
      );
      final extras = extraAudioOf(project, '/proj');
      expect(extras.every((e) => e.music && e.volume == 0.5), isTrue);
      final graph = extraAudioGraph(extras, 3);
      expect(graph.music, 'music');
      expect(graph.voice, isNull);
      expect(graph.filters.first, contains('loudnorm=I=$musicLoudness'));
    });

    test('music ducks under the video and voiceovers when switched on', () {
      final f = finalMixFilters(const AudioMix(), (
        voice: 'voice',
        music: 'music',
        other: null,
      )).join(';');
      // The voiceover is split three ways: mixed, keying the video's
      // ducking, keying the music's.
      expect(f, contains('[voice]asplit=3[vmix][vkey][vmk]'));
      expect(f, contains('[aomk][vmk]amix'));
      expect(f, contains('[music][speech]sidechaincompress'));
      expect(f, contains('[mduck]'));
    });

    test('nothing is ducked when both switches are off', () {
      final f = finalMixFilters(const AudioMix(duck: false, duckMusic: false), (
        voice: 'voice',
        music: 'music',
        other: null,
      )).join(';');
      expect(f, isNot(contains('sidechaincompress')));
      expect(f, contains('[aorig][voice][music]amix=inputs=3'));
    });

    final ffmpeg = const FfmpegLocator().find();
    test(
      'FFmpeg runs the graph, and music is quieter while someone talks',
      () async {
        final dir = Directory.systemTemp.createTempSync('cutline_music');
        addTearDown(() => dir.deleteSync(recursive: true));
        // "Speech" in the video: a 3 kHz tone for the first 3 s, then
        // silence. "Music": a steady 200 Hz tone.
        Future<void> tone(String name, String expr) async {
          final r = await Process.run(ffmpeg!, [
            '-y',
            '-f',
            'lavfi',
            '-i',
            expr,
            '-t',
            '7',
            p.join(dir.path, name),
          ]);
          expect(r.exitCode, 0, reason: '${r.stderr}');
        }

        await tone(
          'speech.wav',
          "aevalsrc='if(lt(t,3),0.5*sin(2*PI*3000*t),0)':s=48000",
        );
        await tone('music.wav', "aevalsrc='0.3*sin(2*PI*200*t)':s=48000");

        final graph = extraAudioGraph([
          ExtraAudio(
            path: p.join(dir.path, 'music.wav'),
            start: Duration.zero,
            length: s(7),
            music: true,
          ),
        ], 1);
        final filters = [
          '[0:a]aresample=48000,'
              'aformat=sample_fmts=fltp:channel_layouts=stereo[amain]',
          ...graph.filters,
          ...finalMixFilters(const AudioMix(), (
            voice: null,
            music: graph.music,
            other: null,
          )),
        ];
        final out = p.join(dir.path, 'mix.raw');
        final r = await Process.run(ffmpeg!, [
          '-y',
          '-i',
          p.join(dir.path, 'speech.wav'),
          ...graph.inputs,
          '-filter_complex',
          // Keep only the music's 200 Hz to measure it.
          '${filters.join(';')};'
              '[aout]lowpass=f=500,lowpass=f=500,lowpass=f=500[measure]',
          '-map',
          '[measure]',
          '-f',
          'f32le',
          '-ac',
          '1',
          '-ar',
          '48000',
          out,
        ]);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        final samples = File(out).readAsBytesSync().buffer.asFloat32List();
        double rms(double from, double to) {
          var sum = 0.0;
          final a = (from * 48000).round();
          final b = (to * 48000).round();
          for (var i = a; i < b; i++) {
            sum += samples[i] * samples[i];
          }
          return math.sqrt(sum / (b - a));
        }

        final talking = rms(1, 2.8);
        final quiet = rms(5, 6.8);
        expect(quiet, greaterThan(0.01));
        // At least ~4.5 dB lower under speech.
        expect(talking / quiet, lessThan(0.6));
      },
      skip: ffmpeg == null ? 'needs ffmpeg' : null,
    );
  });

  group('assistant tools', () {
    const tools = EditToolbox();
    final searches = <String>[];
    final choices = <String, Track>{};
    final context = ToolContext(
      findTracks: (query, {kind = TrackKind.music}) async {
        searches.add('${kind.name}:$query');
        return [
          Track(
            id: 'ov-${query.hashCode}',
            title: kind == TrackKind.music ? 'Sunny Day' : 'Whoosh',
            source: 'https://example.com/a.mp3',
            artist: 'Someone',
            duration: kind == TrackKind.music ? s(15) : s(1),
          ),
        ];
      },
      trackChoices: choices,
      trackMedia: (project, track) async => track.title == 'Whoosh'
          ? const MediaAsset(
              id: 'whoosh',
              path: 'assets/music-whoosh.mp3',
              kind: MediaKind.audio,
              duration: Duration(seconds: 1),
              hasAudio: true,
            )
          : song,
    );

    setUp(() {
      searches.clear();
      choices.clear();
    });

    test('search_music shows cards with ids the model can use', () async {
      final out = await tools.run(
        'search_music',
        {'query': 'upbeat pop'},
        threeClips(),
        context: context,
      );
      expect(out.isError, isFalse);
      expect(out.tracks.single.$1, 'music1');
      expect(choices.keys, ['music1']);
      final result = jsonDecode(out.result) as Map<String, dynamic>;
      expect(((result['options'] as List).single as Map)['id'], 'music1');
    });

    test('add_music by words fills the video and sets the level', () async {
      final out = await tools.run(
        'add_music',
        {'music': 'calm piano', 'level': 0.4},
        threeClips(),
        context: context,
      );
      expect(out.isError, isFalse, reason: out.result);
      expect(searches, ['music:calm piano']);
      final music = out.project.audio.where((a) => a.role == AudioRole.music);
      expect(music.last.end, s(40));
      expect(out.project.mix.music, 0.4);
    });

    test('add_music replaces music already playing there', () async {
      final first = await tools.run(
        'add_music',
        {'music': 'calm'},
        threeClips(),
        context: context,
      );
      final second = await tools.run(
        'add_music',
        {'music': 'epic'},
        first.project,
        context: context,
      );
      final music = second.project.audio.where(
        (a) => a.role == AudioRole.music,
      );
      expect(music, hasLength(3));
      expect(
        music
            .map((a) => a.id)
            .toSet()
            .intersection(first.project.audio.map((a) => a.id).toSet()),
        isEmpty,
      );
    });

    test('add_sound goes at the time given', () async {
      final out = await tools.run(
        'add_sound',
        {'sound': 'whoosh', 'start': 12},
        threeClips(),
        context: context,
      );
      expect(out.isError, isFalse, reason: out.result);
      expect(searches, ['sound:whoosh']);
      final a = out.project.audio.single;
      expect(a.role, AudioRole.effect);
      expect(a.start, s(12));
    });

    test('set_audio_mix changes only what is passed', () async {
      final out = await tools.run(
        'set_audio_mix',
        {'video': 1.4, 'duck_music': false},
        threeClips(),
        context: context,
      );
      expect(out.project.mix.original, 1.4);
      expect(out.project.mix.duckMusic, isFalse);
      expect(out.project.mix.voiceover, 1);
      expect(out.project.mix.music, const AudioMix().music);
    });

    test('remove_audio by role removes all the music', () async {
      final added = await tools.run(
        'add_music',
        {'music': 'calm'},
        threeClips(),
        context: context,
      );
      final out = await tools.run(
        'remove_audio',
        {'role': 'music'},
        added.project,
        context: context,
      );
      expect(out.project.audio, isEmpty);
    });

    test('the project summary shows the mix and music titles', () async {
      final added = await tools.run(
        'add_music',
        {'music': 'calm'},
        threeClips(),
        context: context,
      );
      final result = jsonDecode(added.result) as Map<String, dynamic>;
      final project = result['project'] as Map<String, dynamic>;
      expect((project['mix'] as Map)['music'], const AudioMix().music);
      expect(((project['audio'] as List).first as Map)['title'], 'Sunny Day');
    });

    test('mix levels outside 0–2 are refused', () {
      expect(
        () => SetAudioMix(const AudioMix(music: 3)).apply(threeClips()),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('a track keeps its credit through saving', () {
    final t = Track(
      id: 'ov-1',
      title: 'Sunny Day',
      source: 'https://example.com/a.mp3',
      artist: 'Someone',
      license: 'CC BY 4.0',
      page: 'https://example.com/t/1',
      duration: s(95),
    );
    final back = Track.fromJson(t.toStoredJson());
    expect(
      back.credit,
      '"Sunny Day" by Someone (CC BY 4.0) https://example.com/t/1',
    );
    expect(back.duration, s(95));
  });
}
