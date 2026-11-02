import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../export/export_settings.dart';
import '../export/exporter.dart';
import '../model/project.dart';
import '../media/ffmpeg.dart';

/// File > Export…: pick a size, pick where to save, then show progress.
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

  final preset = await showDialog<ExportPreset>(
    context: context,
    builder: (context) => _PresetDialog(project: state.project),
  );
  if (preset == null || !context.mounted) return;

  final location = await getSaveLocation(
    suggestedName: '${state.project.name}.mp4',
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'MP4 video',
        extensions: ['mp4'],
        uniformTypeIdentifiers: ['public.mpeg-4'],
      ),
    ],
  );
  if (location == null || !context.mounted) return;
  var path = location.path;
  if (!path.toLowerCase().endsWith('.mp4')) path += '.mp4';

  final ExportJob job;
  try {
    job = await Exporter(ffmpeg).start(
      project: state.project,
      projectPath: state.workPath,
      preset: preset,
      outputPath: path,
    );
  } on ExportException catch (e) {
    if (context.mounted) _snack(context, e.message);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ExportProgressDialog(job: job),
  );
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _PresetDialog extends StatefulWidget {
  const _PresetDialog({required this.project});

  final Project project;

  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  ExportPreset _preset = ExportPreset.hd1080;

  /// Credits for music and sounds that are still in the edit.
  late final List<String> _credits = {
    for (final a in widget.project.audio)
      ?widget.project.mediaById(a.mediaId)?.credit,
  }.toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export video'),
      content: RadioGroup<ExportPreset>(
        groupValue: _preset,
        onChanged: (p) => setState(() => _preset = p!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in ExportPreset.values)
              RadioListTile<ExportPreset>(
                value: p,
                title: Text(p.label),
                subtitle: Text(_describe(p)),
              ),
            if (_credits.isNotEmpty) _Credits(_credits),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('export-next'),
          onPressed: () => Navigator.pop(context, _preset),
          child: const Text('Export…'),
        ),
      ],
    );
  }

  String _describe(ExportPreset p) {
    final f = ExportFormat.forProject(widget.project, p);
    return '${f.width}×${f.height}, ${f.frameRate.round()} fps, MP4';
  }
}

/// Progress bar with Cancel, then "Show in Finder" when done.
class ExportProgressDialog extends StatefulWidget {
  const ExportProgressDialog({super.key, required this.job});

  final ExportJob job;

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  double _progress = 0;
  bool _finished = false;
  String? _error;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.job.progress.listen((p) => setState(() => _progress = p));
    widget.job.done.then(
      (ok) {
        if (!mounted) return;
        if (!ok) return Navigator.pop(context);
        setState(() => _finished = true);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = e is ExportException ? e.message : '$e');
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _reveal() async {
    final path = widget.job.outputPath;
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _error != null
        ? 'Export failed'
        : _finished
        ? 'Export finished'
        : 'Exporting…';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: _error != null
            ? Text(_error!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    key: const Key('export-progress'),
                    value: _finished ? 1 : _progress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _finished
                        ? widget.job.outputPath
                        : '${(_progress * 100).round()}%',
                  ),
                ],
              ),
      ),
      actions: [
        if (!_finished && _error == null)
          TextButton(onPressed: widget.job.cancel, child: const Text('Cancel')),
        if (_finished)
          TextButton(
            onPressed: _reveal,
            child: Text(Platform.isMacOS ? 'Show in Finder' : 'Show in Folder'),
          ),
        if (_finished || _error != null)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
      ],
    );
  }
}

/// Creative Commons tracks ask to be credited: one line each, to paste
/// into the video's description.
class _Credits extends StatelessWidget {
  const _Credits(this.credits);

  final List<String> credits;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = credits.map((c) => 'Music: $c').join('\n');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit the music in your description',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  text,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('copy-credits'),
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18),
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
