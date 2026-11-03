import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/recording.dart';
import '../editing/commands.dart';
import '../editing/project_editor.dart';
import '../library/project_library.dart';
import '../music/music_panel.dart';
import '../overlays/overlay_actions.dart';
import '../timeline/timeline_panel.dart';
import '../timeline/timeline_state.dart';
import '../voice/voiceover_dialog.dart';
import 'about.dart';
import 'app_menu.dart';
import 'assistant/chat_draft.dart';
import 'editor_screen.dart';
import 'editor_shortcuts.dart';
import 'export_dialog.dart';
import 'preview_pane.dart';
import 'settings_dialog.dart';
import 'sidebar.dart';
import 'tokens.dart';
import 'transcript_panel.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// The editor on a phone: the video on top, the timeline under it, and
/// the things you do most in a floating glass bar along the bottom, with
/// Ask AI as the hero.
class CompactEditor extends ConsumerWidget {
  const CompactEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);
    final hasClips = ref.watch(
      projectEditorProvider.select((s) => s.project.clips.isNotEmpty),
    );
    return Scaffold(
      backgroundColor: Cut.base,
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
                              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    CutRadii.lg,
                                  ),
                                  boxShadow: CutShadows.e2,
                                ),
                                foregroundDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    CutRadii.lg,
                                  ),
                                  border: Border.all(color: Cut.strokeSubtle),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    CutRadii.lg,
                                  ),
                                  child: const PreviewPane(key: Key('preview')),
                                ),
                              ),
                            ),
                          ),
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

/// Opens the assistant, transcript and memes in a sheet; [tab] picks which
/// one shows first. The chat opens at about 60% height so the video stays
/// in view while the AI edits it; drag the handle up for more room.
Future<void> showSidebarSheet(BuildContext context, {int tab = 0}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Cut.surface1,
      barrierColor: const Color(0x52000000),
      clipBehavior: Clip.antiAlias,
      builder: (context) => _AiSheet(tab: tab),
    );

class _AiSheet extends StatefulWidget {
  const _AiSheet({required this.tab});

  final int tab;

  @override
  State<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends State<_AiSheet> {
  static const _low = 0.6;
  static const _high = 0.94;
  late double _fraction = widget.tab == 0 ? _low : 0.8;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final room = media.size.height - keyboard - media.padding.top;
    // With the keyboard up there's no room to spare for the video.
    final fraction = keyboard > 0 ? _high : _fraction;
    return Padding(
      // Keep the chat box above the keyboard.
      padding: EdgeInsets.only(bottom: keyboard),
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : CutMotion.normal,
        curve: CutMotion.decelerate,
        height: room * fraction,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0DFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.08],
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => setState(() => _dragging = true),
              onVerticalDragUpdate: (d) => setState(
                () => _fraction = (_fraction - d.delta.dy / room).clamp(
                  0.3,
                  _high,
                ),
              ),
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (_fraction < 0.42 || v > 1400 && _fraction < _low + 0.05) {
                  Navigator.maybePop(context);
                  return;
                }
                setState(() {
                  _dragging = false;
                  _fraction = v < -400
                      ? _high
                      : v > 400
                      ? _low
                      : (_fraction - _low).abs() < (_fraction - _high).abs()
                      ? _low
                      : _high;
                });
              },
              onTap: () => setState(
                () => _fraction = _fraction < (_low + _high) / 2 ? _high : _low,
              ),
              child: SizedBox(
                height: 22,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Cut.strokeStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Sidebar(key: const Key('sidebar'), initialTab: widget.tab),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back to your edits, the name, undo/redo and Export.
class CompactTopBar extends ConsumerWidget {
  const CompactTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final editor = ref.read(projectEditorProvider.notifier);
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
    final canExport = state.project.clips.isNotEmpty;
    return SizedBox(
      key: const Key('compact-top-bar'),
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            if (canGoBack)
              CutIconButton(
                key: const Key('back-to-edits'),
                icon: CutIcons.back,
                tooltip: 'Your edits',
                size: 48,
                iconSize: 22,
                color: Cut.textPrimary,
                onPressed: () => leaveEditor(ref, context),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Pressable(
                onTap: () => renameProjectFlow(ref, context),
                pressedScale: 0.98,
                semanticLabel: 'Rename ${state.project.name}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          state.project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CutType.titleSm.copyWith(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CutIcons.down,
                        size: 13,
                        color: Cut.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CutIconButton(
              icon: CutIcons.undo,
              tooltip: state.canUndo ? 'Undo ${state.undoLabel}' : 'Undo',
              size: 44,
              iconSize: 20,
              color: Cut.textPrimary,
              onPressed: state.canUndo ? editor.undo : null,
            ),
            CutIconButton(
              icon: CutIcons.redo,
              tooltip: state.canRedo ? 'Redo ${state.redoLabel}' : 'Redo',
              size: 44,
              iconSize: 20,
              color: Cut.textPrimary,
              onPressed: state.canRedo ? editor.redo : null,
            ),
            const SizedBox(width: 4),
            FilledButton(
              key: const Key('compact-export'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 38),
                shape: const StadiumBorder(),
              ),
              onPressed: canExport ? () => showExportFlow(ref, context) : null,
              child: const Text('Export'),
            ),
            PopupMenuButton<VoidCallback>(
              key: const Key('compact-menu'),
              tooltip: 'More',
              icon: const Icon(CutIcons.moreVertical, size: 22),
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
    builder: (context) => CutDialog(
      title: 'Rename edit',
      icon: CutIcons.rename,
      width: 420,
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
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return;
  ref.read(projectEditorProvider.notifier).run(RenameProject(name));
}

/// Which tool rail the bottom bar shows.
enum _Rail { main, text, memes, audio }

/// What you do most, with words under the icons. Text, Memes and Audio
/// open a rail of their tools in place of the bar (CapCut-style); the back
/// chevron returns.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar();

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  _Rail _rail = _Rail.main;

  void _open(_Rail rail) {
    HapticFeedback.selectionClick();
    setState(() => _rail = rail);
  }

  /// Opens the chat with [prompt] filled in (or sent).
  void _askAi(String prompt, {bool send = false}) {
    ref.read(chatDraftProvider.notifier).set(ChatDraft(prompt, send: send));
    setState(() => _rail = _Rail.main);
    showSidebarSheet(context);
  }

  List<_Tool> _tools(_Rail rail) => switch (rail) {
    _Rail.main => [
      _Tool(
        'action-ask',
        CutIcons.ai,
        'Ask AI',
        () => showSidebarSheet(context),
        hero: true,
      ),
      _Tool('action-text', CutIcons.textStyle, 'Text', () => _open(_Rail.text)),
      _Tool('action-memes', CutIcons.meme, 'Memes', () => _open(_Rail.memes)),
      _Tool('action-audio', CutIcons.audio, 'Audio', () => _open(_Rail.audio)),
      _Tool('action-split', CutIcons.split, 'Split', () {
        HapticFeedback.mediumImpact();
        splitAtPlayhead(ref, context);
      }),
    ],
    _Rail.text => [
      _Tool(
        'action-text-title',
        CutIcons.title,
        'Title',
        () => addTitleFlow(ref, context),
      ),
      _Tool(
        'action-text-intro',
        CutIcons.intro,
        'Intro',
        () => addTitleFlow(ref, context),
      ),
      _Tool(
        'action-text-ai',
        CutIcons.ai,
        'AI intro',
        () => _askAi('Add a punchy intro before the video with my name.'),
        ai: true,
      ),
    ],
    _Rail.memes => [
      _Tool(
        'action-memes-search',
        CutIcons.search,
        'Search',
        () => showSidebarSheet(context, tab: 2),
      ),
      _Tool(
        'action-memes-file',
        CutIcons.addImage,
        'From file',
        () => pickAndAddOverlay(ref, context),
      ),
      _Tool(
        'action-memes-ai',
        CutIcons.ai,
        'AI picks',
        () => _askAi('Suggest memes for the funniest moments.', send: true),
        ai: true,
      ),
    ],
    _Rail.audio => [
      _Tool(
        'action-audio-record',
        CutIcons.mic,
        'Record',
        () => ref.read(recordingProvider.notifier).show(),
      ),
      _Tool(
        'action-audio-script',
        CutIcons.voice,
        'Voiceover',
        () => showVoiceoverDialog(context),
      ),
      _Tool(
        'action-audio-music',
        CutIcons.musicLibrary,
        'Music',
        () => showMusicBrowser(context),
      ),
      _Tool(
        'action-audio-levels',
        CutIcons.levels,
        'Levels',
        () => showMixSheet(context),
      ),
      _Tool(
        'action-audio-ai',
        CutIcons.ai,
        'AI music',
        () => _askAi('Find background music that fits this video.'),
        ai: true,
      ),
    ],
  };

  static String _title(_Rail r) => switch (r) {
    _Rail.text => 'Text',
    _Rail.memes => 'Memes',
    _Rail.audio => 'Audio',
    _Rail.main => '',
  };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final rail = _rail;
    final tools = _tools(rail);
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 10, bottom + 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CutRadii.xl + 4),
          boxShadow: CutShadows.e3,
        ),
        child: GlassPanel(
          radius: CutRadii.xl + 4,
          tint: const Color(0xE01E1C28),
          child: SizedBox(
            height: 68,
            child: AnimatedSwitcher(
              duration: CutMotion.normal,
              switchInCurve: CutMotion.decelerate,
              switchOutCurve: CutMotion.accelerate,
              transitionBuilder: (child, a) {
                final incoming = child.key == ValueKey(rail);
                final dir = rail == _Rail.main ? -1.0 : 1.0;
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset((incoming ? 0.25 : -0.25) * dir, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                );
              },
              child: Row(
                key: ValueKey(rail),
                children: [
                  if (rail != _Rail.main) ...[
                    _BackButton(
                      label: _title(rail),
                      onTap: () => setState(() => _rail = _Rail.main),
                    ),
                    Container(width: 1, height: 32, color: Cut.strokeDefault),
                  ],
                  for (final t in tools) Expanded(child: _ToolButton(tool: t)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool(
    this.key,
    this.icon,
    this.label,
    this.onTap, {
    this.hero = false,
    this.ai = false,
  });

  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Ask AI: an aurora pill behind the icon.
  final bool hero;

  /// An AI tool in a rail: aurora icon.
  final bool ai;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      tool.label,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: CutType.caption.copyWith(
        fontSize: 11,
        height: 14 / 11,
        color: tool.hero ? Cut.textPrimary : Cut.textSecondary,
        fontWeight: tool.hero ? FontWeight.w600 : FontWeight.w500,
        fontVariations: [FontVariation('wght', tool.hero ? 620 : 500)],
      ),
    );
    final Widget icon;
    if (tool.hero) {
      icon = Container(
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          gradient: Cut.auroraGradient,
          borderRadius: BorderRadius.circular(CutRadii.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66B14DFF),
              blurRadius: 16,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CutRadii.pill),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.55],
          ),
        ),
        child: const Icon(CutIcons.ai, size: 19, color: Colors.white),
      );
    } else {
      icon = SizedBox(
        height: 32,
        child: Center(
          child: tool.ai
              ? AuroraIcon(size: 22, icon: tool.icon)
              : Icon(tool.icon, size: 23, color: Cut.textPrimary),
        ),
      );
    }
    return Pressable(
      key: Key(tool.key),
      onTap: tool.onTap,
      pressedScale: 0.92,
      semanticLabel: tool.label,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [icon, const SizedBox(height: 5), label],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('action-back'),
    onTap: onTap,
    pressedScale: 0.92,
    semanticLabel: 'Back',
    child: SizedBox(
      width: 56,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Cut.surface4,
              shape: BoxShape.circle,
              border: Border.all(color: Cut.strokeDefault),
            ),
            child: const Icon(CutIcons.back, size: 16, color: Cut.textPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: CutType.overline.copyWith(
              fontSize: 10,
              color: Cut.textTertiary,
            ),
          ),
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
