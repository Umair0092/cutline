import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/ffmpeg_command.dart';
import 'package:cutline/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  group('outputSize', () {
    test('reframes a landscape source to each aspect at 1080 short side', () {
      expect(outputSize(1920, 1080, ReframeAspect.vertical), (
        width: 1080,
        height: 1920,
      ));
      expect(outputSize(1920, 1080, ReframeAspect.square), (
        width: 1080,
        height: 1080,
      ));
      expect(outputSize(1920, 1080, ReframeAspect.wide), (
        width: 1920,
        height: 1080,
      ));
    });

    test('source keeps the shape, clamped to 1080 short side', () {
      expect(outputSize(1920, 1080, ReframeAspect.source), (
        width: 1920,
        height: 1080,
      ));
      expect(outputSize(1080, 1920, ReframeAspect.source), (
        width: 1080,
        height: 1920,
      ));
    });
  });

  group('ExportFormat honours the project aspect', () {
    test('vertical makes a 9:16 frame', () {
      final f = ExportFormat.forProject(
        threeClips().copyWith(aspect: ReframeAspect.vertical),
        ExportPreset.hd1080,
      );
      expect((f.width, f.height), (1080, 1920));
    });

    test('source is unchanged (regression)', () {
      final f = ExportFormat.forProject(threeClips(), ExportPreset.hd1080);
      expect((f.width, f.height), (1920, 1080));
    });
  });

  test('SetAspect command and the set_aspect tool reframe the project', () async {
    expect(SetAspect(ReframeAspect.vertical).apply(threeClips()).aspect,
        ReframeAspect.vertical);

    final out = await const EditToolbox().run(
      'set_aspect',
      const {'aspect': 'vertical'},
      threeClips(),
    );
    expect(out.isError, isFalse, reason: out.result);
    expect(out.project.aspect, ReframeAspect.vertical);
    expect(out.command!.label, 'Reframe to 9:16');
  });

  test('the ffmpeg filter scales clips to the reframed size', () {
    final project = threeClips().copyWith(aspect: ReframeAspect.vertical);
    final args = buildExportArgs(
      project: project,
      projectPath: null,
      format: ExportFormat.forProject(project, ExportPreset.hd1080),
      encoder: VideoEncoder.x264,
      outputPath: 'out.mp4',
    );
    expect(args.join(' '), contains('scale=1080:1920'));
  });
}
