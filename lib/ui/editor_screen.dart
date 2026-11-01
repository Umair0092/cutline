import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../timeline/timeline_panel.dart';
import 'sidebar.dart';
import 'transcript_panel.dart';
import 'editor_shortcuts.dart';
import 'preview_pane.dart';

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
      body: AutoTranscribe(
        child: EditorShortcuts(
          child: Column(
            children: [
              const ProjectTitleBar(),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: Row(
                  children: [
                    const Expanded(child: PreviewPane(key: Key('preview'))),
                    VerticalDivider(width: 1, color: colors.outlineVariant),
                    const SizedBox(
                      width: sidebarWidth,
                      child: Sidebar(key: Key('sidebar')),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(
                height: timelineHeight,
                child: TimelinePanel(key: Key('timeline')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the project name, and "Edited" when there are unsaved changes.
class ProjectTitleBar extends ConsumerWidget {
  const ProjectTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final theme = Theme.of(context);
    return Container(
      height: 36,
      color: theme.colorScheme.surfaceContainer,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.project.name, style: theme.textTheme.titleSmall),
          if (state.hasUnsavedChanges) ...[
            const SizedBox(width: 8),
            Text(
              'Edited',
              key: const Key('edited'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
