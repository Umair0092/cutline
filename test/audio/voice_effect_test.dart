import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/audio/audio_mix.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/ffmpeg_command.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/voice_effect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

Project withVoice() => threeClips().copyWith(
  media: [
    ...threeClips().media,
    MediaAsset(
      id: 'vo',
      path: '/vo.wav',
      kind: MediaKind.audio,
      duration: s(10),
      hasAudio: true,
    ),
  ],
  audio: [
    AudioItem(
      id: 'a',
      mediaId: 'vo',
      role: AudioRole.voiceover,
      start: s(5),
      sourceStart: s(0),
      sourceEnd: s(8),
    ),
  ],
);

void main() {
  group('effectFilters', () {
    test('2 semitones down: faster sample rate, then the speed put back', () {
      expect(effectFilters(const VoiceEffect(pitch: -2)), [
        'asetrate=42763',
        'aresample=48000',
        'atempo=1.1225',
      ]);
    });

    test('speed outside 0.5–2 chains atempo; cleanup comes first', () {
      expect(
        effectFilters(
          const VoiceEffect(speed: 0.4, denoise: true, normalize: true),
        ),
        [
          'afftdn=nf=-25',
          'atempo=0.5',
          'atempo=0.8000',
          'loudnorm=I=-16:TP=-1.5:LRA=11',
          'aresample=48000',
        ],
      );
      expect(effectFilters(VoiceEffect.none), isEmpty);
      expect(
        effectFilters(const VoiceEffect(robot: true)).single,
        startsWith('afftfilt='),
      );
    });
  });

  test('a sped-up audio item is shorter on the timeline', () {
    final a = withVoice().audio.single.copyWith(
      effect: const VoiceEffect(speed: 2),
    );
    expect(a.sourceLength, s(8));
    expect(a.duration, s(4));
    expect(a.end, s(9));
  });

  group('commands', () {
    test('SetClipEffect: all clips, or some; no speed on the main track', () {
      var p = const SetClipEffect(VoiceEffect(pitch: -2)).apply(threeClips());
      expect(p.clips.every((c) => c.effect.pitch == -2), isTrue);
      p = const SetClipEffect(VoiceEffect.none, clipIds: ['b']).apply(p);
      expect([for (final c in p.clips) c.effect.pitch], [-2, 0, -2]);
      expect(
        () => const SetClipEffect(VoiceEffect(speed: 1.5)).apply(p),
        throwsA(isA<EditException>()),
      );
      expect(
        () => const SetClipEffect(VoiceEffect(pitch: 20)).apply(p),
        throwsA(isA<EditException>()),
      );
    });

    test('UpdateAudio takes speed', () {
      final p = const UpdateAudio(
        'a',
        effect: VoiceEffect(speed: 2, pitch: 3),
      ).apply(withVoice());
      expect(p.audio.single.duration, s(4));
    });
  });

  test('export puts the effect in the clip and audio chains', () {
    final p = const SetClipEffect(VoiceEffect(pitch: -2)).apply(
      const UpdateAudio('a', effect: VoiceEffect(speed: 2)).apply(withVoice()),
    );
    final a = buildExportArgs(
      project: p,
      projectPath: null,
      format: ExportFormat.forProject(p, ExportPreset.hd1080),
      encoder: VideoEncoder.videotoolbox,
      outputPath: '/out.mp4',
    );
    final graph = a[a.indexOf('-filter_complex') + 1];
    expect(
      graph,
      contains(
        'volume=1.000,asetrate=42763,aresample=48000,atempo=1.1225,apad,'
        'atrim=duration=10.000000',
      ),
    );
    // 4 s on the timeline reads 8 s of the file at double speed.
    expect(a, containsAllInOrder(['-t', '8.000000', '-i', '/vo.wav']));
    expect(graph, contains('volume=1.000,atempo=2.0000,adelay=delays=5000'));
  });

  group('set_voice_effect', () {
    const tools = EditToolbox();

    test('"make my voice a bit deeper" lowers every clip', () async {
      final out = await tools.run('set_voice_effect', {
        'target': 'video',
        'pitch': -2,
      }, threeClips());
      expect(out.isError, isFalse, reason: out.result);
      expect(out.project.clips.every((c) => c.effect.pitch == -2), isTrue);
      expect(out.command!.label, 'Voice effect');
    });

    test('presets, cleanup flags, audio targets, reset', () async {
      var out = await tools.run('set_voice_effect', {
        'target': 'a',
        'preset': 'chipmunk',
        'speed': 1.25,
        'denoise': true,
      }, withVoice());
      expect(
        out.project.audio.single.effect,
        const VoiceEffect(pitch: 8, speed: 1.25, denoise: true),
      );
      out = await tools.run('set_voice_effect', {
        'target': 'a',
        'reset': true,
      }, out.project);
      expect(out.project.audio.single.effect.isNone, isTrue);

      final bad = await tools.run('set_voice_effect', {
        'target': 'video',
        'speed': 1.5,
      }, threeClips());
      expect(bad.isError, isTrue);
      expect(bad.result, contains('can\'t change speed'));
      final nobody = await tools.run('set_voice_effect', {
        'target': 'zzz',
        'pitch': 1,
      }, threeClips());
      expect(nobody.result, contains('"video", a clip_id or an audio_id'));
    });
  });
}
