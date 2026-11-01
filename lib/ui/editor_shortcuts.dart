import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preview/preview_controller.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

/// True while the user is typing in a text field, so single-key shortcuts
/// like Space don't steal their keystrokes.
bool isTyping() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// An action that steps aside (doesn't consume the key) while typing.
class _EditorAction<T extends Intent> extends CallbackAction<T> {
  _EditorAction({required super.onInvoke});

  @override
  bool isEnabled(T intent) => !isTyping();
}

/// Keyboard shortcuts for the editor that aren't in the menu bar.
class EditorShortcuts extends ConsumerWidget {
  const EditorShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
      },
      child: Actions(
        actions: {
          PlayPauseIntent: _EditorAction<PlayPauseIntent>(
            onInvoke: (_) => ref.read(previewProvider).togglePlay(),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
