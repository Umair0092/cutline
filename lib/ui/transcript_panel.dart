import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../preview/preview_controller.dart';
import '../transcript/timeline_transcript.dart';
import '../transcript/transcript.dart';
import '../transcript/transcription_service.dart';
import 'assistant/chat_draft.dart';
import 'time_format.dart';
import 'tokens.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// Starts transcribing new videos in the background when the speech model
/// is already downloaded.
class AutoTranscribe extends ConsumerStatefulWidget {
  const AutoTranscribe({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoTranscribe> createState() => _AutoTranscribeState();
}

class _AutoTranscribeState extends ConsumerState<AutoTranscribe> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      // Joined so the listener only fires when the set of files changes.
      projectEditorProvider.select((s) => spokenMediaPaths(s).join('\n')),
      (_, joined) => unawaited(
        ref
            .read(transcriptsProvider.notifier)
            .ensure(joined.isEmpty ? const [] : joined.split('\n')),
      ),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What's said in the video, line by line. The line under the playhead
/// lights up; click a line to jump there, or cut it out or ask the AI about
/// it from its hover actions. A search box filters the lines.
class TranscriptPanel extends ConsumerStatefulWidget {
  const TranscriptPanel({super.key});

  @override
  ConsumerState<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends ConsumerState<TranscriptPanel> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = ref.watch(projectEditorProvider.select(spokenMediaPaths));
    final statuses = ref.watch(transcriptsProvider);
    final lines = ref.watch(timelineTranscriptProvider);

    if (paths.isEmpty) {
      return const EmptyState(
        icon: CutIcons.transcript,
        title: 'No transcript yet',
        body: 'Import a video with sound to see what\'s said in it.',
        compact: true,
      );
    }

    final pending = [
      for (final path in paths)
        if (statuses[path]?.phase != TranscriptPhase.done)
          (path, statuses[path]),
    ];
    final waitingForModel = pending.any(
      (e) => e.$2?.phase == TranscriptPhase.waiting && e.$2?.progress == null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waitingForModel)
          _ModelCard(
            onDownload: () => ref
                .read(transcriptsProvider.notifier)
                .ensure(paths, allowDownload: true),
          ),
        for (final (path, status) in pending)
          if (status != null && status.progress != null ||
              status?.phase == TranscriptPhase.failed)
            _Progress(name: p.basename(path), status: status!),
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _SearchField(
              controller: _query,
              hint: 'Search the transcript',
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: lines.isEmpty
              ? (pending.isEmpty
                    ? const EmptyState(
                        icon: CutIcons.mute,
                        title: 'No speech found.',
                        body: 'There are no spoken words in this video.',
                        compact: true,
                      )
                    : waitingForModel
                    ? const SizedBox()
                    : const _LoadingLines())
              : _Lines(lines: lines, query: _query.text.trim()),
        ),
      ],
    );
  }
}

/// The one-time model download, with a privacy note.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => CutSurface(
    level: 2,
    radius: CutRadii.lg,
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Cut.accentContainer,
                borderRadius: BorderRadius.circular(CutRadii.md),
              ),
              child: const Icon(
                CutIcons.transcript,
                size: 18,
                color: Cut.onAccentContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('See every word you said', style: CutType.titleSm),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Transcripts are made on this computer; nothing is uploaded. The '
          'speech model (148 MB) downloads once.',
          style: CutType.body.copyWith(
            color: Cut.textSecondary,
            fontSize: 13,
            height: 19 / 13,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('transcribe'),
          onPressed: onDownload,
          icon: const Icon(CutIcons.download, size: 16),
          label: const Text('Download Model & Transcribe'),
        ),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.name, required this.status});

  final String name;
  final TranscriptStatus status;

  @override
  Widget build(BuildContext context) {
    final failed = status.phase == TranscriptPhase.failed;
    final pct = ((status.progress ?? 0) * 100).round();
    final label = switch (status.phase) {
      TranscriptPhase.downloadingModel => 'Downloading speech model…',
      TranscriptPhase.transcribing => 'Transcribing $name…',
      TranscriptPhase.failed => '$name: ${status.error}',
      _ => 'Waiting: $name',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: failed
            ? Cut.errorContainer.withValues(alpha: 0.7)
            : Cut.surface2,
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(
          color: failed ? Cut.error.withValues(alpha: 0.3) : Cut.strokeSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  failed ? CutIcons.error : CutIcons.audio,
                  size: 14,
                  color: failed ? Cut.error : Cut.accentHover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: failed ? 4 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: CutType.label.copyWith(
                    color: failed ? const Color(0xFFFFC9CF) : Cut.textPrimary,
                  ),
                ),
              ),
              if (!failed && status.progress != null)
                TimecodeText(
                  '$pct%',
                  style: CutType.timecode.copyWith(fontSize: 12),
                ),
            ],
          ),
          if (!failed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: status.progress,
                minHeight: 4,
                backgroundColor: Cut.surface4,
                color: Cut.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder lines while the first transcript is on its way.
class _LoadingLines extends StatelessWidget {
  const _LoadingLines();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (final w in [0.9, 0.7, 0.85, 0.5, 0.75])
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              const Skeleton(width: 40, height: 12, radius: 4),
              const SizedBox(width: 14),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: w,
                  child: const Skeleton(height: 14, radius: 4),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// A pill-shaped search box.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CutRadii.pill),
      borderSide: const BorderSide(color: Cut.strokeSubtle),
    );
    return SizedBox(
      height: isTouchPlatform ? 44 : 34,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: CutType.body.copyWith(fontSize: 13.5),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: CutType.body.copyWith(
            color: Cut.textTertiary,
            fontSize: 13.5,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          prefixIcon: const Icon(CutIcons.search, size: 15),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(CutIcons.close, size: 13),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: Cut.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The lines, with the one under the playhead highlighted. Clicking a line
/// moves the playhead there.
class _Lines extends ConsumerWidget {
  const _Lines({required this.lines, required this.query});

  final List<TranscriptLine> lines;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    final q = query.toLowerCase();
    final shown = [
      for (final (i, line) in lines.indexed)
        if (q.isEmpty || line.text.toLowerCase().contains(q)) (i, line),
    ];
    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing matches “$query”.',
            textAlign: TextAlign.center,
            style: CutType.body.copyWith(color: Cut.textTertiary),
          ),
        ),
      );
    }
    return StreamBuilder<Duration>(
      stream: preview.positionStream,
      initialData: preview.position,
      builder: (context, snapshot) {
        final t = snapshot.data ?? Duration.zero;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
          itemCount: shown.length,
          itemBuilder: (context, k) {
            final (i, line) = shown[k];
            return _Line(
              key: Key('line-$i'),
              line: line,
              query: q,
              current: t >= line.start && t < line.end,
              past: t >= line.end,
              onTap: () => preview.seek(line.start),
              onCut: () => _cut(ref, context, line),
              onAsk: () => ref
                  .read(chatDraftProvider.notifier)
                  .set(
                    ChatDraft(
                      'At ${formatPlayerTime(line.start)} '
                      '(“${line.text.trim()}”): ',
                    ),
                  ),
            );
          },
        );
      },
    );
  }

  void _cut(WidgetRef ref, BuildContext context, TranscriptLine line) {
    try {
      ref
          .read(projectEditorProvider.notifier)
          .run(RemoveRange(line.start, line.end));
      HapticFeedback.mediumImpact();
    } on EditException catch (e) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Line extends StatefulWidget {
  const _Line({
    super.key,
    required this.line,
    required this.query,
    required this.current,
    required this.past,
    required this.onTap,
    required this.onCut,
    required this.onAsk,
  });

  final TranscriptLine line;
  final String query;
  final bool current;
  final bool past;
  final VoidCallback onTap;
  final VoidCallback onCut;
  final VoidCallback onAsk;

  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  bool _hover = false;

  List<TextSpan> _spans(String text) {
    final q = widget.query;
    if (q.isEmpty) return [TextSpan(text: text)];
    final lower = text.toLowerCase();
    final out = <TextSpan>[];
    var at = 0;
    while (true) {
      final i = lower.indexOf(q, at);
      if (i < 0) break;
      if (i > at) out.add(TextSpan(text: text.substring(at, i)));
      out.add(
        TextSpan(
          text: text.substring(i, i + q.length),
          style: TextStyle(
            color: Cut.textPrimary,
            backgroundColor: Cut.warning.withValues(alpha: 0.28),
          ),
        ),
      );
      at = i + q.length;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final touch = isTouchPlatform;
    final current = widget.current;
    final style = CutType.body.copyWith(
      fontSize: 15,
      height: 24 / 15,
      color: current
          ? Cut.textPrimary
          : widget.past
          ? Cut.textSecondary
          : Cut.textPrimary.withValues(alpha: 0.88),
    );
    final actions = _hover || touch && current;
    final buttonSize = touch ? 36.0 : 26.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CutMotion.fast,
          curve: CutMotion.standard,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          decoration: BoxDecoration(
            color: current
                ? Cut.accent.withValues(alpha: 0.16)
                : _hover
                ? Cut.hover
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(CutRadii.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TimecodeText(
                    formatPlayerTime(widget.line.start),
                    style: CutType.timecode.copyWith(fontSize: 11.5),
                    color: current
                        ? Cut.accentHover
                        : _hover
                        ? Cut.textSecondary
                        : Cut.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _spans(widget.line.text)),
                  style: style,
                ),
              ),
              AnimatedOpacity(
                duration: CutMotion.fast,
                opacity: actions ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !actions,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CutIconButton(
                        icon: CutIcons.aiOutline,
                        tooltip: 'Ask AI about this part',
                        onPressed: widget.onAsk,
                        size: buttonSize,
                        iconSize: 14,
                      ),
                      CutIconButton(
                        icon: CutIcons.cut,
                        tooltip: 'Cut this line out',
                        onPressed: widget.onCut,
                        size: buttonSize,
                        iconSize: 14,
                      ),
                    ],
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
