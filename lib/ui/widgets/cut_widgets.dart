import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'cut_icons.dart';

/// Whether this is a touch device (bigger targets, ripples, haptics).
final bool isTouchPlatform = Platform.isAndroid || Platform.isIOS;

/// Whether to skip blur and glow: on request (reduce motion) or on phones
/// where many blurs at once get expensive.
bool reduceEffects(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A raised surface: a lighter fill, a white-alpha stroke, a faint light
/// along the top edge and a soft two-layer shadow. Levels 1–4 go from a
/// panel to a popover. Use this instead of hand-made boxes.
class CutSurface extends StatelessWidget {
  const CutSurface({
    super.key,
    required this.child,
    this.level = 2,
    this.radius = CutRadii.lg,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.shadow = true,
    this.highlight = true,
    this.clip = false,
    this.width,
    this.height,
  });

  final Widget child;
  final int level;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final bool shadow;
  final bool highlight;
  final bool clip;
  final double? width;
  final double? height;

  static Color fill(int level) => switch (level) {
    <= 1 => Cut.surface1,
    2 => Cut.surface2,
    3 => Cut.surface3,
    _ => Cut.surface4,
  };

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color ?? fill(level),
        borderRadius: r,
        border: Border.all(
          color:
              borderColor ??
              (level >= 3 ? Cut.strokeDefault : Cut.strokeSubtle),
        ),
        boxShadow: !shadow
            ? null
            : level >= 4
            ? CutShadows.e3
            : level == 3
            ? CutShadows.e2
            : level == 2
            ? CutShadows.e1
            : null,
      ),
      foregroundDecoration: highlight
          ? BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Cut.highlightTop, Color(0x00FFFFFF)],
                stops: [0, 0.35],
              ),
            )
          : null,
      child: child,
    );
  }
}

/// Frosted glass for things that float over content (the transport bar,
/// the phone's bottom bar). Falls back to an opaque fill when effects are
/// reduced. Don't nest these.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = CutRadii.lg,
    this.padding,
    this.blur = 24,
    this.borderRadius,
    this.tint = const Color(0xB31E1C28),
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color tint;

  /// Draws glass without the blur. For screenshot tests: capturing a frame
  /// offscreen with several backdrop blurs can stall.
  static final debugNoBlur = ValueNotifier(false);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: debugNoBlur,
    builder: (context, noBlur, _) => _build(context, noBlur),
  );

  Widget _build(BuildContext context, bool noBlur) {
    final r = borderRadius ?? BorderRadius.circular(radius);
    final decoration = BoxDecoration(
      borderRadius: r,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint,
          tint.withValues(alpha: tint.a * 0.85),
        ],
      ),
      border: Border.all(color: const Color(0x24FFFFFF)),
    );
    final box = DecoratedBox(
      decoration: decoration,
      position: DecorationPosition.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.5],
          ),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (reduceEffects(context) || noBlur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Cut.surface3.withValues(alpha: 0.96),
          borderRadius: r,
          border: Border.all(color: Cut.strokeDefault),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: box,
        ),
      ),
    );
  }
}

/// Paints its child (an icon or text) with the AI gradient.
class AuroraMask extends StatelessWidget {
  const AuroraMask({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: Cut.auroraGradient.createShader,
    child: child,
  );
}

/// The AI sparkle, in the aurora gradient.
class AuroraIcon extends StatelessWidget {
  const AuroraIcon({super.key, this.size = 20, this.icon = CutIcons.ai});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AuroraMask(
    child: Icon(icon, size: size, color: Colors.white),
  );
}

/// A gradient ring around [child]: still when [active] is false, slowly
/// spinning with a glow while the AI works ([spinning]).
class AuroraBorder extends StatefulWidget {
  const AuroraBorder({
    super.key,
    required this.child,
    this.radius = CutRadii.xxl,
    this.width = 1.5,
    this.active = true,
    this.spinning = false,
    this.opacity = 1,
  });

  final Widget child;
  final double radius;
  final double width;
  final bool active;
  final bool spinning;
  final double opacity;

  @override
  State<AuroraBorder> createState() => _AuroraBorderState();
}

class _AuroraBorderState extends State<AuroraBorder>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AuroraBorder old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return AnimatedBuilder(
      animation: _spin,
      child: widget.child,
      builder: (context, child) => AnimatedContainer(
        duration: CutMotion.normal,
        curve: CutMotion.standard,
        padding: EdgeInsets.all(widget.width),
        decoration: BoxDecoration(
          borderRadius: r,
          color: widget.active ? null : Cut.strokeDefault,
          gradient: !widget.active
              ? null
              : widget.spinning
              ? SweepGradient(
                  colors: [
                    for (final c in [...Cut.aurora, Cut.aurora.first])
                      c.withValues(alpha: widget.opacity),
                  ],
                  transform: GradientRotation(_spin.value * 2 * math.pi),
                )
              : LinearGradient(
                  colors: [
                    for (final c in Cut.aurora)
                      c.withValues(alpha: widget.opacity),
                  ],
                  stops: Cut.auroraStops,
                ),
          boxShadow: widget.spinning && !reduceEffects(context)
              ? const [
                  BoxShadow(
                    color: Color(0x40B14DFF),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// A soft pool of light behind content, e.g. under an empty state.
class AuroraGlow extends StatelessWidget {
  const AuroraGlow({
    super.key,
    this.size = 440,
    this.color = const Color(0xFFB14DFF),
    this.opacity = 0.22,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    ),
  );
}

/// The primary AI action: a pill with the aurora gradient and a sparkle.
class AuroraButton extends StatelessWidget {
  const AuroraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = CutIcons.ai,
    this.height = 40,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: CutMotion.fast,
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 18),
          decoration: BoxDecoration(
            gradient: Cut.auroraGradient,
            borderRadius: BorderRadius.circular(CutRadii.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55B14DFF),
                blurRadius: 18,
                offset: Offset(0, 6),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: dense ? 16 : 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: CutType.label.copyWith(
                  color: Colors.white,
                  fontSize: dense ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 620)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales down a little while pressed and lifts on hover: the tactile
/// feel of good touch and pointer UIs.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.pressedScale = 0.97,
    this.hoverLift = 0,
    this.cursor = SystemMouseCursors.click,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final double pressedScale;
  final double hoverLift;
  final MouseCursor cursor;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? widget.cursor : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _down = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onSecondaryTap,
          child: AnimatedContainer(
            duration: _down ? CutMotion.instant : CutMotion.normal,
            curve: CutMotion.standard,
            transform: Matrix4.translationValues(
              0,
              _hover && enabled ? -widget.hoverLift : 0,
              0,
            ),
            child: AnimatedScale(
              duration: _down ? CutMotion.instant : CutMotion.normal,
              curve: _down ? Curves.linear : Curves.easeOutBack,
              scale: _down ? widget.pressedScale : 1,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded suggestion: tap to use it ("Cut the silences").
class PromptChip extends StatelessWidget {
  const PromptChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.ai = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool ai;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: isTouchPlatform ? 40 : 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Cut.surface2,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(color: Cut.strokeDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ai)
            const AuroraIcon(size: 14)
          else if (icon != null)
            Icon(icon, size: 15, color: Cut.textSecondary),
          if (ai || icon != null) const SizedBox(width: 6),
          Text(label, style: CutType.label),
        ],
      ),
    ),
  );
}

/// A small tag: "1080p", "AI", "CC BY".
class CutBadge extends StatelessWidget {
  const CutBadge(
    this.label, {
    super.key,
    this.color = Cut.textSecondary,
    this.background = Cut.surface4,
    this.icon,
    this.mono = false,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(CutRadii.xs),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: (mono ? CutType.timecode : CutType.caption).copyWith(
            fontSize: 11,
            height: 1.2,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Text with a light sweeping across it, for "Thinking…" and loading.
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: CutMotion.shimmer)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Cut.textTertiary, Colors.white, Cut.textTertiary],
        stops: const [0.35, 0.5, 0.65],
        begin: Alignment(-2.5 + _c.value * 5, 0),
        end: Alignment(-1.5 + _c.value * 5, 0),
      ).createShader(rect),
      child: child,
    ),
    child: Text(widget.text, style: widget.style ?? CutType.titleSm),
  );
}

/// A grey placeholder block with a moving sheen, while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = CutRadii.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: CutMotion.shimmer)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          colors: const [Cut.surface2, Cut.surface3, Cut.surface2],
          stops: const [0.3, 0.5, 0.7],
          begin: Alignment(-2 + _c.value * 4, 0),
          end: Alignment(-1 + _c.value * 4, 0),
        ),
      ),
    ),
  );
}

/// A timecode in the mono font, with tabular digits.
class TimecodeText extends StatelessWidget {
  const TimecodeText(this.text, {super.key, this.style, this.color});

  final String text;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (style ?? CutType.timecode).copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// A keyboard key, for shortcut hints: ⌘ K.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Cut.surface4,
      borderRadius: BorderRadius.circular(5),
      border: const Border(
        bottom: BorderSide(color: Color(0x33000000), width: 1.5),
      ),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: CutType.timecode.copyWith(fontSize: 11, height: 1.3),
    ),
  );
}

/// A friendly empty screen: an icon on a glow, a title, a line of text and
/// actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
    this.ai = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;
  final bool ai;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 36.0 : 52.0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CutSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: compact ? 80 : 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AuroraGlow(
                      size: compact ? 180 : 260,
                      color: ai ? const Color(0xFFB14DFF) : Cut.accent,
                      opacity: ai ? 0.25 : 0.18,
                    ),
                    Container(
                      width: iconSize + 28,
                      height: iconSize + 28,
                      decoration: BoxDecoration(
                        color: Cut.surface2,
                        borderRadius: BorderRadius.circular(
                          (iconSize + 28) * 0.32,
                        ),
                        border: Border.all(color: Cut.strokeDefault),
                        boxShadow: CutShadows.e2,
                      ),
                      alignment: Alignment.center,
                      child: ai
                          ? AuroraIcon(size: iconSize * 0.7, icon: icon)
                          : Icon(
                              icon,
                              size: iconSize * 0.7,
                              color: Cut.onAccentContainer,
                            ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? CutSpace.s2 : CutSpace.s4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? CutType.title : CutType.headlineSm,
              ),
              if (body != null) ...[
                const SizedBox(height: CutSpace.s2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: CutType.body.copyWith(color: Cut.textSecondary),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: CutSpace.s5),
                Wrap(
                  spacing: CutSpace.s2,
                  runSpacing: CutSpace.s2,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small uppercase label above a group of controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.only(bottom: CutSpace.s2),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: CutType.overline)),
        ?trailing,
      ],
    ),
  );
}

/// A square icon button with a quiet hover fill and a tooltip; [selected]
/// shows it on (accent container).
class CutIconButton extends StatelessWidget {
  const CutIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size,
    this.iconSize,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double? size;
  final double? iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? (isTouchPlatform ? 44.0 : 32.0);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: s,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          isSelected: selected,
          style: IconButton.styleFrom(
            backgroundColor: selected ? Cut.accentContainer : null,
            foregroundColor: selected
                ? Cut.onAccentContainer
                : color ?? Cut.textSecondary,
            disabledForegroundColor: Cut.textDisabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CutRadii.sm),
            ),
          ),
          icon: Icon(icon, size: iconSize ?? (isTouchPlatform ? 22 : 18)),
        ),
      ),
    );
  }
}

/// A pill-shaped segmented control with a sliding thumb.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height,
    this.expand = false,
  });

  final List<(T, String, IconData?)> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double? height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final h = height ?? (isTouchPlatform ? 44.0 : 34.0);
    final index = segments.indexWhere((s) => s.$1 == selected);
    return Container(
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Cut.surface2,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth.isFinite
              ? box.maxWidth / segments.length
              : null;
          final row = Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final (i, (value, label, icon)) in segments.indexed)
                _segment(i == index, value, label, icon, w, expand),
            ],
          );
          if (w == null || index < 0) return row;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: CutMotion.normal,
                curve: CutMotion.decelerate,
                left: w * index,
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
                ),
              ),
              row,
            ],
          );
        },
      ),
    );
  }

  Widget _segment(
    bool on,
    T value,
    String label,
    IconData? icon,
    double? w,
    bool expand,
  ) {
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: w,
          padding: EdgeInsets.symmetric(horizontal: w == null ? 12 : 6),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: on ? Cut.textPrimary : Cut.textTertiary,
                ),
                if (label.isNotEmpty) const SizedBox(width: 6),
              ],
              if (label.isNotEmpty)
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: CutMotion.fast,
                    style: CutType.label.copyWith(
                      color: on ? Cut.textPrimary : Cut.textTertiary,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return w == null && expand ? Expanded(child: child) : child;
  }
}

/// Slides and fades its child in once, e.g. a card arriving in the chat.
class ArriveIn extends StatelessWidget {
  const ArriveIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (reduceEffects(context)) return child;
    final total = CutMotion.enter + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: CutMotion.decelerate),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
    );
  }
}

/// A dialog laid out the Cutline way: big title, optional subtitle, body,
/// and actions at the bottom right (full width on phones).
class CutDialog extends StatelessWidget {
  const CutDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.width = 520,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 20),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: phone ? 12 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Cut.accentContainer,
                        borderRadius: BorderRadius.circular(CutRadii.md),
                      ),
                      child: Icon(icon, size: 20, color: Cut.onAccentContainer),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(title, style: CutType.headlineSm)),
                  CutIconButton(
                    icon: CutIcons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: CutType.body.copyWith(color: Cut.textSecondary),
                ),
              ],
              const SizedBox(height: CutSpace.s5),
              Flexible(child: child),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: CutSpace.s5),
                phone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final a in actions.reversed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: a,
                            ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final (i, a) in actions.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            a,
                          ],
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
