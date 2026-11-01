import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/project_editor.dart';
import '../preview/preview_controller.dart';
import '../transcript/timeline_transcript.dart';
import '../transcript/transcript.dart';
import '../transcript/transcription_service.dart';
import 'time_format.dart';

/// Starts transcribing new videos in the background when the speech model
/// is already downloaded.
class AutoTranscribe extends ConsumerStatefulWidget {
  const AutoTranscribe({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoTranscribe> createState() => _AutoTranscribeState();
}

class _AutoTranscribeState extends ConsumerState<AutoTranscribe> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      // Joined so the listener only fires when the set of files changes.
      projectEditorProvider.select((s) => spokenMediaPaths(s).join('\n')),
      (_, joined) => unawaited(
        ref
            .read(transcriptsProvider.notifier)
            .ensure(joined.isEmpty ? const [] : joined.split('\n')),
      ),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TranscriptPanel extends ConsumerWidget {
  const TranscriptPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(projectEditorProvider.select(spokenMediaPaths));
    final statuses = ref.watch(transcriptsProvider);
    final lines = ref.watch(timelineTranscriptProvider);
    final colors = Theme.of(context).colorScheme;

    if (paths.isEmpty) {
      return _Message(
        text: 'Import a video with sound to see what\'s said in it.',
        color: colors.onSurfaceVariant,
      );
    }

    final pending = [
      for (final path in paths)
        if (statuses[path]?.phase != TranscriptPhase.done)
          (path, statuses[path]),
    ];
    final waitingForModel = pending.any(
      (e) => e.$2?.phase == TranscriptPhase.waiting && e.$2?.progress == null,
    );

    return Column(
      children: [
        if (waitingForModel)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text(
                  'Transcripts are made on this computer; nothing is '
                  'uploaded. The speech model (148 MB) downloads once.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: const Key('transcribe'),
                  onPressed: () => ref
                      .read(transcriptsProvider.notifier)
                      .ensure(paths, allowDownload: true),
                  child: const Text('Download Model & Transcribe'),
                ),
              ],
            ),
          ),
        for (final (path, status) in pending)
          if (status != null && status.progress != null ||
              status?.phase == TranscriptPhase.failed)
            _Progress(name: p.basename(path), status: status!),
        Expanded(
          child: lines.isEmpty
              ? (pending.isEmpty
                    ? _Message(
                        text: 'No speech found.',
                        color: colors.onSurfaceVariant,
                      )
                    : const SizedBox())
              : _Lines(lines: lines),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.name, required this.status});

  final String name;
  final TranscriptStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (status.phase) {
      TranscriptPhase.downloadingModel =>
        'Downloading speech model… ${((status.progress ?? 0) * 100).round()}%',
      TranscriptPhase.transcribing =>
        'Transcribing $name… ${((status.progress ?? 0) * 100).round()}%',
      TranscriptPhase.failed => '$name: ${status.error}',
      _ => 'Waiting: $name',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: status.phase == TranscriptPhase.failed
                  ? colors.error
                  : colors.onSurfaceVariant,
            ),
          ),
          if (status.phase != TranscriptPhase.failed) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: status.progress),
          ],
        ],
      ),
    );
  }
}

/// The lines, with the one under the playhead highlighted. Clicking a line
/// moves the playhead there.
class _Lines extends ConsumerWidget {
  const _Lines({required this.lines});

  final List<TranscriptLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: preview.positionStream,
      initialData: preview.position,
      builder: (context, snapshot) {
        final t = snapshot.data ?? Duration.zero;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final line = lines[i];
            final current = t >= line.start && t < line.end;
            return InkWell(
              key: Key('line-$i'),
              onTap: () => preview.seek(line.start),
              child: Container(
                color: current
                    ? colors.primaryContainer.withValues(alpha: 0.5)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        formatPlayerTime(line.start),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(child: Text(line.text)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color),
      ),
    ),
  );
}
