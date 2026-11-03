import 'dart:async';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_widgets.dart';
import '../audio/effect_controls.dart';
import '../editing/project_editor.dart';
import '../media/media_previews.dart';
import '../model/media_asset.dart';
import '../overlays/overlay_actions.dart';
import '../overlays/overlay_inspector.dart';
import '../overlays/overlay_layer.dart';
import '../overlays/overlay_media.dart';
import '../preview/preview_controller.dart';
import '../storage/project_store.dart';
import '../titles/title_actions.dart';
import '../titles/title_preview.dart';
import 'app_menu.dart';
import 'editor/timecode.dart';
import 'editor/tool_button.dart';
import 'import_actions.dart';
import 'tokens.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// Whether the preview glows with the colours of the current frame
/// (like YouTube's ambient mode). On by default on desktop.
final ambientGlowProvider = NotifierProvider<_AmbientGlowSetting, bool>(
  _AmbientGlowSetting.new,
);

class _AmbientGlowSetting extends Notifier<bool> {
  @override
  bool build() => !isTouchPlatform;

  void toggle() => state = !state;
}

/// The video preview with play controls, or a drop zone when the project is
/// empty. Videos can be dropped here at any time.
class PreviewPane extends ConsumerStatefulWidget {
  const PreviewPane({super.key});

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends ConsumerState<PreviewPane> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        await dropFiles(ref, context, [for (final f in details.files) f.path]);
      },
      child: Container(
        color: Cut.canvas,
        foregroundDecoration: _dragging
            ? BoxDecoration(
                border: Border.all(color: Cut.accent, width: 2),
                color: Cut.accent.withValues(alpha: 0.08),
              )
            : null,
        child: hasClips ? const _Player() : _EmptyState(dragging: _dragging),
      ),
    );
  }
}

/// Videos dropped on the preview go on the main track. Pictures and GIFs
/// go on top of the video at the playhead.
Future<void> dropFiles(
  WidgetRef ref,
  BuildContext context,
  List<String> paths,
) async {
  final videos = [
    for (final f in paths)
      if (overlayKindOf(f) case MediaKind.video || null) f,
  ];
  final pictures = [
    for (final f in paths)
      if (overlayKindOf(f) case MediaKind.image || MediaKind.gif) f,
  ];
  if (videos.isNotEmpty) await importVideos(ref, context, videos);
  if (pictures.isNotEmpty && context.mounted) {
    await addOverlayFiles(ref, context, pictures);
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.dragging});

  final bool dragging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = isCompact(context);
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : CutSpace.s6),
      child: AnimatedContainer(
        duration: CutMotion.fast,
        decoration: BoxDecoration(
          color: dragging ? Cut.accent.withValues(alpha: 0.06) : Cut.base,
          borderRadius: BorderRadius.circular(CutRadii.lg),
          border: Border.all(
            color: dragging ? Cut.accent : Cut.strokeDefault,
            width: dragging ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: CutIcons.video,
              compact: compact,
              title: compact ? 'Pick a video to edit' : 'Drop a video here',
              body: compact
                  ? 'MP4, MOV or M4V'
                  : 'MP4, MOV or M4V. Then drop pictures and GIFs on top.',
              actions: [
                FilledButton.icon(
                  onPressed: () => pickAndImportVideos(ref, context),
                  icon: const Icon(CutIcons.folder, size: 16),
                  label: const Text('Import video…'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Player extends ConsumerStatefulWidget {
  const _Player();

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  /// The floating transport hides after a moment of no pointer movement
  /// while playing, and comes back on hover.
  bool _idle = false;
  Timer? _idleTimer;

  void _poke() {
    _idleTimer?.cancel();
    if (_idle) setState(() => _idle = false);
    _idleTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _idle = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _poke();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(previewProvider);
    final compact = isCompact(context);
    final glow = ref.watch(ambientGlowProvider) && !reduceEffects(context);
    final inset = compact ? 0.0 : CutSpace.s6;
    final radius = compact ? CutRadii.sm : CutRadii.md;
    final stage = LayoutBuilder(
      builder: (context, box) {
        // Titles are drawn on the exact area the video fills (the export
        // frame), not on the bars around it.
        final f = projectTitleFormat(
          ref.watch(projectEditorProvider.select((s) => s.project)),
        );
        final area = Rect.fromLTRB(
          inset,
          inset,
          box.maxWidth - inset,
          box.maxHeight - inset - (compact ? 0 : 52),
        );
        final frame = applyBoxFit(
          BoxFit.contain,
          Size(f.width.toDouble(), f.height.toDouble()),
          area.size.isEmpty ? const Size(1, 1) : area.size,
        ).destination;
        final rect = Alignment.center.inscribe(frame, area);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (glow && !compact)
              Positioned.fromRect(
                rect: rect.inflate(40),
                child: const IgnorePointer(child: _AmbientGlow()),
              ),
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: compact ? null : CutShadows.e2,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview.buildVideo(),
                      OverlayLayer(onTapEmpty: preview.togglePlay),
                      const TitleLayer(),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: Cut.strokeSubtle),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (compact)
              Positioned(
                left: rect.left + 8,
                top: rect.top + 8,
                child: const IgnorePointer(child: _TimecodeChip()),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: CutSpace.s4,
                child: Center(
                  child: StreamBuilder<bool>(
                    stream: preview.playingStream,
                    initialData: preview.isPlaying,
                    builder: (context, playing) => AnimatedOpacity(
                      duration: _idle ? CutMotion.page : CutMotion.fast,
                      opacity: playing.data! && _idle ? 0 : 1,
                      child: const TransportBar(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
    return Column(
      children: [
        Expanded(
          child: MouseRegion(
            onHover: (_) => _poke(),
            onEnter: (_) => _poke(),
            child: stage,
          ),
        ),
        if (compact) const _CompactTransport(),
        const RecordBar(),
        const OverlayInspector(),
        const AudioInspector(),
        const ClipInspector(),
      ],
    );
  }
}

/// The current frame, blurred big and faint behind the video, so the
/// picture's colours bleed onto the canvas. Uses the timeline's thumbnails
/// (already in memory), so it costs playback nothing.
class _AmbientGlow extends ConsumerStatefulWidget {
  const _AmbientGlow();

  @override
  ConsumerState<_AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends ConsumerState<_AmbientGlow> {
  StreamSubscription<Duration>? _sub;
  PreviewController? _preview;
  Duration _at = Duration.zero;
  final _sinceUpdate = Stopwatch()..start();

  void _listen(PreviewController preview) {
    if (identical(preview, _preview)) return;
    _preview = preview;
    unawaited(_sub?.cancel());
    _at = preview.position;
    _sub = preview.positionStream.listen((t) {
      // Twice a second is plenty for a glow.
      if (_sinceUpdate.elapsedMilliseconds < 500) return;
      _sinceUpdate.reset();
      if (mounted) setState(() => _at = t);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listen(ref.watch(previewProvider));
    final state = ref.watch(projectEditorProvider);
    final project = state.project;
    final hit = project.clipAt(_at) ?? project.clipAt(Duration.zero);
    ui.Image? image;
    if (hit != null) {
      final media = project.mediaById(project.clips[hit.index].mediaId);
      if (media != null && media.kind == MediaKind.video) {
        image = ref
            .watch(
              mediaPreviewProvider(
                ProjectStore.resolve(media.path, state.workPath),
              ),
            )
            .value
            ?.thumbnailAt(hit.sourceTime);
      }
    }
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: image == null
            ? const SizedBox.expand()
            : Opacity(
                key: ValueKey(image),
                opacity: 0.3,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 56,
                    sigmaY: 56,
                    tileMode: TileMode.decal,
                  ),
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Where each clip starts plus the end: the stops for skip back/forward.
List<Duration> _stops(WidgetRef ref) {
  final project = ref.read(projectEditorProvider).project;
  return [...project.clipStarts, project.duration];
}

void _skip(WidgetRef ref, {required bool forward}) {
  final preview = ref.read(previewProvider);
  final now = preview.position;
  final stops = _stops(ref);
  // A little slack so "back" from just after a cut goes to the one before.
  const slack = Duration(milliseconds: 300);
  final target = forward
      ? stops
            .where((s) => s > now + const Duration(milliseconds: 10))
            .firstOrNull
      : stops.reversed.where((s) => s < now - slack).firstOrNull;
  unawaited(preview.seek(target ?? (forward ? stops.last : Duration.zero)));
}

/// The floating glass capsule: skip back, play/pause, skip forward, the
/// timecode, and the ambient glow switch.
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    final glow = ref.watch(ambientGlowProvider);
    return GlassPanel(
      radius: CutRadii.pill,
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EditorToolButton(
              key: const Key('skip-back'),
              size: 32,
              tooltip: 'Previous cut',
              icon: const Icon(CutIcons.skipBack, size: 15),
              color: Cut.textPrimary,
              onPressed: () => _skip(ref, forward: false),
            ),
            const SizedBox(width: 2),
            _PlayButton(preview: preview, size: 36),
            const SizedBox(width: 2),
            EditorToolButton(
              key: const Key('skip-forward'),
              size: 32,
              tooltip: 'Next cut',
              icon: const Icon(CutIcons.skipForward, size: 15),
              color: Cut.textPrimary,
              onPressed: () => _skip(ref, forward: true),
            ),
            const SizedBox(width: 10),
            const _Time(),
            const SizedBox(width: 6),
            Container(width: 1, height: 18, color: Cut.strokeDefault),
            const SizedBox(width: 4),
            EditorToolButton(
              key: const Key('ambient-glow'),
              size: 30,
              tooltip: glow ? 'Turn off the glow' : 'Glow with the video',
              icon: Icon(
                glow ? CutIcons.ambientFill : CutIcons.ambient,
                size: 15,
              ),
              color: glow ? Cut.textPrimary : Cut.textTertiary,
              onPressed: ref.read(ambientGlowProvider.notifier).toggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Round play/pause in the accent colour.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.preview, required this.size});

  final PreviewController preview;
  final double size;

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: preview.playingStream,
    initialData: preview.isPlaying,
    builder: (context, playing) {
      final on = playing.data!;
      return ShortcutTooltip(
        message: on ? 'Pause' : 'Play',
        keys: const ['Space'],
        child: Pressable(
          key: const Key('play'),
          onTap: preview.togglePlay,
          semanticLabel: on ? 'Pause' : 'Play',
          pressedScale: 0.92,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Cut.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Cut.accent.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: CutMotion.fast,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                on ? CutIcons.pause : CutIcons.play,
                key: ValueKey(on),
                size: size * 0.44,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// "00:04.12 / 00:20.00": the playhead bright, the length dimmer.
class _Time extends ConsumerWidget {
  const _Time({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    final total = ref.watch(
      projectEditorProvider.select((s) => s.project.duration),
    );
    return StreamBuilder<Duration>(
      stream: preview.positionStream,
      initialData: preview.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final clamped = position > total ? total : position;
        final style = CutType.timecode.copyWith(
          fontSize: compact ? 12 : 13,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return Text.rich(
          key: const Key('time'),
          TextSpan(
            children: [
              TextSpan(
                text: formatTimecode(clamped),
                style: style.copyWith(color: Cut.textPrimary),
              ),
              TextSpan(
                text: ' / ${formatTimecode(total)}',
                style: style.copyWith(color: Cut.textTertiary),
              ),
            ],
          ),
          maxLines: 1,
        );
      },
    );
  }
}

/// On a phone: a small glass chip over the video with the time.
class _TimecodeChip extends StatelessWidget {
  const _TimecodeChip();

  @override
  Widget build(BuildContext context) => const GlassPanel(
    radius: CutRadii.pill,
    blur: 16,
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: _Time(compact: true),
  );
}

/// On a phone: big play, skip back and forward under the video, in thumb
/// reach. Tapping the video also plays and pauses.
class _CompactTransport extends ConsumerWidget {
  const _CompactTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EditorToolButton(
            key: const Key('skip-back'),
            size: 48,
            tooltip: 'Previous cut',
            icon: const Icon(CutIcons.skipBack, size: 20),
            color: Cut.textSecondary,
            onPressed: () => _skip(ref, forward: false),
          ),
          const SizedBox(width: CutSpace.s5),
          _PlayButton(preview: preview, size: 44),
          const SizedBox(width: CutSpace.s5),
          EditorToolButton(
            key: const Key('skip-forward'),
            size: 48,
            tooltip: 'Next cut',
            icon: const Icon(CutIcons.skipForward, size: 20),
            color: Cut.textSecondary,
            onPressed: () => _skip(ref, forward: true),
          ),
        ],
      ),
    );
  }
}
