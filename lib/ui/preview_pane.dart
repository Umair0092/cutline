import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../preview/preview_controller.dart';
import '../titles/title_actions.dart';
import '../titles/title_preview.dart';
import 'import_actions.dart';
import 'time_format.dart';

/// The video preview with play controls, or a drop zone when the project is
/// empty. Videos can be dropped here at any time.
class PreviewPane extends ConsumerStatefulWidget {
  const PreviewPane({super.key});

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends ConsumerState<PreviewPane> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );
    final colors = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        await importVideos(ref, context, [
          for (final f in details.files) f.path,
        ]);
      },
      child: Container(
        color: colors.surfaceContainerLowest,
        foregroundDecoration: _dragging
            ? BoxDecoration(
                border: Border.all(color: colors.primary, width: 3),
                color: colors.primary.withValues(alpha: 0.08),
              )
            : null,
        child: hasClips ? const _Player() : const _EmptyState(),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Drop a video here',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'MP4, MOV or M4V',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => pickAndImportVideos(ref, context),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import Video…'),
          ),
        ],
      ),
    );
  }
}

class _Player extends ConsumerWidget {
  const _Player();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // Titles are drawn on the exact area the video fills (the
              // export frame), not on the black bars around it.
              final f = projectTitleFormat(
                ref.watch(projectEditorProvider.select((s) => s.project)),
              );
              final frame = applyBoxFit(
                BoxFit.contain,
                Size(f.width.toDouble(), f.height.toDouble()),
                box.biggest,
              ).destination;
              final rect = Alignment.center.inscribe(
                frame,
                Offset.zero & box.biggest,
              );
              return Stack(
                children: [
                  Positioned.fill(child: preview.buildVideo()),
                  Positioned.fromRect(rect: rect, child: const TitleLayer()),
                ],
              );
            },
          ),
        ),
        const TransportBar(),
      ],
    );
  }
}

/// Play/pause, current time and a scrubber.
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    final total = ref.watch(
      projectEditorProvider.select((s) => s.project.duration),
    );
    final colors = Theme.of(context).colorScheme;
    final mono = TextStyle(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colors.onSurfaceVariant,
    );

    return Container(
      height: 48,
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: StreamBuilder<Duration>(
        stream: preview.positionStream,
        initialData: preview.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final clamped = position > total ? total : position;
          return Row(
            children: [
              StreamBuilder<bool>(
                stream: preview.playingStream,
                initialData: preview.isPlaying,
                builder: (context, playing) => IconButton(
                  key: const Key('play'),
                  tooltip: playing.data! ? 'Pause (Space)' : 'Play (Space)',
                  icon: Icon(
                    playing.data!
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: preview.togglePlay,
                ),
              ),
              Text(
                '${formatPlayerTime(clamped)} / ${formatPlayerTime(total)}',
                key: const Key('time'),
                style: mono,
              ),
              Expanded(
                child: Slider(
                  value: total.inMilliseconds == 0
                      ? 0
                      : clamped.inMilliseconds / total.inMilliseconds,
                  onChanged: (v) => preview.seek(
                    Duration(milliseconds: (v * total.inMilliseconds).round()),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
