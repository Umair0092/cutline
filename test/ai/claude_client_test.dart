import 'package:cutline/ai/claude_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_claude.dart';

void main() {
  test(
    'sends the right model, headers and options, and streams text',
    () async {
      final http = ScriptedHttp([ScriptedHttp.ok(sseText('Hello there'))]);
      final client = ClaudeClient(
        apiKey: 'sk-ant-test',
        httpClient: http.client,
      );
      final texts = <String>[];
      await for (final b in client.stream(
        system: const [
          {'type': 'text', 'text': 'sys'},
        ],
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
      )) {
        texts.add(b.text);
      }
      expect(texts.last, 'Hello there ');
      expect(texts.length, greaterThan(2), reason: 'arrives in pieces');

      final body = http.requests.single;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['stream'], isTrue);
      expect(body['fallbacks'], 'default');
      expect(body['thinking'], {'type': 'adaptive'});
      expect(body['output_config'], {'effort': 'medium'});
      expect(body.containsKey('tools'), isFalse);
      final headers = http.headers.single;
      expect(headers['x-api-key'], 'sk-ant-test');
      expect(headers['anthropic-version'], '2026-10-21');
      expect(headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    },
  );

  test('retries rate limits and overloads, then succeeds', () async {
    final http = ScriptedHttp([
      ScriptedHttp.status(
        429,
        'rate_limit_error',
        headers: {'retry-after': '1'},
      ),
      ScriptedHttp.status(529, 'overloaded_error'),
      ScriptedHttp.ok(sseText('ok')),
    ]);
    final client = ClaudeClient(apiKey: 'k', httpClient: http.client);
    final last = await client.stream(system: const [], messages: const []).last;
    expect(last.text, 'ok ');
    expect(http.requests, hasLength(3));
  });

  test('a bad key is not retried and says what to do', () async {
    final http = ScriptedHttp([
      ScriptedHttp.status(401, 'authentication_error'),
    ]);
    final client = ClaudeClient(apiKey: 'k', httpClient: http.client);
    await expectLater(
      client.stream(system: const [], messages: const []).last,
      throwsA(
        isA<ClaudeException>().having(
          (e) => e.message,
          'message',
          contains('Settings'),
        ),
      ),
    );
    expect(http.requests, hasLength(1));
  });

  test('an error event mid-stream becomes a ClaudeException', () async {
    final http = ScriptedHttp([
      ScriptedHttp.ok(
        sse([
          {
            'type': 'message_start',
            'message': {'model': 'claude-opus-5-5'},
          },
          {
            'type': 'error',
            'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
          },
        ]),
      ),
    ]);
    final client = ClaudeClient(apiKey: 'k', httpClient: http.client);
    await expectLater(
      client.stream(system: const [], messages: const []).last,
      throwsA(
        isA<ClaudeException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
  });
}
