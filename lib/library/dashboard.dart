import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/preferences.dart';
import '../ui/home/home_sidebar.dart';
import '../ui/home/project_card.dart';
import '../ui/home/start_actions.dart';
import '../ui/home/start_hero.dart';
import '../ui/home/wordmark.dart';
import '../ui/navigation.dart';
import '../ui/settings_dialog.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
import 'project_library.dart';

export '../ui/home/project_card.dart'
    show EditFingerprint, ProjectCard, ProjectThumbnail, timeAgo;
export '../ui/home/start_actions.dart'
    show openLibraryProject, openProjectFile, startNewEdit;

enum EditSort { recent, name, duration }

/// The home screen: start a new edit (from a video, from photos, or with a
/// prompt for the AI) or pick up a past one.
///
/// Desktop gets a sidebar, a header with search and a "Start with AI" drop
/// zone above the grid; phones (and narrow windows) get a collapsing large
/// title, a two-column grid and a "New edit" button in the thumb zone.
class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  EditSort _sort = EditSort.recent;
  bool _fabExtended = true;
  bool _phoneSearch = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  List<ProjectSummary> _visible(List<ProjectSummary> all, Set<String> hidden) {
    final list = [
      for (final s in all)
        if (!hidden.contains(s.path) &&
            (_query.isEmpty || s.name.toLowerCase().contains(_query)))
          s,
    ];
    switch (_sort) {
      case EditSort.recent:
        break;
      case EditSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case EditSort.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
    }
    return list;
  }

  void _focusSearch() {
    if (MediaQuery.sizeOf(context).width < 900) {
      setState(() => _phoneSearch = true);
    }
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autosaveProvider);
    setHasDashboard(true);
    final projects = ref.watch(projectListProvider);
    final compact = MediaQuery.sizeOf(context).width < 900;
    final mac = Platform.isMacOS || Platform.isIOS;
    return Scaffold(
      key: const Key('dashboard'),
      backgroundColor: Cut.base,
      floatingActionButton: compact
          ? _NewEditFab(
              extended: _fabExtended,
              onPressed: () => startNewEdit(ref, context),
            )
          : null,
      body: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.keyK, meta: mac, control: !mac):
              _focusSearch,
        },
        child: Focus(
          autofocus: true,
          child: ValueListenableBuilder(
            valueListenable: pendingDeletes,
            builder: (context, hidden, _) {
              final all = projects.value;
              final shown = all == null ? null : _visible(all, hidden);
              final count = all?.where((s) => !hidden.contains(s.path)).length;
              return compact
                  ? _compactLayout(projects, shown, count)
                  : Row(
                      children: [
                        HomeSidebar(editCount: count),
                        Expanded(child: _wideLayout(projects, shown, count)),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(
    AsyncValue<List<ProjectSummary>> projects,
    List<ProjectSummary>? shown,
    int? count,
  ) {
    const pad = 40.0;
    final empty = count == 0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(pad, 36, pad, 0),
          sliver: SliverToBoxAdapter(
            child: _Header(
              greeting: _greeting(),
              search: empty ? null : _searchField(),
              onNewEdit: () => startNewEdit(ref, context),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(pad, 28, pad, 0),
          sliver: SliverToBoxAdapter(
            child: StartHero(key: const Key('start-hero'), empty: empty),
          ),
        ),
        ..._gridSlivers(projects, shown, count, pad: pad, compact: false),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _compactLayout(
    AsyncValue<List<ProjectSummary>> projects,
    List<ProjectSummary>? shown,
    int? count,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 16.0 : 24.0;
    final empty = count == 0;
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        final extend = switch (n.direction) {
          ScrollDirection.reverse => false,
          ScrollDirection.forward => true,
          ScrollDirection.idle => _fabExtended,
        };
        if (n.metrics.pixels <= 0 && !extend) return false;
        if (extend != _fabExtended) setState(() => _fabExtended = extend);
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PhoneHeader(
              top: MediaQuery.paddingOf(context).top,
              pad: pad,
              greeting: _greeting(),
              searching: _phoneSearch,
              onSearch: empty
                  ? null
                  : () {
                      setState(() => _phoneSearch = !_phoneSearch);
                      if (_phoneSearch) {
                        _searchFocus.requestFocus();
                      } else {
                        _search.clear();
                      }
                    },
            ),
          ),
          if (_phoneSearch && !empty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
              sliver: SliverToBoxAdapter(child: _searchField(expand: true)),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
            sliver: SliverToBoxAdapter(
              child: StartHero(
                key: const Key('start-hero'),
                empty: empty,
                compact: true,
              ),
            ),
          ),
          ..._gridSlivers(projects, shown, count, pad: pad, compact: true),
          // Room to scroll the last cards out from under the button.
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }

  String _greeting() {
    final name = ref.watch(preferencesProvider).value?.yourName.trim() ?? '';
    final h = DateTime.now().hour;
    final part = h < 5
        ? 'Working late'
        : h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
    return name.isEmpty ? part : '$part, ${name.split(' ').first}';
  }

  Widget _searchField({bool expand = false}) =>
      _SearchField(controller: _search, focus: _searchFocus, expand: expand);

  List<Widget> _gridSlivers(
    AsyncValue<List<ProjectSummary>> projects,
    List<ProjectSummary>? shown,
    int? count, {
    required double pad,
    required bool compact,
  }) {
    if (projects.hasError && shown == null) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: CutIcons.warning,
            title: 'Couldn\'t read your edits',
            body:
                'Something is wrong with the Projects folder. Your videos '
                'are safe where they are.',
            compact: true,
          ),
        ),
      ];
    }
    if (count == 0) return const [];
    final section = SliverPadding(
      padding: EdgeInsets.fromLTRB(pad, compact ? 28 : 40, pad, 16),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Text('All edits', style: CutType.title),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                '$count',
                style: CutType.title.copyWith(color: Cut.textTertiary),
              ),
            ],
            const Spacer(),
            if (count != null && count > 1)
              SegmentedPill<EditSort>(
                key: const Key('dashboard-sort'),
                height: compact ? 36 : 32,
                segments: const [
                  (EditSort.recent, 'Recent', null),
                  (EditSort.name, 'Name', null),
                  (EditSort.duration, 'Length', null),
                ],
                selected: _sort,
                onChanged: (s) => setState(() => _sort = s),
              ),
          ],
        ),
      ),
    );
    if (shown == null) {
      return [section, _grid(pad, compact, 6, (_) => const _SkeletonCard())];
    }
    if (shown.isEmpty) {
      return [
        section,
        SliverToBoxAdapter(
          child: EmptyState(
            icon: CutIcons.search,
            title: 'No edits match "${_search.text.trim()}"',
            body: 'Try a shorter word, or clear the search.',
            compact: true,
            actions: [
              TextButton(
                onPressed: _search.clear,
                child: const Text('Clear search'),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      section,
      _grid(
        pad,
        compact,
        shown.length,
        (i) => ArriveIn(
          delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
          child: ProjectCard(
            key: ValueKey(shown[i].path),
            summary: shown[i],
            compact: isTouchPlatform,
          ),
        ),
      ),
    ];
  }

  Widget _grid(
    double pad,
    bool compact,
    int count,
    Widget Function(int) item,
  ) => SliverPadding(
    padding: EdgeInsets.symmetric(horizontal: pad),
    // Cards are exactly as tall as a 16:9 frame plus the text under it,
    // whatever the column width.
    sliver: SliverLayoutBuilder(
      builder: (context, c) {
        final gap = compact && c.crossAxisExtent < 600 ? 12.0 : 16.0;
        final w = c.crossAxisExtent;
        var cols = compact
            ? (w < 360
                  ? 1
                  : w < 600
                  ? 2
                  : (w / (300 + gap)).ceil())
            : (w / (320 + gap)).ceil();
        // Desktop cards stay between 240 and 320 wide.
        while (!compact && cols > 1 && (w - gap * (cols - 1)) / cols < 240) {
          cols--;
        }
        final cardW = (w - gap * (cols - 1)) / cols;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: cardW * 9 / 16 + ProjectCard.footerHeight(context),
          ),
          itemCount: count,
          itemBuilder: (_, i) => item(i),
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.search,
    required this.onNewEdit,
  });

  final String greeting;
  final Widget? search;
  final VoidCallback onNewEdit;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: CutType.label.copyWith(color: Cut.textTertiary),
            ),
            const SizedBox(height: 6),
            Text('Your edits', style: CutType.display),
          ],
        ),
      ),
      if (search != null) ...[search!, const SizedBox(width: 12)],
      SizedBox(
        height: 40,
        child: FilledButton.icon(
          key: const Key('new-edit'),
          onPressed: onNewEdit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CutRadii.md),
            ),
            padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
          ),
          icon: const Icon(CutIcons.add, size: 18),
          label: const Text('New edit'),
        ),
      ),
    ],
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    this.expand = false,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final mac = Platform.isMacOS || Platform.isIOS;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CutRadii.pill),
      borderSide: const BorderSide(color: Cut.strokeSubtle),
    );
    return SizedBox(
      width: expand ? double.infinity : 260,
      height: expand ? 44 : 36,
      child: TextField(
        key: const Key('dashboard-search'),
        controller: controller,
        focusNode: focus,
        textAlignVertical: TextAlignVertical.center,
        style: CutType.label.copyWith(fontSize: 14),
        onTapOutside: (_) => focus.unfocus(),
        decoration: InputDecoration(
          hintText: 'Search edits',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          prefixIcon: const Icon(CutIcons.search, size: 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: controller.text.isNotEmpty
              ? CutIconButton(
                  icon: CutIcons.close,
                  tooltip: 'Clear',
                  size: 28,
                  iconSize: 14,
                  onPressed: controller.clear,
                )
              : isTouchPlatform
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyCap(mac ? '⌘' : 'Ctrl'),
                      const SizedBox(width: 3),
                      const KeyCap('K'),
                    ],
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 36),
          border: pill,
          enabledBorder: pill,
          focusedBorder: pill.copyWith(
            borderSide: const BorderSide(color: Cut.focusRing, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The phone's top: the wordmark, the AI status and settings, and a large
/// "Your edits" that tucks into the bar as you scroll.
class _PhoneHeader extends SliverPersistentHeaderDelegate {
  _PhoneHeader({
    required this.top,
    required this.pad,
    required this.greeting,
    required this.searching,
    required this.onSearch,
  });

  final double top;
  final double pad;
  final String greeting;
  final bool searching;
  final VoidCallback? onSearch;

  static const _bar = 56.0;
  static const _large = 76.0;

  @override
  double get minExtent => top + _bar;

  @override
  double get maxExtent => top + _bar + _large;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / _large).clamp(0.0, 1.0);
    final bg = Cut.base.withValues(alpha: 0.82 + 0.1 * t);
    final content = Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: bg)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Opacity(
            opacity: t,
            child: const Divider(height: 1, color: Cut.strokeSubtle),
          ),
        ),
        // The large title, fading and rising into the bar.
        Positioned(
          left: pad,
          right: pad,
          top: top + _bar - shrinkOffset.clamp(0, _large) * 0.5,
          child: Opacity(
            opacity: (1 - t * 1.6).clamp(0.0, 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: CutType.label.copyWith(color: Cut.textTertiary),
                ),
                const SizedBox(height: 4),
                Text('Your edits', style: CutType.displaySm),
              ],
            ),
          ),
        ),
        Positioned(
          left: pad,
          right: pad - 8,
          top: top,
          height: _bar,
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Opacity(
                      opacity: 1 - t,
                      child: const CutlineWordmark(
                        size: 22,
                        background: Cut.base,
                      ),
                    ),
                    Opacity(
                      opacity: t,
                      child: Text('Your edits', style: CutType.title),
                    ),
                  ],
                ),
              ),
              const AiStatusChip(compact: true),
              const SizedBox(width: 4),
              if (onSearch != null)
                CutIconButton(
                  key: const Key('dashboard-search-toggle'),
                  icon: searching ? CutIcons.close : CutIcons.search,
                  tooltip: searching ? 'Close search' : 'Search',
                  size: 44,
                  iconSize: 22,
                  onPressed: onSearch,
                ),
              CutIconButton(
                key: const Key('dashboard-settings'),
                icon: CutIcons.settings,
                tooltip: 'Settings',
                size: 44,
                iconSize: 22,
                onPressed: () => showSettings(context),
              ),
            ],
          ),
        ),
      ],
    );
    if (t == 0 || reduceEffects(context)) return content;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20 * t, sigmaY: 20 * t),
        child: content,
      ),
    );
  }

  @override
  bool shouldRebuild(_PhoneHeader old) =>
      old.top != top ||
      old.pad != pad ||
      old.greeting != greeting ||
      old.searching != searching ||
      (old.onSearch == null) != (onSearch == null);
}

/// The phone's main action: an aurora pill that tucks into a round button
/// while you scroll down the list.
class _NewEditFab extends StatelessWidget {
  const _NewEditFab({required this.extended, required this.onPressed});

  final bool extended;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('new-edit'),
    semanticLabel: 'New edit',
    onTap: () {
      HapticFeedback.selectionClick();
      onPressed();
    },
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: Cut.auroraGradient,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66B14DFF),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: CutMotion.normal,
        curve: CutMotion.decelerate,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CutIcons.ai, size: 22, color: Colors.white),
              if (extended) ...[
                const SizedBox(width: 10),
                Text(
                  'New edit',
                  style: CutType.label.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 620)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Cut.surface1,
      borderRadius: BorderRadius.circular(CutRadii.lg),
      border: Border.all(color: Cut.strokeSubtle),
    ),
    clipBehavior: Clip.antiAlias,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: 0)),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 4, width: 120, radius: 2),
              SizedBox(height: 12),
              Skeleton(height: 12, width: 140, radius: 4),
              SizedBox(height: 8),
              Skeleton(height: 10, width: 90, radius: 4),
            ],
          ),
        ),
      ],
    ),
  );
}
