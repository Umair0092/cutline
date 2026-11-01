import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';
import '../ai/chat_controller.dart';
import '../editing/project_editor.dart';
import 'settings_dialog.dart';

/// The chat sidebar: messages, a box to type in, and send/stop.
class AssistantPanel extends ConsumerStatefulWidget {
  const AssistantPanel({super.key});

  static const examples = [
    'Cut the first 5 seconds',
    'Add an intro with my name',
    'Make my voice a bit deeper',
  ];

  @override
  ConsumerState<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends ConsumerState<AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Enter sends; Shift+Enter makes a new line.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _send([String? text]) {
    final message = text ?? _input.text;
    if (message.trim().isEmpty || ref.read(chatProvider).busy) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(message);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final hasKey = ref.watch(apiKeyProvider).value != null;
    final colors = Theme.of(context).colorScheme;
    ref.listen(chatProvider, (_, _) => _scrollToEnd());

    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edits are applied as one undo step per message.',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  onPressed: () => showSettings(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: !hasKey
                ? _NoKey(onOpenSettings: () => showSettings(context))
                : chat.entries.isEmpty && chat.streamingText == null
                ? _Examples(onPick: _send)
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (var i = 0; i < chat.entries.length; i++)
                        chat.entries[i].role == ChatRole.change
                            ? _ChangeCard(index: i, entry: chat.entries[i])
                            : _Bubble(entry: chat.entries[i]),
                      if (chat.streamingText != null)
                        _Bubble(
                          entry: ChatEntry(
                            role: ChatRole.assistant,
                            text: chat.streamingText!.isEmpty
                                ? 'Thinking…'
                                : chat.streamingText!,
                          ),
                          key: const Key('streaming'),
                        ),
                    ],
                  ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: _input,
                    focusNode: _focus,
                    enabled: hasKey,
                    minLines: 1,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Tell me what to change…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                chat.busy
                    ? IconButton.filledTonal(
                        key: const Key('stop'),
                        tooltip: 'Stop',
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: ref.read(chatProvider.notifier).stop,
                      )
                    : IconButton.filled(
                        key: const Key('send'),
                        tooltip: 'Send (Enter)',
                        icon: const Icon(Icons.arrow_upward_rounded),
                        onPressed: hasKey ? _send : null,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry, super.key});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = entry.role == ChatRole.user;
    if (entry.role == ChatRole.notice) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          entry.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: entry.isError ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          entry.text,
          style: TextStyle(
            color: isUser ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// What the assistant changed, with an Undo button while it's still the
/// latest edit.
class _ChangeCard extends ConsumerWidget {
  const _ChangeCard({required this.index, required this.entry});

  final int index;
  final ChatEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when the project changes, since that decides if Undo works.
    ref.watch(projectEditorProvider);
    final canUndo = ref.read(chatProvider.notifier).canUndoChange(index);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: Key('change-$index'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.undone ? Icons.undo : Icons.check_circle_outline,
            size: 16,
            color: entry.undone ? colors.onSurfaceVariant : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in entry.changes)
                  Text(
                    c,
                    style: text.bodySmall?.copyWith(
                      decoration: entry.undone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                if (entry.undone)
                  Text(
                    'Undone',
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canUndo)
            TextButton(
              key: Key('undo-change-$index'),
              onPressed: () =>
                  ref.read(chatProvider.notifier).undoChange(index),
              child: const Text('Undo'),
            ),
        ],
      ),
    );
  }
}

class _NoKey extends StatelessWidget {
  const _NoKey({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add an API key to start editing with the assistant. Groq has a free one.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const Key('open-settings'),
              onPressed: onOpenSettings,
              child: const Text('Add API Key…'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Try asking',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in AssistantPanel.examples)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: ActionChip(label: Text(e), onPressed: () => onPick(e)),
              ),
          ],
        ),
      ),
    );
  }
}
