import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../library/project_library.dart';
import '../timeline/timeline_panel.dart';
import 'sidebar.dart';
import 'transcript_panel.dart';
import 'app_menu.dart';
import 'compact_editor.dart';
import 'file_actions.dart';
import 'editor_shortcuts.dart';
import 'export_dialog.dart';
import 'preview_pane.dart';

/// The main editor window: preview on the top left, sidebar on the right,
/// timeline along the bottom.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);
    // Back (button, gesture or Esc) goes to the dashboard via leaveEditor,
    // which saves first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leaveEditor(ref, context);
      },
      child: isCompact(context) ? const CompactEditor() : const _WideEditor(),
    );
  }
}

/// Asks to save changes to a project kept outside the library before
/// leaving it. Returns false if the user cancelled.
Future<bool> confirmLeave(WidgetRef ref, BuildContext context) =>
    FileActions(ref, context).confirmDiscard();

class _WideEditor extends StatelessWidget {
  const _WideEditor();

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
    final path = state.projectPath;
    // Edits in the library save themselves, so "Edited" would only worry.
    final autosaved =
        path != null &&
        (ref.watch(projectLibraryProvider).value?.contains(path) ?? false);
    final canGoBack = Navigator.of(context).canPop();
    return Container(
      height: 40,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (canGoBack)
            Positioned(
              left: 8,
              child: TextButton.icon(
                key: const Key('back-to-edits'),
                onPressed: () => leaveEditor(ref, context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Your edits'),
              ),
            ),
          if (state.project.clips.isNotEmpty)
            Positioned(
              right: 8,
              child: FilledButton.icon(
                key: const Key('export-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => showExportFlow(ref, context),
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Export'),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => renameProjectFlow(ref, context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.project.name, style: theme.textTheme.titleSmall),
                  if (state.hasUnsavedChanges && !autosaved) ...[
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
            ),
          ),
        ],
      ),
    );
  }
}
