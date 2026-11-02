import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editing/commands.dart';
import '../../editing/project_editor.dart';
import '../../library/project_library.dart';
import '../compact_editor.dart';
import '../export_dialog.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import 'tool_button.dart';

/// The editor's top bar: back to your edits, the edit's name (click to
/// rename it right there) with its save status, undo/redo and Export.
class ProjectTitleBar extends ConsumerWidget {
  const ProjectTitleBar({super.key});

  static const height = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final editor = ref.read(projectEditorProvider.notifier);
    final canGoBack = Navigator.of(context).canPop();
    final hasClips = state.project.clips.isNotEmpty;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Cut.base,
        border: Border(bottom: BorderSide(color: Cut.strokeSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CutSpace.s3),
      child: Row(
        children: [
          if (canGoBack) ...[
            ShortcutTooltip(
              message: 'Back to your edits',
              keys: const ['Esc'],
              child: TextButton.icon(
                key: const Key('back-to-edits'),
                style: TextButton.styleFrom(
                  foregroundColor: Cut.textSecondary,
                  padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                  minimumSize: const Size(0, 32),
                  textStyle: CutType.label,
                ),
                onPressed: () => leaveEditor(ref, context),
                icon: const Icon(CutIcons.back, size: 16),
                label: const Text('Edits'),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.only(left: 4, right: 10),
              color: Cut.strokeDefault,
            ),
          ],
          const Flexible(child: _ProjectName()),
          const SizedBox(width: CutSpace.s3),
          const _SaveStatus(),
          const Spacer(),
          EditorToolButton(
            key: const Key('undo'),
            size: 32,
            tooltip: state.canUndo ? 'Undo ${state.undoLabel}' : 'Undo',
            keys: [modKey, 'Z'],
            icon: const Icon(CutIcons.undo),
            onPressed: state.canUndo ? editor.undo : null,
          ),
          EditorToolButton(
            key: const Key('redo'),
            size: 32,
            tooltip: state.canRedo ? 'Redo ${state.redoLabel}' : 'Redo',
            keys: [modKey, '⇧', 'Z'],
            icon: const Icon(CutIcons.redo),
            onPressed: state.canRedo ? editor.redo : null,
          ),
          const SizedBox(width: CutSpace.s3),
          ShortcutTooltip(
            message: 'Export the video',
            keys: [modKey, 'E'],
            child: FilledButton.icon(
              key: const Key('export-button'),
              style: FilledButton.styleFrom(
                backgroundColor: Cut.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Cut.surface3,
                disabledForegroundColor: Cut.textDisabled,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: CutType.label.copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: hasClips ? () => showExportFlow(ref, context) : null,
              icon: const Icon(CutIcons.export, size: 16),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The edit's name. Click it to type a new one; Enter keeps it, Esc
/// doesn't.
class _ProjectName extends ConsumerStatefulWidget {
  const _ProjectName();

  @override
  ConsumerState<_ProjectName> createState() => _ProjectNameState();
}

class _ProjectNameState extends ConsumerState<_ProjectName> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _controller
      ..text = ref.read(projectEditorProvider).project.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    final name = _controller.text.trim();
    setState(() => _editing = false);
    if (name.isNotEmpty &&
        name != ref.read(projectEditorProvider).project.name) {
      ref.read(projectEditorProvider.notifier).run(RenameProject(name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(projectEditorProvider.select((s) => s.project.name));
    final style = CutType.titleSm;
    if (_editing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              _controller.text = name;
              _focus.unfocus();
            },
          },
          child: TextField(
            key: const Key('project-name-field'),
            controller: _controller,
            focusNode: _focus,
            style: style,
            cursorColor: Cut.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Cut.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 7,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CutRadii.sm),
                borderSide: const BorderSide(color: Cut.accent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CutRadii.sm),
                borderSide: const BorderSide(color: Cut.accent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CutRadii.sm),
                borderSide: const BorderSide(color: Cut.accent, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _focus.unfocus(),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Rename',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          key: const Key('project-name'),
          onTap: _start,
          child: AnimatedContainer(
            duration: CutMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _hover ? Cut.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(CutRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedOpacity(
                  duration: CutMotion.fast,
                  opacity: _hover ? 1 : 0,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      CutIcons.rename,
                      size: 13,
                      color: Cut.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Saved" with a check, "Saving…" with a spinner for edits in the
/// library (they save themselves); "Edited" for files kept elsewhere that
/// have unsaved changes.
class _SaveStatus extends ConsumerWidget {
  const _SaveStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final path = state.projectPath;
    final autosaved =
        path != null &&
        (ref.watch(projectLibraryProvider).value?.contains(path) ?? false);
    final Widget child;
    if (autosaved) {
      child = state.hasUnsavedChanges
          ? const _Status(
              key: ValueKey('saving'),
              icon: SizedBox.square(
                dimension: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Cut.textTertiary,
                ),
              ),
              text: 'Saving…',
            )
          : const _Status(
              key: ValueKey('saved'),
              icon: Icon(CutIcons.check, size: 11, color: Cut.textTertiary),
              text: 'Saved',
            );
    } else if (state.hasUnsavedChanges) {
      child = const _Status(
        key: Key('edited'),
        icon: DecoratedBox(
          decoration: BoxDecoration(color: Cut.warning, shape: BoxShape.circle),
          child: SizedBox.square(dimension: 6),
        ),
        text: 'Edited',
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('clean'));
    }
    return AnimatedSwitcher(duration: CutMotion.fast, child: child);
  }
}

class _Status extends StatelessWidget {
  const _Status({super.key, required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 6),
      Text(text, style: CutType.caption.copyWith(color: Cut.textTertiary)),
    ],
  );
}
