import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../startup/startup.dart';
import 'home/wordmark.dart';
import 'tokens.dart';
import 'widgets/cut_widgets.dart';

/// Brand colours for the logo.
const _logoStart = Color(0xFF6C5CE7);
const _logoEnd = Color(0xFFE84393);

/// The Cutline mark: a rounded square with a play triangle and a cut line
/// through it.
class CutlineLogo extends StatelessWidget {
  const CutlineLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintCutlineLogo(canvas, size);

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

/// Draws the logo filling [size]. Also used to make the app icons
/// (tool/make_icons_test.dart).
void paintCutlineLogo(Canvas canvas, Size size) {
  final s = size.width;
  final rect = Offset.zero & size;
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(s * 0.24)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_logoStart, _logoEnd],
      ).createShader(rect),
  );
  final play = Path()
    ..moveTo(s * 0.38, s * 0.28)
    ..lineTo(s * 0.74, s * 0.5)
    ..lineTo(s * 0.38, s * 0.72)
    ..close();
  canvas.drawPath(play, Paint()..color = Colors.white);
  // The cut: a slanted gap through the triangle.
  canvas.drawLine(
    Offset(s * 0.28, s * 0.66),
    Offset(s * 0.70, s * 0.30),
    Paint()
      ..color = const Color(0xFFA05BD5)
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round,
  );
}

/// The first thing you see: the wordmark draws itself in on a dark canvas
/// (the cut line first, then the letters), with a thin progress line and
/// what's being got ready underneath.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  // The cut line draws first, the letters rise in once it's going, and a
  // light runs along the line once at the end.
  late final _line = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.45, curve: CutMotion.decelerate),
  );
  late final _letters = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.18, 0.78, curve: CutMotion.decelerate),
  );
  late final _shimmer = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.62, 1, curve: Curves.easeInOut),
  );
  late final _status = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.7, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupProvider);
    final short = MediaQuery.sizeOf(context).shortestSide;
    final markSize = (short * 0.15).clamp(52.0, 84.0);
    final still = reduceEffects(context);
    return Scaffold(
      key: const Key('splash'),
      backgroundColor: Cut.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // One big, soft pool of violet light, a little above the middle.
          Align(
            alignment: const Alignment(0, -0.18),
            child: AuroraGlow(size: short * 1.2, color: Cut.accent),
          ),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _intro,
                    builder: (context, _) => CutlineWordmark(
                      key: const Key('splash-wordmark'),
                      size: markSize,
                      line: still ? 1 : _line.value,
                      letters: still ? 1 : _letters.value,
                      shimmer: still ? null : _shimmer.value,
                      background: Cut.canvas,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: CutSpace.s9,
                  child: FadeTransition(
                    opacity: still ? const AlwaysStoppedAnimation(1) : _status,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          child: TweenAnimationBuilder<double>(
                            // Glide between steps instead of jumping.
                            tween: Tween(end: startup.progress),
                            duration: CutMotion.enter,
                            curve: CutMotion.standard,
                            builder: (context, value, _) =>
                                _AuroraProgress(value: value),
                          ),
                        ),
                        const SizedBox(height: CutSpace.s3),
                        Text(
                          startup.message,
                          key: const Key('splash-message'),
                          style: CutType.caption.copyWith(
                            color: Cut.textTertiary,
                          ),
                        ),
                      ],
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
}

/// A 2 px track with an aurora fill: the splash's progress line.
class _AuroraProgress extends StatelessWidget {
  const _AuroraProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Getting ready',
    value: '${(value * 100).round()}%',
    child: Container(
      key: const Key('splash-progress'),
      height: 2,
      decoration: BoxDecoration(
        color: Cut.strokeSubtle,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.02, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: Cut.aurora,
              stops: Cut.auroraStops,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66B14DFF), blurRadius: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows the splash until startup is done, then hands over to [child]: the
/// wordmark shrinks back and fades while the app fades in towards you.
/// Mentions any startup warnings once.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  static const _splashKey = ValueKey('splash-gate');

  @override
  Widget build(BuildContext context) {
    ref.listen(startupProvider, (before, now) {
      if (now.done && !(before?.done ?? false) && now.warnings.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(now.warnings.join('\n'))));
        });
      }
    });
    final done = ref.watch(startupProvider.select((s) => s.done));
    return AnimatedSwitcher(
      duration: CutMotion.enter,
      switchInCurve: CutMotion.decelerate,
      switchOutCurve: CutMotion.accelerate,
      transitionBuilder: (child, animation) {
        final splash = child.key == _splashKey;
        // The splash leaves by shrinking a little; the app arrives from
        // slightly larger, so it feels like moving forward (shared axis Z).
        final scale = Tween<double>(
          begin: splash ? 0.92 : 1.04,
          end: 1,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: done
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : const SplashScreen(key: _splashKey),
    );
  }
}
