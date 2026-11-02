import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../onboarding/onboarding.dart';
import 'about.dart';
import 'export_dialog.dart';
import 'file_actions.dart';
import 'editor_shortcuts.dart';
import 'import_actions.dart';
import 'settings_dialog.dart';

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
        MenuCommand(
          'Import Video…',
          mod(LogicalKeyboardKey.keyI),
          () => pickAndImportVideos(ref, context),
        ),
        MenuCommand(
          'Export…',
          mod(LogicalKeyboardKey.keyE),
          () => showExportFlow(ref, context),
        ),
        if (defaultTargetPlatform != TargetPlatform.macOS)
          MenuCommand(
            'Settings…',
            mod(LogicalKeyboardKey.comma),
            () => showSettings(context),
          ),
      ],
      'Edit': [
        MenuCommand(
          state.canUndo ? 'Undo ${state.undoLabel}' : 'Undo',
          mod(LogicalKeyboardKey.keyZ),
          () => _undoOrTextUndo(editor.undo, redo: false),
        ),
        MenuCommand(
          state.canRedo ? 'Redo ${state.redoLabel}' : 'Redo',
          mod(LogicalKeyboardKey.keyZ, shift: true),
          () => _undoOrTextUndo(editor.redo, redo: true),
        ),
      ],
      'Help': [
        MenuCommand('Getting Started…', null, () => showOnboarding(context)),
        if (defaultTargetPlatform != TargetPlatform.macOS)
          MenuCommand('About Cutline', null, () => showCutlineAbout(context)),
      ],
    };

    final scoped = AppMenuScope(menus: menus, child: child);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Cutline',
            menus: [
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'About Cutline',
                    onSelected: () => showCutlineAbout(context),
                  ),
                ],
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Settings…',
                    shortcut: mod(LogicalKeyboardKey.comma),
                    onSelected: () => showSettings(context),
                  ),
                ],
              ),
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
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
        child: scoped,
      );
    }

    return CallbackShortcuts(
      bindings: {
        for (final c in menus.values.expand((x) => x))
          if (c.shortcut != null && c.onSelected != null)
            c.shortcut!: c.onSelected!,
      },
      // On a phone-sized screen the editor shows these in its own top bar.
      child: isCompact(context)
          ? scoped
          : Column(
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
                Expanded(child: scoped),
              ],
            ),
    );
  }
}

/// Phone-sized screens get the compact editor layout.
bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

/// Makes the menu commands available below [AppMenu], for the compact
/// layout's own menu button.
class AppMenuScope extends InheritedWidget {
  const AppMenuScope({super.key, required this.menus, required super.child});

  final Map<String, List<MenuCommand>> menus;

  static Map<String, List<MenuCommand>> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMenuScope>()?.menus ??
      const {};

  @override
  bool updateShouldNotify(AppMenuScope old) => old.menus != menus;
}

/// The native macOS menu catches Cmd+Z before a text field sees it, so while
/// typing, Undo/Redo go to the text field instead of the project.
void _undoOrTextUndo(VoidCallback projectAction, {required bool redo}) {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (isTyping() && focus != null) {
    Actions.maybeInvoke(
      focus,
      redo
          ? const RedoTextIntent(SelectionChangedCause.keyboard)
          : const UndoTextIntent(SelectionChangedCause.keyboard),
    );
    return;
  }
  projectAction();
}
