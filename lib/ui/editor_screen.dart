import 'package:flutter/material.dart';

/// The main editor window: preview on the top left, sidebar on the right,
/// timeline along the bottom.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  static const sidebarWidth = 340.0;
  static const timelineHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const Expanded(
                  child: EditorPane(
                    key: Key('preview'),
                    label: 'Preview',
                    icon: Icons.play_circle_outline,
                  ),
                ),
                VerticalDivider(width: 1, color: colors.outlineVariant),
                const SizedBox(
                  width: sidebarWidth,
                  child: EditorPane(
                    key: Key('sidebar'),
                    label: 'Assistant',
                    icon: Icons.auto_awesome,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(
            height: timelineHeight,
            child: EditorPane(
              key: Key('timeline'),
              label: 'Timeline',
              icon: Icons.view_timeline_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for an area of the editor that isn't built yet.
class EditorPane extends StatelessWidget {
  const EditorPane({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
