import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_preview.dart';
import '../fixtures.dart';
import 'fake_claude.dart';

/// An assistant reply that calls tools: [(id, name, inputJson)].
String sseTools(List<(String, String, String)> calls, {String text = ''}) =>
    sse([
      {
        'type': 'message_start',
        'message': {'model': 'claude-opus-5-5'},
      },
      ...thinkingEvents(),
      for (var i = 0; i < calls.length; i++) ...[
        {
          'type': 'content_block_start',
          'index': i + 1,
          'content_block': {
            'type': 'tool_use',
            'id': calls[i].$1,
            'name': calls[i].$2,
            'input': {},
          },
        },
        {
          'type': 'content_block_delta',
          'index': i + 1,
          'delta': {'type': 'input_json_delta', 'partial_json': calls[i].$3},
        },
        {'type': 'content_block_stop', 'index': i + 1},
      ],
      {
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      },
      {'type': 'message_stop'},
    ]);

void main() {
  late ScriptedHttp http;
  late ProviderContainer container;
  late FakePreviewController preview;
  EditorState editor() => container.read(projectEditorProvider);
  ChatState chat() => container.read(chatProvider);

  void setUpWith(List<dynamic> responses) {
    http = ScriptedHttp(responses.cast());
    preview = FakePreviewController();
    container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('sk-ant-k')),
        previewProvider.overrideWithValue(preview),
        assistantClientFactoryProvider.overrideWithValue(
          (_, k) => ClaudeClient(apiKey: k, httpClient: http.client),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
  }

  test('"cut the first 5 seconds": one tool call, one undo step', () async {
    setUpWith([
      ScriptedHttp.ok(
        sseTools([('t1', 'cut_range', '{"start": 0, "end": 5}')]),
      ),
      ScriptedHttp.ok(sseText('Cut the first 5 seconds.')),
    ]);
    await container.read(chatProvider.notifier).send('Cut the first 5 seconds');

    expect(editor().project.duration, s(35));
    expect(editor().undoStack, hasLength(1));
    expect(editor().undoLabel, 'Assistant: Cut 0:00.00–0:05.00');

    // The first request carried the project state and the tools.
    final first = http.requests.first;
    final userContent =
        ((first['messages'] as List).last as Map)['content'] as List;
    expect((userContent.first as Map)['text'], contains('<project_state>'));
    expect((userContent.first as Map)['text'], contains('"duration":40.0'));
    expect(
      (first['tools'] as List).map((t) => (t as Map)['name']),
      contains('cut_range'),
    );

    // The second request answered the tool call.
    final second = http.requests.last['messages'] as List;
    final toolResult = ((second.last as Map)['content'] as List).single as Map;
    expect(toolResult['type'], 'tool_result');
    expect(toolResult['tool_use_id'], 't1');
    expect(toolResult.containsKey('is_error'), isFalse);
    expect(toolResult['content'], contains('"duration":35.0'));

    expect(chat().entries.map((e) => e.role), [
      ChatRole.user,
      ChatRole.assistant,
      ChatRole.change,
    ]);
    expect(chat().entries.last.changes, ['Cut 0:00.00–0:05.00']);
    expect(chat().history, hasLength(4));
  });

  test('several calls over two rounds still make one undo step', () async {
    setUpWith([
      ScriptedHttp.ok(
        sseTools([
          ('t1', 'cut_range', '{"start": 0, "end": 5}'),
          ('t2', 'set_clip_volume', '{"clip_id": "c", "volume": 0}'),
        ]),
      ),
      ScriptedHttp.ok(sseTools([('t3', 'seek', '{"time": 3}')])),
      ScriptedHttp.ok(sseText('Done.')),
    ]);
    await container
        .read(chatProvider.notifier)
        .send('Cut the start, mute the end');
    expect(editor().undoStack, hasLength(1));
    expect(editor().undoLabel, 'Assistant edit (2 changes)');
    expect(editor().project.clips.last.volume, 0);
    expect(preview.position, s(3));

    container.read(chatProvider.notifier).undoChange(chat().entries.length - 1);
    expect(editor().project, threeClips());
    expect(chat().entries.last.undone, isTrue);
  });

  test('a bad call is reported back and the model can fix it', () async {
    setUpWith([
      ScriptedHttp.ok(sseTools([('t1', 'delete_clip', '{"clip_id": "nope"}')])),
      ScriptedHttp.ok(sseTools([('t2', 'delete_clip', '{"clip_id": "b"}')])),
      ScriptedHttp.ok(sseText('Deleted the middle clip.')),
    ]);
    await container.read(chatProvider.notifier).send('Delete the middle clip');
    final retry = http.requests[1]['messages'] as List;
    final error = ((retry.last as Map)['content'] as List).single as Map;
    expect(error['is_error'], isTrue);
    expect(error['content'], contains('no clip'));
    expect([for (final c in editor().project.clips) c.id], ['a', 'c']);
    expect(editor().undoStack, hasLength(1));
  });

  test('a network failure mid-turn applies nothing', () async {
    setUpWith([
      ScriptedHttp.ok(
        sseTools([('t1', 'cut_range', '{"start": 0, "end": 5}')]),
      ),
      ScriptedHttp.status(400, 'invalid_request_error'),
    ]);
    await container.read(chatProvider.notifier).send('Cut the start');
    expect(editor().project, threeClips());
    expect(editor().undoStack, isEmpty);
    expect(chat().history, isEmpty);
    expect(chat().entries.last.isError, isTrue);
  });

  test(
    'the change Undo button only works while it is the latest edit',
    () async {
      setUpWith([
        ScriptedHttp.ok(
          sseTools([('t1', 'cut_range', '{"start": 0, "end": 5}')]),
        ),
        ScriptedHttp.ok(sseText('Done.')),
      ]);
      await container.read(chatProvider.notifier).send('Cut the start');
      final index = chat().entries.length - 1;
      expect(
        container.read(chatProvider.notifier).canUndoChange(index),
        isTrue,
      );

      // A manual edit afterwards: the AI change is no longer the latest.
      container.read(projectEditorProvider.notifier).undo();
      container.read(projectEditorProvider.notifier).redo();
      expect(
        container.read(chatProvider.notifier).canUndoChange(index),
        isTrue,
      );
      container.read(projectEditorProvider.notifier).undo();
      expect(
        container.read(chatProvider.notifier).canUndoChange(index),
        isFalse,
      );
    },
  );
}
