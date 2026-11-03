import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/api_key_store.dart';
import '../ai/chat_controller.dart';
import '../editing/project_editor.dart';
import '../media/image_import.dart';
import '../music/music_library.dart';
import '../transcript/timeline_transcript.dart';
import 'assistant/chat_cards.dart';
import 'assistant/chat_draft.dart';
import 'assistant/chat_parts.dart';
import 'assistant/chat_welcome.dart';
import 'assistant/composer.dart';
import 'settings_dialog.dart';
import 'time_format.dart';
import 'tokens.dart';
import 'widgets/cut_icons.dart';
import 'widgets/cut_widgets.dart';

/// The chat: what you and the assistant said, the edits it made, and the
/// box to type in.
class AssistantPanel extends ConsumerStatefulWidget {
  const AssistantPanel({super.key});

  @override
  ConsumerState<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends ConsumerState<AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Files picked to go with the next message.
  final _attachments = <String>[];
  late final _focus = FocusNode(onKeyEvent: _onKey);
  bool _dragging = false;

  /// Entries before this index were there when the panel opened, so they
  /// don't animate in.
  late int _seen = ref.read(chatProvider).entries.length;

  @override
  void initState() {
    super.initState();
    ref.listenManual(chatDraftProvider, (_, draft) {
      if (draft != null) _useDraft();
    }, fireImmediately: true);
  }

  void _useDraft() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final draft = ref.read(chatDraftProvider.notifier).take();
    if (draft == null) return;
    if (draft.send) {
      _send(draft.text, draft.attachments);
    } else {
      _input.text = draft.text;
      _input.selection = TextSelection.collapsed(offset: draft.text.length);
      setState(() => _attachments.addAll(draft.attachments));
      _focus.requestFocus();
    }
  });

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Enter sends; Shift+Enter makes a new line.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Sends the box (or [text], e.g. a picked suggestion, with [files]).
  void _send([String? text, List<String>? files]) {
    final fromBox = text == null;
    final message = text ?? _input.text;
    final attach = files ?? (fromBox ? [..._attachments] : const <String>[]);
    if ((message.trim().isEmpty && attach.isEmpty) ||
        ref.read(chatProvider).busy) {
      return;
    }
    if (fromBox) {
      _input.clear();
      setState(_attachments.clear);
    }
    ref.read(chatProvider.notifier).send(message, attachments: attach);
  }

  static const _attachTypes = XTypeGroup(
    label: 'Pictures and audio',
    extensions: [...imageExtensions, ...audioExtensions],
    uniformTypeIdentifiers: ['public.image', 'public.audio'],
  );

  static const _pictureTypes = XTypeGroup(
    label: 'Pictures',
    extensions: imageExtensions,
    uniformTypeIdentifiers: ['public.image'],
  );

  Future<void> _attach() async {
    final files = await openFiles(acceptedTypeGroups: const [_attachTypes]);
    if (files.isEmpty || !mounted) return;
    _addAttachments([for (final f in files) f.path]);
    _focus.requestFocus();
  }

  void _addAttachments(List<String> paths) => setState(() {
    for (final f in paths) {
      if (!_attachments.contains(f)) _attachments.add(f);
    }
  });

  static bool _attachable(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return imageExtensions.contains(ext) || audioExtensions.contains(ext);
  }

  void _onDrop(List<String> paths) {
    final ok = paths.where(_attachable).toList();
    if (ok.isNotEmpty) {
      _addAttachments(ok);
      _focus.requestFocus();
    }
    if (ok.length < paths.length && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Only pictures and audio can go in the chat. Drop videos on the '
            'preview instead.',
          ),
        ),
      );
    }
  }

  Future<void> _pickSuggestion(ChatSuggestion s) async {
    if (ref.read(chatProvider).busy) return;
    switch (s.needs) {
      case SuggestionNeeds.nothing:
        _send(s.prompt);
      case SuggestionNeeds.logo:
        final file = await openFile(acceptedTypeGroups: const [_pictureTypes]);
        if (file == null || !mounted) return;
        _send(s.prompt, [file.path]);
      case SuggestionNeeds.photos:
        final files = await openFiles(
          acceptedTypeGroups: const [_pictureTypes],
        );
        if (files.isEmpty || !mounted) return;
        _send(s.prompt, [for (final f in files) f.path]);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _contextLine() {
    final project = ref.watch(projectEditorProvider.select((s) => s.project));
    final hasTranscript = ref.watch(
      timelineTranscriptProvider.select((l) => l.isNotEmpty),
    );
    if (project.clips.isEmpty) {
      return 'Import a video, then tell me what to change. Every reply is '
          'one undo step.';
    }
    final length = formatPlayerTime(project.duration).split('.').first;
    return hasTranscript
        ? 'I can see your $length video and its transcript.'
        : 'I can see your $length video. Every reply is one undo step.';
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final hasKey = ref.watch(apiKeyProvider).value != null;
    final provider = ref.watch(aiProviderProvider).value;
    ref.listen(chatProvider, (before, now) {
      if (now.entries.length < (before?.entries.length ?? 0)) {
        _seen = now.entries.length;
      }
      _scrollToEnd();
    });
    final empty = chat.entries.isEmpty && chat.streamingText == null;
    final phone = isTouchPlatform || MediaQuery.sizeOf(context).width < 600;

    final panel = Column(
      children: [
        Expanded(
          child: !hasKey
              ? ChatNoKey(onOpenSettings: () => showSettings(context))
              : empty
              ? ChatWelcome(context: _contextLine(), onPick: _pickSuggestion)
              : _Messages(
                  chat: chat,
                  scroll: _scroll,
                  seen: _seen,
                  onSend: _send,
                ),
        ),
        if (hasKey)
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, phone ? 10 : 12),
            child: ChatComposer(
              controller: _input,
              focusNode: _focus,
              attachments: _attachments,
              onRemoveAttachment: (f) => setState(() => _attachments.remove(f)),
              onAttach: hasKey && !chat.busy ? _attach : null,
              onSend: hasKey ? _send : null,
              onStop: ref.read(chatProvider.notifier).stop,
              busy: chat.busy,
              enabled: hasKey,
              footer: _Footer(
                label: provider?.label,
                showHint: !phone,
                onModel: () => showSettings(context),
              ),
            ),
          ),
      ],
    );

    final body = Stack(
      children: [
        Positioned.fill(child: panel),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: CutMotion.fast,
              opacity: _dragging ? 1 : 0,
              child: const _DropHint(),
            ),
          ),
        ),
      ],
    );

    return ColoredBox(
      color: Cut.surface1,
      child: isTouchPlatform || !hasKey
          ? body
          : DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (d) {
                setState(() => _dragging = false);
                _onDrop([for (final f in d.files) f.path]);
              },
              child: body,
            ),
    );
  }
}

/// The conversation. The assistant's consecutive replies, cards and
/// results sit under one "Cutline AI" header.
class _Messages extends StatelessWidget {
  const _Messages({
    required this.chat,
    required this.scroll,
    required this.seen,
    required this.onSend,
  });

  final ChatState chat;
  final ScrollController scroll;
  final int seen;
  final void Function(String text) onSend;

  static bool _fromAi(ChatRole r) => r != ChatRole.user && r != ChatRole.notice;

  @override
  Widget build(BuildContext context) {
    final entries = chat.entries;
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final prev = i > 0 ? entries[i - 1].role : null;
      final startsTurn = _fromAi(e.role) && (prev == null || !_fromAi(prev));
      final gap = i == 0
          ? 0.0
          : startsTurn || e.role == ChatRole.user
          ? 20.0
          : e.role == ChatRole.notice
          ? 14.0
          : 10.0;
      Widget item = switch (e.role) {
        ChatRole.user => UserBubble(text: e.text, attachments: e.attachments),
        ChatRole.assistant => AssistantText(e.text),
        ChatRole.notice => NoticeLine(text: e.text, error: e.isError),
        ChatRole.change => ChangeCard(index: i, entry: e),
        ChatRole.memes => MemeChoices(
          entry: e,
          onPick: (id) => onSend('Use $id'),
        ),
        ChatRole.tracks => TrackChoices(
          entry: e,
          onPick: (id) => onSend(
            id.startsWith('sound')
                ? 'Add $id'
                : 'Use $id as the background music',
          ),
        ),
        ChatRole.suggestion => SuggestionCard(index: i, entry: e),
      };
      if (startsTurn) {
        item = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const AiHeader(), item],
        );
      }
      if (i >= seen) item = ArriveIn(child: item);
      children.add(
        Padding(
          padding: EdgeInsets.only(top: gap),
          child: item,
        ),
      );
    }
    final streaming = chat.streamingText;
    if (streaming != null) {
      final last = entries.lastOrNull?.role;
      final startsTurn = last == null || !_fromAi(last);
      final thinking = streaming.isEmpty || streaming.endsWith('…');
      children.add(
        Padding(
          key: const Key('streaming'),
          padding: EdgeInsets.only(top: entries.isEmpty ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (startsTurn) const AiHeader(),
              if (thinking)
                ThinkingLine(text: streaming.isEmpty ? 'Thinking…' : streaming)
              else
                AssistantText(streaming, caret: true),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Under the composer: which AI is connected (tap for settings) and the
/// keyboard hint.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.label,
    required this.showHint,
    required this.onModel,
  });

  final String? label;
  final bool showHint;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    final hint = CutType.caption.copyWith(
      color: Cut.textTertiary,
      fontSize: 11.5,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          if (label != null)
            Tooltip(
              message: 'AI settings',
              waitDuration: const Duration(milliseconds: 500),
              child: Pressable(
                key: const Key('chat-model'),
                onTap: onModel,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Cut.surface2,
                    borderRadius: BorderRadius.circular(CutRadii.pill),
                    border: Border.all(color: Cut.strokeSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuroraIcon(size: 11),
                      const SizedBox(width: 5),
                      Text(
                        label!,
                        maxLines: 1,
                        style: hint.copyWith(color: Cut.textSecondary),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        CutIcons.down,
                        size: 10,
                        color: Cut.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: showHint
                ? Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '↵',
                            style: hint.copyWith(color: Cut.textSecondary),
                          ),
                          Text(' send', style: hint),
                          const SizedBox(width: 10),
                          Text(
                            '⇧↵',
                            style: hint.copyWith(color: Cut.textSecondary),
                          ),
                          Text(' new line', style: hint),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

/// Shown while pictures or audio are dragged over the chat.
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) => Container(
    color: Cut.surface1.withValues(alpha: 0.88),
    padding: const EdgeInsets.all(12),
    child: AuroraBorder(
      radius: CutRadii.lg,
      width: 1.5,
      opacity: 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: Cut.surface2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(CutRadii.lg - 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const AuroraGlow(size: 280, opacity: 0.22),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuroraIcon(size: 36, icon: CutIcons.attach),
                const SizedBox(height: 12),
                Text('Drop to attach', style: CutType.title),
                const SizedBox(height: 4),
                Text(
                  'Pictures and audio go with your next message',
                  textAlign: TextAlign.center,
                  style: CutType.caption.copyWith(color: Cut.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
