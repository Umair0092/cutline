import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../startup/startup.dart';

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

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('splash'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CutlineLogo(),
            const SizedBox(height: 20),
            Text(
              'Cutline',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: 'Inter',
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Edit videos by saying what you want',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 240,
              child: TweenAnimationBuilder<double>(
                // Glide between steps instead of jumping.
                tween: Tween(end: startup.progress),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) => LinearProgressIndicator(
                  key: const Key('splash-progress'),
                  value: value,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              startup.message,
              key: const Key('splash-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the splash until startup is done, then fades into [child] and
/// mentions any startup warnings once.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
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
      duration: const Duration(milliseconds: 400),
      child: done ? widget.child : const SplashScreen(),
    );
  }
}
