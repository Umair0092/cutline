import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_key_store.dart';
import 'claude_client.dart';
import 'message_builder.dart';

enum ChatRole { user, assistant, notice }

/// One bubble in the chat panel.
class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.text,
    this.isError = false,
  });

  factory ChatEntry.fromJson(Map<String, dynamic> json) => ChatEntry(
    role: ChatRole.values.byName(json['role'] as String),
    text: json['text'] as String,
    isError: json['isError'] as bool? ?? false,
  );

  final ChatRole role;
  final String text;
  final bool isError;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    if (isError) 'isError': true,
  };
}

class ChatState {
  const ChatState({
    this.entries = const [],
    this.history = const [],
    this.streamingText,
    this.busy = false,
  });

  /// What the panel shows.
  final List<ChatEntry> entries;

  /// The conversation exactly as sent to and received from the API
  /// (including thinking blocks). Only ever appended to.
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
}

/// Builds the client for a key. Tests override this with a fake.
final claudeClientFactoryProvider = Provider<ClaudeClient Function(String)>(
  (_) =>
      (key) => ClaudeClient(apiKey: key),
);

const systemPrompt = '''
You are the editing assistant inside Cutline, a video editor. The user is editing a video and talks to you in a side panel.

Keep replies short and plain: a sentence or two, no markdown headings, tables or code blocks. The panel is narrow.

You can't change the project yet. If the user asks for an edit, tell them briefly what you would do and that editing from chat is coming soon.''';

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  StreamSubscription<MessageBuilder>? _subscription;
  Completer<void>? _done;

  @override
  ChatState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const ChatState();
  }

  /// Replaces the conversation, e.g. when a project is opened.
  void load(ChatState chat) {
    _cancel();
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

    final userTurn = {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': message},
      ],
    };
    final before = state;
    state = state.copyWith(
      entries: [
        ...state.entries,
        ChatEntry(role: ChatRole.user, text: message),
      ],
      streamingText: () => '',
      busy: true,
    );

    final client = ref.read(claudeClientFactoryProvider)(key);
    final done = _done = Completer<void>();
    MessageBuilder? last;
    _subscription = client
        .stream(
          system: const [
            {'type': 'text', 'text': systemPrompt},
          ],
          messages: [...before.history, userTurn],
        )
        .listen(
          (builder) {
            last = builder;
            state = state.copyWith(streamingText: () => builder.text);
          },
          onError: (Object e) {
            client.close();
            // The failed turn isn't added to history, so the next message
            // starts clean.
            state = state.copyWith(
              entries: [
                ...state.entries,
                ChatEntry(
                  role: ChatRole.notice,
                  text: e is ClaudeException
                      ? e.message
                      : 'Something went wrong: $e',
                  isError: true,
                ),
              ],
              streamingText: () => null,
              busy: false,
            );
            done.complete();
          },
          onDone: () {
            client.close();
            if (!done.isCompleted) {
              _finish(before, userTurn, last);
              done.complete();
            }
          },
          cancelOnError: true,
        );
    return done.future;
  }

  void _finish(
    ChatState before,
    Map<String, dynamic> userTurn,
    MessageBuilder? reply,
  ) {
    if (reply == null || reply.stopReason == 'refusal') {
      state = state.copyWith(
        entries: [
          ...state.entries,
          const ChatEntry(
            role: ChatRole.notice,
            text: 'Claude declined that request. Try asking another way.',
            isError: true,
          ),
        ],
        streamingText: () => null,
        busy: false,
      );
      return;
    }
    var text = reply.text.trim();
    if (reply.stopReason == 'max_tokens') {
      text += '\n\n(The reply was cut off.)';
    }
    state = state.copyWith(
      entries: [
        ...state.entries,
        if (text.isNotEmpty) ChatEntry(role: ChatRole.assistant, text: text),
      ],
      history: [
        ...before.history,
        userTurn,
        {'role': 'assistant', 'content': reply.historyBlocks},
      ],
      streamingText: () => null,
      busy: false,
    );
  }

  /// Stops the reply in progress. The partial reply is dropped from the
  /// conversation sent to Claude next time.
  void stop() {
    if (!state.busy) return;
    _cancel();
    final partial = state.streamingText?.trim() ?? '';
    state = state.copyWith(
      entries: [
        ...state.entries,
        if (partial.isNotEmpty)
          ChatEntry(role: ChatRole.assistant, text: '$partial …'),
        const ChatEntry(role: ChatRole.notice, text: 'Stopped.'),
      ],
      streamingText: () => null,
      busy: false,
    );
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_done?.isCompleted == false) _done!.complete();
  }

  void _notice(String text) => state = state.copyWith(
    entries: [
      ...state.entries,
      ChatEntry(role: ChatRole.notice, text: text, isError: true),
    ],
  );
}
