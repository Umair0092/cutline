import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/ffmpeg_command.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  group('ExportFormat', () {
    test('1080p keeps a landscape source shape', () {
      final f = ExportFormat.forProject(threeClips(), ExportPreset.hd1080);
      expect((f.width, f.height), (1920, 1080));
      expect(f.frameRate, 30);
    });

    test('a phone video stays vertical and sizes stay even', () {
      final p = Project(
        media: const [
          MediaAsset(
            id: 'm',
            path: '/v.mov',
            kind: MediaKind.video,
            duration: Duration(seconds: 5),
            width: 1080,
            height: 1921,
            frameRate: 59.94,
          ),
        ],
        clips: [
          VideoClip(id: 'c', mediaId: 'm', sourceStart: s(0), sourceEnd: s(5)),
        ],
      );
      final f = ExportFormat.forProject(p, ExportPreset.hd1080);
      expect(f.width, 1080);
      expect(f.height, 1922, reason: 'rounded up to even');
      expect(f.frameRate, 59.94);
      expect(ExportFormat.forProject(p, ExportPreset.uhd4k).width, 2160);
    });
  });

  group('buildExportArgs', () {
    final format = ExportFormat.forProject(threeClips(), ExportPreset.hd1080);
    List<String> args({Project? project}) => buildExportArgs(
      project: project ?? threeClips(),
      projectPath: '/p/Talk.cutline',
      format: format,
      encoder: VideoEncoder.videotoolbox,
      outputPath: '/out/talk.mp4',
    );

    test('one seeked input per clip', () {
      final a = args();
      final inputs = [
        for (var i = 0; i < a.length; i++)
          if (a[i] == '-i') (a[i - 3], a[i - 1], a[i + 1]),
      ];
      expect(inputs, [
        ('0.000000', '10.000000', '/videos/talk.mp4'),
        ('20.000000', '20.000000', '/videos/talk.mp4'),
        ('50.000000', '10.000000', '/videos/talk.mp4'),
      ]);
    });

    test('scales, pads, pins audio length and concats', () {
      final graph = args()[args().indexOf('-filter_complex') + 1];
      expect(
        graph,
        contains('[0:v:0]scale=1920:1080:force_original_aspect_ratio=decrease'),
      );
      expect(graph, contains('pad=1920:1080:(ow-iw)/2:(oh-ih)/2'));
      expect(graph, contains('apad,atrim=duration=20.000000'));
      expect(
        graph,
        contains('[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[vmain][amain]'),
      );
      expect(graph, contains('[vmain]null[vout]'));
      expect(graph, contains('[amain]volume=1.000[aorig]'));
      expect(graph, endsWith('[aorig]anull[aout]'));
    });

    test('voiceovers duck the original; other sounds just mix in', () {
      var project = threeClips().copyWith(
        media: [
          ...threeClips().media,
          const MediaAsset(
            id: 'vo',
            path: 'assets/vo.m4a',
            kind: MediaKind.audio,
            duration: Duration(seconds: 30),
            hasAudio: true,
          ),
          const MediaAsset(
            id: 'beep',
            path: '/memes/bruh.mp4',
            kind: MediaKind.video,
            duration: Duration(seconds: 2),
            width: 160,
            height: 90,
            hasAudio: true,
          ),
        ],
        audio: [
          AudioItem(
            id: 'a1',
            mediaId: 'vo',
            role: AudioRole.voiceover,
            start: s(4),
            sourceStart: s(1),
            sourceEnd: s(11),
            fadeIn: s(0.5),
            fadeOut: s(1),
          ),
        ],
        overlays: [
          OverlayItem(
            id: 'o1',
            mediaId: 'beep',
            start: s(20),
            duration: s(3),
            volume: 0.5,
          ),
        ],
        mix: const AudioMix(original: 0.8, voiceover: 1.5),
      );
      final a = buildExportArgs(
        project: project,
        projectPath: '/p/Talk.cutline',
        format: format,
        encoder: VideoEncoder.videotoolbox,
        outputPath: '/out.mp4',
      );
      // The voiceover is cut from its file; the meme sound plays once.
      expect(
        a,
        containsAllInOrder([
          '-ss',
          '1.000000',
          '-t',
          '10.000000',
          '-i',
          '/p/Talk.cutline/assets/vo.m4a',
          '-t',
          '2.000000',
          '-i',
          '/memes/bruh.mp4',
        ]),
      );
      final graph = a[a.indexOf('-filter_complex') + 1];
      expect(graph, contains('[3:a:0]aresample=48000'));
      expect(
        graph,
        contains(
          'volume=1.500,afade=t=in:st=0:d=0.500,afade=t=out:st=9.000:d=1.000,'
          'adelay=delays=4000:all=1[x0]',
        ),
      );
      expect(graph, contains('volume=0.500,adelay=delays=20000:all=1[x1]'));
      expect(graph, contains('[amain]volume=0.800[aorig]'));
      expect(graph, contains('[aorig][vkey]sidechaincompress'));
      expect(
        graph,
        endsWith(
          '[aduck][vmix][other]amix=inputs=3:normalize=0:duration=first:'
          'dropout_transition=0[aout]',
        ),
      );

      // Ducking off, original muted: no compressor.
      project = project.copyWith(mix: const AudioMix(original: 0, duck: true));
      final b = buildExportArgs(
        project: project,
        projectPath: '/p/Talk.cutline',
        format: format,
        encoder: VideoEncoder.videotoolbox,
        outputPath: '/out.mp4',
      );
      final graph2 = b[b.indexOf('-filter_complex') + 1];
      expect(graph2, isNot(contains('sidechaincompress')));
      expect(graph2, contains('[aorig][voice][other]amix=inputs=3'));
    });

    test('silent clips get generated silence', () {
      final p = threeClips().copyWith(
        media: [threeClips().media.first.copyWith(hasAudio: false)],
      );
      final graph = args(
        project: p,
      )[args(project: p).indexOf('-filter_complex') + 1];
      expect(
        graph,
        contains('anullsrc=r=48000:cl=stereo,atrim=duration=10.000000'),
      );
      expect(graph, isNot(contains('[0:a:0]')));
    });

    test('project-relative media resolves against the project folder', () {
      final p = threeClips().copyWith(
        media: [threeClips().media.first.copyWith(path: 'assets/rec.mp4')],
      );
      expect(args(project: p), contains('/p/Talk.cutline/assets/rec.mp4'));
    });

    test('encoder, audio, faststart, progress and output', () {
      final a = args();
      expect(a.sublist(a.indexOf('-c:v'), a.indexOf('-c:v') + 2), [
        '-c:v',
        'h264_videotoolbox',
      ]);
      expect(a, containsAllInOrder(['-c:a', 'aac', '-movflags', '+faststart']));
      expect(a, containsAllInOrder(['-progress', 'pipe:1']));
      expect(a.last, '/out/talk.mp4');
    });
  });

  test('parseProgress reads the last out_time_us', () {
    expect(
      parseProgress('frame=10\nout_time_us=1500000\nprogress=continue\n'),
      const Duration(milliseconds: 1500),
    );
    expect(
      parseProgress('out_time_us=1\nout_time_us=2000000\n'),
      const Duration(seconds: 2),
    );
    expect(parseProgress('out_time_us=N/A\n'), isNull);
    expect(parseProgress('bitrate=1k\n'), isNull);
  });
}
