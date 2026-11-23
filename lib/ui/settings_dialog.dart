import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ai/api_key_store.dart';
import '../ai/assistant_client.dart';
import '../ai/builtin_keys.dart';
import '../memes/meme_search.dart';
import '../onboarding/onboarding.dart';
import '../settings/preferences.dart';
import '../titles/templates.dart';
import 'dialogs/dialog_kit.dart';
import 'splash_screen.dart';
import 'tokens.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// The pages of Settings.
enum SettingsPage {
  ai('AI assistant', 'The service that edits for you', CutIcons.aiOutline),
  intros('Intros', 'Your name and brand colour for titles', DialogIcons.brush),
  memes('Memes', 'GIF and sticker search', DialogIcons.smiley),
  shortcuts('Shortcuts', 'Keys that save you clicks', CutIcons.keyboard),
  about('About', 'Version, privacy and licences', DialogIcons.appInfo);

  const SettingsPage(this.label, this.blurb, this.icon);

  final String label;
  final String blurb;
  final IconData icon;
}

/// Opens Settings. Everything saves as you go; there is no Save button
/// except for keys, which are checked first.
Future<void> showSettings(BuildContext context, {SettingsPage? page}) =>
    showCutModal<void>(
      context,
      builder: (_) => SettingsDialog(initialPage: page),
    );

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key, this.initialPage});

  /// The page to open on; phones start on the list when null.
  final SettingsPage? initialPage;

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _key = TextEditingController();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _giphy = TextEditingController();
  final _search = TextEditingController();
  bool _show = false;
  bool _showGiphy = false;
  bool _savingKey = false;
  String? _error;
  String? _brandError;
  String? _giphyError;
  Timer? _debounce;
  Timer? _savedTimer;
  bool _saved = false;
  late SettingsPage? _page = widget.initialPage;

  @override
  void initState() {
    super.initState();
    ref.read(preferencesProvider.future).then((p) {
      if (!mounted) return;
      _name.text = p.yourName;
      _brand.text = p.brandColor;
      setState(() {});
    }, onError: (_) {});
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      unawaited(_savePersonal(quiet: true));
    }
    _savedTimer?.cancel();
    _key.dispose();
    _name.dispose();
    _brand.dispose();
    _giphy.dispose();
    _search.dispose();
    super.dispose();
  }

  void _flashSaved() {
    if (!mounted) return;
    setState(() => _saved = true);
    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _setProvider(AiProvider provider) async {
    final prefs = await ref.read(preferencesProvider.future);
    if (prefs.provider == provider) return;
    await ref
        .read(preferencesProvider.notifier)
        .save(prefs.copyWith(provider: provider));
    if (!mounted) return;
    setState(() {
      _key.clear();
      _error = null;
    });
    _flashSaved();
  }

  Future<void> _saveKey() async {
    final prefs = await ref.read(preferencesProvider.future);
    final provider = prefs.provider;
    if (!provider.looksLikeKey(_key.text)) {
      setState(
        () => _error =
            'That doesn\'t look like a ${provider.label} key '
            '(they start with ${provider.keyPrefix}).',
      );
      return;
    }
    setState(() => _savingKey = true);
    try {
      await ref.read(apiKeyProvider.notifier).save(_key.text.trim());
    } finally {
      if (mounted) setState(() => _savingKey = false);
    }
    if (!mounted) return;
    setState(() {
      _key.clear();
      _show = false;
    });
    _flashSaved();
  }

  Future<void> _paste(TextEditingController c, VoidCallback after) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    c.text = text;
    after();
  }

  void _personalChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _savePersonal);
  }

  Future<void> _savePersonal({bool quiet = false}) async {
    final brand = _brand.text.trim();
    final color = brand.isEmpty ? null : parseHexColor(brand);
    if (brand.isNotEmpty && color == null) {
      if (!quiet && mounted) {
        setState(() => _brandError = 'Use a colour like #6C5CE7.');
      }
      return;
    }
    final prefs = await ref.read(preferencesProvider.future);
    final next = prefs.copyWith(
      yourName: _name.text.trim(),
      brandColor: color == null ? '' : toHex(color),
    );
    if (next.yourName == prefs.yourName &&
        next.brandColor == prefs.brandColor) {
      return;
    }
    await ref.read(preferencesProvider.notifier).save(next);
    if (!quiet) _flashSaved();
  }

  Future<void> _saveGiphy() async {
    final giphy = _giphy.text.trim();
    if (giphy.length < 10) {
      setState(() => _giphyError = 'Paste the whole key from GIPHY.');
      return;
    }
    await ref.read(giphyKeyProvider.notifier).save(giphy);
    if (!mounted) return;
    setState(() {
      _giphy.clear();
      _giphyError = null;
    });
    _flashSaved();
  }

  @override
  Widget build(BuildContext context) =>
      isPhoneLayout(context) ? _phone() : _desktop();

  // --------------------------------------------------------------- frames

  Widget _desktop() {
    final page = _page ?? SettingsPage.ai;
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: CutSurface(
          level: 4,
          color: Cut.surface2,
          radius: CutRadii.xl,
          clip: true,
          width: math.min(780, screen.width - 48),
          height: math.min(560, screen.height - 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 208,
                color: Cut.surface1,
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 18),
                      child: Text('Settings', style: CutType.headlineSm),
                    ),
                    for (final p in SettingsPage.values)
                      _NavItem(
                        page: p,
                        selected: p == page,
                        onTap: () => setState(() => _page = p),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Changes save as you go.',
                        style: CutType.caption.copyWith(
                          color: Cut.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 14, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(page.label, style: CutType.title),
                                const SizedBox(height: 2),
                                Text(page.blurb, style: CutType.caption),
                              ],
                            ),
                          ),
                          SavedPip(visible: _saved),
                          const SizedBox(width: 6),
                          CutIconButton(
                            icon: CutIcons.close,
                            tooltip: 'Close',
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: CutMotion.fast,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previous, ?current],
                        ),
                        child: SingleChildScrollView(
                          key: ValueKey(page),
                          padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
                          child: _content(page),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phone() {
    final page = _page;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: CutMotion.normal,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: Offset(
                child.key == const ValueKey('list') ? -0.06 : 0.06,
                0,
              ),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: CutMotion.decelerate)),
            child: child,
          ),
        ),
        child: page == null
            ? KeyedSubtree(key: const ValueKey('list'), child: _phoneList())
            : KeyedSubtree(key: ValueKey(page), child: _phonePage(page)),
      ),
    );
  }

  Widget _phoneList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        child: Row(
          children: [
            Expanded(child: Text('Settings', style: CutType.headline)),
            CutIconButton(
              icon: CutIcons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _status(),
            const SizedBox(height: CutSpace.s5),
            _InsetGroup(
              children: [
                for (final p in SettingsPage.values.take(3))
                  _GroupRow(page: p, onTap: () => setState(() => _page = p)),
              ],
            ),
            const SizedBox(height: CutSpace.s5),
            _InsetGroup(
              children: [
                for (final p in SettingsPage.values.skip(3))
                  _GroupRow(page: p, onTap: () => setState(() => _page = p)),
              ],
            ),
            const SizedBox(height: CutSpace.s4),
            Center(
              child: Text(
                'Changes save as you go.',
                style: CutType.caption.copyWith(color: Cut.textTertiary),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _phonePage(SettingsPage page) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
        child: Row(
          children: [
            CutIconButton(
              icon: CutIcons.back,
              tooltip: 'Settings',
              onPressed: () => setState(() => _page = null),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(page.label, style: CutType.title)),
            SavedPip(visible: _saved),
            CutIconButton(
              icon: CutIcons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _content(page),
        ),
      ),
    ],
  );

  Widget _content(SettingsPage page) => switch (page) {
    SettingsPage.ai => _aiPage(),
    SettingsPage.intros => _introsPage(),
    SettingsPage.memes => _memesPage(),
    SettingsPage.shortcuts => _shortcutsPage(),
    SettingsPage.about => const _AboutPage(),
  };

  // ------------------------------------------------------------------- AI

  Widget _status({bool compact = false}) {
    final saved = ref.watch(apiKeyProvider).value;
    final builtIn = saved != null && saved == builtinGroqKey;
    final provider =
        ref.watch(preferencesProvider).value?.provider ?? AiProvider.groq;
    final ready = saved != null;
    final detail = !ready
        ? 'Add a key below to start editing with AI'
        : builtIn
        ? 'Using the key that came with Cutline'
        : 'Your key …${saved.substring(math.max(0, saved.length - 4))} · '
              'in the system keychain';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cut.surface1,
        borderRadius: BorderRadius.circular(CutRadii.lg),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Cut.surface3,
              borderRadius: BorderRadius.circular(CutRadii.md),
              border: Border.all(color: Cut.strokeSubtle),
            ),
            alignment: Alignment.center,
            child: const AuroraIcon(size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Dot(color: ready ? Cut.success : Cut.warning),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ready
                            ? 'Connected · ${provider.label}'
                            : 'Needs a key · ${provider.label}',
                        style: CutType.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: CutType.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (compact)
            CutIconButton(
              icon: CutIcons.forward,
              tooltip: 'AI assistant',
              onPressed: () => setState(() => _page = SettingsPage.ai),
            ),
        ],
      ),
    );
  }

  Widget _aiPage() {
    final saved = ref.watch(apiKeyProvider).value;
    final builtIn = saved != null && saved == builtinGroqKey;
    final prefs = ref.watch(preferencesProvider).value;
    final provider = prefs?.provider ?? AiProvider.groq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _status(),
        const SizedBox(height: CutSpace.s6),
        const FieldLabel('Service'),
        LayoutBuilder(
          builder: (context, c) {
            const gap = CutSpace.s3;
            final cols = c.maxWidth < 380 ? 1 : 2;
            final width = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              key: const Key('provider'),
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in AiProvider.values)
                  SizedBox(
                    width: width,
                    child: _ProviderCard(
                      provider: p,
                      model: prefs?.modelFor(p) ?? p.model,
                      selected: p == provider,
                      onTap: () => _setProvider(p),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: CutSpace.s6),
        _AdvancedModelFields(provider: provider),
        const SizedBox(height: CutSpace.s6),
        FieldLabel(
          '${provider.label} API key',
          icon: CutIcons.key,
          trailing: saved != null && !builtIn
              ? TextButton(
                  onPressed: () async {
                    await ref.read(apiKeyProvider.notifier).remove();
                    _flashSaved();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Cut.error,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Remove key'),
                )
              : null,
        ),
        _SecretField(
          fieldKey: const Key('api-key'),
          controller: _key,
          revealed: _show,
          onReveal: () => setState(() => _show = !_show),
          onPaste: () => _paste(_key, () => setState(() => _error = null)),
          hint: saved == null ? '${provider.keyPrefix}…' : 'Paste a new key',
          error: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _saveKey(),
          action: PrimaryButton(
            key: const Key('save-key'),
            label: 'Save key',
            busy: _savingKey,
            height: 40,
            onPressed: _saveKey,
          ),
        ),
        const SizedBox(height: CutSpace.s2),
        Text(
          saved == null
              ? 'Get a key at ${provider.consoleUrl}. It\'s kept in your '
                    'system keychain, never in the project.'
              : builtIn
              ? 'Paste your own key to use it instead of the built-in one.'
              : 'Paste another key to replace it.',
          style: CutType.caption.copyWith(color: Cut.textTertiary),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- intros

  Widget _introsPage() {
    final brand = parseHexColor(_brand.text.trim());
    const quick = ['#8B6DFF', '#5B8CFF', '#33D1C1', '#3DD68C', '#FFB547'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The assistant and the title templates use these, so you don\'t '
          'have to type them for every intro.',
          style: CutType.body.copyWith(color: Cut.textSecondary),
        ),
        const SizedBox(height: CutSpace.s5),
        const FieldLabel('Your name', icon: DialogIcons.user),
        TextField(
          key: const Key('your-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Umair Hassan'),
          onChanged: (_) => _personalChanged(),
        ),
        const SizedBox(height: CutSpace.s5),
        const FieldLabel('Brand colour', icon: CutIcons.palette),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                key: const Key('brand-color'),
                controller: _brand,
                style: CutType.timecode.copyWith(
                  color: Cut.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '#6C5CE7',
                  errorText: _brandError,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AnimatedContainer(
                      duration: CutMotion.fast,
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: brand ?? Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Cut.strokeStrong),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                onChanged: (_) {
                  setState(() => _brandError = null);
                  _personalChanged();
                },
              ),
            ),
            const SizedBox(width: CutSpace.s3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hex in quick)
                      _Swatch(
                        color: parseHexColor(hex)!,
                        selected: brand != null && toHex(brand) == hex,
                        onTap: () {
                          _brand.text = hex;
                          setState(() => _brandError = null);
                          _personalChanged();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CutSpace.s2),
        Text(
          'Leave it empty to keep each template\'s own colours.',
          style: CutType.caption.copyWith(color: Cut.textTertiary),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- memes

  Widget _memesPage() {
    final giphy = ref.watch(giphyKeyProvider).value;
    final giphyBuiltIn = giphy != null && giphy == builtinGiphyKey;
    final ready = giphy != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Cut.surface1,
            borderRadius: BorderRadius.circular(CutRadii.lg),
            border: Border.all(color: Cut.strokeSubtle),
          ),
          child: Row(
            children: [
              _Dot(color: ready ? Cut.success : Cut.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'GIPHY search is on' : 'GIPHY search is off',
                      style: CutType.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !ready
                          ? 'Optional: a free key lets you search GIFs and '
                                'stickers. Get one at developers.giphy.com.'
                          : giphyBuiltIn
                          ? 'Using the GIPHY key that came with this copy.'
                          : 'Your key …${giphy.substring(math.max(0, giphy.length - 4))} '
                                'is in the system keychain.',
                      style: CutType.caption,
                    ),
                  ],
                ),
              ),
              if (ready && !giphyBuiltIn)
                CutIconButton(
                  icon: CutIcons.trash,
                  tooltip: 'Remove the GIPHY key',
                  color: Cut.error,
                  onPressed: () async {
                    await ref.read(giphyKeyProvider.notifier).remove();
                    _flashSaved();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: CutSpace.s6),
        const FieldLabel('GIPHY API key', icon: CutIcons.key),
        _SecretField(
          fieldKey: const Key('giphy-key'),
          controller: _giphy,
          revealed: _showGiphy,
          onReveal: () => setState(() => _showGiphy = !_showGiphy),
          onPaste: () =>
              _paste(_giphy, () => setState(() => _giphyError = null)),
          hint: ready ? 'Paste a new key' : 'Paste your key',
          error: _giphyError,
          onChanged: (_) => setState(() => _giphyError = null),
          onSubmitted: (_) => _saveGiphy(),
          action: PrimaryButton(
            key: const Key('save-giphy'),
            label: 'Save key',
            height: 40,
            onPressed: _saveGiphy,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ shortcuts

  Widget _shortcutsPage() {
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl';
    final shift = Platform.isMacOS ? '⇧' : 'Shift';
    final groups = <String, List<(String, List<String>)>>{
      'Playback and editing': [
        ('Play or pause', ['Space']),
        ('Split at the playhead', ['S']),
        ('Delete the selected clip', ['⌫']),
        ('Zoom in', ['=']),
        ('Zoom out', ['−']),
      ],
      'Project': [
        ('New project', [mod, 'N']),
        ('Open', [mod, 'O']),
        ('Save', [mod, 'S']),
        ('Save as', [shift, mod, 'S']),
        ('Import video', [mod, 'I']),
        ('Export', [mod, 'E']),
        ('Settings', [mod, ',']),
      ],
      'Undo': [
        ('Undo', [mod, 'Z']),
        ('Redo', [shift, mod, 'Z']),
      ],
    };
    final q = _search.text.trim().toLowerCase();
    final filtered = {
      for (final MapEntry(:key, :value) in groups.entries)
        key: [
          for (final s in value)
            if (q.isEmpty || s.$1.toLowerCase().contains(q)) s,
        ],
    }..removeWhere((_, v) => v.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            hintText: 'Search shortcuts',
            prefixIcon: Icon(CutIcons.search, size: 18),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CutSpace.s4),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No shortcut matches "${_search.text.trim()}".',
              textAlign: TextAlign.center,
              style: CutType.caption,
            ),
          ),
        for (final MapEntry(:key, :value) in filtered.entries) ...[
          SectionLabel(key, padding: const EdgeInsets.fromLTRB(4, 8, 0, 8)),
          _InsetGroup(
            children: [
              for (final (label, keys) in value)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: CutType.body)),
                      for (final (i, k) in keys.indexed) ...[
                        if (i > 0) const SizedBox(width: 4),
                        KeyCap(k),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: CutSpace.s2),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ pieces

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final SettingsPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: selected ? Cut.surface3 : Colors.transparent,
      borderRadius: BorderRadius.circular(CutRadii.sm),
      child: InkWell(
        key: Key('settings-${page.name}'),
        borderRadius: BorderRadius.circular(CutRadii.sm),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              page == SettingsPage.ai && selected
                  ? const AuroraIcon(size: 17)
                  : Icon(
                      page.icon,
                      size: 17,
                      color: selected ? Cut.textPrimary : Cut.textTertiary,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  page.label,
                  style: CutType.label.copyWith(
                    color: selected ? Cut.textPrimary : Cut.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

/// An iOS-style inset group: rows on one rounded card with hairlines.
class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Cut.surface2,
      borderRadius: BorderRadius.circular(CutRadii.lg),
      border: Border.all(color: Cut.strokeSubtle),
    ),
    child: Column(
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0)
            const Divider(height: 1, indent: 14, color: Cut.strokeSubtle),
          c,
        ],
      ],
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.page, required this.onTap});

  final SettingsPage page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Cut.surface4,
                borderRadius: BorderRadius.circular(CutRadii.sm),
              ),
              alignment: Alignment.center,
              child: page == SettingsPage.ai
                  ? const AuroraIcon(size: 16)
                  : Icon(page.icon, size: 16, color: Cut.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(page.label, style: CutType.bodyStrong),
                  Text(
                    page.blurb,
                    style: CutType.caption.copyWith(color: Cut.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(CutIcons.forward, size: 16, color: Cut.textTertiary),
          ],
        ),
      ),
    ),
  );
}

/// The editable model id for the chosen provider, plus the endpoint URL when
/// the provider is "Custom". Both save as you type (debounced).
class _AdvancedModelFields extends ConsumerStatefulWidget {
  const _AdvancedModelFields({required this.provider});

  final AiProvider provider;

  @override
  ConsumerState<_AdvancedModelFields> createState() =>
      _AdvancedModelFieldsState();
}

class _AdvancedModelFieldsState extends ConsumerState<_AdvancedModelFields> {
  final _model = TextEditingController();
  final _endpoint = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AdvancedModelFields old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(preferencesProvider.future);
      if (!mounted) return;
      _model.text = prefs.models[widget.provider.name] ?? '';
      _endpoint.text = prefs.customEndpoint;
      setState(() {});
    } on Object {
      // Leave the fields empty if preferences can't be read.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _model.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _save);
  }

  Future<void> _save() async {
    final prefs = await ref.read(preferencesProvider.future);
    final next = prefs
        .withModel(widget.provider, _model.text)
        .copyWith(
          customEndpoint: widget.provider.needsEndpoint
              ? _endpoint.text.trim()
              : null,
        );
    await ref.read(preferencesProvider.notifier).save(next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final defaultModel = provider.model.isEmpty
        ? 'e.g. gpt-4o-mini'
        : provider.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.needsEndpoint) ...[
          const FieldLabel('Endpoint', icon: DialogIcons.cloud),
          TextField(
            key: const Key('custom-endpoint'),
            controller: _endpoint,
            autocorrect: false,
            enableSuggestions: false,
            style: CutType.timecode.copyWith(
              color: Cut.textPrimary,
              fontSize: 13,
            ),
            decoration: const InputDecoration(
              hintText: 'https://api.your-provider.com/v1/chat/completions',
            ),
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: CutSpace.s5),
        ],
        const FieldLabel('Model', icon: CutIcons.aiOutline),
        TextField(
          key: const Key('model'),
          controller: _model,
          autocorrect: false,
          enableSuggestions: false,
          style: CutType.timecode.copyWith(
            color: Cut.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(hintText: defaultModel),
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: CutSpace.s2),
        Text(
          provider.needsEndpoint
              ? 'Any OpenAI-compatible chat endpoint. Your key is sent as a '
                    'Bearer token.'
              : 'Leave empty to use the default ($defaultModel). Change it if '
                    'the provider updates its model names.',
          style: CutType.caption.copyWith(color: Cut.textTertiary),
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final AiProvider provider;

  /// The effective model (override or default) to show on the card.
  final String model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final free = provider.freeToStart;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: CutMotion.fast,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? Cut.accentContainer : Cut.surface3,
            borderRadius: BorderRadius.circular(CutRadii.md),
            border: Border.all(
              color: selected ? Cut.accent : Cut.strokeSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    free ? DialogIcons.cloud : CutIcons.aiOutline,
                    size: 18,
                    color: selected ? Cut.onAccentContainer : Cut.textSecondary,
                  ),
                  const Spacer(),
                  CutBadge(
                    free ? 'Free' : 'Paid',
                    color: free ? Cut.success : Cut.textSecondary,
                    background: free ? Cut.successContainer : Cut.surface4,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(provider.label, style: CutType.titleSm),
              const SizedBox(height: 2),
              Text(
                provider.blurb,
                style: CutType.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                model.isEmpty ? 'Set a model below' : model,
                style: CutType.timecode.copyWith(
                  fontSize: 11,
                  color: Cut.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A masked key field in mono with paste and reveal buttons, and its save
/// button beside it.
class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.fieldKey,
    required this.controller,
    required this.revealed,
    required this.onReveal,
    required this.onPaste,
    required this.hint,
    required this.error,
    required this.onChanged,
    required this.onSubmitted,
    required this.action,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onPaste;
  final String hint;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: fieldKey,
      controller: controller,
      obscureText: !revealed,
      obscuringCharacter: '•',
      autocorrect: false,
      enableSuggestions: false,
      style: CutType.timecode.copyWith(color: Cut.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: CutType.timecode.copyWith(color: Cut.textTertiary),
        errorText: error,
        errorMaxLines: 2,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CutIconButton(
              icon: DialogIcons.paste,
              tooltip: 'Paste',
              size: 30,
              iconSize: 16,
              onPressed: onPaste,
            ),
            CutIconButton(
              icon: revealed ? CutIcons.eyeOff : CutIcons.eye,
              tooltip: revealed ? 'Hide' : 'Show',
              size: 30,
              iconSize: 16,
              onPressed: onReveal,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    if (isPhoneLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [field, const SizedBox(height: 10), action],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 10),
        action,
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    pressedScale: 0.9,
    child: AnimatedContainer(
      duration: CutMotion.fast,
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Cut.textPrimary : Colors.transparent,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

class _AboutPage extends StatefulWidget {
  const _AboutPage();

  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const CutlineLogo(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cutline', style: CutType.headlineSm),
                const SizedBox(height: 2),
                Text(
                  'Edit videos by saying what you want.',
                  style: CutType.caption,
                ),
                if (_version.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TimecodeText('v$_version', color: Cut.textTertiary),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CutSpace.s5),
      _InsetGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(DialogIcons.shield, size: 18, color: Cut.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your videos never leave your computer: export uses FFmpeg '
                    'and transcripts use whisper.cpp, both on your computer. '
                    'The assistant is sent what you type, a summary of the '
                    'project and its transcript. Meme searches go to GIPHY, '
                    'and Groq voices send the voiceover text to Groq.',
                    style: CutType.body.copyWith(color: Cut.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CutSpace.s4),
      Wrap(
        spacing: CutSpace.s2,
        runSpacing: CutSpace.s2,
        children: [
          QuietButton(
            label: 'Getting started guide',
            icon: DialogIcons.guide,
            onPressed: () => showOnboarding(context),
          ),
          QuietButton(
            label: 'Licences',
            icon: DialogIcons.book,
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Cutline',
              applicationVersion: _version,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: CutlineLogo(size: 48),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
