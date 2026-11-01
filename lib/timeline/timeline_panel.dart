import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../media/media_previews.dart';
import '../preview/preview_controller.dart';
import '../storage/project_store.dart';
import '../export/exporter.dart';
import '../model/title_item.dart';
import '../titles/title_actions.dart';
import '../titles/title_editor_dialog.dart';
import 'timeline_geometry.dart';
import 'timeline_layout.dart';
import 'timeline_painter.dart';
import 'timeline_state.dart';

/// Splits the main track at the playhead. Shared by the toolbar and the S key.
void splitAtPlayhead(WidgetRef ref, BuildContext context) {
  final at = ref.read(previewProvider).position;
  _runOrShow(ref, context, SplitAt(at));
}

/// Deletes the selected title or clip. Shared by the toolbar and
/// Delete/Backspace.
void deleteSelectedClip(WidgetRef ref, BuildContext context) {
  final titleId = ref.read(timelineUiProvider).selectedTitleId;
  if (titleId != null) {
    if (ref
        .read(projectEditorProvider)
        .project
        .titles
        .any((t) => t.id == titleId)) {
      _runOrShow(ref, context, RemoveTitle(titleId));
    }
    ref.read(timelineUiProvider.notifier).selectTitle(null);
    return;
  }
  final id = ref.read(timelineUiProvider).selectedClipId;
  if (id == null) return;
  if (ref.read(projectEditorProvider).project.clipIndex(id) < 0) {
    // The clip went away (e.g. undo) since it was selected.
    ref.read(timelineUiProvider.notifier).select(null);
    return;
  }
  if (ref.read(projectEditorProvider).project.clips.length == 1) {
    _show(context, 'Can\'t delete the only clip. Use New Project instead.');
    return;
  }
  if (_runOrShow(ref, context, RemoveClip(id))) {
    ref.read(timelineUiProvider.notifier).select(null);
  }
}

bool _runOrShow(WidgetRef ref, BuildContext context, EditCommand command) {
  try {
    ref.read(projectEditorProvider.notifier).run(command);
    return true;
  } on EditException catch (e) {
    _show(context, e.message);
    return false;
  }
}

/// Opens the title editor and adds what the user makes. Titles over the
/// video start at the playhead.
Future<void> addTitleFlow(WidgetRef ref, BuildContext context) async {
  final project = ref.read(projectEditorProvider).project;
  final f = projectTitleFormat(project);
  final edit = await showTitleEditor(context, aspectRatio: f.width / f.height);
  if (edit == null || !context.mounted) return;
  final playhead = ref.read(previewProvider).position;
  await _withProgress(
    context,
    edit.placement == TitlePlacement.before,
    () => addTitle(ref, edit.spec, edit.placement, start: playhead),
  );
}

/// Edits a title over the video, or an intro clip made from a template.
Future<void> editTitleFlow(
  WidgetRef ref,
  BuildContext context, {
  String? titleId,
  String? introMediaId,
}) async {
  final project = ref.read(projectEditorProvider).project;
  final f = projectTitleFormat(project);
  final spec = titleId != null
      ? project.titles.where((t) => t.id == titleId).firstOrNull?.spec
      : project.mediaById(introMediaId!)?.title;
  if (spec == null) return;
  final edit = await showTitleEditor(
    context,
    initial: spec,
    placement: titleId != null ? TitlePlacement.over : TitlePlacement.before,
    aspectRatio: f.width / f.height,
  );
  if (edit == null || edit.spec == spec || !context.mounted) return;
  await _withProgress(
    context,
    titleId == null,
    () => titleId != null
        ? updateOverlayTitle(ref, titleId, edit.spec)
        : updateIntroClip(ref, introMediaId!, edit.spec),
  );
}

/// Intros before the video are rendered to a clip, which takes a moment.
Future<void> _withProgress(
  BuildContext context,
  bool rendering,
  Future<void> Function() work,
) async {
  if (rendering) _show(context, 'Making the intro…');
  try {
    await work();
    if (rendering && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  } on EditException catch (e) {
    if (context.mounted) _show(context, e.message);
  } on ExportException catch (e) {
    if (context.mounted) _show(context, e.message);
  }
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class TimelinePanel extends ConsumerWidget {
  const TimelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          const _Toolbar(),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: hasClips
                ? const TimelineTracks()
                : Center(
                    child: Text(
                      'Import a video to start editing',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(timelineUiProvider);
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );
    final zoom = ref.read(timelineUiProvider.notifier);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            key: const Key('split'),
            tooltip: 'Split at playhead (S)',
            icon: const Icon(Icons.content_cut, size: 18),
            onPressed: hasClips ? () => splitAtPlayhead(ref, context) : null,
          ),
          IconButton(
            key: const Key('delete'),
            tooltip: 'Delete (Delete)',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: ui.selectedClipId != null || ui.selectedTitleId != null
                ? () => deleteSelectedClip(ref, context)
                : null,
          ),
          IconButton(
            key: const Key('add-title'),
            tooltip: 'Add title or intro',
            icon: const Icon(Icons.title, size: 18),
            onPressed: hasClips ? () => addTitleFlow(ref, context) : null,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Zoom out (-)',
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: () => zoom.zoomBy(1 / 1.5),
          ),
          SizedBox(
            width: 120,
            child: Slider(
              // Log scale so the slider feels even from minutes to frames.
              value: math.log(ui.pixelsPerSecond),
              min: math.log(0.5),
              max: math.log(600),
              onChanged: (v) => zoom.setZoom(math.exp(v)),
            ),
          ),
          IconButton(
            tooltip: 'Zoom in (=)',
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: () => zoom.zoomBy(1.5),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// The scrollable tracks area with all the mouse interactions.
class TimelineTracks extends ConsumerStatefulWidget {
  const TimelineTracks({super.key});

  @override
  ConsumerState<TimelineTracks> createState() => _TimelineTracksState();
}

enum _DragKind { scrub, trim, move, moveTitle }

class _TimelineTracksState extends ConsumerState<TimelineTracks> {
  final _scroll = ScrollController();
  final _position = ValueNotifier(Duration.zero);
  StreamSubscription<Duration>? _positionSub;
  PreviewController? _preview;

  TimelineDrag? _drag;
  _DragKind? _dragKind;
  double _dragStartX = 0;

  /// Distance from the grabbed edge to the pointer, so the edge doesn't
  /// jump when grabbed slightly off-centre.
  double _grabOffset = 0;
  MouseCursor _cursor = SystemMouseCursors.basic;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    _scroll.dispose();
    _position.dispose();
    super.dispose();
  }

  void _listenTo(PreviewController preview) {
    if (identical(preview, _preview)) return;
    _preview = preview;
    unawaited(_positionSub?.cancel());
    _position.value = preview.position;
    _positionSub = preview.positionStream.listen((t) {
      _position.value = t;
      _followPlayhead(t);
    });
  }

  /// Keeps the playhead on screen while playing.
  void _followPlayhead(Duration t) {
    if (!_scroll.hasClients || _drag != null) return;
    final g = _geometry();
    final x = g.xOf(t);
    final view = _scroll.position;
    if (x > view.pixels + view.viewportDimension - 24 || x < view.pixels) {
      _scroll.jumpTo(
        (x - view.viewportDimension * 0.1).clamp(0, view.maxScrollExtent),
      );
    }
  }

  TimelineGeometry _geometry() => TimelineGeometry(
    project: ref.read(projectEditorProvider).project,
    pixelsPerSecond: ref.read(timelineUiProvider).pixelsPerSecond,
  );

  ({String id, Duration start})? _titleDrag;
  Duration _titleGrab = Duration.zero;
  Offset? _doubleTapAt;

  // Double-clicks are detected here instead of with a double-tap
  // recognizer, which would delay every single click by ~300 ms.
  Offset? _lastTapAt;
  final _sinceLastTap = Stopwatch();

  bool _isDoubleClick(Offset at) {
    final last = _lastTapAt;
    final quick =
        _sinceLastTap.isRunning &&
        _sinceLastTap.elapsed < const Duration(milliseconds: 350);
    _lastTapAt = at;
    _sinceLastTap
      ..reset()
      ..start();
    return last != null && quick && (last - at).distance < 6;
  }

  bool _inTitleRow(double y) =>
      y >= TimelineRows.overlayTop &&
      y <= TimelineRows.overlayTop + TimelineRows.rowHeight;

  /// The title under the pointer in the titles row, if any.
  TitleItem? _hitTitle(Offset at) {
    if (!_inTitleRow(at.dy)) return null;
    final g = _geometry();
    final t = g.timeAt(at.dx);
    return g.project.titles.reversed
        .where((x) => t >= x.start && t < x.end)
        .firstOrNull;
  }

  void _onDoubleTap() {
    final at = _doubleTapAt;
    if (at == null) return;
    final title = _hitTitle(at);
    if (title != null) {
      unawaited(editTitleFlow(ref, context, titleId: title.id));
      return;
    }
    if (!_inVideoRow(at.dy)) return;
    final g = _geometry();
    final hit = g.hitClip(at.dx);
    if (hit == null) return;
    final media = g.project.mediaById(g.project.clips[hit.index].mediaId);
    if (media?.title != null) {
      unawaited(editTitleFlow(ref, context, introMediaId: media!.id));
    }
  }

  bool _inVideoRow(double y) =>
      y >= TimelineRows.videoTop &&
      y <= TimelineRows.waveTop + TimelineRows.waveHeight;

  void _seekTo(double x) {
    final g = _geometry();
    final total = g.project.duration;
    var t = g.timeAt(x);
    if (t > total) t = total;
    _position.value = t;
    unawaited(ref.read(previewProvider).seek(t));
  }

  void _onHover(PointerHoverEvent e) {
    final hit = _inVideoRow(e.localPosition.dy)
        ? _geometry().hitClip(e.localPosition.dx)
        : null;
    final cursor = switch (hit?.zone) {
      ClipZone.leftEdge ||
      ClipZone.rightEdge => SystemMouseCursors.resizeLeftRight,
      ClipZone.body => SystemMouseCursors.grab,
      null => SystemMouseCursors.basic,
    };
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  void _onTapUp(TapUpDetails d) {
    if (_isDoubleClick(d.localPosition)) {
      _doubleTapAt = d.localPosition;
      _onDoubleTap();
      return;
    }
    final title = _hitTitle(d.localPosition);
    if (title != null) {
      ref.read(timelineUiProvider.notifier).selectTitle(title.id);
      _seekTo(d.localPosition.dx);
      return;
    }
    final g = _geometry();
    final hit = _inVideoRow(d.localPosition.dy)
        ? g.hitClip(d.localPosition.dx)
        : null;
    ref
        .read(timelineUiProvider.notifier)
        .select(hit == null ? null : g.project.clips[hit.index].id);
    _seekTo(d.localPosition.dx);
  }

  void _onPanStart(DragStartDetails d) {
    final title = _hitTitle(d.localPosition);
    if (title != null) {
      ref.read(timelineUiProvider.notifier).selectTitle(title.id);
      _titleGrab = _geometry().timeAt(d.localPosition.dx) - title.start;
      setState(() {
        _dragKind = _DragKind.moveTitle;
        _titleDrag = (id: title.id, start: title.start);
      });
      return;
    }
    final g = _geometry();
    final hit = _inVideoRow(d.localPosition.dy)
        ? g.hitClip(d.localPosition.dx)
        : null;
    _dragStartX = d.localPosition.dx;
    if (hit == null) {
      _dragKind = _DragKind.scrub;
      _seekTo(d.localPosition.dx);
      return;
    }
    ref.read(timelineUiProvider.notifier).select(g.project.clips[hit.index].id);
    final start = g.project.clipStarts[hit.index];
    setState(() {
      if (hit.zone == ClipZone.body) {
        _dragKind = _DragKind.move;
        _drag = MoveDrag(index: hit.index, dx: 0, x: d.localPosition.dx);
      } else {
        final left = hit.zone == ClipZone.leftEdge;
        final edge = left ? start : start + g.project.clips[hit.index].duration;
        _dragKind = _DragKind.trim;
        _grabOffset = d.localPosition.dx - g.xOf(edge);
        _drag = TrimDrag(index: hit.index, left: left, edgeTime: edge);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final g = _geometry();
    final drag = _drag;
    switch (_dragKind) {
      case _DragKind.scrub:
        _seekTo(d.localPosition.dx);
      case _DragKind.move when drag is MoveDrag:
        setState(() {
          _drag = MoveDrag(
            index: drag.index,
            dx: d.localPosition.dx - _dragStartX,
            x: d.localPosition.dx,
          );
        });
      case _DragKind.moveTitle when _titleDrag != null:
        var start = g.timeAt(d.localPosition.dx) - _titleGrab;
        if (start < Duration.zero) start = Duration.zero;
        start = g.snap(start, [
          Duration.zero,
          _position.value,
          ...g.project.clipStarts,
        ]);
        setState(() => _titleDrag = (id: _titleDrag!.id, start: start));
      case _DragKind.trim when drag is TrimDrag:
        final raw = g.timeAt(d.localPosition.dx - _grabOffset);
        final targets = [
          _position.value,
          ...g.project.clipStarts,
          g.project.duration,
        ];
        setState(() {
          _drag = TrimDrag(
            index: drag.index,
            left: drag.left,
            edgeTime: g.snap(raw, targets),
          );
        });
      default:
    }
  }

  void _onPanEnd(DragEndDetails _) {
    final titleDrag = _titleDrag;
    if (_dragKind == _DragKind.moveTitle && titleDrag != null) {
      setState(() {
        _titleDrag = null;
        _dragKind = null;
      });
      _runOrShow(
        ref,
        context,
        UpdateTitle(titleDrag.id, start: titleDrag.start),
      );
      return;
    }
    final g = _geometry();
    final drag = _drag;
    setState(() {
      _drag = null;
      _dragKind = null;
    });
    final clipId = switch (drag) {
      TrimDrag(:final index) ||
      MoveDrag(:final index) => g.project.clips[index].id,
      null => null,
    };
    try {
      switch (drag) {
        case TrimDrag():
          final r = trimResult(g.project, drag);
          ref
              .read(projectEditorProvider.notifier)
              .run(
                TrimClip(
                  clipId!,
                  sourceStart: r.sourceStart,
                  sourceEnd: r.sourceEnd,
                ),
              );
        case MoveDrag():
          final to = g.dropIndex(drag.x, drag.index);
          if (to != drag.index) {
            ref.read(projectEditorProvider.notifier).run(MoveClip(clipId!, to));
          }
        case null:
      }
    } on EditException catch (e) {
      _show(context, e.message);
    }
  }

  /// Ctrl/Cmd + scroll wheel zooms, plain scroll pans sideways.
  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isControlPressed) {
      ref
          .read(timelineUiProvider.notifier)
          .zoomBy(e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
    } else if (_scroll.hasClients) {
      final delta = e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
      _scroll.jumpTo(
        (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectEditorProvider);
    final ui = ref.watch(timelineUiProvider);
    _listenTo(ref.watch(previewProvider));

    final project = state.project;
    final g = TimelineGeometry(
      project: project,
      pixelsPerSecond: ui.pixelsPerSecond,
    );
    final previews = <String, MediaPreview>{
      for (final m in project.media)
        m.id:
            ref
                .watch(
                  mediaPreviewProvider(
                    ProjectStore.resolve(m.path, state.workPath),
                  ),
                )
                .value ??
            MediaPreview.empty,
    };
    final colors = TimelineColors.of(Theme.of(context).colorScheme);
    final drag = _drag;
    final boxes = layoutClips(g, drag: drag);
    double? dropX;
    if (drag is MoveDrag) {
      final to = g.dropIndex(drag.x, drag.index);
      final others = [
        for (var i = 0; i < project.clips.length; i++)
          if (i != drag.index) boxes[i],
      ];
      dropX = to < others.length
          ? others[to].left
          : (others.lastOrNull?.right ?? g.leftPadding);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = g.contentWidth > constraints.maxWidth
            ? g.contentWidth
            : constraints.maxWidth;
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        final visible = (left: offset, right: offset + constraints.maxWidth);
        return Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: MouseRegion(
                cursor: _dragKind == _DragKind.move
                    ? SystemMouseCursors.grabbing
                    : _cursor,
                onHover: _onHover,
                child: GestureDetector(
                  key: const Key('timeline-tracks'),
                  behavior: HitTestBehavior.opaque,
                  // Report where the pointer went down, not where it was
                  // once it had moved far enough to count as a drag, so
                  // grabbing an edge grabs that edge.
                  dragStartBehavior: DragStartBehavior.down,
                  onTapUp: _onTapUp,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: SizedBox(
                    width: width,
                    height: constraints.maxHeight,
                    child: CustomPaint(
                      painter: TracksPainter(
                        geometry: g,
                        boxes: boxes,
                        previews: previews,
                        colors: colors,
                        selectedClipId: ui.selectedClipId,
                        dropX: dropX,
                        visible: visible,
                        selectedTitleId: ui.selectedTitleId,
                        titleDrag: _titleDrag,
                      ),
                      foregroundPainter: PlayheadPainter(
                        geometry: g,
                        position: _position,
                        color: colors.playhead,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
