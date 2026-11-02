import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/project.dart';
import '../model/voice_effect.dart';
import '../timeline/timeline_state.dart';
import '../ui/commit_slider.dart';
import '../ui/editor/inspector_card.dart';
import '../ui/time_format.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';

/// Preset, pitch, speed and cleanup for one clip's sound. Each change is
/// one undo step. Returns its controls as separate widgets so they flow
/// with the rest of an inspector.
class VoiceEffectControls extends StatelessWidget {
  const VoiceEffectControls({
    super.key,
    required this.effect,
    required this.onChanged,
    this.allowSpeed = false,
  });

  final VoiceEffect effect;
  final ValueChanged<VoiceEffect> onChanged;
  final bool allowSpeed;

  @override
  Widget build(BuildContext context) {
    final preset = VoicePreset.values
        .where((p) => p.effect == effect)
        .firstOrNull;
    return Wrap(
      spacing: CutSpace.s5,
      runSpacing: CutSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InspectorDropdown<String>(
          buttonKey: const Key('voice-preset'),
          icon: CutIcons.voiceEffect,
          value: effect.isNone ? 'none' : preset?.name ?? 'custom',
          items: [
            const DropdownMenuItem(value: 'none', child: Text('Normal voice')),
            for (final p in VoicePreset.values)
              DropdownMenuItem(value: p.name, child: Text(p.label)),
            if (!effect.isNone && preset == null)
              const DropdownMenuItem(value: 'custom', child: Text('Custom')),
          ],
          onChanged: (v) {
            if (v == null || v == 'custom') return;
            onChanged(
              v == 'none'
                  ? VoiceEffect.none.copyWith(speed: effect.speed)
                  : VoicePreset.values
                        .byName(v)
                        .effect
                        .copyWith(speed: effect.speed),
            );
          },
        ),
        CommitSlider(
          key: const Key('voice-pitch'),
          icon: CutIcons.pitch,
          tooltip:
              'Pitch: ${effect.pitch > 0 ? '+' : ''}'
              '${effect.pitch.toStringAsFixed(0)} semitones',
          value: effect.pitch,
          min: -12,
          max: 12,
          divisions: 24,
          format: (v) => '${v > 0 ? '+' : ''}${v.round()} st',
          onCommit: (v) => onChanged(effect.copyWith(pitch: v.roundToDouble())),
        ),
        if (allowSpeed)
          CommitSlider(
            key: const Key('voice-speed'),
            icon: CutIcons.speed,
            tooltip: 'Speed ${effect.speed.toStringAsFixed(2)}×',
            value: effect.speed,
            min: 0.5,
            max: 2,
            divisions: 30,
            format: (v) => '${v.toStringAsFixed(2)}×',
            onCommit: (v) => onChanged(effect.copyWith(speed: v)),
          ),
        InspectorToggle(
          label: 'Clean up noise',
          selected: effect.denoise,
          onChanged: (v) => onChanged(effect.copyWith(denoise: v)),
        ),
        InspectorToggle(
          label: 'Even loudness',
          selected: effect.normalize,
          onChanged: (v) => onChanged(effect.copyWith(normalize: v)),
        ),
      ],
    );
  }
}

/// Settings for the selected main-track clip: volume and voice effect.
class ClipInspector extends ConsumerWidget {
  const ClipInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(timelineUiProvider.select((s) => s.selectedClipId));
    final project = ref.watch(projectEditorProvider.select((s) => s.project));
    final clip = project.clips.where((c) => c.id == id).firstOrNull;
    final media = clip == null ? null : project.mediaById(clip.mediaId);
    if (clip == null || !(media?.hasAudio ?? false)) {
      return const SizedBox.shrink();
    }

    void run(EditCommand command) {
      try {
        ref.read(projectEditorProvider.notifier).run(command);
      } on EditException catch (e) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    final everyClip = project.clips.length > 1;
    final index = project.clipIndex(clip.id);
    return InspectorCard(
      key: const Key('clip-inspector'),
      icon: CutIcons.video,
      color: Cut.trackVideo,
      title: everyClip
          ? 'Clip ${index + 1} of ${project.clips.length}'
          : 'Clip',
      meta: formatPlayerTime(clip.duration),
      children: [
        CommitSlider(
          key: Key('clip-volume-${clip.id}'),
          icon: clip.volume == 0 ? CutIcons.mute : CutIcons.volume,
          tooltip: 'Volume',
          value: clip.volume,
          min: 0,
          max: 2,
          format: (v) => '${(v * 100).round()}%',
          onCommit: (v) => run(SetClipVolume(clip.id, v)),
        ),
        VoiceEffectControls(
          effect: clip.effect,
          // With several clips, effects go on all of them: it's usually
          // the same voice throughout. One clip can still differ.
          onChanged: (e) => run(
            SetClipEffect(
              e,
              clipIds: everyClip && _sameEverywhere(project, clip.effect)
                  ? null
                  : [clip.id],
            ),
          ),
        ),
        if (everyClip && !_sameEverywhere(project, clip.effect))
          TextButton(
            key: const Key('effect-all-clips'),
            onPressed: () => run(SetClipEffect(clip.effect)),
            child: const Text('Use on every clip'),
          ),
      ],
    );
  }

  static bool _sameEverywhere(Project project, VoiceEffect effect) =>
      project.clips.every((c) => c.effect == effect);
}
