import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/media_asset.dart';
import '../overlays/overlay_media.dart';
import '../preview/preview_controller.dart';
import '../ui/settings_dialog.dart';
import 'meme_actions.dart';
import 'meme_search.dart';

/// Search GIPHY and your own memes folder. Click a meme to put it on the
/// video at the playhead, or drag it onto the timeline or the video.
class MemePanel extends ConsumerStatefulWidget {
  const MemePanel({super.key});

  @override
  ConsumerState<MemePanel> createState() => _MemePanelState();
}

class _MemePanelState extends ConsumerState<MemePanel> {
  final _query = TextEditingController();
  bool _stickers = false;
  Future<MemeResults>? _results;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Show what's in your memes folder straight away.
    _results = _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<MemeResults> _search(String query) async {
    final folder = await ref.read(memesFolderProvider.future);
    if (query.trim().isEmpty) {
      return MemeResults(LocalMemes(folder).search(''), const []);
    }
    final key = await ref.read(giphyKeyProvider.future);
    final local = LocalMemes(folder).search(query);
    if (key == null) return MemeResults(local, const []);
    try {
      final online = await ref
          .read(giphyClientFactoryProvider)(key)
          .search(query, stickers: _stickers);
      return MemeResults(local, online);
    } on MemeSearchException catch (e) {
      return MemeResults(local, const [], error: e.message);
    }
  }

  void _run() {
    final results = _search(_query.text);
    setState(() {
      _results = results;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _run);
  }

  Future<void> _openFolder() async {
    final folder = await ref.read(memesFolderProvider.future);
    await Process.run(Platform.isWindows ? 'explorer' : 'open', [folder]);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(giphyKeyProvider).value != null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            key: const Key('meme-search'),
            controller: _query,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search memes, e.g. this is fine',
              border: OutlineInputBorder(),
            ),
            onChanged: _onChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              _run();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final (stickers, label) in [
                (false, 'GIFs'),
                (true, 'Stickers'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _stickers == stickers,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      if (_stickers == stickers) return;
                      _stickers = stickers;
                      _run();
                    },
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Open your memes folder',
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                onPressed: _openFolder,
              ),
            ],
          ),
        ),
        if (!hasKey)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text.rich(
              TextSpan(
                text: 'Only your memes folder is searched. ',
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => showSettings(context),
                      child: Text(
                        'Add a free GIPHY key',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' to search online.'),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<MemeResults>(
            future: _results,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final r = snap.data ?? const MemeResults([], []);
              return _Results(
                results: r,
                searched: _query.text.trim().isNotEmpty,
              );
            },
          ),
        ),
        if (hasKey)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              'Powered by GIPHY',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.searched});

  final MemeResults results;
  final bool searched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget grid(List<Meme> memes) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 110,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: memes.length,
        itemBuilder: (context, i) => MemeTile(meme: memes[i]),
      ),
    );
    final empty = results.all.isEmpty;
    return CustomScrollView(
      slivers: [
        if (results.local.isNotEmpty) ...[
          SliverToBoxAdapter(child: header('Your memes')),
          grid(results.local),
        ],
        if (results.online.isNotEmpty) ...[
          SliverToBoxAdapter(child: header('GIPHY')),
          grid(results.online),
        ],
        if (results.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                results.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        if (empty && results.error == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  searched
                      ? 'No memes found.'
                      : 'Put pictures, GIFs and short clips in your memes '
                            'folder, named after what they are '
                            '("this is fine.gif"), or search GIPHY.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

/// One result. Click to add it at the playhead; drag it to place it.
class MemeTile extends ConsumerWidget {
  const MemeTile({super.key, required this.meme});

  final Meme meme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = _MemeImage(meme: meme);
    return Tooltip(
      message: meme.title,
      waitDuration: const Duration(milliseconds: 600),
      child: Draggable<Meme>(
        data: meme,
        // The feedback's top-left is the pointer, so drop targets can use
        // the drop offset as the pointer position.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Opacity(
          opacity: 0.8,
          child: SizedBox(width: 90, height: 90, child: image),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: image),
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            key: Key('meme-${meme.id}'),
            onTap: () =>
                addMeme(ref, context, meme, ref.read(previewProvider).position),
            child: image,
          ),
        ),
      ),
    );
  }
}

class _MemeImage extends StatelessWidget {
  const _MemeImage({required this.meme});

  final Meme meme;

  @override
  Widget build(BuildContext context) {
    Widget fallback(IconData icon) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              meme.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
    if (!meme.isLocal) {
      return Image.network(
        meme.preview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(Icons.broken_image_outlined),
      );
    }
    if (overlayKindOf(meme.source) == MediaKind.video) {
      return fallback(Icons.movie_outlined);
    }
    return Image.file(
      File(meme.preview),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(Icons.broken_image_outlined),
    );
  }
}
