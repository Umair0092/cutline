import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/media_asset.dart';
import '../overlays/overlay_media.dart';
import '../preview/preview_controller.dart';
import '../ui/assistant/chat_draft.dart';
import '../ui/settings_dialog.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
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
    setState(() {}); // the clear button
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
    final touch = isTouchPlatform;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CutRadii.pill),
      borderSide: const BorderSide(color: Cut.strokeSubtle),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: touch ? 44 : 36,
            child: TextField(
              key: const Key('meme-search'),
              controller: _query,
              textAlignVertical: TextAlignVertical.center,
              style: CutType.body.copyWith(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                prefixIcon: const Icon(CutIcons.search, size: 16),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                hintText: 'Search memes, e.g. this is fine',
                hintStyle: CutType.body.copyWith(
                  color: Cut.textTertiary,
                  fontSize: 13.5,
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(CutIcons.close, size: 13),
                        onPressed: () {
                          _query.clear();
                          _run();
                        },
                      ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: Cut.accent, width: 1.5),
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _run();
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
          child: Row(
            children: [
              SegmentedPill<bool>(
                height: touch ? 36 : 28,
                segments: const [
                  (false, 'GIFs', null),
                  (true, 'Stickers', null),
                ],
                selected: _stickers,
                onChanged: (stickers) {
                  if (_stickers == stickers) return;
                  setState(() => _stickers = stickers);
                  _run();
                },
              ),
              const Spacer(),
              CutIconButton(
                icon: CutIcons.folder,
                tooltip: 'Open your memes folder',
                onPressed: _openFolder,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _AskAiChip(
            onTap: () => ref
                .read(chatDraftProvider.notifier)
                .set(
                  const ChatDraft(
                    'Suggest memes for the funniest moments.',
                    send: true,
                  ),
                ),
          ),
        ),
        if (!hasKey)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 0),
            child: Text.rich(
              TextSpan(
                text: 'Only your memes folder is searched. ',
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => showSettings(context),
                        child: Text(
                          'Add a free GIPHY key',
                          style: CutType.caption.copyWith(
                            color: Cut.accentHover,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' to search online.'),
                ],
              ),
              style: CutType.caption.copyWith(color: Cut.textTertiary),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: FutureBuilder<MemeResults>(
            future: _results,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _LoadingGrid();
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
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Text(
              'Powered by GIPHY',
              textAlign: TextAlign.center,
              style: CutType.overline.copyWith(letterSpacing: 0.4),
            ),
          ),
      ],
    );
  }
}

/// "✦ Suggest memes for the funny moments": hands the job to the AI.
class _AskAiChip extends StatelessWidget {
  const _AskAiChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('meme-ask-ai'),
    onTap: onTap,
    pressedScale: 0.98,
    child: AuroraBorder(
      radius: CutRadii.md,
      width: 1,
      opacity: 0.5,
      child: Container(
        height: isTouchPlatform ? 48 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Cut.surface2,
          borderRadius: BorderRadius.circular(CutRadii.md - 1),
        ),
        child: Row(
          children: [
            const AuroraIcon(size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Suggest memes for the funny moments',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CutType.label.copyWith(color: Cut.textPrimary),
              ),
            ),
            const Icon(CutIcons.forward, size: 13, color: Cut.textTertiary),
          ],
        ),
      ),
    ),
  );
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 96,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: 9,
    itemBuilder: (_, _) => const Skeleton(radius: 10),
  );
}

class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.searched});

  final MemeResults results;
  final bool searched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget header(String text, int count) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      child: Row(
        children: [
          Text(text, style: CutType.label.copyWith(color: Cut.textPrimary)),
          const SizedBox(width: 8),
          CutBadge('$count', mono: true),
        ],
      ),
    );
    Widget grid(List<Meme> memes) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 96,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: memes.length,
        itemBuilder: (context, i) => ArriveIn(
          delay: Duration(milliseconds: 25 * i.clamp(0, 8)),
          offset: 6,
          child: MemeTile(meme: memes[i]),
        ),
      ),
    );
    final empty = results.all.isEmpty;
    return CustomScrollView(
      slivers: [
        if (results.local.isNotEmpty) ...[
          SliverToBoxAdapter(child: header('Your memes', results.local.length)),
          grid(results.local),
        ],
        if (results.online.isNotEmpty) ...[
          SliverToBoxAdapter(child: header('GIPHY', results.online.length)),
          grid(results.online),
        ],
        if (results.error != null)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Cut.errorContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(CutRadii.md),
                border: Border.all(color: Cut.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CutIcons.error, size: 15, color: Cut.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      results.error!,
                      style: CutType.label.copyWith(
                        color: const Color(0xFFFFC9CF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (empty && results.error == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: searched
                ? const EmptyState(
                    icon: CutIcons.search,
                    title: 'No memes found.',
                    body: 'Try another word, or a GIF instead of a sticker.',
                    compact: true,
                  )
                : const EmptyState(
                    icon: CutIcons.meme,
                    title: 'Your meme stash',
                    body:
                        'Put pictures, GIFs and short clips in your memes '
                        'folder, named after what they are ("this is '
                        'fine.gif"), or search GIPHY.',
                    compact: true,
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

/// One result. Click to add it at the playhead; drag it to place it.
class MemeTile extends ConsumerStatefulWidget {
  const MemeTile({super.key, required this.meme});

  final Meme meme;

  @override
  ConsumerState<MemeTile> createState() => _MemeTileState();
}

class _MemeTileState extends ConsumerState<MemeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final meme = widget.meme;
    final image = MemeThumbnail(meme: meme);
    final r = BorderRadius.circular(10);
    return Tooltip(
      message: meme.title,
      waitDuration: const Duration(milliseconds: 600),
      child: Draggable<Meme>(
        data: meme,
        // The feedback's top-left is the pointer, so drop targets can use
        // the drop offset as the pointer position.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Opacity(
          opacity: 0.85,
          child: Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Cut.surface3,
              borderRadius: r,
              border: Border.all(color: Cut.trackOverlay, width: 1.5),
              boxShadow: CutShadows.e3,
            ),
            child: image,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: ClipRRect(borderRadius: r, child: image),
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Pressable(
            key: Key('meme-${meme.id}'),
            pressedScale: 0.95,
            onTap: () =>
                addMeme(ref, context, meme, ref.read(previewProvider).position),
            child: AnimatedContainer(
              duration: CutMotion.fast,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Cut.surface2,
                borderRadius: r,
                boxShadow: _hover ? CutShadows.e2 : null,
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                  color: _hover ? Cut.strokeStrong : Cut.strokeSubtle,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    duration: CutMotion.normal,
                    curve: CutMotion.decelerate,
                    scale: _hover ? 1.06 : 1,
                    child: image,
                  ),
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: AnimatedOpacity(
                      duration: CutMotion.fast,
                      opacity: _hover ? 1 : 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Cut.accent,
                          shape: BoxShape.circle,
                          boxShadow: CutShadows.e1,
                        ),
                        child: const Icon(
                          CutIcons.add,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A meme's preview picture (an icon for local videos).
class MemeThumbnail extends StatelessWidget {
  const MemeThumbnail({super.key, required this.meme});

  final Meme meme;

  @override
  Widget build(BuildContext context) {
    Widget fallback(IconData icon) => ColoredBox(
      color: Cut.surface3,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Cut.trackOverlay),
              const SizedBox(height: 4),
              Text(
                meme.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: CutType.caption.copyWith(
                  fontSize: 10.5,
                  height: 13 / 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!meme.isLocal) {
      return Image.network(
        meme.preview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) => sync || frame != null
            ? child
            : const ColoredBox(color: Cut.surface3),
        errorBuilder: (_, _, _) => fallback(CutIcons.image),
      );
    }
    if (overlayKindOf(meme.source) == MediaKind.video) {
      return fallback(CutIcons.video);
    }
    return Image.file(
      File(meme.preview),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(CutIcons.image),
    );
  }
}
