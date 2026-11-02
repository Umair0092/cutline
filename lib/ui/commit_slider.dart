import 'package:flutter/material.dart';

/// A slider that shows changes live but only commits (one undo step) when
/// you let go.
class CommitSlider extends StatefulWidget {
  const CommitSlider({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.width = 110,
    this.divisions,
  });

  final IconData icon;
  final String tooltip;
  final double value;
  final double min;
  final double max;
  final double width;
  final int? divisions;
  final ValueChanged<double> onCommit;

  @override
  State<CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<CommitSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 16),
          SizedBox(
            width: widget.width,
            child: Slider(
              value: (_dragging ?? widget.value).clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                if (v != widget.value) widget.onCommit(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
