import 'dart:io';

import 'package:cutline/editing/commands.dart';
import 'package:cutline/export/export_settings.dart';
import 'package:cutline/export/exporter.dart';
import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final sample = Platform.environment['SAMPLE_VIDEO'];

  testWidgets('exports a cut video with the bundled ffmpeg', (tester) async {
    await tester.runAsync(() async {
      final ffmpeg = const FfmpegLocator().find();
      expect(ffmpeg, contains('Contents/Resources/bin/ffmpeg'));

      final asset = await probeVideo(sample!);
      var project = Project(
        media: [asset],
        clips: [
          VideoClip(
            id: 'c1',
            mediaId: asset.id,
            sourceStart: Duration.zero,
            sourceEnd: asset.duration,
          ),
        ],
      );
      project = const RemoveRange(
        Duration(seconds: 5),
        Duration(seconds: 10),
      ).apply(project);

      final out = p.join(
        Directory.systemTemp.createTempSync('cutline_export').path,
        'out.mp4',
      );
      final job = await Exporter(ffmpeg!).start(
        project: project,
        projectPath: null,
        preset: ExportPreset.hd1080,
        outputPath: out,
      );
      final progress = <double>[];
      job.progress.listen(progress.add);
      final watch = Stopwatch()..start();
      expect(await job.done, isTrue);
      // ignore: avoid_print
      print(
        'EXPORT took ${watch.elapsed}, ${progress.length} progress '
        'updates, ${File(out).lengthSync() ~/ 1024} KB',
      );

      expect(progress, isNotEmpty);
      expect(progress.last, greaterThan(0.9));

      final result = await probeVideo(out);
      expect(result.duration.inMilliseconds, closeTo(15000, 150));
      expect((result.width, result.height), (1920, 1080));
      expect(result.hasAudio, isTrue);

      // Cancelling stops ffmpeg and removes the partial file.
      final cancelled = await Exporter(ffmpeg).start(
        project: project,
        projectPath: null,
        preset: ExportPreset.uhd4k,
        outputPath: '$out.cancel.mp4',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      cancelled.cancel();
      expect(await cancelled.done, isFalse);
      expect(File('$out.cancel.mp4').existsSync(), isFalse);
    });
  }, skip: sample == null);
}
