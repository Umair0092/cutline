import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/overlay_item.dart';
import '../model/project.dart';
import '../preview/playhead_clock.dart';
import '../preview/preview_controller.dart';
import '../storage/project_store.dart';
import '../timeline/timeline_state.dart';
import 'overlay_frames.dart';
import 'overlay_paint.dart';

/// Size of the resize handle's hit area, in pixels.
const _handleRadius = 12.0;

/// Draws the overlays on screen at the playhead over the video, and lets
/// you click one to select it, drag it to move it and drag its corner to
/// resize it. A drag is one undo step.
class OverlayLayer extends ConsumerStatefulWidget {
  const OverlayLayer({super.key});

  @override
  ConsumerState<OverlayLayer> createState() => _OverlayLayerState();
}

enum _Drag { move, resize }

class _OverlayLayerState extends ConsumerState<OverlayLayer>
    with SingleTickerProviderStateMixin {
  late final PlayheadClock _clock = PlayheadClock(
    ref.read(previewProvider),
    this,
  );

  _Drag? _drag;
  String? _dragId;
  OverlayTransform? _draft;
  OverlayTransform _from = const OverlayTransform();
  Offset _grab = Offset.zero;
  MouseCursor _cursor = MouseCursor.defer;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Project get _project => ref.read(projectEditorProvider).project;

  double _aspect(OverlayItem o) {
    final m = _project.mediaById(o.mediaId);
    return m == null || m.height == 0 ? 1 : m.width / m.height;
  }

  /// Overlays on screen now, top first.
  List<OverlayItem> _onScreen() {
    final now = _clock.now;
    return [
      for (final o in _project.overlays)
        if (now >= o.start && now < o.end) o,
    ]..sort((a, b) => b.layer.compareTo(a.layer));
  }

  OverlayItem? _hit(Offset at, Size size) {
    for (final o in _onScreen()) {
      final rect = overlayRect(size, _aspect(o), o.transform);
      if (rect.contains(unrotate(at, rect, o.transform.rotation))) return o;
    }
    return null;
  }

  /// The selected overlay if [at] is on its resize handle.
  OverlayItem? _onHandle(Offset at, Size size) {
    final id = ref.read(timelineUiProvider).selectedOverlayId;
    final o = _onScreen().where((o) => o.id == id).firstOrNull;
    if (o == null) return null;
    final rect = overlayRect(size, _aspect(o), o.transform);
    final corner = rotateAround(rect.bottomRight, rect, o.transform.rotation);
    return (corner - at).distance <= _handleRadius ? o : null;
  }

  void _onTapUp(TapUpDetails d, Size size) {
    final hit = _hit(d.localPosition, size);
    final ui = ref.read(timelineUiProvider.notifier);
    if (hit != null) {
      ui.selectOverlay(hit.id);
    } else if (ref.read(timelineUiProvider).selectedOverlayId != null) {
      ui.selectOverlay(null);
    }
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final handle = _onHandle(d.localPosition, size);
    final o = handle ?? _hit(d.localPosition, size);
    if (o == null) return;
    ref.read(timelineUiProvider.notifier).selectOverlay(o.id);
    setState(() {
      _drag = handle != null ? _Drag.resize : _Drag.move;
      _dragId = o.id;
      _from = o.transform;
      _draft = o.transform;
      _grab = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_drag == null) return;
    final now = d.localPosition;
    setState(() {
      if (_drag == _Drag.move) {
        final delta = now - _grab;
        _draft = _from.copyWith(
          x: (_from.x + delta.dx / size.width).clamp(0.0, 1.0),
          y: (_from.y + delta.dy / size.height).clamp(0.0, 1.0),
        );
      } else {
        final centre = Offset(_from.x * size.width, _from.y * size.height);
        final before = (_grab - centre).distance;
        if (before < 1) return;
        _draft = _from.copyWith(
          scale: (_from.scale * (now - centre).distance / before).clamp(
            0.02,
            3.0,
          ),
        );
      }
    });
  }

  void _onPanEnd() {
    final id = _dragId;
    final draft = _draft;
    setState(() {
      _drag = null;
      _dragId = null;
      _draft = null;
    });
    if (id == null || draft == null || draft == _from) return;
    try {
      ref
          .read(projectEditorProvider.notifier)
          .run(UpdateOverlay(id, transform: draft));
    } on EditException catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onHover(PointerHoverEvent e, Size size) {
    final cursor = _onHandle(e.localPosition, size) != null
        ? SystemMouseCursors.resizeUpLeftDownRight
        : _hit(e.localPosition, size) != null
        ? SystemMouseCursors.move
        : MouseCursor.defer;
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectEditorProvider);
    final selected = ref.watch(
      timelineUiProvider.select((s) => s.selectedOverlayId),
    );
    final project = state.project;
    // Frames for every overlay load up front, so they're ready on time.
    final frames = <String, OverlayFrames>{};
    for (final o in project.overlays) {
      final media = project.mediaById(o.mediaId);
      if (media == null) continue;
      final f = ref
          .watch(
            overlayFramesProvider((
              path: ProjectStore.resolve(media.path, state.workPath),
              media: media,
            )),
          )
          .value;
      if (f != null) frames[o.id] = f;
    }
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return MouseRegion(
          cursor: _cursor,
          onHover: (e) => _onHover(e, size),
          child: GestureDetector(
            key: const Key('overlay-layer'),
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (d) => _onTapUp(d, size),
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            child: ListenableBuilder(
              listenable: _clock,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _OverlaysPainter(
                  overlays: project.overlays,
                  frames: frames,
                  now: _clock.now,
                  selectedId: selected,
                  draft: _draft == null ? null : (id: _dragId!, t: _draft!),
                  selection: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverlaysPainter extends CustomPainter {
  _OverlaysPainter({
    required this.overlays,
    required this.frames,
    required this.now,
    required this.selectedId,
    required this.draft,
    required this.selection,
  });

  final List<OverlayItem> overlays;
  final Map<String, OverlayFrames> frames;
  final Duration now;
  final String? selectedId;
  final ({String id, OverlayTransform t})? draft;
  final Color selection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final visible = [
      for (final o in overlays)
        if (now >= o.start && now < o.end) o,
    ]..sort((a, b) => a.layer.compareTo(b.layer));
    for (final o in visible) {
      final f = frames[o.id];
      if (f == null) continue;
      final local = now - o.start;
      final image = f.frameAt(local);
      final t = draft?.id == o.id ? draft!.t : o.transform;
      paintOverlay(
        canvas,
        size,
        image,
        o,
        local.inMicroseconds / 1e6,
        transform: t,
      );
      if (o.id == selectedId) {
        _paintSelection(
          canvas,
          overlayRect(size, image.width / image.height, t),
          t,
        );
      }
    }
  }

  void _paintSelection(Canvas canvas, Rect rect, OverlayTransform t) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = selection;
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..rotate(t.rotation * 3.141592653589793 / 180)
      ..translate(-rect.center.dx, -rect.center.dy)
      ..drawRect(rect, line)
      ..drawCircle(rect.bottomRight, 6, Paint()..color = selection)
      ..drawCircle(
        rect.bottomRight,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OverlaysPainter old) =>
      old.now != now ||
      old.overlays != overlays ||
      old.frames.length != frames.length ||
      old.selectedId != selectedId ||
      old.draft != draft;
}
