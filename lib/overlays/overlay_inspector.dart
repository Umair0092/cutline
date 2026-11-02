import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/overlay_item.dart';
import '../timeline/timeline_state.dart';

/// Settings for the selected overlay, shown under the preview.
class OverlayInspector extends ConsumerWidget {
  const OverlayInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(timelineUiProvider.select((s) => s.selectedOverlayId));
    final project = ref.watch(projectEditorProvider.select((s) => s.project));
    final o = project.overlays.where((o) => o.id == id).firstOrNull;
    if (o == null) return const SizedBox.shrink();
    final media = project.mediaById(o.mediaId);
    final colors = Theme.of(context).colorScheme;

    void run(EditCommand command) {
      try {
        ref.read(projectEditorProvider.notifier).run(command);
      } on EditException catch (e) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    return Container(
      key: const Key('overlay-inspector'),
      width: double.infinity,
      color: colors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  media == null ? 'Overlay' : p.basename(media.path),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          DropdownButton<OverlayAnimation>(
            key: const Key('overlay-animation'),
            value: o.animation,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final a in OverlayAnimation.values)
                DropdownMenuItem(value: a, child: Text(_animationLabel(a))),
            ],
            onChanged: (a) => a == null || a == o.animation
                ? null
                : run(UpdateOverlay(o.id, animation: a)),
          ),
          _CommitSlider(
            key: Key('overlay-opacity-${o.id}'),
            icon: Icons.opacity,
            tooltip: 'Opacity',
            value: o.transform.opacity,
            min: 0.05,
            max: 1,
            onCommit: (v) => run(
              UpdateOverlay(o.id, transform: o.transform.copyWith(opacity: v)),
            ),
          ),
          _CommitSlider(
            key: Key('overlay-rotation-${o.id}'),
            icon: Icons.rotate_right,
            tooltip: 'Rotation',
            value: o.transform.rotation,
            min: -180,
            max: 180,
            onCommit: (v) => run(
              UpdateOverlay(
                o.id,
                // Snap to straight when close.
                transform: o.transform.copyWith(rotation: v.abs() < 3 ? 0 : v),
              ),
            ),
          ),
          if (media?.hasAudio ?? false)
            _CommitSlider(
              key: Key('overlay-volume-${o.id}'),
              icon: o.volume == 0 ? Icons.volume_off : Icons.volume_up,
              tooltip: 'Sound',
              value: o.volume,
              min: 0,
              max: 2,
              onCommit: (v) => run(UpdateOverlay(o.id, volume: v)),
            ),
          IconButton(
            tooltip: 'Delete overlay',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {
              run(RemoveOverlay(o.id));
              ref.read(timelineUiProvider.notifier).selectOverlay(null);
            },
          ),
        ],
      ),
    );
  }
}

String _animationLabel(OverlayAnimation a) => switch (a) {
  OverlayAnimation.none => 'No animation',
  OverlayAnimation.pop => 'Pop in',
  OverlayAnimation.fade => 'Fade in',
  OverlayAnimation.slide => 'Slide up',
};

/// A slider that shows changes live but only commits (one undo step) when
/// you let go.
class _CommitSlider extends StatefulWidget {
  const _CommitSlider({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
  });

  final IconData icon;
  final String tooltip;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onCommit;

  @override
  State<_CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<_CommitSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 16),
          SizedBox(
            width: 110,
            child: Slider(
              value: (_dragging ?? widget.value).clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                if (v != widget.value) widget.onCommit(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
