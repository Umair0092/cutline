import 'package:flutter/material.dart';

import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';

/// What a suggestion card needs before it can be sent.
enum SuggestionNeeds { nothing, logo, photos }

/// A thing to try in an empty chat.
class ChatSuggestion {
  const ChatSuggestion({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.prompt,
    this.needs = SuggestionNeeds.nothing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String prompt;
  final SuggestionNeeds needs;
}

/// Four big ideas for the 2 × 2 grid, then two more as chips. Each shows
/// off something the assistant really does.
const chatSuggestions = [
  ChatSuggestion(
    icon: CutIcons.cut,
    color: Cut.trackVideo,
    title: 'Cut the silences',
    subtitle: 'and slow starts',
    prompt:
        'Cut out the long pauses, and trim the first few seconds before I '
        'start talking.',
  ),
  ChatSuggestion(
    icon: CutIcons.intro,
    color: Cut.trackTitle,
    title: 'Add a logo intro',
    subtitle: 'attach your logo',
    prompt: 'Make a short intro before the video with this logo.',
    needs: SuggestionNeeds.logo,
  ),
  ChatSuggestion(
    icon: CutIcons.music,
    color: Cut.trackMusic,
    title: 'Background music',
    subtitle: 'calm and lo-fi',
    prompt: 'Find some calm lo-fi background music for this video.',
  ),
  ChatSuggestion(
    icon: CutIcons.meme,
    color: Cut.trackOverlay,
    title: 'Funny memes',
    subtitle: 'at the right moments',
    prompt: 'Suggest memes for the funniest moments.',
  ),
  ChatSuggestion(
    icon: CutIcons.mic,
    color: Cut.trackVoice,
    title: 'Write a voiceover',
    subtitle: '',
    prompt:
        'Write a short, friendly voiceover introducing this video and add it '
        'at the start.',
  ),
  ChatSuggestion(
    icon: CutIcons.image,
    color: Cut.trackOverlay,
    title: 'Video from photos',
    subtitle: '',
    prompt: 'Make a video from these photos, about 3 seconds each.',
    needs: SuggestionNeeds.photos,
  ),
];

/// The empty chat: a soft aurora glow, a sparkle, "What should we make?",
/// a line that says what the assistant can see, and ideas to start with.
class ChatWelcome extends StatelessWidget {
  const ChatWelcome({super.key, required this.context, required this.onPick});

  /// "I can see your 0:20 video and its transcript."
  final String context;
  final ValueChanged<ChatSuggestion> onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final short = box.maxHeight < 380;
      final compact = box.maxHeight < 560;
      final cards = chatSuggestions.take(4).toList();
      final more = chatSuggestions.skip(4).toList();
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, compact ? 8 : 20, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (box.maxHeight - (compact ? 24 : 36)).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: compact ? 72 : 104,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      child: AuroraGlow(
                        size: compact ? 220 : 300,
                        opacity: 0.26,
                      ),
                    ),
                    _HeroSparkle(size: compact ? 52 : 64),
                  ],
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              Text(
                'What should we make?',
                textAlign: TextAlign.center,
                style: CutType.headlineSm.copyWith(
                  fontSize: compact ? 20 : 24,
                  height: compact ? 26 / 20 : 30 / 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                this.context,
                textAlign: TextAlign.center,
                style: CutType.body.copyWith(
                  color: Cut.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(height: compact ? 14 : 22),
              if (short)
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: chatSuggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => SizedBox(
                      width: 176,
                      child: ArriveIn(
                        delay: Duration(milliseconds: 30 * i),
                        child: _SuggestionCard(
                          s: chatSuggestions[i],
                          onTap: () => onPick(chatSuggestions[i]),
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, s) in cards.indexed)
                          SizedBox(
                            width: w,
                            child: ArriveIn(
                              delay: Duration(milliseconds: 40 * i),
                              child: _SuggestionCard(
                                s: s,
                                onTap: () => onPick(s),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in more)
                      PromptChip(
                        label: s.title,
                        icon: s.icon,
                        onTap: () => onPick(s),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// The big sparkle on a dark glass tile with a faint aurora ring.
class _HeroSparkle extends StatelessWidget {
  const _HeroSparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => AuroraBorder(
    radius: size * 0.32,
    width: 1,
    opacity: 0.55,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Cut.surface2,
        borderRadius: BorderRadius.circular(size * 0.32 - 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55B14DFF),
            blurRadius: 32,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32 - 1),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.5],
        ),
      ),
      alignment: Alignment.center,
      child: AuroraIcon(size: size * 0.5),
    ),
  );
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({required this.s, required this.onTap});

  final ChatSuggestion s;
  final VoidCallback onTap;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        hoverLift: 2,
        pressedScale: 0.98,
        semanticLabel: s.title,
        child: AnimatedContainer(
          duration: CutMotion.fast,
          curve: CutMotion.standard,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
          decoration: BoxDecoration(
            color: _hover ? Cut.surface3 : Cut.surface2,
            borderRadius: BorderRadius.circular(CutRadii.md),
            border: Border.all(
              color: _hover ? Cut.strokeDefault : Cut.strokeSubtle,
            ),
            boxShadow: _hover ? CutShadows.e2 : CutShadows.e1,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CutRadii.md),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Cut.highlightTop, Color(0x00FFFFFF)],
              stops: [0, 0.4],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(s.icon, size: 14, color: s.color),
                  ),
                  const Spacer(),
                  if (s.needs != SuggestionNeeds.nothing)
                    const Icon(
                      CutIcons.attach,
                      size: 13,
                      color: Cut.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CutType.label.copyWith(
                  color: Cut.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              if (s.subtitle.isNotEmpty)
                Text(
                  s.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CutType.caption.copyWith(
                    color: Cut.textTertiary,
                    fontSize: 11.5,
                    height: 15 / 11.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No API key yet: what the assistant does, and the button to connect it.
class ChatNoKey extends StatelessWidget {
  const ChatNoKey({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Positioned(child: AuroraGlow(size: 260, opacity: 0.2)),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Cut.surface2,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Cut.strokeDefault),
                      boxShadow: CutShadows.e2,
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        AuroraIcon(size: 28),
                        Positioned(
                          right: 9,
                          bottom: 9,
                          child: Icon(
                            CutIcons.key,
                            size: 14,
                            color: Cut.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Edit by talking',
              textAlign: TextAlign.center,
              style: CutType.headlineSm,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect an AI to cut, add titles, music and memes just by '
              'asking. Groq is free and takes a minute to set up.',
              textAlign: TextAlign.center,
              style: CutType.body.copyWith(color: Cut.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('open-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(CutIcons.key, size: 16),
              label: const Text('Add API Key…'),
              style: FilledButton.styleFrom(
                minimumSize: Size(0, isTouchPlatform ? 48 : 40),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CutIcons.lock, size: 13, color: Cut.textTertiary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your key is stored securely on this device.',
                    style: CutType.caption.copyWith(color: Cut.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
