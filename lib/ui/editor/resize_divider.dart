import 'package:flutter/material.dart';

import '../tokens.dart';

/// A 6 px horizontal strip you drag up and down to resize what's below
/// it. A small grip shows on hover; the line lights up while dragging.
class ResizeDivider extends StatefulWidget {
  const ResizeDivider({super.key, required this.onDrag, this.onReset});

  /// Called with how far the pointer moved, in pixels (down is positive).
  final ValueChanged<double> onDrag;

  /// Double-click puts the size back.
  final VoidCallback? onReset;

  @override
  State<ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<ResizeDivider> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const Key('timeline-divider'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
        onVerticalDragEnd: (_) => setState(() => _dragging = false),
        onVerticalDragCancel: () => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          height: 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 2.5,
                height: 1,
                child: AnimatedContainer(
                  duration: CutMotion.fast,
                  color: _dragging
                      ? Cut.accent.withValues(alpha: 0.6)
                      : Cut.strokeSubtle,
                ),
              ),
              AnimatedOpacity(
                duration: CutMotion.fast,
                opacity: active ? 1 : 0,
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _dragging ? Cut.accent : Cut.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
