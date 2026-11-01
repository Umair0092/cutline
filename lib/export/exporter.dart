import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project.dart';
import '../titles/title_renderer.dart';
import 'export_settings.dart';
import 'ffmpeg_command.dart';

class ExportException implements Exception {
  ExportException(this.message, {this.details});

  final String message;

  /// The end of ffmpeg's error output, for bug reports.
  final String? details;

  @override
  String toString() => message;
}

/// Picks the best H.264 encoder this ffmpeg and this machine can actually
/// use. Hardware encoders are listed even without the hardware, so each one
/// is tried on a tiny test clip.
class EncoderPicker {
  EncoderPicker(this.ffmpeg);

  final String ffmpeg;
  static final _cache = <String, VideoEncoder>{};

  static List<VideoEncoder> candidates() => Platform.isMacOS
      ? const [
          VideoEncoder.videotoolbox,
          VideoEncoder.openh264,
          VideoEncoder.x264,
        ]
      : const [
          VideoEncoder.nvenc,
          VideoEncoder.qsv,
          VideoEncoder.amf,
          VideoEncoder.openh264,
          VideoEncoder.x264,
        ];

  Future<VideoEncoder> pick() async {
    final cached = _cache[ffmpeg];
    if (cached != null) return cached;
    for (final encoder in candidates()) {
      final r = await Process.run(ffmpeg, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=black:s=256x256:d=0.2',
        '-c:v',
        encoder.ffmpegName,
        ...encoder.args(1000000),
        '-f',
        'null',
        '-',
      ]);
      if (r.exitCode == 0) return _cache[ffmpeg] = encoder;
    }
    throw ExportException('No H.264 encoder works on this computer.');
  }
}

/// One running export. Listen to [progress] (0..1) and await [done].
class ExportJob {
  ExportJob._(this._process, this.outputPath, this._total) {
    _process.stdout.transform(utf8.decoder).listen((chunk) {
      final t = parseProgress(chunk);
      if (t != null && _total > Duration.zero) {
        _progress.add(
          (t.inMicroseconds / _total.inMicroseconds).clamp(0.0, 1.0),
        );
      }
    });
    _process.stderr.transform(utf8.decoder).listen((chunk) {
      _stderr.write(chunk);
      // Only the end is useful for errors; keep memory bounded.
      if (_stderr.length > 20000) {
        final tail = _stderr.toString().substring(_stderr.length - 10000);
        _stderr
          ..clear()
          ..write(tail);
      }
    });
    done = _finish();
  }

  final Process _process;
  final String outputPath;
  final Duration _total;
  final _progress = StreamController<double>.broadcast();
  final _stderr = StringBuffer();
  bool _cancelled = false;

  Stream<double> get progress => _progress.stream;

  /// Completes when the file is written; throws [ExportException] on
  /// failure. Completes normally (with false) when cancelled.
  late final Future<bool> done;

  void cancel() {
    _cancelled = true;
    _process.kill();
  }

  Future<bool> _finish() async {
    final code = await _process.exitCode;
    await _progress.close();
    if (_cancelled || code != 0) {
      final partial = File(outputPath);
      if (partial.existsSync()) partial.deleteSync();
    }
    if (_cancelled) return false;
    if (code != 0) {
      final lines = const LineSplitter().convert(_stderr.toString());
      throw ExportException(
        'The export failed (ffmpeg exit code $code).',
        details: lines
            .skip(lines.length > 15 ? lines.length - 15 : 0)
            .join('\n'),
      );
    }
    return true;
  }
}

class Exporter {
  Exporter(this.ffmpeg);

  final String ffmpeg;

  Future<ExportJob> start({
    required Project project,
    required String? projectPath,
    required ExportPreset preset,
    required String outputPath,
  }) async {
    final encoder = await EncoderPicker(ffmpeg).pick();
    final format = ExportFormat.forProject(project, preset);

    // Titles over the video are drawn at the exact output size first.
    final work = Directory.systemTemp.createTempSync('cutline_export');
    final overlays = <({String path, Duration start})>[];
    for (final title in project.titles) {
      final path = p.join(work.path, '${title.id}.mov');
      await TitleRenderer(ffmpeg).renderOverlay(
        title.spec,
        path,
        width: format.width,
        height: format.height,
        fps: format.frameRate,
      );
      overlays.add((path: path, start: title.start));
    }

    final args = buildExportArgs(
      project: project,
      projectPath: projectPath,
      format: format,
      encoder: encoder,
      outputPath: outputPath,
      titleOverlays: overlays,
    );
    final process = await Process.start(ffmpeg, args);
    final job = ExportJob._(process, outputPath, project.duration);
    unawaited(
      job.done
          .whenComplete(() => work.deleteSync(recursive: true))
          .then((_) {}, onError: (_) {}),
    );
    return job;
  }
}
