import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('the API key round-trips through the real keychain', (
    tester,
  ) async {
    const store = ApiKeyStore();
    final previous = (await tester.runAsync(store.read));
    await tester.runAsync(() => store.write('sk-ant-test-roundtrip-123456'));
    expect(await tester.runAsync(store.read), 'sk-ant-test-roundtrip-123456');
    await tester.runAsync(store.delete);
    expect(await tester.runAsync(store.read), isNull);
    if (previous != null) await tester.runAsync(() => store.write(previous));
  });

  testWidgets('chat panel layout', (tester) async {
    final container = ProviderContainer(
      overrides: [
        apiKeyProvider.overrideWith(() => _FixedKey('sk-ant-demo-key-000000')),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(chatProvider.notifier)
        .load(
          const ChatState(
            entries: [
              ChatEntry(role: ChatRole.user, text: 'Cut the first 5 seconds'),
              ChatEntry(
                role: ChatRole.assistant,
                text:
                    'I can\'t edit from chat yet, but I\'d remove 0:00–0:05 '
                    'and the rest would move up.',
              ),
              ChatEntry(role: ChatRole.notice, text: 'Stopped.'),
            ],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Make my voice deeper',
    );
    await saveScreenshot(tester, 'assistant');
  });

  // Runs only when a real key is given: CLAUDE_API_KEY=sk-ant-...
  final liveKey = Platform.environment['CLAUDE_API_KEY'];
  testWidgets('live: Claude answers in the panel', (tester) async {
    final container = ProviderContainer(
      overrides: [apiKeyProvider.overrideWith(() => _FixedKey(liveKey!))],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(chatProvider.notifier).send('Say hello in 3 words.'),
    );
    final chat = container.read(chatProvider);
    // ignore: avoid_print
    print(
      'LIVE: ${chat.entries.map((e) => '${e.role.name}: ${e.text}').join(' | ')}',
    );
    expect(chat.entries.last.role, ChatRole.assistant);
    expect(chat.history, hasLength(2));
  }, skip: liveKey == null);
}

class _FixedKey extends ApiKeyNotifier {
  _FixedKey(this.key);

  final String key;

  @override
  Future<String?> build() async => key;
}
