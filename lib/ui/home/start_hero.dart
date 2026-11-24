import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/onboarding.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';
import 'start_actions.dart';

/// Things to ask for on the way in. Each picks a video, then hands the
/// words to the assistant.
const startPrompts = [
  ('Make a 30 s highlight', 'Cut this down to the best 30 seconds.'),
  (
    'Add an intro + music',
    'Add a short intro title, then background music that fits the mood.',
  ),
  ('Turn it into a meme', 'Add memes where it\'s funny.'),
];

/// The "Start with AI" card at the top of the home screen: drop videos or
/// pictures on it, or pick a prompt to start an edit with. When there are
/// no edits yet it grows into the welcome ([empty]).
class StartHero extends ConsumerStatefulWidget {
  const StartHero({super.key, this.empty = false, this.compact = false});

  /// No edits yet: the big welcome version.
  final bool empty;

  /// Phone layout: no drop zone, actions as big buttons.
  final bool compact;

  @override
  ConsumerState<StartHero> createState() => _StartHeroState();
}

class _StartHeroState extends ConsumerState<StartHero> {
  bool _dragging = false;

  void _video([String? prompt]) => startNewEdit(ref, context, prompt: prompt);
  void _photos() => startFromPhotos(ref, context);
  void _sample() => startWithSample(ref, context, () => makeSampleVideo(ref));

  @override
  Widget build(BuildContext context) {
    final content = widget.empty
        ? _welcome()
        : widget.compact
        ? _compactBody()
        : _wideBody();
    const inner = CutRadii.xl - 1.5;
    final surface = AnimatedContainer(
      duration: CutMotion.normal,
      decoration: BoxDecoration(
        color: _dragging
            ? Color.alphaBlend(Cut.accent.withValues(alpha: 0.06), Cut.surface2)
            : Cut.surface2,
        borderRadius: BorderRadius.circular(inner),
        boxShadow: CutShadows.e1,
      ),
      child: CustomPaint(
        foregroundPainter: _dragging ? null : _DashedBorder(radius: inner),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(inner),
          child: content,
        ),
      ),
    );
    // While something is dragged over it, the dashed edge becomes a
    // spinning aurora ring and the card leans in.
    final card = AnimatedScale(
      scale: _dragging ? 1.01 : 1,
      duration: CutMotion.normal,
      curve: Curves.easeOutBack,
      child: _dragging
          ? AuroraBorder(radius: CutRadii.xl, spinning: true, child: surface)
          : Padding(padding: const EdgeInsets.all(1.5), child: surface),
    );
    if (isTouchPlatform) return card;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        await startFromDrop(ref, context, [
          for (final f in details.files) f.path,
        ]);
      },
      child: card,
    );
  }

  /// The quick-start chips. [photosFirst] puts the photo start up front,
  /// where there's no other way in without a video (phone layout).
  List<Widget> _chipWidgets({required bool photosFirst}) {
    final photos = PromptChip(
      key: const Key('start-photos-chip'),
      label: 'Photos → video',
      icon: CutIcons.image,
      onTap: _photos,
    );
    return [
      if (photosFirst) photos,
      for (final (label, prompt) in startPrompts)
        PromptChip(label: label, ai: true, onTap: () => _video(prompt)),
      if (!photosFirst) photos,
    ];
  }

  Widget _chips({bool wrap = true}) {
    final chips = _chipWidgets(photosFirst: !wrap);
    if (wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CutSpace.s4),
      child: Row(
        children: [
          for (final (i, c) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            c,
          ],
        ],
      ),
    );
  }

  /// Wide layout: a single scrollable strip that stays inside its column.
  /// Chips that don't fit stay reachable by scrolling, and a trailing fade
  /// hints there's more rather than hard-clipping the last chip behind the
  /// action buttons.
  Widget _wideChips() {
    final chips = _chipWidgets(photosFirst: false);
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0, 0.9, 1],
        colors: [Colors.black, Colors.black, Colors.transparent],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, c) in chips.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              c,
            ],
            // Breathing room so the fade never bites into the last chip.
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _sparkleTile(double size) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -size,
          top: -size,
          right: -size,
          bottom: -size,
          child: const AuroraGlow(opacity: 0.2),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Cut.surface3,
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(color: Cut.strokeDefault),
            boxShadow: CutShadows.e1,
          ),
          alignment: Alignment.center,
          child: AuroraIcon(size: size * 0.46),
        ),
      ],
    ),
  );

  Widget _wideBody() => SizedBox(
    height: 148,
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            children: [
              _sparkleTile(56),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'START WITH AI',
                      style: CutType.overline.copyWith(
                        color: Cut.onAccentContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drop a video or photos here, then say what you want',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CutType.title,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(height: 32, child: _wideChips()),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 188,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('start-video'),
                      onPressed: _video,
                      icon: const Icon(CutIcons.video, size: 18),
                      label: const Text('Choose video'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('start-photos'),
                      onPressed: _photos,
                      icon: const Icon(CutIcons.image, size: 18),
                      label: const Text('Start from photos'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_dragging) Positioned.fill(child: _dropHint()),
      ],
    ),
  );

  Widget _dropHint() => IgnorePointer(
    child: Container(
      color: Cut.surface2.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuroraIcon(size: 22),
          const SizedBox(width: 10),
          Text('Drop to start a new edit', style: CutType.title),
        ],
      ),
    ),
  );

  Widget _compactBody() => Padding(
    padding: const EdgeInsets.symmetric(vertical: CutSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CutSpace.s4),
          child: Row(
            children: [
              _sparkleTile(44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START WITH AI',
                      style: CutType.overline.copyWith(
                        color: Cut.onAccentContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick a video or photos, then say what you want',
                      style: CutType.titleSm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _chips(wrap: false),
      ],
    ),
  );

  Widget _welcome() {
    final compact = widget.compact;
    return Stack(
      children: [
        Positioned(
          top: -160,
          left: 0,
          right: 0,
          child: Center(
            child: AuroraGlow(size: compact ? 420 : 560, opacity: 0.2),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 40,
            compact ? 28 : 40,
            compact ? 20 : 40,
            compact ? 20 : 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: double.infinity),
              Container(
                width: compact ? 76 : 92,
                height: compact ? 76 : 92,
                decoration: BoxDecoration(
                  color: Cut.surface3,
                  borderRadius: BorderRadius.circular(compact ? 24 : 28),
                  border: Border.all(color: Cut.strokeDefault),
                  boxShadow: CutShadows.e2,
                ),
                alignment: Alignment.center,
                // Duotone: a soft accent fill under the outline.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      CutIcons.filmFill,
                      size: compact ? 48 : 60,
                      color: Cut.accent.withValues(alpha: 0.32),
                    ),
                    Icon(
                      CutIcons.film,
                      size: compact ? 48 : 60,
                      color: Cut.onAccentContainer,
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              Text(
                'Your first edit is one sentence away',
                textAlign: TextAlign.center,
                style: compact ? CutType.headlineSm : CutType.headline,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  compact
                      ? 'Pick a video, then tell Cutline what to change: '
                            '“cut the ums”, “add an intro”, “put music '
                            'under it”.'
                      : 'Drop a video here, or pick one. Then tell Cutline '
                            'what to change: “cut the ums”, “add an intro”, '
                            '“put music under it”.',
                  textAlign: TextAlign.center,
                  style: CutType.body.copyWith(color: Cut.textSecondary),
                ),
              ),
              SizedBox(height: compact ? 20 : 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('empty-import'),
                    onPressed: _video,
                    icon: const Icon(CutIcons.upload, size: 18),
                    label: const Text('Import video'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('empty-sample'),
                    onPressed: _sample,
                    icon: const Icon(CutIcons.playCircle, size: 18),
                    label: const Text('Try a sample clip'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 24 : 32),
              _ideas(),
            ],
          ),
        ),
        if (_dragging) Positioned.fill(child: _dropHint()),
      ],
    );
  }

  /// Three starting points as little cards.
  Widget _ideas() {
    final ideas = [
      (
        CutIcons.cut,
        Cut.trackVideo,
        'Highlight reel',
        'The best 30 seconds of a long take',
        () => _video(startPrompts.first.$2),
      ),
      (
        CutIcons.intro,
        Cut.trackTitle,
        'Logo intro',
        'Your logo spins in before the video',
        () => startFromPhotos(
          ref,
          context,
          prompt: 'Make an intro with my logo.',
        ),
      ),
      (
        CutIcons.image,
        Cut.trackOverlay,
        'Photo story',
        'A video made from your pictures',
        _photos,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final stack = box.maxWidth < 560;
        final cards = [
          for (final (icon, color, title, body, onTap) in ideas)
            _IdeaCard(
              icon: icon,
              color: color,
              title: title,
              body: body,
              onTap: onTap,
            ),
        ];
        if (stack) {
          return Column(
            children: [
              for (final (i, c) in cards.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                c,
              ],
            ],
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Row(
            children: [
              for (final (i, c) in cards.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: c),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IdeaCard extends StatefulWidget {
  const _IdeaCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Pressable(
      onTap: widget.onTap,
      hoverLift: 2,
      child: AnimatedContainer(
        duration: CutMotion.normal,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hover ? Cut.surface4 : Cut.surface3,
          borderRadius: BorderRadius.circular(CutRadii.md + 2),
          border: Border.all(
            color: _hover ? Cut.strokeDefault : Cut.strokeSubtle,
          ),
          boxShadow: _hover ? CutShadows.e2 : CutShadows.e1,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(CutRadii.sm + 2),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 20, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: CutType.titleSm.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CutType.caption.copyWith(color: Cut.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A 1 px dashed rounded border, for drop zones.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = Cut.strokeStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.radius != radius;
}
