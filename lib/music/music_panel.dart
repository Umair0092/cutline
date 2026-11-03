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
import '../ui/dialogs/dialog_kit.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
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

// ---------------------------------------------------------------- levels

/// Track levels and ducking: your video's sound, the voiceover, the music.
/// Used in the desktop mix popover and the phone's sound sheet.
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
    final hasVoice = ref.watch(
      projectEditorProvider.select(
        (s) => s.project.audio.any((a) => a.role != AudioRole.music),
      ),
    );
    void set(AudioMix m) => _run(context, ref, SetAudioMix(m));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Level(
          key: const Key('mix-original'),
          icon: CutIcons.person,
          color: Cut.trackWave,
          label: 'Video sound',
          hint: 'Your voice in the video',
          value: mix.original,
          normal: 1,
          onCommit: (v) => set(mix.copyWith(original: v)),
        ),
        _Level(
          key: const Key('mix-voiceover'),
          icon: CutIcons.mic,
          color: Cut.trackVoice,
          label: 'Voiceover',
          hint: hasVoice ? 'Recorded and AI voices' : 'No voiceover yet',
          value: mix.voiceover,
          normal: 1,
          onCommit: (v) => set(mix.copyWith(voiceover: v)),
        ),
        _Level(
          key: const Key('mix-music'),
          icon: CutIcons.music,
          color: Cut.trackMusic,
          label: 'Music',
          hint: hasMusic ? 'Background music' : 'No music yet',
          value: mix.music,
          normal: const AudioMix().music,
          onCommit: (v) => set(mix.copyWith(music: v)),
        ),
        const SizedBox(height: CutSpace.s3),
        const Divider(height: 1),
        const SizedBox(height: CutSpace.s1),
        _DuckRow(
          key: const Key('mix-duck-music'),
          color: Cut.trackMusic,
          title: 'Lower the music when someone talks',
          subtitle: 'Fills the pauses, then gets out of the way',
          value: mix.duckMusic,
          onChanged: (v) => set(mix.copyWith(duckMusic: v)),
        ),
        _DuckRow(
          key: const Key('mix-duck'),
          color: Cut.trackVoice,
          title: 'Lower the video under voiceovers',
          subtitle: 'So the voiceover is easy to hear',
          value: mix.duck,
          onChanged: (v) => set(mix.copyWith(duck: v)),
        ),
      ],
    );
  }
}

/// One track's level: a tile in the track's colour, the name, a percentage
/// you can tap to reset, mute, and a fader that commits on release.
class _Level extends StatefulWidget {
  const _Level({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.hint,
    required this.value,
    required this.normal,
    required this.onCommit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String hint;
  final double value;

  /// The default level: marked on the fader, restored by tapping the %.
  final double normal;
  final ValueChanged<double> onCommit;

  @override
  State<_Level> createState() => _LevelState();
}

class _LevelState extends State<_Level> {
  double? _dragging;
  double _beforeMute = 1;

  static const _thumb = 9.0;

  @override
  Widget build(BuildContext context) {
    final v = _dragging ?? widget.value;
    final muted = v == 0;
    final c = muted ? Cut.textTertiary : widget.color;
    return Padding(
      padding: const EdgeInsets.only(top: CutSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: CutMotion.fast,
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(CutRadii.sm),
                  border: Border.all(color: c.withValues(alpha: 0.3)),
                ),
                child: Icon(widget.icon, size: 16, color: c),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: CutType.bodyStrong.copyWith(fontSize: 13),
                    ),
                    Text(
                      widget.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CutType.caption.copyWith(
                        fontSize: 11,
                        color: Cut.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Reset to ${(widget.normal * 100).round()}%',
                child: InkWell(
                  borderRadius: BorderRadius.circular(CutRadii.xs),
                  onTap: () => widget.onCommit(widget.normal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: TimecodeText(
                      muted ? 'Muted' : '${(v * 100).round()}%',
                      color: muted ? Cut.error : Cut.textPrimary,
                    ),
                  ),
                ),
              ),
              CutIconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                icon: muted ? CutIcons.mute : CutIcons.volume,
                size: 30,
                iconSize: 16,
                color: muted ? Cut.error : null,
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
          SizedBox(
            height: 30,
            child: LayoutBuilder(
              builder: (context, box) {
                final usable = box.maxWidth - 2 * _thumb;
                return Stack(
                  children: [
                    // A tick where the default level sits.
                    Positioned(
                      left: _thumb + usable * widget.normal / 2 - 1,
                      top: 7,
                      bottom: 7,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Cut.strokeStrong,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6,
                          activeTrackColor: c,
                          inactiveTrackColor: Cut.surface4.withValues(
                            alpha: 0.8,
                          ),
                          thumbColor: Colors.white,
                          overlayColor: c.withValues(alpha: 0.15),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: _thumb,
                            elevation: 3,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _thumb,
                          ),
                        ),
                        child: Slider(
                          value: v.clamp(0, 2),
                          max: 2,
                          divisions: 40,
                          semanticFormatterCallback: (x) =>
                              '${widget.label} ${(x * 100).round()}%',
                          onChanged: (x) => setState(() => _dragging = x),
                          onChangeEnd: (x) {
                            setState(() => _dragging = null);
                            if (x != widget.value) widget.onCommit(x);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DuckRow extends StatelessWidget {
  const _DuckRow({
    super.key,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    child: InkWell(
      borderRadius: BorderRadius.circular(CutRadii.sm),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              DialogIcons.duck,
              size: 16,
              color: value ? color : Cut.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CutType.label),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: CutType.caption.copyWith(
                      fontSize: 11,
                      color: Cut.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sound levels in a bottom sheet (phones).
Future<void> showMixSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Cut.surface1,
  builder: (sheet) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Sound levels', style: CutType.headlineSm)),
              CutIconButton(
                icon: CutIcons.close,
                tooltip: 'Close',
                onPressed: () => Navigator.maybePop(sheet),
              ),
            ],
          ),
          Text(
            'Changes play right away, and undo works as usual.',
            style: CutType.caption,
          ),
          const SizedBox(height: CutSpace.s1),
          const MixControls(),
          const SizedBox(height: CutSpace.s4),
          QuietButton(
            key: const Key('mix-sheet-add-music'),
            label: 'Add music or a sound',
            icon: CutIcons.musicLibrary,
            onPressed: () {
              Navigator.pop(sheet);
              showMusicBrowser(context);
            },
          ),
        ],
      ),
    ),
  ),
);

// ----------------------------------------------------------------- music

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

const _sounds = ['Whoosh', 'Applause', 'Ding', 'Pop', 'Swoosh', 'Click'];

/// Find background music (or a sound) and add it: a search of the free
/// Creative Commons library with mood chips, or a file of your own.
Future<void> showMusicBrowser(
  BuildContext context, {
  TrackKind kind = TrackKind.music,
}) => showCutModal<void>(context, builder: (_) => _MusicBrowser(kind: kind));

class _MusicBrowser extends ConsumerStatefulWidget {
  const _MusicBrowser({required this.kind});

  final TrackKind kind;

  @override
  ConsumerState<_MusicBrowser> createState() => _MusicBrowserState();
}

class _MusicBrowserState extends ConsumerState<_MusicBrowser> {
  final _query = TextEditingController();
  late var _kind = widget.kind;
  late String _current = _defaultQuery;
  List<Track>? _results;
  String? _error;
  bool _searching = false;
  String? _adding;
  int _search = 0;
  late final TrackPlayer _player;

  String get _defaultQuery =>
      _kind == TrackKind.music ? _moods.first : _sounds.first;

  @override
  void initState() {
    super.initState();
    _player = ref.read(trackPlayerProvider.notifier);
    unawaited(_run(_defaultQuery));
  }

  @override
  void dispose() {
    // Stop the preview after the tree settles; providers can't change mid-unmount.
    final player = _player;
    unawaited(Future(player.stop));
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
      _current = q;
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
    unawaited(_player.stop());
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
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (mounted) Navigator.pop(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _kind == TrackKind.music
                  ? 'Added "${track.title}" under the whole video.'
                  : 'Added "${track.title}" at the playhead.',
            ),
          ),
        );
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

  void _setKind(TrackKind k) {
    if (k == _kind) return;
    unawaited(_player.stop());
    setState(() {
      _kind = k;
      _results = null;
    });
    unawaited(_run(_query.text.isNotEmpty ? _query.text : _defaultQuery));
  }

  @override
  Widget build(BuildContext context) {
    final music = _kind == TrackKind.music;
    final playingId = ref.watch(trackPlayerProvider);
    final playing = _results?.where((t) => t.id == playingId).firstOrNull;
    final phone = isPhoneLayout(context);
    final chips = music ? _moods : _sounds;
    return CutModal(
      width: 680,
      height: phone ? null : 720,
      title: music ? 'Add music' : 'Add a sound',
      subtitle: music
          ? 'Free Creative Commons tracks. Music dips when someone talks.'
          : 'Free sound effects, placed at the playhead',
      icon: music ? CutIcons.music : DialogIcons.bell,
      iconColor: Cut.trackMusic,
      iconBackground: Cut.trackMusic.withValues(alpha: 0.14),
      headerTrailing: phone
          ? null
          : SizedBox(
              width: 196,
              child: SegmentedPill<TrackKind>(
                key: const Key('music-kind'),
                height: 34,
                expand: true,
                segments: const [
                  (TrackKind.music, 'Music', null),
                  (TrackKind.sound, 'Sounds', null),
                ],
                selected: _kind,
                onChanged: _setKind,
              ),
            ),
      scroll: false,
      bodyPadding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedPill<TrackKind>(
                key: const Key('music-kind'),
                expand: true,
                segments: const [
                  (TrackKind.music, 'Music', null),
                  (TrackKind.sound, 'Sounds', null),
                ],
                selected: _kind,
                onChanged: _setKind,
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 24),
            child: TextField(
              key: const Key('music-search'),
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
              decoration: InputDecoration(
                prefixIcon: const Icon(CutIcons.search, size: 18),
                hintText: music
                    ? 'Search a mood, genre or instrument'
                    : 'Whoosh, applause, ding…',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CutRadii.pill),
                  borderSide: const BorderSide(color: Cut.strokeSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CutRadii.pill),
                  borderSide: const BorderSide(color: Cut.strokeSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CutRadii.pill),
                  borderSide: const BorderSide(color: Cut.accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: CutSpace.s3),
          SizedBox(
            height: isTouchPlatform ? 40 : 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 24),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _MoodChip(
                label: chips[i],
                selected: chips[i].toLowerCase() == _current.toLowerCase(),
                onTap: () {
                  _query.text = chips[i];
                  unawaited(_run(chips[i]));
                },
              ),
            ),
          ),
          const SizedBox(height: CutSpace.s3),
          Expanded(child: _list(phone, playingId)),
          if (playing != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                phone ? 12 : 20,
                4,
                phone ? 12 : 20,
                8,
              ),
              child: _MiniPlayer(
                track: playing,
                adding: _adding == playing.id,
                onStop: () => _player.stop(),
                onAdd: () => _add(playing),
              ),
            ),
        ],
      ),
      footer: Row(
        children: [
          QuietButton(
            key: const Key('music-file'),
            label: 'Use a file of my own',
            icon: DialogIcons.fileAudio,
            onPressed: _adding == null ? _pickFile : null,
          ),
          if (!phone) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'From Openverse · credits are listed when you export',
                textAlign: TextAlign.right,
                maxLines: 2,
                style: CutType.caption.copyWith(color: Cut.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(bool phone, String? playingId) {
    final results = _results;
    final pad = EdgeInsets.fromLTRB(phone ? 8 : 16, 0, phone ? 8 : 16, 8);
    if (results == null && _error == null) {
      return ListView(
        padding: pad,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const Skeleton(width: 40, height: 40, radius: CutRadii.sm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 120.0 + (i * 37) % 90, height: 12),
                        const SizedBox(height: 6),
                        Skeleton(width: 80.0 + (i * 23) % 60, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (_error != null) {
      return EmptyState(
        compact: true,
        icon: CutIcons.warning,
        title: 'Couldn\'t search right now',
        body: _error,
        actions: [
          QuietButton(label: 'Try again', onPressed: () => _run(_current)),
        ],
      );
    }
    if (results!.isEmpty) {
      return EmptyState(
        compact: true,
        icon: CutIcons.search,
        title: 'Nothing found',
        body: 'Try other words, or one of the moods above.',
      );
    }
    return AnimatedOpacity(
      opacity: _searching ? 0.45 : 1,
      duration: CutMotion.fast,
      child: ListView.builder(
        key: ValueKey('results-$_current-$_kind'),
        padding: pad,
        itemCount: results.length,
        itemBuilder: (context, i) {
          final t = results[i];
          final row = _TrackRow(
            key: Key('track-${t.id}'),
            track: t,
            playing: playingId == t.id,
            adding: _adding == t.id,
            canAdd: _adding == null,
            onPlay: () => _player.toggle(t.id, t.source),
            onAdd: () => _add(t),
          );
          return i < 8
              ? ArriveIn(
                  delay: Duration(milliseconds: 30 * i),
                  offset: 6,
                  child: row,
                )
              : row;
        },
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: CutMotion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Cut.textPrimary : Cut.surface3,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(
          color: selected ? Cut.textPrimary : Cut.strokeSubtle,
        ),
      ),
      child: Text(
        label,
        style: CutType.label.copyWith(
          color: selected ? Cut.base : Cut.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ),
  );
}

String _mmss(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// A cover tile: a gradient from the track's genre (or title), with a play
/// button on hover and bouncing bars while it plays.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.track,
    required this.playing,
    required this.hover,
    this.size = 40,
  });

  final Track track;
  final bool playing;
  final bool hover;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(CutRadii.sm),
      gradient: seededGradient(
        track.genres.firstOrNull ?? track.title,
        tint: Cut.trackMusic,
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Icon(
          CutIcons.music,
          size: size * 0.42,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        AnimatedOpacity(
          opacity: playing || hover ? 1 : 0,
          duration: CutMotion.fast,
          child: ColoredBox(
            color: const Color(0x8C000000),
            child: Center(
              child: playing
                  ? EqualizerBars(
                      color: Cut.trackMusic,
                      size: size * 0.4,
                      active: playing,
                    )
                  : Icon(CutIcons.play, size: size * 0.42, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TrackRow extends StatefulWidget {
  const _TrackRow({
    super.key,
    required this.track,
    required this.playing,
    required this.adding,
    required this.canAdd,
    required this.onPlay,
    required this.onAdd,
  });

  final Track track;
  final bool playing;
  final bool adding;
  final bool canAdd;
  final VoidCallback onPlay;
  final VoidCallback onAdd;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final meta = [
      if (t.artist.isNotEmpty) t.artist,
      if (t.license.isNotEmpty) t.license,
    ].join(' · ');
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        label: '${widget.playing ? 'Stop' : 'Play'} ${t.title}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPlay,
          onLongPress: widget.canAdd ? widget.onAdd : null,
          child: AnimatedContainer(
            duration: CutMotion.fast,
            height: isTouchPlatform || isPhoneLayout(context) ? 64 : 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: widget.playing
                  ? Cut.surface3
                  : _hover
                  ? Cut.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(CutRadii.md),
            ),
            child: Row(
              children: [
                _Cover(track: t, playing: widget.playing, hover: _hover),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.bodyStrong.copyWith(
                          color: widget.playing
                              ? Cut.trackMusic
                              : Cut.textPrimary,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CutType.caption.copyWith(
                            color: Cut.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (t.duration > Duration.zero) ...[
                  const SizedBox(width: 8),
                  TimecodeText(_mmss(t.duration), color: Cut.textTertiary),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 76,
                  child: widget.adding
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _AddButton(
                          emphasis: widget.playing || _hover,
                          onPressed: widget.canAdd ? widget.onAdd : null,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.emphasis, required this.onPressed});

  final bool emphasis;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(72, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: const StadiumBorder(),
      foregroundColor: emphasis ? Cut.base : Cut.textPrimary,
      backgroundColor: emphasis ? Cut.trackMusic : Cut.surface3,
      side: BorderSide(color: emphasis ? Cut.trackMusic : Cut.strokeSubtle),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(DialogIcons.plusBold, size: 13),
        SizedBox(width: 4),
        Text('Add'),
      ],
    ),
  );
}

/// What's playing, kept at the bottom so Add is always in reach.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.track,
    required this.adding,
    required this.onStop,
    required this.onAdd,
  });

  final Track track;
  final bool adding;
  final VoidCallback onStop;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ArriveIn(
    offset: 8,
    child: CutSurface(
      level: 4,
      radius: CutRadii.lg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          _Cover(track: track, playing: true, hover: false, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CutType.label.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  track.artist.isEmpty ? 'Previewing' : track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CutType.caption.copyWith(
                    fontSize: 11,
                    color: Cut.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          CutIconButton(
            icon: CutIcons.stop,
            tooltip: 'Stop',
            onPressed: onStop,
          ),
          const SizedBox(width: 4),
          PrimaryButton(
            label: 'Add',
            icon: CutIcons.add,
            busy: adding,
            height: 36,
            onPressed: onAdd,
          ),
        ],
      ),
    ),
  );
}
