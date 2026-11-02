import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../timeline/timeline_panel.dart';
import 'about.dart';
import 'app_menu.dart';
import 'editor_shortcuts.dart';
import 'preview_pane.dart';
import 'settings_dialog.dart';
import 'sidebar.dart';
import 'transcript_panel.dart';

/// The editor on a phone: video on top, timeline below, and the assistant,
/// transcript and memes in a sheet that slides up.
class CompactEditor extends StatelessWidget {
  const CompactEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: AutoTranscribe(
        child: EditorShortcuts(
          child: SafeArea(
            child: Column(
              children: [
                const CompactTopBar(),
                Divider(height: 1, color: colors.outlineVariant),
                // The preview gets a bit more room than the timeline.
                const Expanded(
                  flex: 11,
                  child: PreviewPane(key: Key('preview')),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                const Expanded(
                  flex: 9,
                  child: TimelinePanel(key: Key('timeline')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the assistant, transcript and memes in a sheet covering most of
/// the screen; [tab] picks which one shows first.
Future<void> showSidebarSheet(BuildContext context, {int tab = 0}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Padding(
          // Keep the chat box above the keyboard.
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SizedBox(
            height: (media.size.height - media.viewInsets.bottom) * 0.82,
            child: Sidebar(key: const Key('sidebar'), initialTab: tab),
          ),
        );
      },
    );

/// Project name, undo/redo, the assistant and a menu with everything else.
class CompactTopBar extends ConsumerWidget {
  const CompactTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final editor = ref.read(projectEditorProvider.notifier);
    final theme = Theme.of(context);
    final menus = AppMenuScope.of(context);
    final commands = [
      for (final group in ['File', 'Help'])
        ...?menus[group]?.where((c) => c.onSelected != null),
    ];
    return Container(
      key: const Key('compact-top-bar'),
      height: 52,
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.project.name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.hasUnsavedChanges)
                  Text(
                    'Edited',
                    key: const Key('edited'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: state.canUndo ? 'Undo ${state.undoLabel}' : 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: state.canUndo ? editor.undo : null,
          ),
          IconButton(
            tooltip: state.canRedo ? 'Redo ${state.redoLabel}' : 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: state.canRedo ? editor.redo : null,
          ),
          IconButton.filledTonal(
            key: const Key('open-assistant'),
            tooltip: 'Assistant, transcript and memes',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => showSidebarSheet(context),
          ),
          PopupMenuButton<VoidCallback>(
            key: const Key('compact-menu'),
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              for (final c in commands)
                if (c.label != 'Settings…' && c.label != 'About Cutline')
                  PopupMenuItem(value: c.onSelected, child: Text(c.label)),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: () => showSettings(context),
                child: const Text('Settings…'),
              ),
              PopupMenuItem(
                value: () => showCutlineAbout(context),
                child: const Text('About Cutline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
