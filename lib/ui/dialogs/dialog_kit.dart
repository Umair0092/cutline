import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';

/// The building blocks every Cutline dialog and sheet shares: how they
/// open (a centred card on desktop, a tall sheet on phones), their frame,
/// buttons, rows and small animated bits.

/// Icons the dialogs need beyond [CutIcons].
abstract final class DialogIcons {
  static const aspect = IconData(0xe626, fontFamily: 'PhosphorRegular');
  static const finder = IconData(0xeb60, fontFamily: 'PhosphorRegular');
  static const open = IconData(0xe5de, fontFamily: 'PhosphorRegular');
  static const paste = IconData(0xe198, fontFamily: 'PhosphorRegular');
  static const user = IconData(0xe4c4, fontFamily: 'PhosphorRegular');
  static const smiley = IconData(0xe666, fontFamily: 'PhosphorRegular');
  static const command = IconData(0xe1c4, fontFamily: 'PhosphorRegular');
  static const appInfo = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
  static const brush = IconData(0xe6f0, fontFamily: 'PhosphorRegular');
  static const fine = IconData(0xe434, fontFamily: 'PhosphorRegular');
  static const speed = IconData(0xe628, fontFamily: 'PhosphorRegular');
  static const placementBefore = IconData(
    0xe870,
    fontFamily: 'PhosphorRegular',
  );
  static const placementOver = IconData(0xe468, fontFamily: 'PhosphorRegular');
  static const repeat = IconData(0xe3f6, fontFamily: 'PhosphorRegular');
  static const font = IconData(0xe6ee, fontFamily: 'PhosphorRegular');
  static const shield = IconData(0xe40c, fontFamily: 'PhosphorRegular');
  static const book = IconData(0xe8f2, fontFamily: 'PhosphorRegular');
  static const guide = IconData(0xe89c, fontFamily: 'PhosphorRegular');
  static const disc = IconData(0xecac, fontFamily: 'PhosphorRegular');
  static const bell = IconData(0xe5ea, fontFamily: 'PhosphorRegular');
  static const duck = IconData(0xea9c, fontFamily: 'PhosphorRegular');
  static const fileAudio = IconData(0xea20, fontFamily: 'PhosphorRegular');
  static const plusBold = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const cloud = IconData(0xe1aa, fontFamily: 'PhosphorRegular');
  static const desktop = IconData(0xe560, fontFamily: 'PhosphorRegular');
  static const xCircle = IconData(0xe4f8, fontFamily: 'PhosphorFill');
  static const faders = IconData(0xe228, fontFamily: 'PhosphorRegular');
  static const timer = IconData(0xe492, fontFamily: 'PhosphorRegular');
  static const headphones = IconData(0xe2a6, fontFamily: 'PhosphorRegular');
  static const checker = IconData(0xe8c4, fontFamily: 'PhosphorRegular');
  static const sparkleFill = IconData(0xe6a2, fontFamily: 'PhosphorFill');
  static const dashed = IconData(0xe69c, fontFamily: 'PhosphorRegular');
  static const swap = IconData(0xe094, fontFamily: 'PhosphorRegular');
  static const musicNote = IconData(0xe33c, fontFamily: 'PhosphorRegular');
  static const waveform = IconData(0xe802, fontFamily: 'PhosphorRegular');
  static const micFill = IconData(0xe326, fontFamily: 'PhosphorFill');
}

/// Phones (and very narrow windows) get sheets and stacked layouts.
bool isPhoneLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;

/// Opens [builder] the Cutline way: a centred card that rises in on desktop,
/// a bottom sheet on phones ([fullHeight] makes it nearly the whole screen).
Future<T?> showCutModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool fullHeight = true,
}) {
  if (isPhoneLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Cut.surface1,
      builder: (context) {
        final child = builder(context);
        if (!fullHeight) return child;
        return FractionallySizedBox(heightFactor: 0.96, child: child);
      },
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Cut.scrim,
    transitionDuration: CutMotion.enter,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      if (reduceEffects(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: CutMotion.decelerate,
        reverseCurve: CutMotion.accelerate,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - curved.value)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * curved.value,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// The frame of a dialog: a header (icon tile, title, subtitle, close), a
/// scrolling body and a footer of actions. On desktop it is a raised card
/// of [width]×[height]; inside a phone sheet it fills the sheet and the
/// footer sits at the bottom, in thumb reach.
class CutModal extends StatelessWidget {
  const CutModal({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.headerTrailing,
    this.footer,
    this.width = 560,
    this.height,
    this.bodyPadding,
    this.scroll = true,
    this.showClose = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? headerTrailing;
  final Widget body;
  final Widget? footer;
  final double width;
  final double? height;
  final EdgeInsetsGeometry? bodyPadding;
  final bool scroll;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    final gutter = phone ? CutSpace.s4 : CutSpace.s6;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        phone ? 0 : CutSpace.s5,
        phone ? CutSpace.s2 : CutSpace.s4,
        CutSpace.s4,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground ?? Cut.accentContainer,
                borderRadius: BorderRadius.circular(CutRadii.md),
                border: Border.all(color: Cut.strokeSubtle),
              ),
              child: Icon(
                icon,
                size: 21,
                color: iconColor ?? Cut.onAccentContainer,
              ),
            ),
            const SizedBox(width: CutSpace.s3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: CutType.headlineSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: CutType.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (headerTrailing != null) ...[
            const SizedBox(width: CutSpace.s3),
            headerTrailing!,
          ],
          if (showClose) ...[
            const SizedBox(width: CutSpace.s1),
            CutIconButton(
              icon: CutIcons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ],
      ),
    );
    final pad = bodyPadding ?? EdgeInsets.fromLTRB(gutter, 0, gutter, gutter);
    final content = scroll
        ? SingleChildScrollView(padding: pad, child: body)
        : Padding(padding: pad, child: body);
    final foot = footer == null
        ? null
        : Container(
            padding: EdgeInsets.fromLTRB(
              gutter,
              CutSpace.s3,
              gutter,
              phone ? CutSpace.s3 : CutSpace.s4,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Cut.strokeSubtle)),
            ),
            child: SafeArea(top: false, child: footer!),
          );

    if (phone) {
      return Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: content),
            ?foot,
          ],
        ),
      );
    }

    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CutSpace.s6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(width, screen.width - 48),
            maxHeight: math.min(height ?? 9999, screen.height - 48),
          ),
          child: SizedBox(
            height: height == null ? null : math.min(height!, screen.height),
            child: Material(
              type: MaterialType.transparency,
              child: CutSurface(
                level: 4,
                color: Cut.surface2,
                radius: CutRadii.xl,
                clip: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (height != null)
                      Expanded(child: content)
                    else
                      Flexible(child: content),
                    ?foot,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer actions: on desktop a quiet [leading] action on the left and the
/// rest on the right; on phones the buttons share the width, 48 tall.
class ModalActions extends StatelessWidget {
  const ModalActions({super.key, required this.actions, this.leading});

  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (isPhoneLayout(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[leading!, const SizedBox(height: 8)],
          Row(
            children: [
              for (final (i, a) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: CutSpace.s2),
                Expanded(child: a),
              ],
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        ?leading,
        const Spacer(),
        for (final (i, a) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: CutSpace.s2),
          a,
        ],
      ],
    );
  }
}

double _buttonHeight(BuildContext context) =>
    isTouchPlatform || isPhoneLayout(context) ? 48 : 40;

/// The main action: accent fill, an optional icon, a spinner while [busy].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = height ?? _buttonHeight(context);
    final child = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(expand ? double.infinity : 96, h),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        disabledForegroundColor: busy ? Cut.textPrimary : Cut.textDisabled,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Cut.textPrimary,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (busy || icon != null) const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return child;
  }
}

/// A quiet button on a raised fill: Cancel, Change, Show in Finder.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.height,
    this.transparent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final double? height;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? Cut.error : Cut.textPrimary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(64, height ?? _buttonHeight(context)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: fg,
        disabledForegroundColor: Cut.textDisabled,
        backgroundColor: transparent ? null : Cut.surface3,
        side: transparent ? null : const BorderSide(color: Cut.strokeSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: onPressed == null ? null : fg),
            const SizedBox(width: 7),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// A label above a control, with an optional value or action on the right.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing, this.icon});

  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CutSpace.s2),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: Cut.textTertiary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            text,
            style: CutType.label.copyWith(
              color: Cut.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A row with a title, an explanation and a switch; the whole row toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.color = Cut.accent,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: InkWell(
      borderRadius: BorderRadius.circular(CutRadii.md),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CutSpace.s3,
          vertical: CutSpace.s3,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: value ? color : Cut.textTertiary),
              const SizedBox(width: CutSpace.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CutType.bodyStrong),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: CutType.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: CutSpace.s3),
            Switch(value: value, onChanged: onChanged, activeTrackColor: color),
          ],
        ),
      ),
    ),
  );
}

/// A section that opens and closes under a header row ("Fine-tune").
class Disclosure extends StatefulWidget {
  const Disclosure({
    super.key,
    required this.title,
    required this.child,
    this.summary,
    this.icon,
    this.initiallyOpen = false,
  });

  final String title;
  final String? summary;
  final IconData? icon;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(CutRadii.sm),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CutSpace.s2),
          child: Row(
            children: [
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: CutMotion.normal,
                curve: CutMotion.decelerate,
                child: const Icon(
                  CutIcons.forward,
                  size: 14,
                  color: Cut.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 15, color: Cut.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.title,
                style: CutType.label.copyWith(
                  color: Cut.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.summary != null && !_open)
                TimecodeText(widget.summary!, color: Cut.textTertiary),
            ],
          ),
        ),
      ),
      AnimatedSize(
        duration: CutMotion.normal,
        curve: CutMotion.decelerate,
        alignment: Alignment.topCenter,
        child: _open
            ? Padding(
                padding: const EdgeInsets.only(top: CutSpace.s2),
                child: widget.child,
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

/// A gentle inline message: an error, a warning or a note.
class InlineNotice extends StatelessWidget {
  const InlineNotice(
    this.text, {
    super.key,
    this.color = Cut.error,
    this.background = Cut.errorContainer,
    this.icon = CutIcons.error,
    this.selectable = true,
  });

  final String text;
  final Color color;
  final Color background;
  final IconData icon;
  final bool selectable;

  @override
  Widget build(BuildContext context) => ArriveIn(
    offset: 4,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: selectable
                ? SelectableText(
                    text,
                    style: CutType.body.copyWith(color: Cut.textPrimary),
                  )
                : Text(
                    text,
                    style: CutType.body.copyWith(color: Cut.textPrimary),
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Bouncing bars, like a music app's "now playing" icon.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    this.color = Cut.trackMusic,
    this.size = 16,
    this.bars = 4,
    this.active = true,
  });

  final Color color;
  final double size;
  final int bars;
  final bool active;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size * (widget.bars / 4) * 1.1,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _BarsPainter(
          widget.color,
          widget.bars,
          reduceEffects(context) ? 0.3 : _c.value,
        ),
      ),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.color, this.bars, this.t);

  final Color color;
  final int bars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / bars * 0.35;
    final w = (size.width - gap * (bars - 1)) / bars;
    final paint = Paint()..color = color;
    for (var i = 0; i < bars; i++) {
      final phase = t * 2 * math.pi * (1 + i * 0.37) + i * 1.7;
      final h = size.height * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase)));
      final x = i * (w + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.color != color;
}

/// A soft two-colour gradient picked from [seed], for covers and avatars
/// that have no picture.
LinearGradient seededGradient(String seed, {Color? tint}) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final hue = (h % 360).toDouble();
  final a = HSLColor.fromAHSL(1, hue, 0.62, 0.52).toColor();
  final b = HSLColor.fromAHSL(1, (hue + 48) % 360, 0.7, 0.32).toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tint == null ? a : Color.lerp(a, tint, 0.45)!, b],
  );
}

/// A grey and dark-grey checkerboard, the universal sign for "see-through".
class Checkerboard extends StatelessWidget {
  const Checkerboard({super.key, this.cell = 10, this.child});

  final double cell;
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CheckerPainter(cell), child: child);
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter(this.cell);

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1B1A22),
    );
    final p = Paint()..color = const Color(0xFF23212C);
    for (var y = 0.0; y < size.height; y += cell) {
      for (
        var x = ((y / cell).round().isOdd ? cell : 0.0);
        x < size.width;
        x += cell * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.cell != cell;
}

/// A tiny "Saved" pill that fades in and out after [show] flips true.
class SavedPip extends StatelessWidget {
  const SavedPip({super.key, required this.visible, this.label = 'Saved'});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: visible ? CutMotion.fast : CutMotion.enter,
    child: CutBadge(
      label,
      icon: CutIcons.check,
      color: Cut.success,
      background: Cut.successContainer,
    ),
  );
}
