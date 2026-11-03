import 'package:flutter/material.dart';

import 'tokens.dart';

/// A slider that shows changes live but only commits (one undo step) when
/// you let go. An icon and a short label sit on the left; [format], if
/// given, shows the value in mono on the right.
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
    this.label,
    this.format,
  });

  final IconData icon;
  final String tooltip;
  final double value;
  final double min;
  final double max;
  final double width;
  final int? divisions;
  final ValueChanged<double> onCommit;
  final String? label;
  final String Function(double value)? format;

  @override
  State<CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<CommitSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ?? widget.value).clamp(widget.min, widget.max);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            size: 15,
            color: _dragging != null ? Cut.accent : Cut.textTertiary,
          ),
          if (widget.label != null) ...[
            const SizedBox(width: 6),
            Text(widget.label!, style: CutType.caption),
          ],
          SizedBox(
            width: widget.width,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: value,
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
          ),
          if (widget.format != null)
            SizedBox(
              width: 44,
              child: Text(
                widget.format!(value),
                textAlign: TextAlign.left,
                style: CutType.timecode.copyWith(
                  fontSize: 11,
                  color: _dragging != null ? Cut.textPrimary : Cut.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
