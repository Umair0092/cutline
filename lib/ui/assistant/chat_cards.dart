import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/chat_controller.dart';
import '../../ai/meme_tools.dart';
import '../../editing/project_editor.dart';
import '../../memes/meme_panel.dart';
import '../../music/track_player.dart';
import '../../preview/preview_controller.dart';
import '../time_format.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';

/// What kind of edit a change line ("Cut 0:00.00–0:05.00", "Add title")
/// is, for its icon and the card's headline.
enum _Kind { cut, title, meme, picture, audio, voice, rename, volume, other }

_Kind _kindOf(String label) {
  final l = label.toLowerCase();
  if (l.startsWith('cut ') ||
      l.startsWith('keep ') ||
      l.contains('trim') ||
      l.contains('split') ||
      l.contains('clip') && !l.contains('volume') && !l.contains('mute')) {
    return _Kind.cut;
  }
  if (l.contains('title') || l.contains('intro')) return _Kind.title;
  if (l.contains('meme') || l.contains('overlay')) return _Kind.meme;
  if (l.contains('picture') || l.contains('media')) return _Kind.picture;
  if (l.contains('voice')) return _Kind.voice;
  if (l.contains('audio') || l.contains('music') || l.contains('sound')) {
    return _Kind.audio;
  }
  if (l.contains('rename')) return _Kind.rename;
  if (l.contains('volume') || l.contains('mute')) return _Kind.volume;
  return _Kind.other;
}

IconData _iconOf(_Kind k) => switch (k) {
  _Kind.cut => CutIcons.cut,
  _Kind.title => CutIcons.text,
  _Kind.meme => CutIcons.meme,
  _Kind.picture => CutIcons.image,
  _Kind.audio => CutIcons.music,
  _Kind.voice => CutIcons.voiceEffect,
  _Kind.rename => CutIcons.rename,
  _Kind.volume => CutIcons.volume,
  _Kind.other => CutIcons.magic,
};

Color _colorOf(_Kind k) => switch (k) {
  _Kind.cut => Cut.trackVideo,
  _Kind.title => Cut.trackTitle,
  _Kind.meme || _Kind.picture => Cut.trackOverlay,
  _Kind.audio => Cut.trackMusic,
  _Kind.voice => Cut.trackVoice,
  _ => Cut.onAccentContainer,
};

String _headline(List<_Kind> kinds) {
  if (kinds.isEmpty) return 'Edited your video';
  final k = kinds.first;
  final same = kinds.every((e) => e == k);
  if (!same) return '${kinds.length} edits applied';
  final n = kinds.length;
  return switch (k) {
    _Kind.cut => n == 1 ? 'Trimmed the video' : 'Made $n cuts',
    _Kind.title => n == 1 ? 'Added a title' : 'Updated $n titles',
    _Kind.meme => n == 1 ? 'Added a meme' : 'Added $n memes',
    _Kind.picture => n == 1 ? 'Added a picture' : 'Added $n pictures',
    _Kind.audio => n == 1 ? 'Added audio' : 'Made $n audio changes',
    _Kind.voice => 'Changed the voice',
    _Kind.rename => 'Renamed the edit',
    _Kind.volume => 'Changed the volume',
    _Kind.other => n == 1 ? 'Edited your video' : '$n edits applied',
  };
}

final _range = RegExp(r'(\d+):(\d+(?:\.\d+)?)\s*[–-]\s*(\d+):(\d+(?:\.\d+)?)');

/// The start and end of a "Cut 0:01.00–0:03.50" line, if it has one.
(Duration, Duration)? _rangeOf(String label) {
  final m = _range.firstMatch(label);
  if (m == null) return null;
  Duration t(String min, String sec) => Duration(
    milliseconds: (int.parse(min) * 60000 + double.parse(sec) * 1000).round(),
  );
  return (t(m[1]!, m[2]!), t(m[3]!, m[4]!));
}

String _seconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

/// What the assistant changed, Descript-style: an icon, a headline, the
/// list of edits, and Undo while it's still the latest edit.
class ChangeCard extends ConsumerWidget {
  const ChangeCard({super.key, required this.index, required this.entry});

  final int index;
  final ChatEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when the project changes, since that decides if Undo works.
    ref.watch(projectEditorProvider);
    final canUndo = ref.read(chatProvider.notifier).canUndoChange(index);
    final undone = entry.undone;
    final kinds = [for (final c in entry.changes) _kindOf(c)];
    final lead = kinds.firstOrNull ?? _Kind.other;
    final removed = entry.changes
        .where((c) => c.startsWith('Cut '))
        .map(_rangeOf)
        .whereType<(Duration, Duration)>()
        .fold(Duration.zero, (sum, r) => sum + (r.$2 - r.$1));
    final meta = [
      if (removed > Duration.zero)
        '−${_seconds(removed)}'
      else if (entry.changes.length > 1)
        '${entry.changes.length} changes',
      'one undo step',
    ].join(' · ');

    return AuroraBorder(
      key: Key('change-$index'),
      radius: CutRadii.md + 1,
      width: 1,
      active: !undone,
      opacity: 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: Cut.surface2,
          borderRadius: BorderRadius.circular(CutRadii.md),
          boxShadow: undone ? null : CutShadows.e1,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CutRadii.md),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Cut.highlightTop, Color(0x00FFFFFF)],
            stops: [0, 0.3],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _KindTile(
                  icon: undone ? CutIcons.undo : _iconOf(lead),
                  color: undone ? Cut.textTertiary : _colorOf(lead),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline(kinds),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.bodyStrong.copyWith(
                          color: undone ? Cut.textTertiary : Cut.textPrimary,
                          decoration: undone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Cut.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.caption.copyWith(
                          color: Cut.textTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (undone)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: CutBadge('Undone', icon: CutIcons.undo),
                  )
                else if (canUndo)
                  _SmallButton(
                    key: Key('undo-change-$index'),
                    icon: CutIcons.undo,
                    label: 'Undo',
                    onTap: () =>
                        ref.read(chatProvider.notifier).undoChange(index),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Cut.surface1.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(CutRadii.sm),
                border: Border.all(color: Cut.strokeSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in entry.changes.indexed)
                    _ChangeLine(label: c, kind: kinds[i], undone: undone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(CutRadii.sm + 1),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Icon(icon, size: 17, color: color),
  );
}

/// One edit in a change card. Lines with a time jump the playhead there.
class _ChangeLine extends ConsumerWidget {
  const _ChangeLine({
    required this.label,
    required this.kind,
    required this.undone,
  });

  final String label;
  final _Kind kind;
  final bool undone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _rangeOf(label);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: undone
                  ? Cut.textDisabled
                  : _colorOf(kind).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CutType.label.copyWith(
                fontSize: 12.5,
                color: undone ? Cut.textTertiary : Cut.textSecondary,
                decoration: undone ? TextDecoration.lineThrough : null,
                decorationColor: Cut.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (range != null && !undone)
            const Icon(CutIcons.forward, size: 12, color: Cut.textTertiary),
        ],
      ),
    );
    if (range == null || undone) return row;
    return Tooltip(
      message: 'Show at ${formatPlayerTime(range.$1)}',
      waitDuration: const Duration(milliseconds: 500),
      child: _Hover(
        onTap: () => ref.read(previewProvider).seek(range.$1),
        child: row,
      ),
    );
  }
}

/// A quiet hover fill for rows you can click.
class _Hover extends StatefulWidget {
  const _Hover({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _on = true),
    onExit: (_) => setState(() => _on = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: CutMotion.instant,
        color: _on ? Cut.hover : const Color(0x00FFFFFF),
        child: widget.child,
      ),
    ),
  );
}

/// A small secondary pill: "↶ Undo", "Skip".
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final h = isTouchPlatform ? 36.0 : 28.0;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 10),
        decoration: BoxDecoration(
          color: primary ? Cut.accent : Cut.surface4,
          borderRadius: BorderRadius.circular(CutRadii.pill),
          border: primary ? null : Border.all(color: Cut.strokeDefault),
          boxShadow: primary
              ? const [
                  BoxShadow(
                    color: Color(0x408B6DFF),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: primary ? Colors.white : Cut.textPrimary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: CutType.label.copyWith(
                fontSize: 12.5,
                color: primary ? Colors.white : Cut.textPrimary,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meme search results, numbered by the id the assistant uses. Clicking
/// one tells the assistant to use it.
class MemeChoices extends StatelessWidget {
  const MemeChoices({super.key, required this.entry, required this.onPick});

  final ChatEntry entry;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 300 ? 4 : 3;
      const gap = 8.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Tap one to use it',
              style: CutType.caption.copyWith(color: Cut.textTertiary),
            ),
          ),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (i, (id, meme)) in entry.memes.indexed)
                ArriveIn(
                  delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
                  child: Tooltip(
                    message: meme.title,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Pressable(
                      key: Key('meme-choice-$id'),
                      hoverLift: 2,
                      pressedScale: 0.96,
                      onTap: () => onPick(id),
                      child: Container(
                        width: w,
                        height: w * 0.8,
                        decoration: BoxDecoration(
                          color: Cut.surface3,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: CutShadows.e1,
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Cut.strokeDefault),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MemeThumbnail(meme: meme),
                            Positioned(
                              left: 5,
                              top: 5,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC111017),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Cut.strokeDefault),
                                ),
                                child: Text(
                                  id.replaceFirst('meme', ''),
                                  textAlign: TextAlign.center,
                                  style: CutType.timecode.copyWith(
                                    fontSize: 10.5,
                                    height: 1.2,
                                    color: Cut.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// Music or sounds the assistant found: play to try one, Use to add it.
class TrackChoices extends ConsumerWidget {
  const TrackChoices({super.key, required this.entry, required this.onPick});

  final ChatEntry entry;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(trackPlayerProvider);
    return CutSurface(
      level: 2,
      radius: CutRadii.md,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          for (final (i, (id, track)) in entry.tracks.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 52,
                endIndent: 8,
                color: Cut.strokeSubtle,
              ),
            ArriveIn(
              delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
              child: _TrackRow(
                id: id,
                title: track.title,
                meta: [
                  if (track.artist.isNotEmpty) track.artist,
                  if (track.license.isNotEmpty) track.license,
                ].join(' · '),
                duration: track.duration > Duration.zero
                    ? '${track.duration.inMinutes}:'
                          '${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}'
                    : null,
                sound: id.startsWith('sound'),
                playing: playing == id,
                onPlay: () => ref
                    .read(trackPlayerProvider.notifier)
                    .toggle(id, track.source),
                onUse: () {
                  ref.read(trackPlayerProvider.notifier).stop();
                  onPick(id);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.id,
    required this.title,
    required this.meta,
    required this.duration,
    required this.sound,
    required this.playing,
    required this.onPlay,
    required this.onUse,
  });

  final String id;
  final String title;
  final String meta;
  final String? duration;
  final bool sound;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final playSize = isTouchPlatform ? 40.0 : 36.0;
    return AnimatedContainer(
      duration: CutMotion.fast,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: playing
            ? Cut.trackMusic.withValues(alpha: 0.08)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(CutRadii.sm),
      ),
      child: Row(
        children: [
          Tooltip(
            message: playing ? 'Stop' : 'Play',
            child: Pressable(
              key: Key('track-play-$id'),
              onTap: onPlay,
              pressedScale: 0.92,
              child: AnimatedContainer(
                duration: CutMotion.fast,
                width: playSize,
                height: playSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playing ? Cut.trackMusic : Cut.surface4,
                  border: Border.all(
                    color: playing
                        ? Cut.trackMusic.withValues(alpha: 0.4)
                        : Cut.strokeDefault,
                  ),
                  boxShadow: playing
                      ? [
                          BoxShadow(
                            color: Cut.trackMusic.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: -3,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  playing ? CutIcons.stop : CutIcons.play,
                  size: 15,
                  color: playing ? Cut.canvas : Cut.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sound ? CutIcons.sound : CutIcons.music,
                      size: 12,
                      color: Cut.trackMusic,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                if (meta.isNotEmpty || duration != null)
                  Row(
                    children: [
                      if (duration != null) ...[
                        TimecodeText(
                          duration!,
                          style: CutType.timecode.copyWith(fontSize: 11),
                          color: Cut.textTertiary,
                        ),
                        if (meta.isNotEmpty) const SizedBox(width: 6),
                      ],
                      if (meta.isNotEmpty)
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CutType.caption.copyWith(
                              color: Cut.textTertiary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallButton(
            key: Key('track-use-$id'),
            label: 'Use',
            primary: true,
            onTap: onUse,
          ),
        ],
      ),
    );
  }
}

/// A meme the assistant suggests for a moment, with Add and Skip.
class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key, required this.index, required this.entry});

  final int index;
  final ChatEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = entry.suggestion!;
    final chat = ref.read(chatProvider.notifier);
    final pending = s.status == SuggestionStatus.pending;
    final accepted = s.status == SuggestionStatus.accepted;
    return AnimatedOpacity(
      key: Key('suggestion-$index'),
      duration: CutMotion.normal,
      opacity: pending || accepted ? 1 : 0.6,
      child: CutSurface(
        level: 2,
        radius: CutRadii.md,
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => ref.read(previewProvider).seek(s.start),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 76,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Cut.surface3,
                    borderRadius: BorderRadius.circular(CutRadii.sm),
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CutRadii.sm),
                    border: Border.all(color: Cut.strokeDefault),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MemeThumbnail(meme: s.meme),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0B0A10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TimecodeText(
                            formatPlayerTime(s.start),
                            style: CutType.timecode.copyWith(
                              fontSize: 10,
                              height: 1.3,
                              color: Cut.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    s.meme.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CutType.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: CutType.caption.copyWith(
                      fontSize: 12,
                      height: 16 / 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pending)
                    Row(
                      children: [
                        _SmallButton(
                          key: Key('accept-$index'),
                          icon: CutIcons.check,
                          label: 'Add',
                          primary: true,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            chat.acceptSuggestion(index);
                          },
                        ),
                        const SizedBox(width: 6),
                        _SmallButton(
                          key: Key('reject-$index'),
                          label: 'Skip',
                          onTap: () => chat.rejectSuggestion(index),
                        ),
                      ],
                    )
                  else
                    CutBadge(
                      accepted ? 'Added' : 'Skipped',
                      icon: accepted ? CutIcons.check : CutIcons.close,
                      color: accepted ? Cut.success : Cut.textTertiary,
                      background: accepted
                          ? Cut.successContainer
                          : Cut.surface4,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
