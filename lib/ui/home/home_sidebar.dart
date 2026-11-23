import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/api_key_store.dart';
import '../../ai/assistant_client.dart';
import '../../onboarding/onboarding.dart';
import '../about.dart';
import '../settings_dialog.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';
import 'start_actions.dart';
import 'wordmark.dart';

/// The home screen's left column on desktop: the wordmark, where you are,
/// and at the bottom which AI is connected and the settings.
class HomeSidebar extends ConsumerWidget {
  const HomeSidebar({super.key, required this.editCount});

  final int? editCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Cut.surface1,
        border: Border(right: BorderSide(color: Cut.strokeSubtle)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CutlineWordmark(size: 26, background: Cut.surface1),
                ),
              ),
              _NavItem(
                icon: CutIcons.home,
                selectedIcon: CutIcons.homeFill,
                label: 'Your edits',
                trailing: editCount == null || editCount == 0
                    ? null
                    : '$editCount',
                selected: true,
                onTap: () {},
              ),
              if (!Platform.isAndroid && !Platform.isIOS)
                _NavItem(
                  key: const Key('open-project-file'),
                  icon: CutIcons.folder,
                  label: 'Open project file…',
                  onTap: () => openProjectFile(ref, context),
                ),
              _NavItem(
                key: const Key('dashboard-tour'),
                icon: CutIcons.help,
                label: 'Getting started',
                onTap: () => showOnboarding(context),
              ),
              const Spacer(),
              const AiStatusChip(),
              const SizedBox(height: 8),
              _NavItem(
                key: const Key('dashboard-settings'),
                icon: CutIcons.settings,
                label: 'Settings',
                onTap: () => showSettings(context),
              ),
              _NavItem(
                icon: CutIcons.info,
                label: 'About Cutline',
                onTap: () => showCutlineAbout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selectedIcon,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? trailing;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: on,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: CutMotion.instant,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: on
                    ? Cut.surface4
                    : _hover
                    ? Cut.hover
                    : null,
                borderRadius: BorderRadius.circular(CutRadii.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    on ? widget.selectedIcon ?? widget.icon : widget.icon,
                    size: 18,
                    color: on ? Cut.textPrimary : Cut.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CutType.label.copyWith(
                        fontSize: 14,
                        color: on ? Cut.textPrimary : Cut.textSecondary,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.trailing case final t?)
                    Text(
                      t,
                      style: CutType.caption.copyWith(
                        color: Cut.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

/// Which AI is connected: "Groq · Free" with a green dot, or a nudge to
/// add a key. Opens Settings.
class AiStatusChip extends ConsumerWidget {
  const AiStatusChip({super.key, this.compact = false});

  /// Just the dot and the service name (phone top bar).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(aiProviderProvider).value ?? AiProvider.groq;
    final key = ref.watch(apiKeyProvider);
    final ready = key.value != null;
    final name = provider.freeToStart ? 'Groq · Free' : provider.label;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ready ? Cut.success : Cut.warning,
        boxShadow: [
          BoxShadow(
            color: (ready ? Cut.success : Cut.warning).withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
    if (compact) {
      return Tooltip(
        message: ready ? 'Assistant: $name' : 'Add an AI key',
        child: Pressable(
          onTap: () => showSettings(context),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Cut.surface2,
              borderRadius: BorderRadius.circular(CutRadii.pill),
              border: Border.all(color: Cut.strokeSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot,
                const SizedBox(width: 6),
                Text(
                  ready ? name : 'Add AI key',
                  style: CutType.caption.copyWith(color: Cut.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Pressable(
      key: const Key('ai-status'),
      onTap: () => showSettings(context),
      pressedScale: 0.98,
      child: CutSurface(
        level: 2,
        radius: CutRadii.md,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            const AuroraIcon(size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistant',
                    style: CutType.caption.copyWith(color: Cut.textTertiary),
                  ),
                  Text(
                    ready ? name : 'Add an AI key',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CutType.label.copyWith(color: Cut.textPrimary),
                  ),
                ],
              ),
            ),
            dot,
          ],
        ),
      ),
    );
  }
}
