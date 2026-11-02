import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/overlay_item.dart';
import '../timeline/timeline_state.dart';
import '../ui/commit_slider.dart';
import '../ui/editor/inspector_card.dart';
import '../ui/editor/tool_button.dart';
import '../ui/time_format.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';

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

    void run(EditCommand command) {
      try {
        ref.read(projectEditorProvider.notifier).run(command);
      } on EditException catch (e) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    String percent(double v) => '${(v * 100).round()}%';
    return InspectorCard(
      key: const Key('overlay-inspector'),
      icon: CutIcons.layers,
      color: Cut.trackOverlay,
      title: media == null ? 'Overlay' : p.basename(media.path),
      meta: 'Overlay · ${formatPlayerTime(o.duration)}',
      trailing: [
        EditorToolButton(
          tooltip: 'Delete overlay',
          keys: const ['⌫'],
          icon: const Icon(CutIcons.trash),
          onPressed: () {
            run(RemoveOverlay(o.id));
            ref.read(timelineUiProvider.notifier).selectOverlay(null);
          },
        ),
      ],
      children: [
        InspectorDropdown<OverlayAnimation>(
          buttonKey: const Key('overlay-animation'),
          icon: CutIcons.animation,
          value: o.animation,
          items: [
            for (final a in OverlayAnimation.values)
              DropdownMenuItem(value: a, child: Text(_animationLabel(a))),
          ],
          onChanged: (a) => a == null || a == o.animation
              ? null
              : run(UpdateOverlay(o.id, animation: a)),
        ),
        CommitSlider(
          key: Key('overlay-opacity-${o.id}'),
          icon: CutIcons.opacity,
          tooltip: 'Opacity',
          value: o.transform.opacity,
          min: 0.05,
          max: 1,
          format: percent,
          onCommit: (v) => run(
            UpdateOverlay(o.id, transform: o.transform.copyWith(opacity: v)),
          ),
        ),
        CommitSlider(
          key: Key('overlay-rotation-${o.id}'),
          icon: CutIcons.rotate,
          tooltip: 'Rotation',
          value: o.transform.rotation,
          min: -180,
          max: 180,
          format: (v) => '${v.round()}°',
          onCommit: (v) => run(
            UpdateOverlay(
              o.id,
              // Snap to straight when close.
              transform: o.transform.copyWith(rotation: v.abs() < 3 ? 0 : v),
            ),
          ),
        ),
        if (media?.hasAudio ?? false)
          CommitSlider(
            key: Key('overlay-volume-${o.id}'),
            icon: o.volume == 0 ? CutIcons.mute : CutIcons.volume,
            tooltip: 'Sound',
            value: o.volume,
            min: 0,
            max: 2,
            format: percent,
            onCommit: (v) => run(UpdateOverlay(o.id, volume: v)),
          ),
      ],
    );
  }
}

String _animationLabel(OverlayAnimation a) => switch (a) {
  OverlayAnimation.none => 'No animation',
  OverlayAnimation.pop => 'Pop in',
  OverlayAnimation.fade => 'Fade in',
  OverlayAnimation.slide => 'Slide up',
};
