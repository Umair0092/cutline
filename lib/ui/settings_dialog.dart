import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';

Future<void> showSettings(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _key = TextEditingController();
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!looksLikeApiKey(_key.text)) {
      setState(
        () => _error =
            'That doesn\'t look like a Claude API key '
            '(they start with sk-ant-).',
      );
      return;
    }
    await ref.read(apiKeyProvider.notifier).save(_key.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(apiKeyProvider).value;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Claude API key', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              saved == null
                  ? 'The assistant needs a key from console.anthropic.com. '
                        'It\'s stored in your system keychain.'
                  : 'A key ending in …${saved.substring(saved.length - 4)} '
                        'is saved in your system keychain.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('api-key'),
              controller: _key,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: saved == null ? 'sk-ant-…' : 'Paste a new key',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide' : 'Show',
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        if (saved != null)
          TextButton(
            onPressed: () async {
              await ref.read(apiKeyProvider.notifier).remove();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Remove Key'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-key'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
