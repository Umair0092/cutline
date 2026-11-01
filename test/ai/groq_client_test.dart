import 'dart:convert';

import 'package:cutline/ai/assistant_client.dart';
import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/ai/groq_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_claude.dart';

/// An OpenAI-style SSE stream from chunks.
String openAiSse(List<Map<String, dynamic>> chunks) =>
    '${chunks.map((c) => 'data: ${jsonEncode(c)}\n\n').join()}data: [DONE]\n\n';

Map<String, dynamic> chunk({
  String? text,
  List<Map<String, dynamic>>? calls,
  String? finish,
}) => {
  'choices': [
    {
      'index': 0,
      'delta': {'content': ?text, 'tool_calls': ?calls},
      'finish_reason': finish,
    },
  ],
};

void main() {
  test('the conversation is translated to OpenAI chat messages', () {
    final out = toOpenAiMessages(
      [
        {'type': 'text', 'text': 'You edit videos.'},
      ],
      [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '<project_state>{}</project_state>'},
            {'type': 'text', 'text': 'Cut the start'},
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {'type': 'thinking', 'thinking': '', 'signature': 's'},
            {'type': 'text', 'text': 'On it.'},
            {
              'type': 'tool_use',
              'id': 't1',
              'name': 'cut_range',
              'input': {'start': 0, 'end': 5},
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {'type': 'tool_result', 'tool_use_id': 't1', 'content': 'ok'},
          ],
        },
      ],
    );
    expect(out, [
      {'role': 'system', 'content': 'You edit videos.'},
      {
        'role': 'user',
        'content': '<project_state>{}</project_state>\n\nCut the start',
      },
      {
        'role': 'assistant',
        'content': 'On it.',
        'tool_calls': [
          {
            'id': 't1',
            'type': 'function',
            'function': {
              'name': 'cut_range',
              'arguments': '{"start":0,"end":5}',
            },
          },
        ],
      },
      {'role': 'tool', 'tool_call_id': 't1', 'content': 'ok'},
    ]);
  });

  test('tool errors are marked for the model', () {
    final out = toOpenAiMessages(const [], [
      {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 't1',
            'content': 'no clip',
            'is_error': true,
          },
        ],
      },
    ]);
    expect(out.single['content'], 'Error: no clip');
  });

  test('every edit tool translates to a function with its schema', () {
    final tools = toOpenAiTools(const EditToolbox().definitions);
    expect(
      tools.map((t) => (t['function'] as Map)['name']),
      contains('add_title'),
    );
    for (final t in tools) {
      final fn = t['function'] as Map<String, dynamic>;
      expect(t['type'], 'function');
      expect((fn['parameters'] as Map)['type'], 'object');
      expect(fn.containsKey('eager_input_streaming'), isFalse);
    }
  });

  test(
    'streamed text and tool calls come back as Messages API blocks',
    () async {
      final http = ScriptedHttp([
        ScriptedHttp.ok(
          openAiSse([
            chunk(text: 'Cutting '),
            chunk(text: 'now.'),
            chunk(
              calls: [
                {
                  'index': 0,
                  'id': 'call_a',
                  'function': {
                    'name': 'cut_range',
                    'arguments': '{"start": 0,',
                  },
                },
              ],
            ),
            chunk(
              calls: [
                {
                  'index': 0,
                  'function': {'arguments': ' "end": 5}'},
                },
              ],
            ),
            chunk(
              calls: [
                {
                  'index': 1,
                  'id': 'call_b',
                  'function': {'name': 'seek', 'arguments': '{"time": 0}'},
                },
              ],
            ),
            chunk(finish: 'tool_calls'),
          ]),
        ),
      ]);
      final client = GroqClient(apiKey: 'gsk_test', httpClient: http.client);
      final reply = await client
          .stream(
            system: const [],
            messages: const [],
            tools: const EditToolbox().definitions,
          )
          .last;
      expect(reply.text, 'Cutting now.');
      expect(reply.stopReason, 'tool_use');
      final calls = reply.blocks.where((b) => b['type'] == 'tool_use').toList();
      expect(calls.map((c) => c['id']), ['call_a', 'call_b']);
      expect(calls.map((c) => c['name']), ['cut_range', 'seek']);
      expect(calls[0]['input'], {'start': 0, 'end': 5});
      expect(calls[1]['input'], {'time': 0});

      final body = http.requests.single;
      expect(body['model'], 'openai/gpt-oss-120b');
      expect(body['stream'], isTrue);
      expect(body['tool_choice'], 'auto');
      expect(http.headers.single['authorization'], 'Bearer gsk_test');
    },
  );

  test('finish reasons map to stop reasons', () async {
    Future<String?> stopFor(String finish) async {
      final http = ScriptedHttp([
        ScriptedHttp.ok(openAiSse([chunk(text: 'x'), chunk(finish: finish)])),
      ]);
      return (await GroqClient(
        apiKey: 'k',
        httpClient: http.client,
      ).stream(system: const [], messages: const []).last).stopReason;
    }

    expect(await stopFor('stop'), 'end_turn');
    expect(await stopFor('length'), 'max_tokens');
    expect(await stopFor('content_filter'), 'refusal');
  });

  test(
    'a bad key is explained; rate limits and broken tool calls retry',
    () async {
      var http = ScriptedHttp([ScriptedHttp.status(401, 'invalid_api_key')]);
      await expectLater(
        GroqClient(
          apiKey: 'k',
          httpClient: http.client,
        ).stream(system: const [], messages: const []).last,
        throwsA(
          isA<AssistantException>().having(
            (e) => e.message,
            'message',
            contains('Groq API key'),
          ),
        ),
      );

      http = ScriptedHttp([
        ScriptedHttp.status(
          429,
          'rate_limit_exceeded',
          headers: {'retry-after': '1'},
        ),
        ScriptedHttp.status(400, 'tool_use_failed'),
        ScriptedHttp.ok(openAiSse([chunk(text: 'ok'), chunk(finish: 'stop')])),
      ]);
      final reply = await GroqClient(
        apiKey: 'k',
        httpClient: http.client,
      ).stream(system: const [], messages: const []).last;
      expect(reply.text, 'ok');
      expect(http.requests, hasLength(3));
    },
  );
}
