import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/edit_command.dart';
import '../memes/meme_actions.dart';
import '../memes/meme_search.dart';
import '../model/overlay_item.dart';
import 'meme_tools.dart';
import '../editing/project_editor.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../settings/preferences.dart';
import '../titles/title_actions.dart';
import '../preview/preview_controller.dart';
import '../transcript/timeline_transcript.dart';
import 'api_key_store.dart';
import 'assistant_client.dart';
import 'claude_client.dart';
import 'groq_client.dart';
import 'edit_tools.dart';
import 'message_builder.dart';
import 'project_summary.dart';

enum ChatRole { user, assistant, notice, change, memes, suggestion }

/// One item in the chat panel.
class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.text,
    this.isError = false,
    this.changes = const [],
    this.undone = false,
    this.memes = const [],
    this.suggestion,
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
    memes: [
      for (final m in json['memes'] as List<dynamic>? ?? const [])
        (
          (m as Map<String, dynamic>)['choice'] as String,
          Meme.fromJson(m['meme'] as Map<String, dynamic>),
        ),
    ],
    suggestion: json['suggestion'] == null
        ? null
        : MemeSuggestion.fromJson(json['suggestion'] as Map<String, dynamic>),
  );

  final ChatRole role;
  final String text;
  final bool isError;

  /// For [ChatRole.change]: one line per edit, e.g. "Cut 0:00.00–0:05.00".
  final List<String> changes;
  final bool undone;

  /// For [ChatRole.memes]: search results by the id the assistant uses.
  final List<(String, Meme)> memes;

  /// For [ChatRole.suggestion].
  final MemeSuggestion? suggestion;

  ChatEntry copyWith({bool? undone, MemeSuggestion? suggestion}) => ChatEntry(
    role: role,
    text: text,
    isError: isError,
    changes: changes,
    undone: undone ?? this.undone,
    memes: memes,
    suggestion: suggestion ?? this.suggestion,
  );

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    if (isError) 'isError': true,
    if (changes.isNotEmpty) 'changes': changes,
    if (undone) 'undone': true,
    if (memes.isNotEmpty)
      'memes': [
        for (final (choice, meme) in memes)
          {'choice': choice, 'meme': meme.toStoredJson()},
      ],
    if (suggestion != null) 'suggestion': suggestion!.toJson(),
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

/// Makes intro clips for the assistant's "before the video" titles. Tests
/// override this so they don't need FFmpeg.
final introRendererProvider =
    Provider<
      Future<MediaAsset> Function(Project, TitleSpec, {String? id})? Function(
        String?,
      )
    >(
      (_) =>
          (workPath) => workPath == null
          ? null
          : (project, spec, {id}) =>
                renderIntroMedia(project, workPath, spec, id: id),
    );

/// Searches memes for the assistant: your memes folder first, then
/// GIPHY when there's a key. Tests override this.
final memeFinderProvider =
    Provider<Future<List<Meme>> Function(String, {bool stickers})>(
      (ref) => (query, {stickers = false}) async {
        final folder = await ref.read(memesFolderProvider.future);
        final local = LocalMemes(folder).search(query);
        final key = await ref.read(giphyKeyProvider.future);
        if (key == null) return local;
        try {
          final online = await ref
              .read(giphyClientFactoryProvider)(key)
              .search(query, stickers: stickers, limit: 6);
          return [...local, ...online];
        } on MemeSearchException {
          // Your own memes still work when GIPHY doesn't.
          if (local.isNotEmpty) return local;
          rethrow;
        }
      },
    );

/// Turns a meme into placing commands. Tests override this so they don't
/// need FFmpeg or the network.
final memePlacerProvider = Provider<MemePlacer>((_) => memeCommands);

typedef MemePlacer = Future<List<EditCommand>> Function(
  Project project,
  String workPath,
  Meme meme,
  Duration start, {
  OverlayTransform transform,
  Duration? duration,
  OverlayAnimation animation,
  String? id,
});

/// Builds the client for a service and key. Tests override this with a
/// fake.
final assistantClientFactoryProvider =
    Provider<AssistantClient Function(AiProvider, String)>(
      (_) =>
          (provider, key) => switch (provider) {
            AiProvider.groq => GroqClient(apiKey: key, model: provider.model),
            AiProvider.claude => ClaudeClient(apiKey: key),
          },
    );

const systemPrompt = '''
You are the editing assistant inside Cutline, a video editor. The user talks to you in a narrow side panel while editing a video.

Each user message starts with a <project_state> block: the current project as JSON. Times are timeline seconds. If the video has been transcribed, "transcript" lists what is said and when (already on the timeline, after cuts), so you can find moments by what's said: "remove the part where I say um, let me restart" means find that line and cut its start to end. The main track is a list of clips that play back to back; cutting closes the gap, so times after a cut move earlier. Tool results include the updated project; use those times for any further edits in the same turn.

Titles and intros: templates are clean-card (title + subtitle card), bold-kinetic (big words popping in, plus a name), lower-third (name and role in a bar, see-through, only "over" the video) and logo-reveal (initials in a circle, then name and subtitle). "Add an intro" usually means a full-screen card "before" the video; a name tag while someone talks is a lower-third "over" the video. "you" in the project state holds the user's saved name and brand colour; use them, and if an intro needs a name you don't have, ask for it. Titles over the video are listed in "titles"; intro clips have "intro" on their clip. For "make it shorter", "use blue", or "change the subtitle", call edit_title with only what changes.

Memes: add_meme finds and places a meme in one step. "When I talk about deadlines" means use "phrase" with the words from the transcript (or the matching line's start). "Bottom right" is a position; "small" or "big" is a size. If the user names a meme loosely and several could fit, call search_memes and ask which one; they can see the numbered thumbnails. For "suggest memes for this video", call suggest_memes with up to 5 good moments; the user accepts or rejects each one on cards that already show the meme, time and reason, so don't list them again: just say how many you suggested. Search results also show as thumbnails, so don't list those either. "overlays" in the project state lists memes already on the video.

Make the edits the user asks for with the tools. If a request is ambiguous (for example, which of two similar moments), ask a short question instead of guessing. If no tool can do what they ask, say so plainly; more tools are being added.

Don't write anything before or between tool calls. When all edits are done, reply once, in one short sentence saying what changed. Use plain text, no markdown. Write times as minutes:seconds, like 0:15 or 1:15.5.''';

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

  /// Memes from the assistant's searches, by the id it uses ("meme3").
  final _memeChoices = <String, Meme>{};

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
    _memeChoices
      ..clear()
      ..addAll({
        for (final e in chat.entries)
          for (final (id, meme) in e.memes) id: meme,
      });
    state = chat;
  }

  void clear() => load(const ChatState());

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.busy) return;
    final key = await ref.read(apiKeyProvider.future);
    if (key == null) {
      _notice('Add an API key in Settings to use the assistant.');
      return;
    }

    final turn = ++_turn;
    final editor = ref.read(projectEditorProvider.notifier);
    final start = ref.read(projectEditorProvider).project;
    final playhead = ref.read(previewProvider).position;
    // Saved name/brand colour; never let reading them hold up the chat.
    final prefs = await ref
        .read(preferencesProvider.future)
        .timeout(const Duration(seconds: 2))
        .catchError((Object _) => const Preferences());
    final workPath = ref.read(projectEditorProvider).workPath;
    final transcript = ref.read(timelineTranscriptProvider);
    final toolContext = ToolContext(
      playhead: playhead,
      preferences: prefs,
      renderIntro: ref.read(introRendererProvider)(workPath),
      transcript: transcript,
      findMemes: ref.read(memeFinderProvider),
      memeCommands: workPath == null
          ? null
          : (project, meme, start, transform, duration, animation) =>
                ref.read(memePlacerProvider)(
                  project,
                  workPath,
                  meme,
                  start,
                  transform: transform,
                  duration: duration,
                  animation: animation,
                ),
      memeChoices: _memeChoices,
    );
    final before = state;
    final turnHistory = <Map<String, dynamic>>[
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                '<project_state>\n'
                '${jsonEncode(projectSummary(start, playhead: playhead, transcript: transcript, preferences: prefs))}\n'
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

    final provider = await ref
        .read(aiProviderProvider.future)
        .catchError((Object _) => AiProvider.groq);
    final client = ref.read(assistantClientFactoryProvider)(provider, key);
    var working = start;
    final commands = <EditCommand>[];
    Duration? seekTo;
    final shownMemes = <(String, Meme)>[];
    final suggestions = <MemeSuggestion>[];
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
          final outcome = await _toolbox.run(
            call['name'] as String,
            call['input'] as Map<String, dynamic>? ?? const {},
            working,
            invalidJson: call['_invalidJson'] as String?,
            context: toolContext,
          );
          if (turn != _turn) return; // stopped while a tool ran
          working = outcome.project;
          if (outcome.command != null) commands.add(outcome.command!);
          seekTo = outcome.seekTo ?? seekTo;
          shownMemes.addAll(outcome.memes);
          suggestions.addAll(outcome.suggestions);
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
    if (shownMemes.isNotEmpty) {
      entries.add(ChatEntry(role: ChatRole.memes, text: '', memes: shownMemes));
    }
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
    for (final s in suggestions) {
      entries.add(
        ChatEntry(role: ChatRole.suggestion, text: s.reason, suggestion: s),
      );
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
    AssistantClient client,
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
              notice: e is AssistantException
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

  /// Adds a suggested meme (one undo step) and marks it accepted.
  Future<void> acceptSuggestion(int index) async {
    final entry = state.entries[index];
    final s = entry.suggestion;
    if (s == null || s.status != SuggestionStatus.pending) return;
    final editor = ref.read(projectEditorProvider);
    final workPath = editor.workPath;
    if (workPath == null) return;
    try {
      final commands = await ref.read(memePlacerProvider)(
        editor.project,
        workPath,
        s.meme,
        s.start,
        transform: memeTransform(s.position, s.size),
      );
      ref
          .read(projectEditorProvider.notifier)
          .runAll('Add meme "${s.meme.title}"', commands);
      _setSuggestion(index, s.withStatus(SuggestionStatus.accepted));
    } on MemeSearchException catch (e) {
      _notice(e.message);
    } on EditException catch (e) {
      _notice(e.message);
    }
  }

  void rejectSuggestion(int index) {
    final s = state.entries[index].suggestion;
    if (s == null || s.status != SuggestionStatus.pending) return;
    _setSuggestion(index, s.withStatus(SuggestionStatus.rejected));
  }

  void _setSuggestion(int index, MemeSuggestion s) {
    final entries = [...state.entries];
    entries[index] = entries[index].copyWith(suggestion: s);
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
