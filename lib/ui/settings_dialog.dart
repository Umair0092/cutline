import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';
import '../ai/assistant_client.dart';
import '../ai/builtin_keys.dart';
import '../memes/meme_search.dart';
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
  final _giphy = TextEditingController();
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
    _giphy.dispose();
    super.dispose();
  }

  Future<void> _setProvider(AiProvider provider) async {
    final prefs = await ref.read(preferencesProvider.future);
    await ref
        .read(preferencesProvider.notifier)
        .save(prefs.copyWith(provider: provider));
    setState(() {
      _key.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    final brand = _brand.text.trim();
    if (brand.isNotEmpty && parseHexColor(brand) == null) {
      setState(() => _brandError = 'Use a colour like #6C5CE7.');
      return;
    }
    final prefs = await ref.read(preferencesProvider.future);
    await ref
        .read(preferencesProvider.notifier)
        .save(
          prefs.copyWith(
            yourName: _name.text.trim(),
            brandColor: brand.isEmpty ? '' : toHex(parseHexColor(brand)!),
          ),
        );
    final giphy = _giphy.text.trim();
    if (giphy.isNotEmpty) {
      await ref.read(giphyKeyProvider.notifier).save(giphy);
    }
    final provider = prefs.provider;
    // The key is optional here: saving only your name (or a GIPHY key) is
    // fine once a key is stored.
    final saved = ref.read(apiKeyProvider).value;
    if (_key.text.trim().isEmpty && (saved != null || giphy.isNotEmpty)) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!provider.looksLikeKey(_key.text)) {
      setState(
        () => _error =
            'That doesn\'t look like a ${provider.label} key '
            '(they start with ${provider.keyPrefix}).',
      );
      return;
    }
    await ref.read(apiKeyProvider.notifier).save(_key.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(apiKeyProvider).value;
    final builtIn = saved != null && saved == builtinGroqKey;
    final giphy = ref.watch(giphyKeyProvider).value;
    final giphyBuiltIn = giphy != null && giphy == builtinGiphyKey;
    final provider =
        ref.watch(preferencesProvider).value?.provider ?? AiProvider.groq;
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: const Text('Settings'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assistant', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AiProvider>(
              key: const Key('provider'),
              segments: [
                for (final p in AiProvider.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {provider},
              onSelectionChanged: (s) => _setProvider(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              provider == AiProvider.groq
                  ? 'Free, with limits on how much you can ask per minute. '
                        'Uses ${provider.model}.'
                  : 'Paid; the most capable. Uses ${provider.model}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '${provider.label} API key',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              saved == null
                  ? 'Get a key at ${provider.consoleUrl}. '
                        'It\'s stored in your system keychain.'
                  : builtIn
                  ? 'Using the key that came with this copy of Cutline. '
                        'Paste another to use yours instead.'
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
                hintText: saved == null
                    ? '${provider.keyPrefix}…'
                    : 'Paste a new key',
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
            const SizedBox(height: 20),
            Text('Memes', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              giphy == null
                  ? 'Optional: a free GIPHY key lets you search GIFs and '
                        'stickers. Get one at developers.giphy.com.'
                  : giphyBuiltIn
                  ? 'Using the GIPHY key that came with this copy.'
                  : 'A GIPHY key ending in '
                        '…${giphy.substring(giphy.length < 4 ? 0 : giphy.length - 4)} '
                        'is saved in your system keychain.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('giphy-key'),
                    controller: _giphy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'GIPHY API key',
                      hintText: giphy == null ? null : 'Paste a new key',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (giphy != null && !giphyBuiltIn)
                  IconButton(
                    tooltip: 'Remove the GIPHY key',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(giphyKeyProvider.notifier).remove(),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (saved != null && !builtIn)
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
