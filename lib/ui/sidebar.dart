import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../memes/meme_panel.dart';
import 'assistant/chat_draft.dart';
import 'assistant_panel.dart';
import 'tokens.dart';
import 'transcript_panel.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// The side panel: the assistant, the transcript and memes, switched with
/// a segmented pill. Tabs are built the first time you open them and then
/// kept, so a half-typed message or a meme search survives a tab switch.
class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  late int _tab = widget.initialTab;
  late final _opened = {widget.initialTab};

  @override
  void initState() {
    super.initState();
    // A prompt sent from another tab (e.g. "Suggest memes") shows the chat.
    ref.listenManual(chatDraftProvider, (_, draft) {
      if (draft != null && _tab != 0) _select(0);
    });
  }

  void _select(int i) => setState(() {
    _tab = i;
    _opened.add(i);
  });

  static const _panels = [AssistantPanel(), TranscriptPanel(), MemePanel()];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Cut.surface1,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: _Tabs(selected: _tab, onSelect: _select),
        ),
        Expanded(
          child: Stack(
            children: [
              for (final i in [0, 1, 2])
                if (_opened.contains(i))
                  Positioned.fill(
                    child: Offstage(
                      offstage: i != _tab,
                      child: TickerMode(
                        enabled: i == _tab,
                        child: _FadeIn(on: i == _tab, child: _panels[i]),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A short fade and rise each time a tab is shown.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: CutMotion.normal,
    value: 1,
  );

  @override
  void didUpdateWidget(_FadeIn old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceEffects(context)) return widget.child;
    final t = CurvedAnimation(parent: _c, curve: CutMotion.decelerate);
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(t),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.008),
          end: Offset.zero,
        ).animate(t),
        child: widget.child,
      ),
    );
  }
}

/// AI · Transcript · Memes as a pill with a sliding thumb. The AI tab
/// carries the aurora sparkle.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    ('tab-assistant', 'AI', null),
    ('tab-transcript', 'Transcript', CutIcons.transcript),
    ('tab-memes', 'Memes', CutIcons.meme),
  ];

  @override
  Widget build(BuildContext context) {
    final h = isTouchPlatform ? 44.0 : 36.0;
    return Container(
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Cut.base,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / _tabs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: CutMotion.normal,
                curve: CutMotion.decelerate,
                left: w * selected,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: Cut.surface4,
                    borderRadius: BorderRadius.circular(CutRadii.pill),
                    border: Border.all(color: Cut.strokeDefault),
                    boxShadow: CutShadows.e1,
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CutRadii.pill),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Cut.highlightTop, Color(0x00FFFFFF)],
                      stops: [0, 0.6],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, (key, label, icon)) in _tabs.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == selected,
                        button: true,
                        child: GestureDetector(
                          key: Key(key),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: _TabLabel(
                              label: label,
                              icon: icon,
                              on: i == selected,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.icon, required this.on});

  final String label;
  final IconData? icon;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? Cut.textPrimary : Cut.textTertiary;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == null)
                AnimatedOpacity(
                  duration: CutMotion.fast,
                  opacity: on ? 1 : 0.75,
                  child: const AuroraIcon(size: 14),
                )
              else
                Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: CutMotion.fast,
                style: CutType.label.copyWith(
                  color: color,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  fontVariations: [FontVariation('wght', on ? 600 : 500)],
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
