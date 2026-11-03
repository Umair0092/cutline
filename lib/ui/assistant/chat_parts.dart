import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../media/image_import.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';

/// The assistant's little face: an aurora sparkle in a dark, glowing chip.
class AiAvatar extends StatelessWidget {
  const AiAvatar({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Cut.surface3,
      border: Border.all(color: const Color(0x40B14DFF)),
      boxShadow: const [
        BoxShadow(color: Color(0x30B14DFF), blurRadius: 10, spreadRadius: -2),
      ],
    ),
    alignment: Alignment.center,
    child: AuroraIcon(size: size * 0.58),
  );
}

/// "✦ Cutline AI" above the first thing the assistant says in a turn.
class AiHeader extends StatelessWidget {
  const AiHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CutSpace.s2),
    child: Row(
      children: [
        const AiAvatar(),
        const SizedBox(width: CutSpace.s2),
        Text(
          'Cutline AI',
          style: CutType.caption.copyWith(
            color: Cut.textSecondary,
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    ),
  );
}

/// What you said: a bubble on the right with a tucked bottom-right corner.
class UserBubble extends StatelessWidget {
  const UserBubble({
    super.key,
    required this.text,
    this.attachments = const [],
  });

  final String text;
  final List<String> attachments;

  @override
  Widget build(BuildContext context) {
    final phone = isTouchPlatform || MediaQuery.sizeOf(context).width < 600;
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [for (final a in attachments) AttachmentThumb(a)],
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Cut.surface3,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                  border: Border.all(color: Cut.strokeSubtle),
                ),
                foregroundDecoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Cut.highlightTop, Color(0x00FFFFFF)],
                    stops: [0, 0.5],
                  ),
                ),
                child: SelectableText(
                  text,
                  style: CutType.body.copyWith(
                    fontSize: phone ? 15 : 14,
                    height: phone ? 22 / 15 : 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The assistant's words: no bubble, full width, light markdown (bold,
/// `code`, bullet and numbered lists). With [caret], a blinking caret
/// follows the text while it streams in.
class AssistantText extends StatelessWidget {
  const AssistantText(this.text, {super.key, this.caret = false});

  final String text;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final phone = isTouchPlatform || MediaQuery.sizeOf(context).width < 600;
    final base = CutType.body.copyWith(
      fontSize: phone ? 15 : 14,
      height: phone ? 22 / 15 : 21 / 14,
      color: Cut.textPrimary.withValues(alpha: 0.92),
    );
    final blocks = _blocks(text.trim());
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, b) in blocks.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : b.gap),
              child: _block(b, base, caret && i == blocks.length - 1),
            ),
          if (blocks.isEmpty && caret)
            const Align(
              alignment: Alignment.centerLeft,
              child: StreamingCaret(),
            ),
        ],
      ),
    );
  }

  Widget _block(_Block b, TextStyle base, bool withCaret) {
    final spans = [
      ..._inline(b.text, base),
      if (withCaret)
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(left: 2),
            child: StreamingCaret(),
          ),
        ),
    ];
    final body = Text.rich(TextSpan(children: spans), style: base);
    if (b.marker == null) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: b.marker == '•'
              ? Padding(
                  padding: EdgeInsets.only(
                    top: (base.fontSize! * base.height!) / 2 - 2.5,
                    left: 4,
                  ),
                  child: Container(
                    width: 5,
                    height: 5,
                    alignment: Alignment.topLeft,
                    decoration: const BoxDecoration(
                      color: Cut.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : Text(
                  b.marker!,
                  style: base.copyWith(
                    color: Cut.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
        Expanded(child: body),
      ],
    );
  }

  static final _bullet = RegExp(r'^\s*[-*•]\s+');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+');
  static final _heading = RegExp(r'^#{1,6}\s+');

  static List<_Block> _blocks(String text) {
    final out = <_Block>[];
    var gap = 0.0;
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        gap = 10;
        continue;
      }
      final listGap = out.isNotEmpty && out.last.marker != null ? 4.0 : 8.0;
      if (_bullet.hasMatch(line)) {
        out.add(
          _Block(line.replaceFirst(_bullet, ''), '•', gap > 0 ? gap : listGap),
        );
      } else if (_numbered.firstMatch(line) case final m?) {
        out.add(
          _Block(
            line.replaceFirst(_numbered, ''),
            '${m.group(1)}.',
            gap > 0 ? gap : listGap,
          ),
        );
      } else if (_heading.hasMatch(line)) {
        out.add(_Block('**${line.replaceFirst(_heading, '')}**', null, 12));
      } else {
        out.add(_Block(line, null, gap > 0 ? gap : 6));
      }
      gap = 0;
    }
    return out;
  }

  static final _inlinePattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');

  static List<InlineSpan> _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _inlinePattern.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(
              color: Cut.textPrimary,
              fontWeight: FontWeight.w600,
              fontVariations: [FontVariation('wght', 620)],
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(
              fontFamily: CutFonts.mono,
              fontSize: base.fontSize! - 1.5,
              color: Cut.onAccentContainer,
              backgroundColor: Cut.accentContainer.withValues(alpha: 0.6),
            ),
          ),
        );
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }
}

class _Block {
  const _Block(this.text, this.marker, this.gap);

  final String text;
  final String? marker;
  final double gap;
}

/// A 2 × 14 accent caret that blinks while a reply streams in.
class StreamingCaret extends StatefulWidget {
  const StreamingCaret({super.key});

  @override
  State<StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c.drive(
      TweenSequence([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      ]),
    ),
    child: Container(
      width: 2,
      height: 15,
      decoration: BoxDecoration(
        color: Cut.accent,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

/// "Thinking…" with light sweeping through it, and three soft dots.
class ThinkingLine extends StatelessWidget {
  const ThinkingLine({super.key, this.text = 'Thinking…'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: ShimmerText(
      text,
      style: CutType.titleSm.copyWith(color: Cut.textSecondary),
    ),
  );
}

/// A quiet system line ("Stopped. Nothing was changed."), or an inline
/// error card when something went wrong.
class NoticeLine extends StatelessWidget {
  const NoticeLine({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (!error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Expanded(child: Divider(color: Cut.strokeSubtle)),
            const SizedBox(width: 10),
            Flexible(
              flex: 6,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: CutType.caption.copyWith(color: Cut.textTertiary),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Divider(color: Cut.strokeSubtle)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Cut.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(color: Cut.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(CutIcons.error, size: 16, color: Cut.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              text,
              style: CutType.label.copyWith(
                color: const Color(0xFFFFC9CF),
                height: 18 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool isPicturePath(String path) => imageExtensions.contains(
  p.extension(path).replaceFirst('.', '').toLowerCase(),
);

/// A sent or waiting picture (thumbnail) or audio file (a little tile with
/// its name).
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb(this.path, {super.key, this.size = 76});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isPicturePath(path) && File(path).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CutRadii.md),
          boxShadow: CutShadows.e1,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CutRadii.md),
          border: Border.all(color: Cut.strokeDefault),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CutRadii.md),
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
          ),
        ),
      );
    }
    final picture = isPicturePath(path);
    return Container(
      height: size < 64 ? size : 48,
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: Cut.surface3,
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: (picture ? Cut.trackOverlay : Cut.trackMusic).withValues(
                  alpha: 0.16,
                ),
                borderRadius: BorderRadius.circular(CutRadii.sm),
              ),
              child: Icon(
                picture ? CutIcons.image : CutIcons.music,
                size: 16,
                color: picture ? Cut.trackOverlay : Cut.trackMusic,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.basenameWithoutExtension(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CutType.label.copyWith(fontSize: 12.5),
                ),
                Text(
                  p.extension(path).replaceFirst('.', '').toUpperCase(),
                  style: CutType.overline.copyWith(fontSize: 9.5, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Files waiting to go with the next message, each with a remove button.
class PendingAttachments extends StatelessWidget {
  const PendingAttachments({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<String> files;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(top: 6, right: 6),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final f = files[i];
        return ArriveIn(
          offset: 6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: AttachmentThumb(f, size: 52)),
              Positioned(
                right: -6,
                top: 0,
                child: Pressable(
                  key: Key('remove-attachment-${p.basename(f)}'),
                  semanticLabel: 'Remove ${p.basename(f)}',
                  onTap: () => onRemove(f),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Cut.surface4,
                      shape: BoxShape.circle,
                      border: Border.all(color: Cut.strokeStrong),
                      boxShadow: CutShadows.e1,
                    ),
                    child: const Icon(
                      CutIcons.close,
                      size: 11,
                      color: Cut.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
