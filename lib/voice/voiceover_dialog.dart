import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/api_key_store.dart';
import '../ai/chat_controller.dart';
import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/speech_spec.dart';
import '../music/track_player.dart';
import '../preview/preview_controller.dart';
import '../timeline/timeline_state.dart';
import '../ui/dialogs/dialog_kit.dart';
import '../ui/time_format.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
import 'tts.dart';
import 'voiceover_actions.dart';

/// Write a script and turn it into voiceover lines at the playhead.
Future<void> showVoiceoverDialog(BuildContext context) =>
    showCutModal<void>(context, builder: (_) => const VoiceoverDialog());

/// Change one generated line's words, voice or speed and make it again.
Future<void> showEditLineDialog(BuildContext context, String audioId) =>
    showCutModal<void>(
      context,
      builder: (_) => VoiceoverDialog(audioId: audioId),
    );

/// Known voices' character, for the little tags on the cards.
const _voiceTags = {
  'troy': 'Warm · Male',
  'hannah': 'Bright · Female',
  'austin': 'Casual · Male',
  'diana': 'Clear · Female',
  'daniel': 'Calm · Male',
  'autumn': 'Soft · Female',
  'Samantha': 'Clear · Female',
  'Daniel': 'British · Male',
  'Karen': 'Australian · Female',
  'Moira': 'Irish · Female',
  'Alex': 'Natural · Male',
  'Fred': 'Retro · Male',
  'Tessa': 'South African · Female',
  'Rishi': 'Indian · Male',
  'Veena': 'Indian · Female',
  'Victoria': 'Formal · Female',
};

String _display(String v) =>
    v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';

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
  List<String>? _voices;
  bool _busy = false;
  String? _error;
  String? _previewing;
  final _previews = <String, String>{};
  Directory? _previewDir;
  late final TrackPlayer _player;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _player = ref.read(trackPlayerProvider.notifier);
    final project = ref.read(projectEditorProvider).project;
    final item = project.audio.where((a) => a.id == widget.audioId).firstOrNull;
    final spec = item == null ? null : project.mediaById(item.mediaId)?.speech;
    if (spec != null) {
      _script.text = spec.text;
      _engine = spec.engine;
      _voice = spec.voice;
      _speed = spec.speed;
    }
    _script.addListener(() => setState(() {}));
    _loadVoices();
  }

  @override
  void dispose() {
    if (_played) {
      final player = _player;
      unawaited(Future(player.stop));
    }
    try {
      _previewDir?.deleteSync(recursive: true);
    } on Object {
      // A temp folder; the system cleans it up anyway.
    }
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
      if (mounted) {
        setState(() {
          _voices = const [];
          _error = e.message;
        });
      }
    }
  }

  void _setEngine(VoiceEngine e) {
    if (_busy || e == _engine) return;
    setState(() {
      _engine = e;
      _voices = null;
      _voice = '';
      _error = null;
    });
    _loadVoices();
  }

  /// Says a short line in [voice] so you can hear it before choosing.
  Future<void> _preview(String voice) async {
    final id = 'voice-preview-${_engine.name}-$voice-$_speed';
    if (ref.read(trackPlayerProvider) == id) {
      await _player.stop();
      return;
    }
    var path = _previews[id];
    if (path == null) {
      setState(() => _previewing = voice);
      try {
        final speaker = await ref.read(speakerFactoryProvider)(_engine);
        _previewDir ??= Directory.systemTemp.createTempSync('cutline_voice');
        path = p.join(_previewDir!.path, '${_previews.length}.wav');
        await speaker.speak(
          SpeechSpec(
            text:
                'Hi, I\'m ${_display(voice)}. This is how your '
                'voiceover will sound.',
            engine: _engine,
            voice: voice,
            speed: _speed,
          ),
          path,
        );
        _previews[id] = path;
      } on SpeechException catch (e) {
        if (mounted) setState(() => _error = e.message);
        return;
      } finally {
        if (mounted) setState(() => _previewing = null);
      }
    }
    if (!mounted) return;
    _played = true;
    await _player.toggle(id, path);
  }

  Future<void> _generate() async {
    final state = ref.read(projectEditorProvider);
    final work = state.workPath;
    if (work == null) return;
    if (_script.text.trim().isEmpty) {
      setState(() => _error = 'Write what the voice should say first.');
      return;
    }
    unawaited(_player.stop());
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

  void _askAssistant() {
    unawaited(
      ref
          .read(chatProvider.notifier)
          .send(
            'Write a short voiceover script from what I say in the video '
            'and add it as a voiceover.',
          ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.audioId != null;
    final at = ref.read(previewProvider).position;
    final hasKey = ref.watch(apiKeyProvider).value != null;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final text = _script.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final lines = text.isEmpty
        ? 0
        : text.split('\n').where((l) => l.trim().isNotEmpty).length;
    // About 2.5 words a second at normal pace.
    final seconds = (words / 2.5 / _speed).round();

    return PopScope(
      canPop: !_busy,
      child: CutModal(
        width: 640,
        title: editing ? 'Edit voiceover line' : 'AI voiceover',
        subtitle: editing
            ? 'Change the words, voice or pace and make it again'
            : 'Each line becomes its own clip from ${formatPlayerTime(at)}',
        icon: CutIcons.voice,
        iconColor: Cut.trackVoice,
        iconBackground: Cut.warningContainer,
        showClose: !_busy,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              'Script',
              trailing: !editing && hasKey && wide
                  ? PromptChip(
                      label: 'Write it from my video',
                      ai: true,
                      onTap: _busy ? null : _askAssistant,
                    )
                  : null,
            ),
            Container(
              decoration: BoxDecoration(
                color: Cut.surface1,
                borderRadius: BorderRadius.circular(CutRadii.md),
                border: Border.all(color: Cut.strokeSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('voiceover-script'),
                    controller: _script,
                    minLines: editing ? 2 : 6,
                    maxLines: 12,
                    enabled: !_busy,
                    style: CutType.body.copyWith(fontSize: 15, height: 24 / 15),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      hintText: editing
                          ? null
                          : 'Here is the setup screen.\n'
                                'Pick a plan, then press Continue.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                    child: Row(
                      children: [
                        if (!editing) ...[
                          Text(
                            'One line per clip',
                            style: CutType.caption.copyWith(
                              color: Cut.textTertiary,
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        TimecodeText(
                          words == 0
                              ? '0 words'
                              : '$words ${words == 1 ? 'word' : 'words'}'
                                    '${editing ? '' : ' · $lines ${lines == 1 ? 'line' : 'lines'}'}'
                                    ' · ~${seconds}s',
                          style: CutType.timecode.copyWith(fontSize: 12),
                          color: Cut.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CutSpace.s5),
            FieldLabel(
              'Voice',
              trailing: SizedBox(
                width: 250,
                child: SegmentedPill<VoiceEngine>(
                  key: const Key('voice-engine'),
                  height: 32,
                  expand: true,
                  segments: const [
                    (VoiceEngine.system, 'Offline', DialogIcons.desktop),
                    (VoiceEngine.groq, 'Natural', DialogIcons.cloud),
                  ],
                  selected: _engine,
                  onChanged: _setEngine,
                ),
              ),
            ),
            SizedBox(
              key: const Key('voice-name'),
              height: 112,
              child: _voiceRow(),
            ),
            const SizedBox(height: 6),
            Text(
              _engine == VoiceEngine.system
                  ? 'Your computer\'s own voices. Free and offline.'
                  : 'Groq\'s natural voices, using your Groq key. The text '
                        'is sent to Groq.',
              style: CutType.caption.copyWith(color: Cut.textTertiary),
            ),
            const SizedBox(height: CutSpace.s4),
            Disclosure(
              title: 'Fine-tune',
              icon: DialogIcons.fine,
              summary: 'Speed ${_speed.toStringAsFixed(2)}×',
              child: Row(
                children: [
                  const Icon(
                    DialogIcons.speed,
                    size: 16,
                    color: Cut.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Speed',
                    style: CutType.label.copyWith(color: Cut.textSecondary),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Cut.trackVoice,
                        overlayColor: Cut.trackVoice.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: _speed,
                        min: 0.75,
                        max: 1.5,
                        divisions: 15,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _speed = v),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: TimecodeText(
                      '${_speed.toStringAsFixed(2)}×',
                      color: Cut.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: CutSpace.s3),
              InlineNotice(_error!),
            ],
          ],
        ),
        footer: ModalActions(
          actions: [
            QuietButton(
              label: 'Cancel',
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
            _busy
                ? const _MakingPill()
                : PrimaryButton(
                    key: const Key('voiceover-generate'),
                    label: editing ? 'Re-make line' : 'Make voiceover',
                    icon: CutIcons.voice,
                    onPressed: _voices == null ? null : _generate,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _voiceRow() {
    final voices = _voices;
    if (voices == null) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) =>
            const Skeleton(width: 132, height: 112, radius: CutRadii.md),
      );
    }
    if (voices.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cut.surface1,
          borderRadius: BorderRadius.circular(CutRadii.md),
          border: Border.all(color: Cut.strokeSubtle),
        ),
        child: Text(
          'No voices here. Try the other kind.',
          style: CutType.caption,
        ),
      );
    }
    final playing = ref.watch(trackPlayerProvider);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: voices.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final v = voices[i];
        final previewId = 'voice-preview-${_engine.name}-$v-$_speed';
        return _VoiceCard(
          key: Key('voice-$v'),
          name: _display(v),
          tag:
              _voiceTags[v] ??
              (_engine == VoiceEngine.groq ? 'Natural' : 'System'),
          selected: v == _voice,
          loading: _previewing == v,
          playing: playing == previewId,
          onTap: _busy ? null : () => setState(() => _voice = v),
          onPreview: _busy || _previewing != null ? null : () => _preview(v),
        );
      },
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    super.key,
    required this.name,
    required this.tag,
    required this.selected,
    required this.loading,
    required this.playing,
    required this.onTap,
    required this.onPreview,
  });

  final String name;
  final String tag;
  final bool selected;
  final bool loading;
  final bool playing;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    label: name,
    child: Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: CutMotion.fast,
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        decoration: BoxDecoration(
          color: selected
              ? Cut.trackVoice.withValues(alpha: 0.12)
              : Cut.surface3,
          borderRadius: BorderRadius.circular(CutRadii.md),
          border: Border.all(
            color: selected ? Cut.trackVoice : Cut.strokeSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: seededGradient(name, tint: Cut.trackVoice),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '?' : name[0],
                    style: CutType.titleSm.copyWith(color: Colors.white),
                  ),
                ),
                const Spacer(),
                SizedBox.square(
                  dimension: 30,
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Cut.trackVoice,
                          ),
                        )
                      : CutIconButton(
                          icon: playing ? CutIcons.stop : CutIcons.play,
                          tooltip: playing ? 'Stop' : 'Hear $name',
                          size: 30,
                          iconSize: 14,
                          color: Cut.trackVoice,
                          onPressed: onPreview,
                        ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: CutType.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (playing) ...[
                  const SizedBox(width: 6),
                  const EqualizerBars(color: Cut.trackVoice, size: 12),
                ],
              ],
            ),
            Text(
              tag,
              style: CutType.caption.copyWith(
                fontSize: 11,
                color: Cut.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The generate button while the voice is being made.
class _MakingPill extends StatelessWidget {
  const _MakingPill();

  @override
  Widget build(BuildContext context) => Container(
    height: isTouchPlatform || isPhoneLayout(context) ? 48 : 40,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Cut.warningContainer,
      borderRadius: BorderRadius.circular(CutRadii.pill),
      border: Border.all(color: Cut.trackVoice.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EqualizerBars(color: Cut.trackVoice, size: 14),
        const SizedBox(width: 10),
        ShimmerText(
          'Making the voice…',
          style: CutType.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
