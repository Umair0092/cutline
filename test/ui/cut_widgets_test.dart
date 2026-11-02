import 'package:cutline/ui/theme.dart';
import 'package:cutline/ui/widgets/cut_icons.dart';
import 'package:cutline/ui/widgets/cut_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the shared components build with the theme', (tester) async {
    var picked = 'a';
    await tester.pumpWidget(
      MaterialApp(
        theme: cutlineTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const CutSurface(level: 3, child: Text('surface')),
                const GlassPanel(child: Text('glass')),
                const AuroraIcon(),
                const AuroraBorder(spinning: true, child: Text('composer')),
                AuroraButton(label: 'Ask AI', onPressed: () {}),
                PromptChip(label: 'Cut the silences', ai: true, onTap: () {}),
                const CutBadge('1080p', mono: true),
                const ShimmerText('Thinking…'),
                const Skeleton(width: 80),
                const TimecodeText('00:01:23.12'),
                const KeyCap('⌘K'),
                const SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: CutIcons.film,
                    title: 'Nothing yet',
                    body: 'Import a video.',
                  ),
                ),
                const SectionLabel('Audio'),
                CutIconButton(
                  icon: CutIcons.undo,
                  tooltip: 'Undo',
                  onPressed: () {},
                ),
                SizedBox(
                  width: 300,
                  child: SegmentedPill<String>(
                    segments: const [
                      ('a', 'AI', CutIcons.ai),
                      ('b', 'Transcript', CutIcons.transcript),
                    ],
                    selected: picked,
                    onChanged: (v) => picked = v,
                  ),
                ),
                const ArriveIn(child: Text('arrives')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cut the silences'), findsOneWidget);
    await tester.ensureVisible(find.text('Transcript'));
    await tester.pump();
    await tester.tap(find.text('Transcript'));
    expect(picked, 'b');
    // Endless animations (shimmer, spinning border) never settle; unmount.
    await tester.pumpWidget(const SizedBox());
  });

  test('icons use the bundled Phosphor fonts', () {
    expect(CutIcons.ai.fontFamily, 'PhosphorFill');
    expect(CutIcons.split.fontFamily, 'PhosphorRegular');
    expect(CutIcons.send.fontFamily, 'PhosphorBold');
  });
}
