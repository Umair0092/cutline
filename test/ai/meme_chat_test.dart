import 'dart:convert';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/ai/meme_tools.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/overlays/overlay_actions.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/transcript/timeline_transcript.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_preview.dart';
import '../fixtures.dart';
import 'fake_claude.dart';
import 'tool_loop_test.dart' show sseTools;

Meme meme(String title) => Meme(
  id: 'giphy-${title.replaceAll(' ', '-')}',
  title: title,
  preview: 'https://g/$title-small.gif',
  source: 'https://g/$title.gif',
);

/// Finds "this is fine" and "fine dog" for anything with "fine" in it.
Future<List<Meme>> fakeFind(String query, {bool stickers = false}) async =>
    query.contains('fine')
    ? [meme('this is fine'), meme('fine dog'), meme('everything is fine')]
    : const [];

/// Places a meme without FFmpeg or the network.
Future<List<EditCommand>> fakePlace(
  Project project,
  String workPath,
  Meme m,
  Duration start, {
  OverlayTransform transform = const OverlayTransform(),
  Duration? duration,
  OverlayAnimation animation = OverlayAnimation.pop,
  String? id,
}) async => overlayCommands(
  project,
  MediaAsset(
    id: 'media-${m.id}',
    path: 'assets/${m.id}.gif',
    kind: MediaKind.gif,
    duration: const Duration(seconds: 1),
    width: 480,
    height: 270,
  ),
  start,
  transform: transform,
  duration: duration,
  animation: animation,
  id: id,
);

final speech = [
  TranscriptLine(s(0), s(4), 'Hi, today is about shipping on time.'),
  TranscriptLine(s(12), s(16), "Let's talk about deadlines."),
];

void main() {
  const tools = EditToolbox();
  late Map<String, Meme> choices;
  ToolContext ctx() => ToolContext(
    playhead: s(2),
    transcript: speech,
    findMemes: fakeFind,
    memeChoices: choices,
    memeCommands: (p, m, start, t, d, a) => fakePlace(
      p,
      '/work',
      m,
      start,
      transform: t,
      duration: d,
      animation: a,
    ),
  );
  setUp(() => choices = {});

  test('"add the this is fine meme when I talk about deadlines, bottom '
      'right"', () async {
    final out = await tools.run(
      'add_meme',
      {
        'meme': 'this is fine',
        'phrase': 'deadlines',
        'position': 'bottom-right',
        'size': 'small',
      },
      threeClips(),
      context: ctx(),
    );
    expect(out.isError, isFalse, reason: out.result);
    final o = out.project.overlays.single;
    expect(o.start, s(12));
    expect(o.transform.x, greaterThan(0.8));
    expect(o.transform.y, greaterThan(0.7));
    expect(o.transform.scale, 0.2);
    expect(out.command!.label, 'Add meme "this is fine"');
  });

  test('times come from start, else the playhead; bad ones explain', () async {
    var out = await tools.run(
      'add_meme',
      {'meme': 'fine', 'start': 30, 'duration': 2},
      threeClips(),
      context: ctx(),
    );
    expect(out.project.overlays.single.start, s(30));
    expect(out.project.overlays.single.duration, s(2));

    out = await tools.run(
      'add_meme',
      {'meme': 'fine'},
      threeClips(),
      context: ctx(),
    );
    expect(out.project.overlays.single.start, s(2));

    out = await tools.run(
      'add_meme',
      {'meme': 'fine', 'phrase': 'pizza'},
      threeClips(),
      context: ctx(),
    );
    expect(out.isError, isTrue);
    expect(out.result, contains('Couldn\'t find "pizza"'));

    out = await tools.run(
      'add_meme',
      {'meme': 'cats'},
      threeClips(),
      context: ctx(),
    );
    expect(out.result, contains('No meme found'));
  });

  test('search_memes numbers options; add_meme can use the id', () async {
    final found = await tools.run(
      'search_memes',
      {'query': 'fine'},
      threeClips(),
      context: ctx(),
    );
    expect(
      [for (final (id, _) in found.memes) id],
      ['meme1', 'meme2', 'meme3'],
    );
    final options = (jsonDecode(found.result) as Map)['options'] as List;
    expect((options[1] as Map)['title'], 'fine dog');
    expect(found.command, isNull);

    final out = await tools.run(
      'add_meme',
      {'meme': 'meme2', 'start': 5},
      threeClips(),
      context: ctx(),
    );
    expect(out.project.media.last.path, 'assets/giphy-fine-dog.gif');
  });

  test('suggest_memes adds nothing and resolves each suggestion', () async {
    final out = await tools.run(
      'suggest_memes',
      {
        'suggestions': [
          {'meme': 'this is fine', 'phrase': 'deadlines', 'reason': 'Panic'},
          {'meme': 'cats', 'start': 3, 'reason': 'Cute'},
        ],
      },
      threeClips(),
      context: ctx(),
    );
    expect(out.isError, isFalse, reason: out.result);
    expect(out.project.overlays, isEmpty);
    expect(out.suggestions.single.start, s(12));
    expect(out.suggestions.single.meme.title, 'this is fine');
    expect(out.result, contains('skipped'));
  });

  group('in the chat', () {
    late ScriptedHttp http;
    late ProviderContainer container;
    ChatState chat() => container.read(chatProvider);
    EditorState editor() => container.read(projectEditorProvider);

    void setUpWith(List<dynamic> responses) {
      http = ScriptedHttp(responses.cast());
      container = ProviderContainer(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('sk-ant-k')),
          previewProvider.overrideWithValue(FakePreviewController()),
          assistantClientFactoryProvider.overrideWithValue(
            (_, k) => ClaudeClient(apiKey: k, httpClient: http.client),
          ),
          memeFinderProvider.overrideWithValue(fakeFind),
          memePlacerProvider.overrideWithValue(fakePlace),
          timelineTranscriptProvider.overrideWithValue(speech),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    }

    test('search results show as choices; "Use meme2" adds that one', () async {
      setUpWith([
        ScriptedHttp.ok(sseTools([('t1', 'search_memes', '{"query":"fine"}')])),
        ScriptedHttp.ok(sseText('Which one?')),
        ScriptedHttp.ok(
          sseTools([
            ('t2', 'add_meme', '{"meme":"meme2","phrase":"deadlines"}'),
          ]),
        ),
        ScriptedHttp.ok(sseText('Added it at 0:12.')),
      ]);
      await container.read(chatProvider.notifier).send('Add a fine meme');
      final choices = chat().entries.firstWhere(
        (e) => e.role == ChatRole.memes,
      );
      expect(choices.memes, hasLength(3));
      expect(editor().project.overlays, isEmpty);

      await container.read(chatProvider.notifier).send('Use meme2');
      expect(editor().project.overlays.single.start, s(12));
      expect(editor().undoLabel, 'Assistant: Add meme "fine dog"');

      // The choices survive saving the chat.
      final back = ChatState.fromJson(
        jsonDecode(jsonEncode(chat().toJson())) as Map<String, dynamic>,
      );
      expect(
        back.entries
            .firstWhere((e) => e.role == ChatRole.memes)
            .memes[1]
            .$2
            .title,
        'fine dog',
      );
    });

    test('suggestions are added one by one when accepted', () async {
      setUpWith([
        ScriptedHttp.ok(
          sseTools([
            (
              't1',
              'suggest_memes',
              '{"suggestions":['
                  '{"meme":"this is fine","phrase":"deadlines","reason":"Panic"},'
                  '{"meme":"fine dog","start":1,"reason":"Opening"}]}',
            ),
          ]),
        ),
        ScriptedHttp.ok(sseText('Here are two ideas.')),
      ]);
      await container.read(chatProvider.notifier).send('Suggest memes');
      final ids = [
        for (var i = 0; i < chat().entries.length; i++)
          if (chat().entries[i].role == ChatRole.suggestion) i,
      ];
      expect(ids, hasLength(2));
      expect(editor().project.overlays, isEmpty);

      await container.read(chatProvider.notifier).acceptSuggestion(ids[0]);
      container.read(chatProvider.notifier).rejectSuggestion(ids[1]);
      expect(editor().project.overlays.single.start, s(12));
      expect(
        chat().entries[ids[0]].suggestion!.status,
        SuggestionStatus.accepted,
      );
      expect(
        chat().entries[ids[1]].suggestion!.status,
        SuggestionStatus.rejected,
      );
      // Accepting twice doesn't add it twice.
      await container.read(chatProvider.notifier).acceptSuggestion(ids[0]);
      expect(editor().project.overlays, hasLength(1));
    });
  });
}
