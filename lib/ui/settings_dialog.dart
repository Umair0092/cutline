import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';
import '../settings/preferences.dart';
import '../titles/templates.dart';

Future<void> showSettings(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _key = TextEditingController();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  bool _show = false;
  String? _error;
  String? _brandError;

  @override
  void initState() {
    super.initState();
    ref.read(preferencesProvider.future).then((p) {
      if (!mounted) return;
      _name.text = p.yourName;
      _brand.text = p.brandColor;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final brand = _brand.text.trim();
    if (brand.isNotEmpty && parseHexColor(brand) == null) {
      setState(() => _brandError = 'Use a colour like #6C5CE7.');
      return;
    }
    await ref
        .read(preferencesProvider.notifier)
        .save(
          Preferences(
            yourName: _name.text.trim(),
            brandColor: brand.isEmpty ? '' : toHex(parseHexColor(brand)!),
          ),
        );
    // The key is optional here: saving only your name is fine once a key
    // is stored.
    final saved = ref.read(apiKeyProvider).value;
    if (_key.text.trim().isEmpty && saved != null) {
      if (mounted) Navigator.pop(context);
      return;
    }
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
            const SizedBox(height: 20),
            Text('For intros', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'The assistant uses these so you don\'t have to repeat them.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('your-name'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: const Key('brand-color'),
                    controller: _brand,
                    decoration: InputDecoration(
                      labelText: 'Brand colour',
                      hintText: '#6C5CE7',
                      errorText: _brandError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _brandError = null),
                  ),
                ),
              ],
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
