import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/speech_spec.dart';
import '../preview/preview_controller.dart';
import '../timeline/timeline_state.dart';
import '../ui/time_format.dart';
import 'tts.dart';
import 'voiceover_actions.dart';

/// Write a script and turn it into voiceover lines at the playhead.
Future<void> showVoiceoverDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const VoiceoverDialog());

/// Change one generated line's words, voice or speed and make it again.
Future<void> showEditLineDialog(BuildContext context, String audioId) =>
    showDialog<void>(
      context: context,
      builder: (_) => VoiceoverDialog(audioId: audioId),
    );

class VoiceoverDialog extends ConsumerStatefulWidget {
  const VoiceoverDialog({super.key, this.audioId});

  /// Editing this line instead of writing a new script.
  final String? audioId;

  @override
  ConsumerState<VoiceoverDialog> createState() => _VoiceoverDialogState();
}

class _VoiceoverDialogState extends ConsumerState<VoiceoverDialog> {
  final _script = TextEditingController();
  VoiceEngine _engine = VoiceEngine.system;
  String _voice = '';
  double _speed = 1;
  List<String> _voices = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectEditorProvider).project;
    final item = project.audio.where((a) => a.id == widget.audioId).firstOrNull;
    final spec = item == null ? null : project.mediaById(item.mediaId)?.speech;
    if (spec != null) {
      _script.text = spec.text;
      _engine = spec.engine;
      _voice = spec.voice;
      _speed = spec.speed;
    }
    _loadVoices();
  }

  @override
  void dispose() {
    _script.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    try {
      final speaker = await ref.read(speakerFactoryProvider)(_engine);
      final voices = await speaker.voices();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        if (!voices.contains(_voice)) _voice = voices.firstOrNull ?? '';
        _error = null;
      });
    } on SpeechException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _generate() async {
    final state = ref.read(projectEditorProvider);
    final work = state.workPath;
    if (work == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final speaker = await ref.read(speakerFactoryProvider)(_engine);
      final editor = ref.read(projectEditorProvider.notifier);
      if (widget.audioId != null) {
        final command = await regenerateLine(
          project: state.project,
          workPath: work,
          speaker: speaker,
          audioId: widget.audioId!,
          spec: SpeechSpec(
            text: _script.text.trim(),
            engine: _engine,
            voice: _voice,
            speed: _speed,
          ),
        );
        editor.run(command);
      } else {
        final lines = [
          for (final l in _script.text.split('\n'))
            if (l.trim().isNotEmpty) (text: l.trim(), start: null),
        ];
        final commands = await voiceoverCommands(
          project: state.project,
          workPath: work,
          speaker: speaker,
          lines: lines,
          engine: _engine,
          voice: _voice,
          speed: _speed,
          from: ref.read(previewProvider).position,
        );
        editor.runAll('AI voiceover', commands);
        final last = commands.whereType<AddAudio>().lastOrNull;
        if (last != null) {
          ref.read(timelineUiProvider.notifier).selectAudio(last.item.id);
        }
      }
      if (mounted) Navigator.pop(context);
    } on SpeechException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on EditException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.audioId != null;
    final theme = Theme.of(context);
    final at = ref.read(previewProvider).position;
    return AlertDialog(
      scrollable: true,
      title: Text(editing ? 'Edit voiceover line' : 'AI voiceover'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!editing)
              Text(
                'Each line becomes its own clip on the voiceover track, '
                'starting at ${formatPlayerTime(at)}, so you can re-make one '
                'line later without redoing the rest. You can also ask the '
                'assistant to write the script from what you say in the '
                'video.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('voiceover-script'),
              controller: _script,
              minLines: editing ? 2 : 5,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: editing
                    ? null
                    : 'Here is the setup screen.\n'
                          'Pick a plan, then press Continue.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Voice', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<VoiceEngine>(
              key: const Key('voice-engine'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: VoiceEngine.system,
                  label: Text('System (offline)'),
                ),
                ButtonSegment(
                  value: VoiceEngine.groq,
                  label: Text('Groq (natural)'),
                ),
              ],
              selected: {_engine},
              onSelectionChanged: _busy
                  ? null
                  : (s) {
                      setState(() {
                        _engine = s.first;
                        _voices = const [];
                        _voice = '';
                      });
                      _loadVoices();
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('voice-name'),
                    initialValue: _voices.contains(_voice) ? _voice : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Voice',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final v in _voices)
                        DropdownMenuItem(
                          value: v,
                          child: Text('${v[0].toUpperCase()}${v.substring(1)}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _voice = v ?? ''),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Speed ${_speed.toStringAsFixed(2)}×'),
                SizedBox(
                  width: 140,
                  child: Slider(
                    value: _speed,
                    min: 0.75,
                    max: 1.5,
                    divisions: 15,
                    onChanged: _busy ? null : (v) => setState(() => _speed = v),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SelectableText(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('voiceover-generate'),
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.record_voice_over_outlined, size: 18),
          label: Text(
            _busy
                ? 'Making the voice…'
                : (editing ? 'Re-make line' : 'Make voiceover'),
          ),
        ),
      ],
    );
  }
}
