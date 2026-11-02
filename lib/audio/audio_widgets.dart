import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music/music_panel.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/audio_item.dart';
import '../timeline/timeline_state.dart';
import '../ui/commit_slider.dart';
import '../ui/editor/inspector_card.dart';
import '../ui/editor/timecode.dart';
import '../ui/editor/tool_button.dart';
import '../ui/time_format.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
import '../voice/voiceover_dialog.dart';
import 'effect_controls.dart';
import 'recording.dart';

void _run(BuildContext context, WidgetRef ref, EditCommand command) {
  try {
    ref.read(projectEditorProvider.notifier).run(command);
  } on EditException catch (e) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Shown under the preview while recording a voiceover: the record button,
/// a live level meter, the time, the microphone and whether to hear the
/// video.
class RecordBar extends ConsumerWidget {
  const RecordBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(recordingProvider);
    if (!rec.open) return const SizedBox.shrink();
    final controller = ref.read(recordingProvider.notifier);
    return InspectorCard(
      key: const Key('record-bar'),
      icon: CutIcons.mic,
      color: Cut.marker,
      title: rec.recording ? 'Recording…' : 'Voiceover',
      meta: rec.recording
          ? formatTimecode(rec.elapsed)
          : 'Starts at the playhead',
      trailing: [
        EditorToolButton(
          tooltip: rec.recording ? 'Throw this take away' : 'Close',
          icon: const Icon(CutIcons.close),
          onPressed: rec.recording ? controller.cancel : controller.hide,
        ),
      ],
      footer: rec.error == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6, left: 38),
              child: Text(
                rec.error!,
                style: CutType.caption.copyWith(color: Cut.error),
              ),
            ),
      children: [
        _RecordButton(
          recording: rec.recording,
          elapsed: rec.elapsed,
          onPressed: rec.recording ? controller.stop : controller.start,
        ),
        _LevelMeter(level: rec.level),
        InspectorDropdown<String?>(
          buttonKey: const Key('mic-picker'),
          icon: CutIcons.mic,
          value: rec.mic?.id,
          hint: const Text('Default microphone'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Default microphone'),
            ),
            for (final m in rec.mics)
              DropdownMenuItem(
                value: m.id,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(m.label, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
          onChanged: rec.recording
              ? null
              : (id) => controller.pickMic(
                  rec.mics.where((m) => m.id == id).firstOrNull,
                ),
        ),
        Tooltip(
          message:
              'Use headphones, or the video\'s sound ends up in the '
              'recording.',
          child: InspectorToggle(
            label: 'Hear the video',
            selected: rec.hearVideo,
            onChanged: rec.recording ? null : controller.setHearVideo,
          ),
        ),
      ],
    );
  }
}

/// The big round record button: a pink dot that becomes a stop square
/// with the take's length while recording.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.elapsed,
    required this.onPressed,
  });

  final bool recording;
  final Duration elapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('record-button'),
    onTap: onPressed,
    semanticLabel: recording ? 'Stop recording' : 'Record from playhead',
    child: AnimatedContainer(
      duration: CutMotion.normal,
      curve: CutMotion.standard,
      height: isTouchPlatform ? 40 : 32,
      padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
      decoration: BoxDecoration(
        color: recording ? Cut.marker : Cut.surface3,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(
          color: recording ? Cut.marker : Cut.marker.withValues(alpha: 0.5),
        ),
        boxShadow: recording
            ? [
                BoxShadow(
                  color: Cut.marker.withValues(alpha: 0.4),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: recording ? Colors.white : Cut.marker,
              shape: BoxShape.circle,
            ),
            child: recording
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Cut.marker,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          recording
              ? TimecodeText(
                  'Stop  ${formatPlayerTime(elapsed)}',
                  color: Colors.white,
                )
              : Text(
                  'Record from playhead',
                  style: CutType.label.copyWith(fontWeight: FontWeight.w600),
                ),
        ],
      ),
    ),
  );
}

/// A segmented level meter: green, then amber, then red near the top.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level});

  final double level;

  static const _segments = 14;

  @override
  Widget build(BuildContext context) {
    final lit = (level.clamp(0.0, 1.0) * _segments).round();
    return Tooltip(
      message: 'Microphone level',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _segments; i++)
            AnimatedContainer(
              duration: CutMotion.instant,
              width: 4,
              height: 14,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                color: i < lit
                    ? (i >= _segments - 2
                          ? Cut.error
                          : i >= _segments - 5
                          ? Cut.warning
                          : Cut.success)
                    : Cut.surface4,
              ),
            ),
        ],
      ),
    );
  }
}

/// Settings for the selected voiceover or sound on the audio track.
class AudioInspector extends ConsumerWidget {
  const AudioInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(timelineUiProvider.select((s) => s.selectedAudioId));
    final project = ref.watch(projectEditorProvider.select((s) => s.project));
    final a = project.audio.where((a) => a.id == id).firstOrNull;
    if (a == null) return const SizedBox.shrink();
    final media = project.mediaById(a.mediaId);
    final speech = media?.speech;
    final music = a.role == AudioRole.music;
    final role = '${a.role.name[0].toUpperCase()}${a.role.name.substring(1)}';
    final maxFade = a.duration.inMilliseconds / 2000;
    String seconds(double v) => '${v.toStringAsFixed(1)} s';
    return InspectorCard(
      key: const Key('audio-inspector'),
      icon: music ? CutIcons.music : CutIcons.mic,
      color: music ? Cut.trackMusic : Cut.trackVoice,
      title: speech != null ? '"${speech.text}"' : media?.name ?? role,
      meta: '$role · ${formatPlayerTime(a.duration)}',
      trailing: [
        EditorToolButton(
          tooltip: 'Delete',
          keys: const ['⌫'],
          icon: const Icon(CutIcons.trash),
          onPressed: () {
            _run(context, ref, RemoveAudio(a.id));
            ref.read(timelineUiProvider.notifier).selectAudio(null);
          },
        ),
      ],
      children: [
        if (speech != null)
          TextButton.icon(
            key: const Key('edit-voice-line'),
            onPressed: () => showEditLineDialog(context, a.id),
            icon: const Icon(CutIcons.rename, size: 15),
            label: const Text('Edit line'),
          ),
        CommitSlider(
          key: Key('audio-volume-${a.id}'),
          icon: a.volume == 0 ? CutIcons.mute : CutIcons.volume,
          tooltip: 'Volume',
          value: a.volume,
          min: 0,
          max: 2,
          format: (v) => '${(v * 100).round()}%',
          onCommit: (v) => _run(context, ref, UpdateAudio(a.id, volume: v)),
        ),
        CommitSlider(
          key: Key('audio-fade-in-${a.id}'),
          icon: CutIcons.fadeIn,
          tooltip: 'Fade in',
          value: a.fadeIn.inMilliseconds / 1000,
          min: 0,
          max: maxFade.clamp(0.1, 5).toDouble(),
          format: seconds,
          onCommit: (v) => _run(
            context,
            ref,
            UpdateAudio(
              a.id,
              fadeIn: Duration(milliseconds: (v * 1000).round()),
            ),
          ),
        ),
        CommitSlider(
          key: Key('audio-fade-out-${a.id}'),
          icon: CutIcons.fadeOut,
          tooltip: 'Fade out',
          value: a.fadeOut.inMilliseconds / 1000,
          min: 0,
          max: maxFade.clamp(0.1, 5).toDouble(),
          format: seconds,
          onCommit: (v) => _run(
            context,
            ref,
            UpdateAudio(
              a.id,
              fadeOut: Duration(milliseconds: (v * 1000).round()),
            ),
          ),
        ),
        VoiceEffectControls(
          effect: a.effect,
          allowSpeed: true,
          onChanged: (e) => _run(context, ref, UpdateAudio(a.id, effect: e)),
        ),
      ],
    );
  }
}

/// The audio mix: track levels, ducking, and adding music, in a popover
/// off the timeline toolbar.
class AudioMixButton extends ConsumerWidget {
  const AudioMixButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(projectEditorProvider.select((s) => s.project.mix));
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Cut.surface3),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CutRadii.lg),
            side: const BorderSide(color: Cut.strokeDefault),
          ),
        ),
      ),
      menuChildren: [
        Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CutRadii.lg),
            boxShadow: CutShadows.e3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(CutIcons.levels, size: 16, color: Cut.accent),
                  const SizedBox(width: 8),
                  Text('Sound levels', style: CutType.titleSm),
                  const Spacer(),
                  Text('MIX', style: CutType.overline),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'How loud each kind of sound plays in the export.',
                style: CutType.caption.copyWith(color: Cut.textTertiary),
              ),
              const SizedBox(height: CutSpace.s2),
              const MixControls(),
              const SizedBox(height: CutSpace.s3),
              const Divider(height: 1),
              const SizedBox(height: CutSpace.s3),
              FilledButton.tonalIcon(
                key: const Key('mix-add-music'),
                style: FilledButton.styleFrom(
                  backgroundColor: Cut.surface4,
                  foregroundColor: Cut.textPrimary,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => showMusicBrowser(context),
                icon: const Icon(CutIcons.musicLibrary, size: 16),
                label: const Text('Add music or a sound…'),
              ),
            ],
          ),
        ),
      ],
      builder: (context, menu, _) => EditorToolButton(
        key: const Key('audio-mix'),
        tooltip: 'Sound levels and music',
        selected: menu.isOpen,
        icon: Icon(mix.original == 0 ? CutIcons.mute : CutIcons.levels),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
