import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_claude.dart';

void main() {
  late ScriptedHttp http;
  late ProviderContainer container;
  ChatState chat() => container.read(chatProvider);

  void setUpWith(List<dynamic> responses, {String? key = 'sk-ant-xyz'}) {
    http = ScriptedHttp(responses.cast());
    container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore(key)),
        claudeClientFactoryProvider.overrideWithValue(
          (k) => ClaudeClient(apiKey: k, httpClient: http.client),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  test('a turn adds both bubbles and keeps the raw history', () async {
    setUpWith([
      ScriptedHttp.ok(sseText('Sure, cutting it', before: thinkingEvents())),
      ScriptedHttp.ok(sseText('Done')),
    ]);
    await container.read(chatProvider.notifier).send('Cut the start');
    expect(
      [for (final e in chat().entries) (e.role, e.text)],
      [
        (ChatRole.user, 'Cut the start'),
        (ChatRole.assistant, 'Sure, cutting it'),
      ],
    );
    expect(chat().busy, isFalse);
    expect(chat().history, hasLength(2));

    // The second request sends the first turn back unchanged,
    // including the thinking block's signature.
    await container.read(chatProvider.notifier).send('Thanks');
    final sent = http.requests.last['messages'] as List<dynamic>;
    expect(sent, hasLength(3));
    final firstReply =
        (sent[1] as Map<String, dynamic>)['content'] as List<dynamic>;
    expect((firstReply.first as Map<String, dynamic>)['signature'], 'sig123');
  });

  test('no key: a notice, no request', () async {
    setUpWith([], key: null);
    await container.read(chatProvider.notifier).send('hello');
    expect(chat().entries.single.role, ChatRole.notice);
    expect(http.requests, isEmpty);
  });

  test('an error shows a notice and leaves history unchanged', () async {
    setUpWith([ScriptedHttp.status(401, 'authentication_error')]);
    await container.read(chatProvider.notifier).send('hello');
    expect(chat().entries.last.isError, isTrue);
    expect(chat().entries.last.text, contains('rejected'));
    expect(chat().history, isEmpty);
    expect(chat().busy, isFalse);
  });

  test('a refusal is explained and not added to history', () async {
    setUpWith([ScriptedHttp.ok(sseText('', stopReason: 'refusal'))]);
    await container.read(chatProvider.notifier).send('something');
    expect(chat().entries.last.text, contains('declined'));
    expect(chat().history, isEmpty);
  });

  test('saves and loads as JSON', () async {
    setUpWith([ScriptedHttp.ok(sseText('Hi'))]);
    await container.read(chatProvider.notifier).send('Hello');
    final restored = ChatState.fromJson(chat().toJson());
    expect(restored.entries.map((e) => e.text), ['Hello', 'Hi']);
    expect(restored.history, chat().history);
  });
}
