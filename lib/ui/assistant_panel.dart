import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';
import '../ai/chat_controller.dart';
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
                Icon(Icons.auto_awesome, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Assistant',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
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
                      for (final e in chat.entries) _Bubble(entry: e),
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
              'Add your Claude API key to start editing with the assistant.',
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
