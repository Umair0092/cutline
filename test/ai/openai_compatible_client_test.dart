import 'dart:convert';

import 'package:cutline/ai/assistant_client.dart';
import 'package:cutline/ai/openai_compatible_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_claude.dart';

/// An OpenAI-style SSE stream from chunks.
String openAiSse(List<Map<String, dynamic>> chunks) =>
    '${chunks.map((c) => 'data: ${jsonEncode(c)}\n\n').join()}data: [DONE]\n\n';

Map<String, dynamic> textChunk(String? text, {String? finish}) => {
  'choices': [
    {
      'index': 0,
      'delta': {'content': ?text},
      'finish_reason': finish,
    },
  ],
};

void main() {
  test('posts to the given endpoint and model with a Bearer key', () async {
    final http = ScriptedHttp([
      ScriptedHttp.ok(
        openAiSse([textChunk('Done'), textChunk(null, finish: 'stop')]),
      ),
    ]);
    final client = OpenAiCompatibleClient(
      apiKey: 'xai-test-key',
      model: 'grok-test',
      endpoint: 'https://api.example.test/v1/chat/completions',
      serviceName: 'Grok',
      httpClient: http.client,
    );

    final reply = await client
        .stream(system: const [], messages: const [])
        .last;

    expect(reply.text, 'Done');
    expect(reply.stopReason, 'end_turn');
    expect(http.urls.single, 'https://api.example.test/v1/chat/completions');
    expect(http.headers.single['authorization'], 'Bearer xai-test-key');
    expect(http.requests.single['model'], 'grok-test');
    expect(http.requests.single['stream'], isTrue);
  });

  test('a rejected key names the service in the message', () async {
    final http = ScriptedHttp([ScriptedHttp.status(401, 'invalid_api_key')]);
    final client = OpenAiCompatibleClient(
      apiKey: 'bad',
      model: 'm',
      endpoint: 'https://example.test/v1/chat/completions',
      serviceName: 'Gemini',
      httpClient: http.client,
    );
    await expectLater(
      client.stream(system: const [], messages: const []).last,
      throwsA(
        isA<AssistantException>().having(
          (e) => e.message,
          'message',
          contains('Gemini API key'),
        ),
      ),
    );
  });

  test('each OpenAI-compatible provider has an endpoint and a model', () {
    for (final p in AiProvider.values) {
      if (p.protocol != AiProtocol.openai) continue;
      if (p == AiProvider.custom) continue; // user supplies these
      expect(p.endpoint, startsWith('https://'), reason: '${p.name} endpoint');
      expect(p.model, isNotEmpty, reason: '${p.name} model');
    }
  });
}
