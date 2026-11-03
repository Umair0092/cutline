import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/project_editor.dart';
import '../export/export_settings.dart';
import '../export/exporter.dart';
import '../media/ffmpeg.dart';
import '../media/media_previews.dart';
import '../model/project.dart';
import '../preview/preview_controller.dart';
import '../storage/project_store.dart';
import 'dialogs/dialog_kit.dart';
import 'tokens.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// File > Export…: one dialog that goes from choosing a size, to progress,
/// to "Exported" in place.
Future<void> showExportFlow(WidgetRef ref, BuildContext context) async {
  final state = ref.read(projectEditorProvider);
  if (state.project.clips.isEmpty) {
    _snack(context, 'Import a video first.');
    return;
  }
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) {
    _snack(context, 'FFmpeg is missing, so the video can\'t be exported.');
    return;
  }
  Duration at;
  try {
    at = ref.read(previewProvider).position;
  } on Object {
    at = Duration.zero;
  }
  await showCutModal<void>(
    context,
    builder: (_) => ExportDialog(
      project: state.project,
      projectPath: state.workPath,
      ffmpeg: ffmpeg,
      frameAt: at,
    ),
  );
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

enum _Phase { setup, running, done, failed }

/// The three sizes the exporter makes, as cards.
const _presetInfo = {
  ExportPreset.hd1080: ('1080p', 'Full HD'),
  ExportPreset.uhd4k: ('4K', 'Ultra HD'),
  ExportPreset.source: ('Original', 'Same as source'),
};

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.project,
    required this.projectPath,
    required this.ffmpeg,
    this.frameAt = Duration.zero,
    this.startJob,
    this.chooseLocation,
  });

  final Project project;
  final String? projectPath;
  final String ffmpeg;

  /// The frame to show: where the playhead is.
  final Duration frameAt;

  /// Starts the export; tests pass a fake.
  final Future<ExportJob> Function(ExportPreset preset, String path)? startJob;

  /// Asks where to save; tests pass a fake.
  final Future<String?> Function(String suggestedName)? chooseLocation;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportPreset _preset = ExportPreset.hd1080;
  _Phase _phase = _Phase.setup;
  String? _location;
  String? _notice;
  String? _error;
  ExportJob? _job;
  double _progress = 0;
  final _clock = Stopwatch();
  StreamSubscription<double>? _sub;
  int? _outputBytes;

  /// Credits for music and sounds that are still in the edit.
  late final List<String> _credits = {
    for (final a in widget.project.audio)
      ?widget.project.mediaById(a.mediaId)?.credit,
  }.toList();

  ExportFormat get _format => ExportFormat.forProject(widget.project, _preset);

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  String get _suggestedName => '${widget.project.name}.mp4';

  Future<String?> _ask() async {
    if (widget.chooseLocation != null) {
      return widget.chooseLocation!(_suggestedName);
    }
    final location = await getSaveLocation(
      suggestedName: _suggestedName,
      initialDirectory: _location == null ? null : p.dirname(_location!),
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'MP4 video',
          extensions: ['mp4'],
          uniformTypeIdentifiers: ['public.mpeg-4'],
        ),
      ],
    );
    if (location == null) return null;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.mp4')) path += '.mp4';
    return path;
  }

  Future<void> _chooseLocation() async {
    final path = await _ask();
    if (path != null && mounted) setState(() => _location = path);
  }

  Future<void> _export() async {
    final path = _location ?? await _ask();
    if (path == null || !mounted) return;
    setState(() {
      _location = path;
      _notice = null;
    });
    final ExportJob job;
    try {
      job = widget.startJob != null
          ? await widget.startJob!(_preset, path)
          : await Exporter(widget.ffmpeg).start(
              project: widget.project,
              projectPath: widget.projectPath,
              preset: _preset,
              outputPath: path,
            );
    } on ExportException catch (e) {
      if (mounted) setState(() => _notice = e.message);
      return;
    }
    if (!mounted) return;
    _clock
      ..reset()
      ..start();
    setState(() {
      _job = job;
      _progress = 0;
      _phase = _Phase.running;
    });
    _sub = job.progress.listen((v) {
      if (mounted) setState(() => _progress = v);
    });
    unawaited(
      job.done.then(
        (ok) {
          _clock.stop();
          if (!mounted) return;
          if (!ok) {
            setState(() {
              _phase = _Phase.setup;
              _notice = 'Export cancelled. Nothing was saved.';
            });
            return;
          }
          int? bytes;
          try {
            bytes = File(job.outputPath).lengthSync();
          } on Object {
            bytes = null;
          }
          setState(() {
            _outputBytes = bytes;
            _phase = _Phase.done;
          });
        },
        onError: (Object e) {
          _clock.stop();
          if (!mounted) return;
          setState(() {
            _error = e is ExportException ? e.message : '$e';
            _phase = _Phase.failed;
          });
        },
      ),
    );
  }

  Future<void> _reveal() async {
    final path = _job!.outputPath;
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    }
  }

  Future<void> _open() async {
    final path = _job!.outputPath;
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    final running = _phase == _Phase.running;
    final (title, subtitle, icon) = switch (_phase) {
      _Phase.setup => (
        'Export video',
        'An MP4 that plays everywhere',
        CutIcons.export,
      ),
      _Phase.running => ('Exporting…', 'Keep Cutline open', CutIcons.export),
      _Phase.done => (
        'Exported',
        p.basename(_job!.outputPath),
        CutIcons.export,
      ),
      _Phase.failed => ('Export failed', 'Nothing was saved', CutIcons.warning),
    };
    return PopScope(
      canPop: !running,
      child: CutModal(
        width: 820,
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: switch (_phase) {
          _Phase.done => Cut.success,
          _Phase.failed => Cut.error,
          _ => null,
        },
        iconBackground: switch (_phase) {
          _Phase.done => Cut.successContainer,
          _Phase.failed => Cut.errorContainer,
          _ => null,
        },
        showClose: !running,
        body: AnimatedSize(
          duration: CutMotion.normal,
          curve: CutMotion.decelerate,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: CutMotion.normal,
            switchInCurve: CutMotion.decelerate,
            switchOutCurve: CutMotion.accelerate,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.98, end: 1.0).animate(a),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: switch (_phase) {
                _Phase.setup => phone ? _setupPhone() : _setupDesktop(),
                _Phase.running => _runningView(phone),
                _Phase.done => _doneView(phone),
                _Phase.failed => _failedView(),
              },
            ),
          ),
        ),
        footer: _footer(),
      ),
    );
  }

  Widget _footer() => switch (_phase) {
    _Phase.setup => ModalActions(
      actions: [
        QuietButton(
          label: 'Cancel',
          onPressed: () => Navigator.maybePop(context),
        ),
        PrimaryButton(
          key: const Key('export-next'),
          label: _location == null ? 'Export…' : 'Export',
          icon: CutIcons.export,
          onPressed: _export,
        ),
      ],
    ),
    _Phase.running => ModalActions(
      actions: [
        QuietButton(
          label: 'Cancel export',
          icon: CutIcons.close,
          onPressed: _job?.cancel,
        ),
      ],
    ),
    _Phase.done => ModalActions(
      leading: Platform.isMacOS || Platform.isWindows
          ? QuietButton(
              label: Platform.isMacOS ? 'Show in Finder' : 'Show in Folder',
              icon: DialogIcons.finder,
              onPressed: _reveal,
            )
          : null,
      actions: [
        if (Platform.isMacOS || Platform.isWindows)
          QuietButton(label: 'Open', icon: DialogIcons.open, onPressed: _open),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    ),
    _Phase.failed => ModalActions(
      actions: [
        QuietButton(
          label: 'Close',
          onPressed: () => Navigator.maybePop(context),
        ),
        PrimaryButton(
          label: 'Try again',
          onPressed: () => setState(() {
            _phase = _Phase.setup;
            _error = null;
          }),
        ),
      ],
    ),
  };

  // ---------------------------------------------------------------- setup

  Widget _setupDesktop() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Frame(
                  project: widget.project,
                  projectPath: widget.projectPath,
                  at: widget.frameAt,
                  format: _format,
                  maxHeight: 300,
                ),
                const SizedBox(height: CutSpace.s3),
                _summary(),
              ],
            ),
          ),
          const SizedBox(width: CutSpace.s6),
          Expanded(child: _settings()),
        ],
      ),
    ],
  );

  Widget _setupPhone() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: _Frame(
          project: widget.project,
          projectPath: widget.projectPath,
          at: widget.frameAt,
          format: _format,
          maxHeight: 240,
        ),
      ),
      const SizedBox(height: CutSpace.s3),
      _summary(),
      const SizedBox(height: CutSpace.s5),
      _settings(),
    ],
  );

  Widget _summary() {
    final d = widget.project.duration;
    final clips = widget.project.clips.length;
    return Row(
      children: [
        const Icon(CutIcons.clock, size: 14, color: Cut.textTertiary),
        const SizedBox(width: 6),
        TimecodeText(_mmss(d), color: Cut.textSecondary),
        const SizedBox(width: CutSpace.s3),
        const Icon(CutIcons.video, size: 14, color: Cut.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$clips ${clips == 1 ? 'clip' : 'clips'}',
            style: CutType.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    final f = _format;
    final seconds = widget.project.duration.inMicroseconds / 1e6;
    final bytes = (f.videoBitrate + 192000) * seconds / 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Size'),
        Row(
          children: [
            for (final (i, preset) in ExportPreset.values.indexed) ...[
              if (i > 0) const SizedBox(width: CutSpace.s2),
              Expanded(
                child: _PresetCard(
                  key: Key('export-preset-${preset.name}'),
                  preset: preset,
                  format: ExportFormat.forProject(widget.project, preset),
                  selected: preset == _preset,
                  onTap: () => setState(() => _preset = preset),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: CutSpace.s4),
        _Specs(
          items: [
            ('Frame', '${f.width}×${f.height}'),
            ('Rate', '${f.frameRate.round()} fps'),
            ('Video', 'H.264 · ${(f.videoBitrate / 1e6).round()} Mb/s'),
            ('File', '≈ ${_formatBytes(bytes)}'),
          ],
        ),
        const SizedBox(height: CutSpace.s4),
        const FieldLabel('Save to'),
        _Destination(
          path: _location,
          suggestedName: _suggestedName,
          onChange: _chooseLocation,
        ),
        if (_notice != null) ...[
          const SizedBox(height: CutSpace.s3),
          InlineNotice(
            _notice!,
            color: Cut.warning,
            background: Cut.warningContainer,
            icon: CutIcons.info,
          ),
        ],
        if (_credits.isNotEmpty) ...[
          const SizedBox(height: CutSpace.s4),
          _Credits(_credits),
        ],
      ],
    );
  }

  // -------------------------------------------------------------- running

  Widget _runningView(bool phone) {
    final elapsed = _clock.elapsed;
    String left;
    if (_progress < 0.03 || elapsed < const Duration(seconds: 1)) {
      left = 'Working out the time left…';
    } else {
      final total = elapsed.inMilliseconds / _progress;
      final rest = Duration(
        milliseconds: (total - elapsed.inMilliseconds).round(),
      );
      left = rest.inSeconds < 5 ? 'Almost done' : 'About ${_mmss(rest)} left';
    }
    final pct = Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: _progress),
          duration: CutMotion.normal,
          builder: (context, v, _) => Text(
            '${(v * 100).floor()}%',
            style: CutType.display.copyWith(
              fontSize: 56,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: CutSpace.s2),
        Text(left, style: CutType.body.copyWith(color: Cut.textSecondary)),
        const SizedBox(height: CutSpace.s4),
        ClipRRect(
          borderRadius: BorderRadius.circular(CutRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _progress),
            duration: CutMotion.normal,
            builder: (context, v, _) => LinearProgressIndicator(
              key: const Key('export-progress'),
              value: v,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: CutSpace.s3),
        Text(
          '${_presetInfo[_preset]!.$1} · ${_format.width}×${_format.height} · '
          '${p.basename(_job!.outputPath)}',
          style: CutType.caption.copyWith(color: Cut.textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final frame = _Frame(
      project: widget.project,
      projectPath: widget.projectPath,
      at: widget.frameAt,
      format: _format,
      maxHeight: phone ? 260 : 280,
      fill: _progress,
    );
    if (phone) {
      return Column(
        children: [
          const SizedBox(height: CutSpace.s2),
          frame,
          const SizedBox(height: CutSpace.s6),
          pct,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CutSpace.s2),
      child: Row(
        children: [
          SizedBox(width: 340, child: frame),
          const SizedBox(width: CutSpace.s7),
          Expanded(child: pct),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- done

  Widget _doneView(bool phone) {
    final f = _format;
    final details = Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DrawnCheck(),
        const SizedBox(height: CutSpace.s4),
        Text('Your video is ready', style: CutType.headline),
        const SizedBox(height: CutSpace.s2),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: phone ? WrapAlignment.center : WrapAlignment.start,
          children: [
            CutBadge('${f.width}×${f.height}', mono: true),
            CutBadge('${f.frameRate.round()} fps', mono: true),
            if (_outputBytes != null)
              CutBadge(_formatBytes(_outputBytes!.toDouble()), mono: true),
            CutBadge('took ${_mmss(_clock.elapsed)}', mono: true),
          ],
        ),
        const SizedBox(height: CutSpace.s3),
        SelectableText(
          _job!.outputPath,
          style: CutType.caption.copyWith(color: Cut.textTertiary),
          textAlign: phone ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
    final frame = _Frame(
      project: widget.project,
      projectPath: widget.projectPath,
      at: widget.frameAt,
      format: f,
      maxHeight: phone ? 220 : 260,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone) ...[
          Center(child: frame),
          const SizedBox(height: CutSpace.s5),
          details,
        ] else
          Row(
            children: [
              SizedBox(width: 300, child: frame),
              const SizedBox(width: CutSpace.s7),
              Expanded(child: details),
            ],
          ),
        if (_credits.isNotEmpty) ...[
          const SizedBox(height: CutSpace.s5),
          _Credits(_credits),
        ],
      ],
    );
  }

  Widget _failedView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InlineNotice(_error ?? 'Something went wrong.'),
      const SizedBox(height: CutSpace.s3),
      Text(
        'Check there is space on the disk and that the folder can be '
        'written to, then try again.',
        style: CutType.caption,
      ),
    ],
  );
}

String _mmss(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _formatBytes(double bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).round()} MB';
  return '${math.max(1, (bytes / 1e3).round())} KB';
}

/// The current frame in the output's shape, with format chips. While
/// exporting, [fill] turns it from grey to colour, left to right.
class _Frame extends ConsumerWidget {
  const _Frame({
    required this.project,
    required this.projectPath,
    required this.at,
    required this.format,
    required this.maxHeight,
    this.fill,
  });

  final Project project;
  final String? projectPath;
  final Duration at;
  final ExportFormat format;
  final double maxHeight;
  final double? fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hit = project.clipAt(at) ?? project.clipAt(Duration.zero);
    final clip = hit == null ? null : project.clips[hit.index];
    final media = clip == null ? null : project.mediaById(clip.mediaId);
    final preview = media == null
        ? null
        : ref
              .watch(
                mediaPreviewProvider(
                  ProjectStore.resolve(media.path, projectPath),
                ),
              )
              .value;
    final image = preview?.thumbnailAt(hit!.sourceTime);
    final aspect = format.width / format.height;

    Widget picture(bool grey) {
      Widget w = image == null
          ? const ColoredBox(
              color: Cut.canvas,
              child: Center(
                child: Icon(CutIcons.film, size: 36, color: Cut.textDisabled),
              ),
            )
          : RawImage(image: image, fit: BoxFit.cover);
      if (grey) {
        w = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 0.55, 0,
          ]),
          child: w,
        );
      }
      return w;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspect,
        child: AnimatedContainer(
          duration: CutMotion.normal,
          curve: CutMotion.decelerate,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Cut.canvas,
            borderRadius: BorderRadius.circular(CutRadii.md),
            border: Border.all(color: Cut.strokeDefault),
            boxShadow: CutShadows.e2,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fill == null)
                picture(false)
              else ...[
                picture(true),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fill!.clamp(0, 1)),
                  duration: CutMotion.normal,
                  builder: (context, v, child) =>
                      ClipRect(clipper: _LeftClipper(v), child: child),
                  child: picture(false),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fill!.clamp(0, 1)),
                  duration: CutMotion.normal,
                  builder: (context, v, _) => Align(
                    alignment: Alignment(v * 2 - 1, 0),
                    child: Container(
                      width: 2,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Color(0x99FFFFFF), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 8,
                bottom: 8,
                child: Row(
                  children: [
                    _OverlayChip('${format.width}×${format.height}'),
                    const SizedBox(width: 4),
                    _OverlayChip('${format.frameRate.round()} fps'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.fraction != fraction;
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xB3000000),
      borderRadius: BorderRadius.circular(CutRadii.xs),
    ),
    child: Text(
      text,
      style: CutType.timecode.copyWith(
        fontSize: 11,
        height: 1.2,
        color: Colors.white,
      ),
    ),
  );
}

/// A selectable size: the frame's shape drawn to scale, its name and pixels.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    super.key,
    required this.preset,
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final ExportPreset preset;
  final ExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (name, sub) = _presetInfo[preset]!;
    // Bigger outputs get a bigger shape, so the cards compare at a glance.
    final scale = (math.sqrt(format.width * format.height) / 2880).clamp(
      0.45,
      1.0,
    );
    final aspect = format.width / format.height;
    const box = 44.0;
    final w = aspect >= 1 ? box * scale : box * scale * aspect;
    final h = aspect >= 1 ? box * scale / aspect : box * scale;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: CutMotion.fast,
          curve: CutMotion.standard,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? Cut.accentContainer : Cut.surface3,
            borderRadius: BorderRadius.circular(CutRadii.md),
            border: Border.all(
              color: selected ? Cut.accent : Cut.strokeSubtle,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? null : CutShadows.e1,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: box,
                    width: box,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: AnimatedContainer(
                        duration: CutMotion.fast,
                        width: w,
                        height: h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: selected
                                ? Cut.onAccentContainer
                                : Cut.textTertiary,
                            width: 1.5,
                          ),
                          color: selected
                              ? Cut.accent.withValues(alpha: 0.25)
                              : Cut.surface4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CutSpace.s3),
                  Text(
                    name,
                    style: CutType.titleSm.copyWith(
                      color: selected ? Cut.textPrimary : Cut.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: CutType.caption.copyWith(
                      color: selected
                          ? Cut.onAccentContainer
                          : Cut.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${format.width}×${format.height}',
                    style: CutType.timecode.copyWith(
                      fontSize: 11,
                      color: selected
                          ? Cut.onAccentContainer
                          : Cut.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: CutMotion.normal,
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Cut.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CutIcons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of small facts in mono: frame size, rate, codec, file size.
class _Specs extends StatelessWidget {
  const _Specs({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Cut.surface1,
      borderRadius: BorderRadius.circular(CutRadii.md),
      border: Border.all(color: Cut.strokeSubtle),
    ),
    child: Wrap(
      spacing: CutSpace.s5,
      runSpacing: CutSpace.s3,
      children: [
        for (final (label, value) in items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(), style: CutType.overline),
              const SizedBox(height: 3),
              TimecodeText(value, color: Cut.textPrimary),
            ],
          ),
      ],
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.path,
    required this.suggestedName,
    required this.onChange,
  });

  final String? path;
  final String suggestedName;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final chosen = path != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Cut.surface1,
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Cut.surface3,
              borderRadius: BorderRadius.circular(CutRadii.sm),
            ),
            child: const Icon(
              CutIcons.folder,
              size: 17,
              color: Cut.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chosen ? p.basename(path!) : suggestedName,
                  style: CutType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  chosen ? p.dirname(path!) : 'You\'ll pick the folder next',
                  style: CutType.caption.copyWith(color: Cut.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          QuietButton(
            label: chosen ? 'Change' : 'Choose…',
            onPressed: onChange,
            height: 34,
          ),
        ],
      ),
    );
  }
}

/// A success check that draws itself in with a little bounce.
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reduceEffects(context) ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 700),
    builder: (context, t, _) {
      final pop = Curves.elasticOut.transform(math.min(1, t * 1.4));
      final draw = Curves.easeOutCubic.transform(
        ((t - 0.25) / 0.6).clamp(0, 1),
      );
      return Transform.scale(
        scale: 0.6 + 0.4 * pop,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Cut.successContainer,
            shape: BoxShape.circle,
            border: Border.all(color: Cut.success.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Cut.success.withValues(alpha: 0.25 * t),
                blurRadius: 24,
              ),
            ],
          ),
          child: CustomPaint(painter: _CheckPainter(draw)),
        ),
      );
    },
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(size.width * 0.3, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.66);
    final c = Offset(size.width * 0.71, size.height * 0.37);
    final path = Path()..moveTo(a.dx, a.dy);
    final first = (b - a).distance;
    final second = (c - b).distance;
    final len = (first + second) * t;
    if (len <= first) {
      final q = Offset.lerp(a, b, len / first)!;
      path.lineTo(q.dx, q.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final q = Offset.lerp(b, c, (len - first) / second)!;
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Cut.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// Creative Commons tracks ask to be credited: one line each, to paste
/// into the video's description.
class _Credits extends StatelessWidget {
  const _Credits(this.credits);

  final List<String> credits;

  @override
  Widget build(BuildContext context) {
    final text = credits.map((c) => 'Music: $c').join('\n');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Cut.trackMusic.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(color: Cut.trackMusic.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(CutIcons.music, size: 17, color: Cut.trackMusic),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit the music in your description',
                  style: CutType.bodyStrong,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  text,
                  style: CutType.timecode.copyWith(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          CutIconButton(
            key: const Key('copy-credits'),
            tooltip: 'Copy',
            icon: CutIcons.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Credits copied.')));
            },
          ),
        ],
      ),
    );
  }
}
