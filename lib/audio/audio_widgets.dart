import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../timeline/timeline_state.dart';
import '../ui/commit_slider.dart';
import '../ui/time_format.dart';
import '../voice/voiceover_dialog.dart';
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

/// Shown under the preview while recording a voiceover: microphone,
/// level, time and the record button.
class RecordBar extends ConsumerWidget {
  const RecordBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(recordingProvider);
    if (!rec.open) return const SizedBox.shrink();
    final controller = ref.read(recordingProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('record-bar'),
      width: double.infinity,
      color: colors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('record-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: rec.recording ? colors.error : null,
                  foregroundColor: rec.recording ? colors.onError : null,
                ),
                onPressed: rec.recording ? controller.stop : controller.start,
                icon: Icon(
                  rec.recording ? Icons.stop_rounded : Icons.mic,
                  size: 18,
                ),
                label: Text(
                  rec.recording
                      ? 'Stop  ${formatPlayerTime(rec.elapsed)}'
                      : 'Record from playhead',
                ),
              ),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: rec.level,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              DropdownButton<String?>(
                key: const Key('mic-picker'),
                value: rec.mic?.id,
                isDense: true,
                underline: const SizedBox.shrink(),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: rec.hearVideo,
                    onChanged: rec.recording
                        ? null
                        : (v) => controller.setHearVideo(v ?? false),
                  ),
                  const Tooltip(
                    message:
                        'Use headphones, or the video\'s sound ends up in '
                        'the recording.',
                    child: Text('Hear the video'),
                  ),
                ],
              ),
              IconButton(
                tooltip: rec.recording ? 'Throw this take away' : 'Close',
                icon: const Icon(Icons.close, size: 18),
                onPressed: rec.recording ? controller.cancel : controller.hide,
              ),
            ],
          ),
          if (rec.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(rec.error!, style: TextStyle(color: colors.error)),
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
    final speech = project.mediaById(a.mediaId)?.speech;
    final colors = Theme.of(context).colorScheme;
    final maxFade = a.duration.inMilliseconds / 2000;
    return Container(
      key: const Key('audio-inspector'),
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
              Icon(Icons.graphic_eq, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  speech != null
                      ? '"${speech.text}"'
                      : '${a.role.name[0].toUpperCase()}'
                            '${a.role.name.substring(1)} · '
                            '${formatPlayerTime(a.duration)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (speech != null)
            TextButton.icon(
              key: const Key('edit-voice-line'),
              onPressed: () => showEditLineDialog(context, a.id),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit line'),
            ),
          CommitSlider(
            key: Key('audio-volume-${a.id}'),
            icon: Icons.volume_up,
            tooltip: 'Volume',
            value: a.volume,
            min: 0,
            max: 2,
            onCommit: (v) => _run(context, ref, UpdateAudio(a.id, volume: v)),
          ),
          CommitSlider(
            key: Key('audio-fade-in-${a.id}'),
            icon: Icons.trending_up,
            tooltip: 'Fade in',
            value: a.fadeIn.inMilliseconds / 1000,
            min: 0,
            max: maxFade.clamp(0.1, 5).toDouble(),
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
            icon: Icons.trending_down,
            tooltip: 'Fade out',
            value: a.fadeOut.inMilliseconds / 1000,
            min: 0,
            max: maxFade.clamp(0.1, 5).toDouble(),
            onCommit: (v) => _run(
              context,
              ref,
              UpdateAudio(
                a.id,
                fadeOut: Duration(milliseconds: (v * 1000).round()),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {
              _run(context, ref, RemoveAudio(a.id));
              ref.read(timelineUiProvider.notifier).selectAudio(null);
            },
          ),
        ],
      ),
    );
  }
}

/// The audio mix: the video's own sound, the voiceover track, and ducking.
class AudioMixButton extends ConsumerWidget {
  const AudioMixButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(projectEditorProvider.select((s) => s.project.mix));
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio mix',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Video sound')),
                    IconButton(
                      key: const Key('mute-original'),
                      tooltip: mix.original == 0 ? 'Unmute' : 'Mute',
                      icon: Icon(
                        mix.original == 0 ? Icons.volume_off : Icons.volume_up,
                        size: 18,
                      ),
                      onPressed: () => _run(
                        context,
                        ref,
                        SetAudioMix(
                          mix.copyWith(original: mix.original == 0 ? 1 : 0),
                        ),
                      ),
                    ),
                  ],
                ),
                CommitSlider(
                  key: const Key('mix-original'),
                  icon: Icons.movie_outlined,
                  tooltip: 'Video sound',
                  value: mix.original,
                  min: 0,
                  max: 2,
                  width: 200,
                  onCommit: (v) => _run(
                    context,
                    ref,
                    SetAudioMix(mix.copyWith(original: v)),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Voiceover'),
                CommitSlider(
                  key: const Key('mix-voiceover'),
                  icon: Icons.mic_none,
                  tooltip: 'Voiceover',
                  value: mix.voiceover,
                  min: 0,
                  max: 2,
                  width: 200,
                  onCommit: (v) => _run(
                    context,
                    ref,
                    SetAudioMix(mix.copyWith(voiceover: v)),
                  ),
                ),
                SwitchListTile(
                  key: const Key('mix-duck'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Lower the video while I talk'),
                  subtitle: const Text('In the export'),
                  value: mix.duck,
                  onChanged: (v) =>
                      _run(context, ref, SetAudioMix(mix.copyWith(duck: v))),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        key: const Key('audio-mix'),
        tooltip: 'Audio mix',
        icon: Icon(
          mix.original == 0 ? Icons.volume_off_outlined : Icons.tune,
          size: 18,
        ),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
