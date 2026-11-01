import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../model/project.dart';
import '../preview/preview_controller.dart';
import 'api_key_store.dart';
import 'claude_client.dart';
import 'edit_tools.dart';
import 'message_builder.dart';
import 'project_summary.dart';

enum ChatRole { user, assistant, notice, change }

/// One item in the chat panel.
class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.text,
    this.isError = false,
    this.changes = const [],
    this.undone = false,
  });

  factory ChatEntry.fromJson(Map<String, dynamic> json) => ChatEntry(
    role: ChatRole.values.byName(json['role'] as String),
    text: json['text'] as String,
    isError: json['isError'] as bool? ?? false,
    changes: [
      for (final c in json['changes'] as List<dynamic>? ?? const [])
        c as String,
    ],
    undone: json['undone'] as bool? ?? false,
  );

  final ChatRole role;
  final String text;
  final bool isError;

  /// For [ChatRole.change]: one line per edit, e.g. "Cut 0:00.00–0:05.00".
  final List<String> changes;
  final bool undone;

  ChatEntry copyWith({bool? undone}) => ChatEntry(
    role: role,
    text: text,
    isError: isError,
    changes: changes,
    undone: undone ?? this.undone,
  );

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    if (isError) 'isError': true,
    if (changes.isNotEmpty) 'changes': changes,
    if (undone) 'undone': true,
  };
}

class ChatState {
  const ChatState({
    this.entries = const [],
    this.history = const [],
    this.streamingText,
    this.busy = false,
  });

  factory ChatState.fromJson(Map<String, dynamic> json) => ChatState(
    entries: [
      for (final e in json['entries'] as List<dynamic>)
        ChatEntry.fromJson(e as Map<String, dynamic>),
    ],
    history: [
      for (final m in json['history'] as List<dynamic>)
        m as Map<String, dynamic>,
    ],
  );

  /// What the panel shows.
  final List<ChatEntry> entries;

  /// The conversation exactly as sent to and received from the API
  /// (including thinking blocks and tool calls). Only ever appended to.
  final List<Map<String, dynamic>> history;

  /// The reply being streamed, or null.
  final String? streamingText;
  final bool busy;

  ChatState copyWith({
    List<ChatEntry>? entries,
    List<Map<String, dynamic>>? history,
    String? Function()? streamingText,
    bool? busy,
  }) => ChatState(
    entries: entries ?? this.entries,
    history: history ?? this.history,
    streamingText: streamingText != null ? streamingText() : this.streamingText,
    busy: busy ?? this.busy,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'entries': [for (final e in entries) e.toJson()],
    'history': history,
  };
}

/// Builds the client for a key. Tests override this with a fake.
final claudeClientFactoryProvider = Provider<ClaudeClient Function(String)>(
  (_) =>
      (key) => ClaudeClient(apiKey: key),
);

const systemPrompt = '''
You are the editing assistant inside Cutline, a video editor. The user talks to you in a narrow side panel while editing a video.

Each user message starts with a <project_state> block: the current project as JSON. Times are timeline seconds. The main track is a list of clips that play back to back; cutting closes the gap, so times after a cut move earlier. Tool results include the updated project; use those times for any further edits in the same turn.

Make the edits the user asks for with the tools. If a request is ambiguous (for example, which of two similar moments), ask a short question instead of guessing. If no tool can do what they ask, say so plainly; more tools are being added.

After editing, reply in one short sentence saying what changed. Use plain text, no markdown. Write times like 1:15.5.''';

/// How many tool round trips one message may take before stopping.
const maxToolRounds = 8;

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  final _toolbox = const EditToolbox();
  StreamSubscription<MessageBuilder>? _subscription;
  Completer<MessageBuilder?>? _reply;
  int _turn = 0;

  /// The project right after each AI change, by entry index, so the change's
  /// Undo button only undoes that change.
  final _changeResults = <int, Project>{};

  @override
  ChatState build() {
    ref.onDispose(_cancel);
    return const ChatState();
  }

  /// Replaces the conversation, e.g. when a project is opened.
  void load(ChatState chat) {
    _cancel();
    _changeResults.clear();
    state = chat;
  }

  void clear() => load(const ChatState());

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.busy) return;
    final key = await ref.read(apiKeyProvider.future);
    if (key == null) {
      _notice('Add your Claude API key in Settings to use the assistant.');
      return;
    }

    final turn = ++_turn;
    final editor = ref.read(projectEditorProvider.notifier);
    final start = ref.read(projectEditorProvider).project;
    final playhead = ref.read(previewProvider).position;
    final before = state;
    final turnHistory = <Map<String, dynamic>>[
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                '<project_state>\n'
                '${jsonEncode(projectSummary(start, playhead: playhead))}\n'
                '</project_state>',
          },
          {'type': 'text', 'text': message},
        ],
      },
    ];
    state = state.copyWith(
      entries: [
        ...state.entries,
        ChatEntry(role: ChatRole.user, text: message),
      ],
      streamingText: () => '',
      busy: true,
    );

    final client = ref.read(claudeClientFactoryProvider)(key);
    var working = start;
    final commands = <EditCommand>[];
    Duration? seekTo;
    final replyText = StringBuffer();
    String? problem;

    try {
      for (var round = 0; ; round++) {
        final reply = await _stream(client, [
          ...before.history,
          ...turnHistory,
        ], replyText.toString());
        if (turn != _turn) return; // stopped
        if (reply == null) return; // error already shown
        if (reply.stopReason == 'refusal') {
          _end(notice: 'Claude declined that request. Try asking another way.');
          return;
        }
        if (replyText.isNotEmpty && reply.text.trim().isNotEmpty) {
          replyText.write('\n');
        }
        replyText.write(reply.text.trim());
        turnHistory.add({'role': 'assistant', 'content': reply.historyBlocks});

        final calls = reply.blocks.where((b) => b['type'] == 'tool_use');
        if (calls.isEmpty || reply.stopReason != 'tool_use') {
          if (reply.stopReason == 'max_tokens') {
            problem = 'The reply was cut off.';
          }
          break;
        }
        if (round >= maxToolRounds) {
          problem = 'Stopped after $maxToolRounds rounds of edits.';
          break;
        }

        final results = <Map<String, dynamic>>[];
        for (final call in calls) {
          final outcome = _toolbox.run(
            call['name'] as String,
            call['input'] as Map<String, dynamic>? ?? const {},
            working,
            invalidJson: call['_invalidJson'] as String?,
          );
          working = outcome.project;
          if (outcome.command != null) commands.add(outcome.command!);
          seekTo = outcome.seekTo ?? seekTo;
          results.add({
            'type': 'tool_result',
            'tool_use_id': call['id'],
            'content': outcome.result,
            if (outcome.isError) 'is_error': true,
          });
        }
        turnHistory.add({'role': 'user', 'content': results});
      }
    } finally {
      client.close();
    }

    // Commit every edit from this message as one undo step.
    var changeIndex = -1;
    final entries = [...state.entries];
    if (replyText.isNotEmpty) {
      entries.add(
        ChatEntry(role: ChatRole.assistant, text: replyText.toString()),
      );
    }
    if (commands.isNotEmpty) {
      try {
        editor.runAll(
          commands.length == 1
              ? 'Assistant: ${commands.single.label}'
              : 'Assistant edit (${commands.length} changes)',
          commands,
        );
        changeIndex = entries.length;
        entries.add(
          ChatEntry(
            role: ChatRole.change,
            text: commands.length == 1
                ? '1 change'
                : '${commands.length} changes',
            changes: [for (final c in commands) c.label],
          ),
        );
      } on EditException catch (e) {
        problem =
            'The project changed while I was working, so nothing was '
            'applied (${e.message}).';
      }
    }
    if (problem != null) {
      entries.add(
        ChatEntry(role: ChatRole.notice, text: problem, isError: true),
      );
    }
    if (changeIndex >= 0) {
      _changeResults[changeIndex] = ref.read(projectEditorProvider).project;
    }
    if (seekTo != null) unawaited(ref.read(previewProvider).seek(seekTo));

    state = state.copyWith(
      entries: entries,
      history: [...before.history, ...turnHistory],
      streamingText: () => null,
      busy: false,
    );
  }

  /// Streams one API reply, showing [shownBefore] plus the new text.
  /// Returns null if the request failed (a notice is shown) or was stopped.
  Future<MessageBuilder?> _stream(
    ClaudeClient client,
    List<Map<String, dynamic>> messages,
    String shownBefore,
  ) {
    final reply = _reply = Completer<MessageBuilder?>();
    MessageBuilder? last;
    final prefix = shownBefore.isEmpty ? '' : '$shownBefore\n';
    _subscription = client
        .stream(
          system: const [
            {'type': 'text', 'text': systemPrompt},
          ],
          messages: messages,
          tools: _toolbox.definitions,
        )
        .listen(
          (builder) {
            last = builder;
            state = state.copyWith(
              streamingText: () => '$prefix${builder.text}',
            );
          },
          onError: (Object e) {
            // The failed message isn't added to history and nothing is
            // committed, so the next message starts clean.
            _end(
              notice: e is ClaudeException
                  ? e.message
                  : 'Something went wrong: $e',
            );
            if (!reply.isCompleted) reply.complete(null);
          },
          onDone: () {
            if (!reply.isCompleted) reply.complete(last);
          },
          cancelOnError: true,
        );
    return reply.future;
  }

  void _end({required String notice}) {
    state = state.copyWith(
      entries: [
        ...state.entries,
        ChatEntry(role: ChatRole.notice, text: notice, isError: true),
      ],
      streamingText: () => null,
      busy: false,
    );
  }

  /// Stops the reply in progress. Nothing from this message is applied.
  void stop() {
    if (!state.busy) return;
    _turn++;
    _cancel();
    final partial = state.streamingText?.trim() ?? '';
    state = state.copyWith(
      entries: [
        ...state.entries,
        if (partial.isNotEmpty)
          ChatEntry(role: ChatRole.assistant, text: '$partial …'),
        const ChatEntry(
          role: ChatRole.notice,
          text: 'Stopped. Nothing was changed.',
        ),
      ],
      streamingText: () => null,
      busy: false,
    );
  }

  /// Whether the change at [index] can still be undone from the chat: it
  /// must be the most recent edit to the project.
  bool canUndoChange(int index) {
    final after = _changeResults[index];
    final last = ref.read(projectEditorProvider).undoStack.lastOrNull;
    return after != null &&
        !state.entries[index].undone &&
        last != null &&
        last.after == after;
  }

  void undoChange(int index) {
    if (!canUndoChange(index)) return;
    ref.read(projectEditorProvider.notifier).undo();
    _changeResults.remove(index);
    final entries = [...state.entries];
    entries[index] = entries[index].copyWith(undone: true);
    state = state.copyWith(entries: entries);
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_reply?.isCompleted == false) _reply!.complete(null);
  }

  void _notice(String text) => state = state.copyWith(
    entries: [
      ...state.entries,
      ChatEntry(role: ChatRole.notice, text: text, isError: true),
    ],
  );
}
