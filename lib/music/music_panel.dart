import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/audio_item.dart';
import '../preview/preview_controller.dart';
import 'music_library.dart';
import 'track_player.dart';

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

void _run(BuildContext context, WidgetRef ref, EditCommand command) {
  try {
    ref.read(projectEditorProvider.notifier).run(command);
  } on EditException catch (e) {
    _snack(context, e.message);
  }
}

/// Track levels and ducking: your video's sound, the voiceover, the music.
/// Used in the desktop mix menu and the phone's sound sheet.
class MixControls extends ConsumerWidget {
  const MixControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(projectEditorProvider.select((s) => s.project.mix));
    final hasMusic = ref.watch(
      projectEditorProvider.select(
        (s) => s.project.audio.any((a) => a.role == AudioRole.music),
      ),
    );
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    void set(AudioMix m) => _run(context, ref, SetAudioMix(m));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Level(
          key: const Key('mix-original'),
          icon: Icons.person_outline,
          label: 'Video sound',
          hint: 'Your voice in the video',
          value: mix.original,
          onCommit: (v) => set(mix.copyWith(original: v)),
        ),
        _Level(
          key: const Key('mix-voiceover'),
          icon: Icons.mic_none,
          label: 'Voiceover',
          hint: 'Recorded and AI voices',
          value: mix.voiceover,
          onCommit: (v) => set(mix.copyWith(voiceover: v)),
        ),
        _Level(
          key: const Key('mix-music'),
          icon: Icons.music_note_outlined,
          label: 'Music',
          hint: hasMusic ? 'Background music' : 'No music yet',
          value: mix.music,
          onCommit: (v) => set(mix.copyWith(music: v)),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: colors.outlineVariant),
        SwitchListTile(
          key: const Key('mix-duck-music'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Lower the music when someone talks'),
          subtitle: Text(
            'Fills the pauses, then gets out of the way',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          value: mix.duckMusic,
          onChanged: (v) => set(mix.copyWith(duckMusic: v)),
        ),
        SwitchListTile(
          key: const Key('mix-duck'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Lower the video under voiceovers'),
          value: mix.duck,
          onChanged: (v) => set(mix.copyWith(duck: v)),
        ),
      ],
    );
  }
}

/// One track's level: name, percentage, mute and a slider that commits on
/// release.
class _Level extends StatefulWidget {
  const _Level({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onCommit,
  });

  final IconData icon;
  final String label;
  final String hint;
  final double value;
  final ValueChanged<double> onCommit;

  @override
  State<_Level> createState() => _LevelState();
}

class _LevelState extends State<_Level> {
  double? _dragging;
  double _beforeMute = 1;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final v = _dragging ?? widget.value;
    final muted = v == 0;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '  ${widget.hint}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(v * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: text.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  muted ? Icons.volume_off : Icons.volume_up_outlined,
                  size: 18,
                  color: muted ? colors.error : null,
                ),
                onPressed: () {
                  if (muted) {
                    widget.onCommit(_beforeMute == 0 ? 1 : _beforeMute);
                  } else {
                    _beforeMute = widget.value;
                    widget.onCommit(0);
                  }
                },
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
              child: Slider(
                value: v.clamp(0, 2),
                max: 2,
                divisions: 40,
                onChanged: (x) => setState(() => _dragging = x),
                onChangeEnd: (x) {
                  setState(() => _dragging = null);
                  if (x != widget.value) widget.onCommit(x);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sound levels in a bottom sheet (phones).
Future<void> showMixSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sound levels', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const MixControls(),
        ],
      ),
    ),
  ),
);

const _moods = [
  'Calm lofi',
  'Upbeat pop',
  'Cinematic',
  'Acoustic',
  'Electronic',
  'Corporate',
  'Hip hop',
  'Piano',
];

/// Find background music (or a sound) and add it: a search of the free
/// Creative Commons library with mood chips, or a file of your own.
Future<void> showMusicBrowser(
  BuildContext context, {
  TrackKind kind = TrackKind.music,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  const browser = _MusicBrowser();
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => const Dialog(
        child: SizedBox(width: 520, height: 600, child: browser),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: browser,
    ),
  );
}

class _MusicBrowser extends ConsumerStatefulWidget {
  const _MusicBrowser();

  @override
  ConsumerState<_MusicBrowser> createState() => _MusicBrowserState();
}

class _MusicBrowserState extends ConsumerState<_MusicBrowser> {
  final _query = TextEditingController();
  var _kind = TrackKind.music;
  List<Track>? _results;
  String? _error;
  bool _searching = false;
  String? _adding;
  int _search = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_run('Calm lofi'));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final n = ++_search;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await ref.read(trackFinderProvider)(q, kind: _kind);
      if (!mounted || n != _search) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } on MusicException catch (e) {
      if (!mounted || n != _search) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    }
  }

  Future<void> _add(Track track) async {
    final editor = ref.read(projectEditorProvider);
    final workPath = editor.workPath;
    if (workPath == null) return;
    unawaited(ref.read(trackPlayerProvider.notifier).stop());
    setState(() => _adding = track.id);
    try {
      final media = await trackMedia(editor.project, workPath, track);
      if (!mounted) return;
      final project = ref.read(projectEditorProvider).project;
      final List<EditCommand> commands;
      if (_kind == TrackKind.music) {
        commands = [
          for (final a in project.audio)
            if (a.role == AudioRole.music) RemoveAudio(a.id),
          ...musicCommands(project, media),
        ];
      } else {
        commands = soundCommands(
          project,
          media,
          ref.read(previewProvider).position,
        );
      }
      ref
          .read(projectEditorProvider.notifier)
          .runAll(
            _kind == TrackKind.music
                ? 'Add music "${track.title}"'
                : 'Add sound "${track.title}"',
            commands,
          );
      if (mounted) Navigator.pop(context);
      if (context.mounted) {
        _snack(
          context,
          _kind == TrackKind.music
              ? 'Added "${track.title}" under the whole video.'
              : 'Added "${track.title}" at the playhead.',
        );
      }
    } on MusicException catch (e) {
      if (mounted) _snack(context, e.message);
    } on EditException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Audio',
          extensions: audioExtensions,
          uniformTypeIdentifiers: ['public.audio'],
        ),
      ],
    );
    if (file == null) return;
    await _add(
      Track(
        id: 'file-${DateTime.now().millisecondsSinceEpoch}',
        title: p.basenameWithoutExtension(file.path),
        source: file.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final playing = ref.watch(trackPlayerProvider);
    final results = _results;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _kind == TrackKind.music ? 'Add music' : 'Add a sound',
                  style: text.titleLarge,
                ),
              ),
              SegmentedButton<TrackKind>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: TrackKind.music, label: Text('Music')),
                  ButtonSegment(value: TrackKind.sound, label: Text('Sounds')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) {
                  setState(() => _kind = s.single);
                  unawaited(
                    _run(
                      _query.text.isNotEmpty
                          ? _query.text
                          : _kind == TrackKind.music
                          ? 'Calm lofi'
                          : 'Whoosh',
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Free Creative Commons tracks from Openverse. Music is lowered '
            'automatically when someone talks.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('music-search'),
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: _run,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _kind == TrackKind.music
                  ? 'A mood, genre or instrument'
                  : 'Whoosh, applause, ding…',
            ),
          ),
          if (_kind == TrackKind.music) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final m in _moods)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(m),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _query.text = m;
                          unawaited(_run(m));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _searching && results == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : results == null || results.isEmpty
                ? const Center(child: Text('Nothing found. Try other words.'))
                : Opacity(
                    opacity: _searching ? 0.5 : 1,
                    child: ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colors.outlineVariant),
                      itemBuilder: (context, i) {
                        final t = results[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: IconButton(
                            tooltip: playing == t.id ? 'Stop' : 'Play',
                            icon: Icon(
                              playing == t.id
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: colors.primary,
                              size: 34,
                            ),
                            onPressed: () => ref
                                .read(trackPlayerProvider.notifier)
                                .toggle(t.id, t.source),
                          ),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (t.artist.isNotEmpty) t.artist,
                              if (t.duration > Duration.zero)
                                '${t.duration.inMinutes}:'
                                    '${(t.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                              if (t.license.isNotEmpty) t.license,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _adding == t.id
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FilledButton.tonal(
                                  onPressed: _adding == null
                                      ? () => _add(t)
                                      : null,
                                  child: const Text('Add'),
                                ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('music-file'),
            onPressed: _adding == null ? _pickFile : null,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Use a file of my own'),
          ),
        ],
      ),
    );
  }
}
