import 'dart:convert';

import 'package:cutline/ai/message_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_claude.dart';

MessageBuilder build(String sseBody) {
  final b = MessageBuilder();
  for (final chunk in sseBody.split('\n\n').where((c) => c.isNotEmpty)) {
    final data = chunk.split('\n').firstWhere((l) => l.startsWith('data: '));
    b.add(jsonDecode(data.substring(6)) as Map<String, dynamic>);
  }
  return b;
}

void main() {
  test('collects text, keeps thinking signatures for the next request', () {
    final b = build(sseText('Cut the intro', before: thinkingEvents()));
    expect(b.text, 'Cut the intro ');
    expect(b.stopReason, 'end_turn');
    expect(b.model, 'claude-opus-5-5');
    expect(b.historyBlocks.first, {
      'type': 'thinking',
      'thinking': '',
      'signature': 'sig123',
    });
  });

  test('assembles tool input from JSON fragments', () {
    final b = build(
      sse([
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'tool_use',
            'id': 't1',
            'name': 'cut',
            'input': {},
          },
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'input_json_delta', 'partial_json': '{"start": 1'},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': '.5, "end": 3}',
          },
        },
        {'type': 'content_block_stop', 'index': 0},
        {'type': 'message_stop'},
      ]),
    );
    expect(b.blocks.single['input'], {'start': 1.5, 'end': 3});
  });

  test('broken tool JSON is flagged, not thrown', () {
    final b = build(
      sse([
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'tool_use',
            'id': 't1',
            'name': 'cut',
            'input': {},
          },
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'input_json_delta', 'partial_json': '{"start": '},
        },
        {'type': 'content_block_stop', 'index': 0},
      ]),
    );
    expect(b.blocks.single['_invalidJson'], '{"start": ');
    expect(b.historyBlocks.single.containsKey('_invalidJson'), isFalse);
  });

  test('after a mid-output fallback, earlier thinking and tool calls are '
      'not sent back', () {
    final b = MessageBuilder()
      ..add({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking', 'thinking': '', 'signature': 's'},
      })
      ..add({
        'type': 'content_block_start',
        'index': 1,
        'content_block': {'type': 'text', 'text': 'Sure'},
      })
      ..add({
        'type': 'content_block_start',
        'index': 2,
        'content_block': {
          'type': 'fallback',
          'from': {'model': 'claude-opus-5-5'},
          'to': {'model': 'claude-opus-5'},
        },
      })
      ..add({
        'type': 'content_block_start',
        'index': 3,
        'content_block': {'type': 'text', 'text': ', done.'},
      });
    expect(
      [for (final x in b.historyBlocks) x['type']],
      ['text', 'fallback', 'text'],
    );
  });
}
