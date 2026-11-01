import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import 'file_actions.dart';

/// One menu command, shown in the native macOS menu bar or an in-window
/// menu bar on Windows.
class MenuCommand {
  const MenuCommand(this.label, this.shortcut, this.onSelected);

  final String label;
  final SingleActivator? shortcut;
  final VoidCallback? onSelected;
}

/// Wraps the editor with the File and Edit menus.
class AppMenu extends ConsumerWidget {
  const AppMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectEditorProvider);
    final editor = ref.read(projectEditorProvider.notifier);
    final files = FileActions(ref, context);
    final mod = defaultTargetPlatform == TargetPlatform.macOS
        ? (LogicalKeyboardKey key, {bool shift = false}) =>
              SingleActivator(key, meta: true, shift: shift)
        : (LogicalKeyboardKey key, {bool shift = false}) =>
              SingleActivator(key, control: true, shift: shift);

    final menus = <String, List<MenuCommand>>{
      'File': [
        MenuCommand(
          'New Project',
          mod(LogicalKeyboardKey.keyN),
          files.newProject,
        ),
        MenuCommand('Open…', mod(LogicalKeyboardKey.keyO), files.open),
        MenuCommand('Save', mod(LogicalKeyboardKey.keyS), files.save),
        MenuCommand(
          'Save As…',
          mod(LogicalKeyboardKey.keyS, shift: true),
          files.saveAs,
        ),
      ],
      'Edit': [
        MenuCommand(
          state.canUndo ? 'Undo ${state.undoLabel}' : 'Undo',
          mod(LogicalKeyboardKey.keyZ),
          state.canUndo ? editor.undo : null,
        ),
        MenuCommand(
          state.canRedo ? 'Redo ${state.redoLabel}' : 'Redo',
          mod(LogicalKeyboardKey.keyZ, shift: true),
          state.canRedo ? editor.redo : null,
        ),
      ],
    };

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return PlatformMenuBar(
        menus: [
          const PlatformMenu(
            label: 'Cutline',
            menus: [
              PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.about,
              ),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
            ],
          ),
          for (final MapEntry(key: title, value: commands) in menus.entries)
            PlatformMenu(
              label: title,
              menus: [
                for (final c in commands)
                  PlatformMenuItem(
                    label: c.label,
                    shortcut: c.shortcut,
                    onSelected: c.onSelected,
                  ),
              ],
            ),
        ],
        child: child,
      );
    }

    return CallbackShortcuts(
      bindings: {
        for (final c in menus.values.expand((x) => x))
          if (c.shortcut != null && c.onSelected != null)
            c.shortcut!: c.onSelected!,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            MenuBar(
              children: [
                for (final MapEntry(key: title, value: commands)
                    in menus.entries)
                  SubmenuButton(
                    menuChildren: [
                      for (final c in commands)
                        MenuItemButton(
                          shortcut: c.shortcut,
                          onPressed: c.onSelected,
                          child: Text(c.label),
                        ),
                    ],
                    child: Text(title),
                  ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
