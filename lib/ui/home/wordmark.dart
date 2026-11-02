import 'package:flutter/material.dart';

import '../tokens.dart';

/// The "cutline" wordmark: Bricolage Grotesque 800 with a thin aurora line
/// cutting through the letters at x-height.
///
/// The animation values let the splash draw it in: [line] is how far the
/// cut line has drawn (0–1), [letters] fades the letters in one after
/// another (0–1), and [shimmer] (0–1) runs a light along the line.
class CutlineWordmark extends StatelessWidget {
  const CutlineWordmark({
    super.key,
    this.size = 28,
    this.line = 1,
    this.letters = 1,
    this.shimmer,
    this.background,
    this.color = Cut.textPrimary,
  });

  /// The font size; the whole mark scales with it.
  final double size;
  final double line;
  final double letters;
  final double? shimmer;

  /// What's behind the mark. When given, the line gets a thin gap of this
  /// colour on each side, so it reads as a cut through the letters.
  final Color? background;
  final Color color;

  static const word = 'cutline';

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: CutFonts.display,
      fontSize: size,
      height: 1,
      letterSpacing: -0.03 * size,
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation('wght', 800)],
      color: color,
    );
    // Each letter fades in over 40% of the run, starting a little after
    // the one before it.
    double alpha(int i) {
      const span = 0.4;
      final start = i / (word.length - 1) * (1 - span);
      return ((letters - start) / span).clamp(0.0, 1.0);
    }

    final barHeight = (size * 0.075).clamp(2.0, 6.0);
    final gap = background == null ? 0.0 : (size * 0.03).clamp(1.0, 2.5);
    // The x-height of Bricolage sits at about 0.42–0.80 of the em box with
    // height 1; the line cuts just under the middle of it.
    final top = size * 0.60 - barHeight / 2;
    final overhang = size * 0.10;

    return Semantics(
      label: 'Cutline',
      excludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, (1 - letters.clamp(0.0, 1.0)) * size * 0.16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              // Room on the right for the line's overhang.
              padding: EdgeInsets.only(right: overhang),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final (i, ch) in word.split('').indexed)
                      TextSpan(
                        text: ch,
                        style: style.copyWith(
                          color: color.withValues(alpha: color.a * alpha(i)),
                        ),
                      ),
                  ],
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ),
            Positioned(
              left: -size * 0.02,
              right: 0,
              top: top - gap,
              height: barHeight + gap * 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: line.clamp(0.0, 1.0),
                  child: _CutLine(
                    height: barHeight,
                    gap: gap,
                    background: background,
                    shimmer: shimmer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CutLine extends StatelessWidget {
  const _CutLine({
    required this.height,
    required this.gap,
    required this.background,
    required this.shimmer,
  });

  final double height;
  final double gap;
  final Color? background;
  final double? shimmer;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height);
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          colors: Cut.aurora,
          stops: Cut.auroraStops,
        ),
      ),
      child: SizedBox(height: height),
    );
    final s = shimmer;
    if (s != null && s > 0 && s < 1) {
      bar = Stack(
        children: [
          bar,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment(-3 + s * 6, 0),
                  end: Alignment(-1 + s * 6, 0),
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0xCCFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (background == null) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(height + gap),
      ),
      child: Padding(padding: EdgeInsets.all(gap), child: bar),
    );
  }
}
