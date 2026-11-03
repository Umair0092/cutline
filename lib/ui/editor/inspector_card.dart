import 'package:flutter/material.dart';

import '../app_menu.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';

/// The card that holds the settings for whatever is selected (a clip, an
/// overlay, a sound) or the voiceover recorder, docked under the preview.
///
/// A coloured badge says what kind of thing it is (in its track colour),
/// then the name, then the controls. On a phone the controls sit in one
/// row that scrolls sideways, so the card never pushes the video away.
class InspectorCard extends StatelessWidget {
  const InspectorCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.meta,
    this.trailing = const [],
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? meta;
  final List<Widget> children;

  /// Buttons at the far right (delete, close).
  final List<Widget> trailing;

  /// A line under the controls, e.g. an error.
  final Widget? footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // In a narrow window the controls go in one sideways-scrolling row,
    // so the card stays short and the video keeps its room.
    builder: (context, box) =>
        _build(context, isCompact(context) || box.maxWidth < 900),
  );

  Widget _build(BuildContext context, bool oneRow) {
    final compact = isCompact(context);
    final badge = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(CutRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 15, color: color),
    );
    final name = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 150 : 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CutType.label.copyWith(fontWeight: FontWeight.w600),
          ),
          if (meta != null)
            Text(
              meta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CutType.timecode.copyWith(
                fontSize: 11,
                color: Cut.textTertiary,
              ),
            ),
        ],
      ),
    );
    final head = Row(
      mainAxisSize: MainAxisSize.min,
      children: [badge, const SizedBox(width: 10), name],
    );
    final Widget body;
    if (oneRow) {
      body = Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  head,
                  for (final c in children) ...[
                    const SizedBox(width: CutSpace.s4),
                    c,
                  ],
                ],
              ),
            ),
          ),
          ...trailing,
        ],
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: head),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: CutSpace.s4),
            color: Cut.strokeSubtle,
          ),
          Expanded(
            child: Wrap(
              spacing: CutSpace.s5,
              runSpacing: CutSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            ),
          ),
          ...trailing,
        ],
      );
    }
    return ArriveIn(
      child: CutSurface(
        level: 2,
        radius: CutRadii.md,
        margin: compact
            ? const EdgeInsets.fromLTRB(0, 6, 0, 0)
            : const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 6, compact ? 6 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [body, ?footer],
        ),
      ),
    );
  }
}

/// A quiet dropdown in a rounded field, for inspector choices.
class InspectorDropdown<T> extends StatelessWidget {
  const InspectorDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
    this.buttonKey,
  });

  /// On the dropdown button itself, for tests to tap.
  final Key? buttonKey;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: isTouchPlatform ? 40 : 30,
    padding: const EdgeInsets.only(left: 10, right: 6),
    decoration: BoxDecoration(
      color: Cut.surface3,
      borderRadius: BorderRadius.circular(CutRadii.sm),
      border: Border.all(color: Cut.strokeSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Cut.textTertiary),
          const SizedBox(width: 6),
        ],
        DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            key: buttonKey,
            value: value,
            items: items,
            hint: hint,
            isDense: true,
            onChanged: onChanged,
            style: CutType.label.copyWith(color: Cut.textPrimary),
            dropdownColor: Cut.surface4,
            borderRadius: BorderRadius.circular(CutRadii.md),
            icon: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(CutIcons.down, size: 12, color: Cut.textTertiary),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A small toggle chip: "Clean up noise", "Even loudness".
class InspectorToggle extends StatelessWidget {
  const InspectorToggle({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onChanged == null ? null : () => onChanged!(!selected),
    child: AnimatedContainer(
      duration: CutMotion.fast,
      height: isTouchPlatform ? 40 : 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? Cut.accentContainer : Cut.surface3,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(
          color: selected
              ? Cut.accent.withValues(alpha: 0.6)
              : Cut.strokeSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: CutMotion.fast,
            child: selected
                ? const Padding(
                    key: ValueKey('on'),
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(
                      CutIcons.check,
                      size: 12,
                      color: Cut.onAccentContainer,
                    ),
                  )
                : const SizedBox(key: ValueKey('off')),
          ),
          Text(
            label,
            style: CutType.label.copyWith(
              fontSize: 12.5,
              color: selected ? Cut.onAccentContainer : Cut.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
