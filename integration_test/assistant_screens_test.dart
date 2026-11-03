import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/ai/meme_tools.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/media/media_probe.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:cutline/music/music_library.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:cutline/transcript/whisper.dart';
import 'package:cutline/ui/assistant/chat_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:path/path.dart' as p;

import '../test/ai/fake_claude.dart';
import '../test/transcript/transcription_service_test.dart' show FakeEngine;
import 'screenshot.dart';

/// Screenshots of the AI chat, side panel tabs and the phone editor, with
/// a realistic conversation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final video =
      Platform.environment['SPEECH_VIDEO'] ??
      Platform.environment['SAMPLE_VIDEO'];
  final memeDir =
      Platform.environment['MEME_SHOTS'] ??
      (Directory(_scratchMemes).existsSync() ? _scratchMemes : null);

  testWidgets('assistant screens, desktop and phone', (tester) async {
    final root = p.dirname(p.dirname(video!));
    final support = Directory.systemTemp.createTempSync('cutline_ai_shots');
    File(p.join(support.path, 'preferences.json'))
        .writeAsStringSync('{"onboarded":true}');
    final asset = (await tester.runAsync(() => probeVideo(video)))!;
    final transcript = parseWhisperJson(
      jsonDecode(
        File(p.join(root, 'test/transcript/whisper_output.json'))
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    final engine = _Engine(transcript)..model = true;
    final hang = StreamController<List<int>>();
    final http0 = ScriptedHttp([
      ScriptedHttp.ok(
        sse([
          {
            'type': 'message_start',
            'message': {'model': 'claude-opus-5-5'},
          },
          {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'tool_use',
              'id': 't1',
              'name': 'cut_range',
              'input': {},
            },
          },
          {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {
              'type': 'input_json_delta',
              'partial_json': '{"start": 0, "end": 1.2}',
            },
          },
          {'type': 'content_block_stop', 'index': 0},
          {
            'type': 'message_delta',
            'delta': {'stop_reason': 'tool_use'},
          },
          {'type': 'message_stop'},
        ]),
      ),
      ScriptedHttp.ok(
        sseText(
          'Done. I trimmed the **first 1.2 seconds** so it opens right on '
          '"Hello". Want me to tighten the pause after "let me restart" too?',
        ),
      ),
      () => http.StreamedResponse(
        hang.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      ),
    ]);
    final keys = MemoryKeyStore('sk-ant-demo-key-000000');
    final container = ProviderContainer(
      overrides: [
        supportDirProvider.overrideWith((_) async => support.path),
        apiKeyStoreProvider.overrideWithValue(keys),
        speechEngineProvider.overrideWith((_) async => engine),
        if (memeDir != null)
          memesFolderProvider.overrideWith((_) async => memeDir),
        assistantClientFactoryProvider.overrideWithValue(
          (_, k) => ClaudeClient(apiKey: k, httpClient: http0.client),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    container.read(projectEditorProvider.notifier).runAll('Import video', [
      AddMedia(asset),
      AddClip(
        VideoClip(
          id: 'c1',
          mediaId: asset.id,
          sourceStart: Duration.zero,
          sourceEnd: asset.duration,
        ),
      ),
    ]);
    Future<void> wait(int ms) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    await wait(1500);
    await saveScreenshot(tester, 'assistant_desktop_empty', settle: false);

    // Focused composer with a picture and a song waiting to go.
    container
        .read(chatDraftProvider.notifier)
        .set(
          ChatDraft(
            'Use this as the thumbnail look for the intro',
            attachments: [
              p.join(root, 'test_media/logo.png'),
              p.join(root, 'test_media/speech.aiff'),
            ],
          ),
        );
    await wait(600);
    await saveScreenshot(tester, 'assistant_desktop_composer', settle: false);
    await tester.enterText(find.byKey(const Key('chat-input')), '');
    for (final f in ['logo.png', 'speech.aiff']) {
      await tester.tap(find.byKey(Key('remove-attachment-$f')));
      await tester.pump();
    }

    // A conversation so far.
    final memes = [
      for (var i = 1; i <= 8; i++)
        Meme(
          id: 'm$i',
          title: 'meme $i',
          preview: memeDir == null ? '' : p.join(memeDir, 'meme $i.png'),
          source: memeDir == null ? '' : p.join(memeDir, 'meme $i.png'),
        ),
    ];
    container
        .read(chatProvider.notifier)
        .load(
          ChatState(
            entries: [
              ChatEntry(
                role: ChatRole.user,
                text: 'Make an intro with my logo',
                attachments: [p.join(root, 'test_media/logo.png')],
              ),
              const ChatEntry(
                role: ChatRole.assistant,
                text:
                    'Here\'s a **logo reveal** before the video:\n'
                    '- your logo in a circle, then your name\n'
                    '- 3 seconds, brand violet\n\n'
                    'Say "make it shorter" or "use blue" to tweak it.',
              ),
              const ChatEntry(
                role: ChatRole.change,
                text: '1 change',
                changes: ['Add title', 'Add media'],
              ),
              const ChatEntry(
                role: ChatRole.user,
                text: 'Find some calm background music',
              ),
              const ChatEntry(
                role: ChatRole.assistant,
                text: 'Three calm lo-fi tracks that fit a 13 s talk:',
              ),
              const ChatEntry(
                role: ChatRole.tracks,
                text: '',
                tracks: [
                  (
                    'music1',
                    Track(
                      id: 'a',
                      title: 'Morning Coffee',
                      source: 'https://example.invalid/a.mp3',
                      artist: 'Lofi Lab',
                      duration: Duration(minutes: 2, seconds: 14),
                      license: 'CC BY',
                    ),
                  ),
                  (
                    'music2',
                    Track(
                      id: 'b',
                      title: 'Slow Tide',
                      source: 'https://example.invalid/b.mp3',
                      artist: 'Kalm',
                      duration: Duration(minutes: 3, seconds: 2),
                      license: 'CC0',
                    ),
                  ),
                  (
                    'music3',
                    Track(
                      id: 'c',
                      title: 'Paper Planes (instrumental)',
                      source: 'https://example.invalid/c.mp3',
                      artist: 'Nightdesk',
                      duration: Duration(minutes: 1, seconds: 48),
                      license: 'CC BY',
                    ),
                  ),
                ],
              ),
              const ChatEntry(
                role: ChatRole.user,
                text: 'Memes for the funny bits?',
              ),
              ChatEntry(
                role: ChatRole.memes,
                text: '',
                memes: [
                  for (final (i, m) in memes.take(8).indexed)
                    ('meme${i + 1}', m),
                ],
              ),
              ChatEntry(
                role: ChatRole.suggestion,
                text: '',
                suggestion: MemeSuggestion(
                  meme: memes[2],
                  start: const Duration(milliseconds: 4200),
                  position: 'top-right',
                  size: 0.3,
                  reason:
                      '"Um, let me restart" — a quick facepalm lands well '
                      'right as you stumble.',
                ),
              ),
              const ChatEntry(
                role: ChatRole.notice,
                text: 'Stopped. Nothing was changed.',
              ),
            ],
          ),
        );
    await wait(1200);
    await saveScreenshot(tester, 'assistant_desktop_cards', settle: false);

    // A real edit through the tool loop: the change card has Undo.
    final input = find.byKey(const Key('chat-input'));
    await tester.tap(input);
    await tester.enterText(input, 'Trim the dead air at the start');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 40 && container.read(chatProvider).busy; i++) {
      await wait(100);
    }
    await wait(800);
    await saveScreenshot(tester, 'assistant_desktop_chat', settle: false);

    // Thinking: the reply never comes, so the shimmer and spinning aurora
    // stay on.
    await tester.tap(input);
    await tester.enterText(input, 'Add captions in my brand colour');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await wait(900);
    await saveScreenshot(tester, 'assistant_desktop_thinking', settle: false);
    await tester.tap(find.byKey(const Key('stop')));
    await wait(400);

    // The other tabs.
    await tester.tap(find.byKey(const Key('tab-transcript')));
    await wait(800);
    await saveScreenshot(tester, 'assistant_desktop_transcript', settle: false);
    await tester.tap(find.byKey(const Key('tab-memes')));
    await wait(1200);
    await saveScreenshot(tester, 'assistant_desktop_memes', settle: false);
    await tester.tap(find.byKey(const Key('tab-assistant')));
    await wait(400);

    // No key.
    await tester.runAsync(
      () => container.read(apiKeyProvider.notifier).remove(),
    );
    await wait(500);
    await saveScreenshot(tester, 'assistant_desktop_nokey', settle: false);
    await tester.runAsync(
      () => container.read(apiKeyProvider.notifier).save('sk-ant-demo-key-0'),
    );

    // Phone (Pixel 8).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    await wait(1500);
    await saveScreenshot(tester, 'assistant_phone_editor', settle: false);
    await tester.tap(find.byKey(const Key('action-audio')));
    await wait(600);
    await saveScreenshot(tester, 'assistant_phone_audio_rail', settle: false);
    await tester.tap(find.byKey(const Key('action-back')));
    await wait(400);
    await tester.tap(find.byKey(const Key('action-ask')));
    await wait(1200);
    await saveScreenshot(tester, 'assistant_phone_chat', settle: false);
    container.read(chatProvider.notifier).clear();
    await wait(800);
    await saveScreenshot(tester, 'assistant_phone_empty', settle: false);
    await tester.tap(find.byKey(const Key('tab-memes')));
    await wait(1200);
    await saveScreenshot(tester, 'assistant_phone_memes', settle: false);
  }, skip: video == null);
}

class _Engine extends FakeEngine {
  _Engine(this.transcript);

  final Transcript transcript;

  @override
  Future<Transcript> transcribe(String path, void Function(double) p) async =>
      transcript;
}

const _scratchMemes =
    '/private/tmp/claude-501/-Users-qbit/03fc5ac9-b9c9-4944-a1d0-713126c344f4/scratchpad/memes';
