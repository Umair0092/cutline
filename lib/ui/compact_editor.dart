import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music/music_panel.dart';

import '../audio/recording.dart';
import '../editing/commands.dart';
import '../editing/project_editor.dart';
import '../library/project_library.dart';
import '../overlays/overlay_actions.dart';
import '../timeline/timeline_state.dart';
import '../timeline/timeline_panel.dart';
import '../voice/voiceover_dialog.dart';
import 'about.dart';
import 'app_menu.dart';
import 'editor_screen.dart';
import 'editor_shortcuts.dart';
import 'export_dialog.dart';
import 'preview_pane.dart';
import 'settings_dialog.dart';
import 'sidebar.dart';
import 'theme.dart';
import 'transcript_panel.dart';

/// The editor on a phone: the video on top, the timeline under it, and
/// the things you do most as labelled buttons along the bottom.
class CompactEditor extends ConsumerWidget {
  const CompactEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );
    return Scaffold(
      body: AutoTranscribe(
        child: EditorShortcuts(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const CompactTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // The video gets the height of a 16:9 frame plus its
                      // play bar (more when an inspector is open), never
                      // more than about half the screen; the timeline gets
                      // the rest.
                      final frame = (box.maxWidth - 20) * 9 / 16 + 60;
                      final inspector = ref.watch(
                        timelineUiProvider.select(
                          (u) =>
                              u.selectedClipId != null ||
                              u.selectedOverlayId != null ||
                              u.selectedAudioId != null,
                        ),
                      );
                      final preview = (frame + (inspector ? 96 : 0)).clamp(
                        160.0,
                        box.maxHeight * 0.6,
                      );
                      return Column(
                        children: [
                          SizedBox(
                            height: preview,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(Radii.card),
                                child: const PreviewPane(key: Key('preview')),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          const Expanded(
                            child: TimelinePanel(key: Key('timeline')),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (hasClips) const _ActionBar(),
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

/// Back to your edits, the name, undo/redo and Export.
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
        ...?menus[group]?.where(
          (c) =>
              c.onSelected != null &&
              !{'Settings…', 'About Cutline', 'Export…'}.contains(c.label),
        ),
    ];
    final canGoBack = Navigator.of(context).canPop();
    return SizedBox(
      key: const Key('compact-top-bar'),
      height: 56,
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              key: const Key('back-to-edits'),
              tooltip: 'Your edits',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => leaveEditor(ref, context),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.chip),
              onTap: () => renameProjectFlow(ref, context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  state.project.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          const SizedBox(width: 4),
          FilledButton(
            key: const Key('compact-export'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 38),
            ),
            onPressed: state.project.clips.isEmpty
                ? null
                : () => showExportFlow(ref, context),
            child: const Text('Export'),
          ),
          PopupMenuButton<VoidCallback>(
            key: const Key('compact-menu'),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              for (final c in commands)
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

/// Renames the edit (the name shows on the dashboard and in exports).
Future<void> renameProjectFlow(WidgetRef ref, BuildContext context) async {
  final controller = TextEditingController(
    text: ref.read(projectEditorProvider).project.name,
  );
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename edit'),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  ref.read(projectEditorProvider.notifier).run(RenameProject(name));
}

/// What you do most, with words under the icons.
class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget action(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool accent = false,
    }) => Expanded(
      child: InkWell(
        key: Key(key),
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: accent ? Palette.cut : null,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: accent ? Colors.white : Palette.paper,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: Palette.dust),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Palette.bench,
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      padding: EdgeInsets.fromLTRB(6, 2, 6, bottom + 2),
      child: Row(
        children: [
          action(
            'action-ask',
            Icons.auto_awesome,
            'Ask AI',
            () => showSidebarSheet(context),
            accent: true,
          ),
          action(
            'action-text',
            Icons.title,
            'Text',
            () => addTitleFlow(ref, context),
          ),
          action(
            'action-memes',
            Icons.emoji_emotions_outlined,
            'Memes',
            () => _memes(context, ref),
          ),
          action(
            'action-audio',
            Icons.graphic_eq,
            'Audio',
            () => _audio(context, ref),
          ),
          action(
            'action-split',
            Icons.content_cut,
            'Split',
            () => splitAtPlayhead(ref, context),
          ),
        ],
      ),
    );
  }

  Future<void> _memes(BuildContext context, WidgetRef ref) async {
    final choice = await _choose(context, [
      (Icons.search, 'Search memes and GIFs', 'search'),
      (Icons.add_photo_alternate_outlined, 'Add a picture or video', 'file'),
    ]);
    if (!context.mounted) return;
    if (choice == 'search') {
      await showSidebarSheet(context, tab: 2);
    } else if (choice == 'file') {
      await pickAndAddOverlay(ref, context);
    }
  }

  Future<void> _audio(BuildContext context, WidgetRef ref) async {
    final choice = await _choose(context, [
      (Icons.mic_none, 'Record a voiceover', 'record'),
      (Icons.record_voice_over_outlined, 'Voiceover from a script', 'script'),
      (Icons.library_music_outlined, 'Add music or a sound', 'music'),
      (Icons.tune, 'Sound levels', 'levels'),
    ]);
    if (!context.mounted) return;
    if (choice == 'record') {
      await ref.read(recordingProvider.notifier).show();
    } else if (choice == 'script') {
      await showVoiceoverDialog(context);
    } else if (choice == 'music') {
      await showMusicBrowser(context);
    } else if (choice == 'levels') {
      await showMixSheet(context);
    }
  }

  Future<String?> _choose(
    BuildContext context,
    List<(IconData, String, String)> options,
  ) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label, value) in options)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Leaves the editor for the dashboard: edits in the library are saved
/// first; others ask to save if they have changes.
Future<void> leaveEditor(WidgetRef ref, BuildContext context) async {
  final state = ref.read(projectEditorProvider);
  final library = await ref.read(projectLibraryProvider.future);
  final path = state.projectPath;
  if (path != null && library.contains(path)) {
    await ref.read(autosaveProvider).flush();
  } else if (context.mounted && !await confirmLeave(ref, context)) {
    return;
  }
  ref.invalidate(projectListProvider);
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (nav.canPop()) nav.pop();
}
