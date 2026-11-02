import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../widgets/cut_widgets.dart';

/// "⌘" on a Mac, "Ctrl" elsewhere, for shortcut hints.
String get modKey =>
    defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl';

/// A tooltip that names the action and shows its shortcut as key caps.
class ShortcutTooltip extends StatelessWidget {
  const ShortcutTooltip({
    super.key,
    required this.message,
    required this.child,
    this.keys = const [],
  });

  final String message;
  final List<String> keys;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty || isTouchPlatform) {
      return Tooltip(message: message, child: child);
    }
    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(text: message),
          const WidgetSpan(child: SizedBox(width: 8)),
          for (final k in keys) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: KeyCap(k),
            ),
            const WidgetSpan(child: SizedBox(width: 3)),
          ],
        ],
      ),
      child: child,
    );
  }
}

/// A square icon button for editor toolbars: quiet at rest, a soft fill on
/// hover, accent container when [selected]. [icon] can be any widget, so
/// AI actions can pass an aurora-painted icon.
class EditorToolButton extends StatelessWidget {
  const EditorToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.keys = const [],
    this.selected = false,
    this.size,
    this.color,
  });

  final Widget icon;
  final String tooltip;
  final List<String> keys;
  final VoidCallback? onPressed;
  final bool selected;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? (isTouchPlatform ? 44.0 : 32.0);
    return ShortcutTooltip(
      message: tooltip,
      keys: keys,
      child: SizedBox.square(
        dimension: s,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          isSelected: selected,
          iconSize: isTouchPlatform ? 22 : 18,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Cut.accentContainer
                  : null,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? Cut.textDisabled
                  : states.contains(WidgetState.selected)
                  ? Cut.onAccentContainer
                  : states.contains(WidgetState.hovered)
                  ? Cut.textPrimary
                  : color ?? Cut.textSecondary,
            ),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? Cut.pressed
                  : states.contains(WidgetState.hovered)
                  ? Cut.hover.withValues(alpha: 0.07)
                  : null,
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CutRadii.sm),
              ),
            ),
          ),
          icon: icon,
        ),
      ),
    );
  }
}

/// A thin upright line between groups of toolbar buttons.
class ToolbarGap extends StatelessWidget {
  const ToolbarGap({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: CutSpace.s2),
    color: Cut.strokeDefault,
  );
}
