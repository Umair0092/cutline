import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/ai/chat_controller.dart';
import 'package:cutline/ai/claude_client.dart';
import 'package:cutline/ai/edit_tools.dart';
import 'package:cutline/ai/project_summary.dart';
import 'package:cutline/ai/vision.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/title_item.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../fake_preview.dart';
import '../fixtures.dart';
import 'fake_claude.dart';
import 'tool_loop_test.dart' show sseTools;

const logo = MediaAsset(
  id: 'logo1',
  path: 'assets/img-logo1.png',
  kind: MediaKind.image,
  width: 512,
  height: 512,
  name: 'logo',
  description: 'A purple play button logo. Colours #7B61FF and #FF4F9A.',
);

/// A 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

class _FakeDescriber implements ImageDescriber {
  int calls = 0;
  @override
  Future<String> describe(Uint8List png) async {
    calls++;
    return 'A tiny red square logo. Colour #FF0000.';
  }
}

var _introCount = 0;

Future<MediaAsset> _fakeIntro(
  Project project,
  TitleSpec spec, {
  String? id,
}) async => MediaAsset(
  id: id ?? 'intro-${spec.templateId}-${_introCount++}',
  path: 'assets/intro-${spec.templateId}.mp4',
  kind: MediaKind.video,
  duration: spec.duration,
  width: 1920,
  height: 1080,
  title: spec,
);

void main() {
  const tools = EditToolbox();
  final withLogo = threeClips().copyWith(media: [...threeClips().media, logo]);
  const ctx = ToolContext(renderIntro: _fakeIntro);

  test('pictures get short ids and descriptions in the project state', () {
    final summary = projectSummary(withLogo);
    final images = summary['images'] as List;
    expect((images.single as Map)['id'], 'img1');
    expect((images.single as Map)['description'], contains('play button'));
    expect(imageAliases(withLogo)['img1']!.id, 'logo1');
  });

  test('a logo intro takes the picture by its id', () async {
    final out = await tools.run(
      'add_title',
      {
        'template': 'logo-spin',
        'placement': 'before',
        'fields': {'logo': 'img1', 'name': 'Umair Codes', 'accent': '#7B61FF'},
      },
      withLogo,
      context: ctx,
    );
    expect(out.isError, isFalse, reason: out.result);
    final intro = out.project.mediaById(out.project.clips.first.mediaId)!;
    expect(intro.title!.fields['logo'], 'assets/img-logo1.png');
    expect(out.project.clips, hasLength(4));
  });

  test('an unknown picture id says which ones exist', () async {
    final out = await tools.run(
      'add_title',
      {
        'template': 'logo-spin',
        'placement': 'before',
        'fields': {'logo': 'img7'},
      },
      withLogo,
      context: ctx,
    );
    expect(out.isError, isTrue);
    expect(out.result, contains('img1'));
  });

  test('photo clips can go after the video, in order', () async {
    var project = withLogo;
    for (final caption in ['One', 'Two']) {
      final out = await tools.run(
        'add_title',
        {
          'template': 'photo-showcase',
          'placement': 'after',
          'duration': 5,
          'fields': {'photo': 'img1', 'caption': caption},
        },
        project,
        context: ctx,
      );
      expect(out.isError, isFalse, reason: out.result);
      project = out.project;
    }
    expect(project.clips, hasLength(5));
    expect(project.duration, s(50));
    final last = project.mediaById(project.clips.last.mediaId)!;
    expect(last.title!.fields['caption'], 'Two');
  });

  test('a picture video can start from an empty project', () async {
    final empty = Project(media: const [logo]);
    final out = await tools.run(
      'add_title',
      {
        'template': 'photo-showcase',
        'placement': 'after',
        'fields': {'photo': 'img1'},
      },
      empty,
      context: ctx,
    );
    expect(out.isError, isFalse, reason: out.result);
    expect(out.project.duration, const Duration(seconds: 5));
  });

  group('attachments in the chat', () {
    late Directory dir;
    late ScriptedHttp http;
    late ProviderContainer container;
    late _FakeDescriber describer;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cutline_attach');
      File(p.join(dir.path, 'my logo.png')).writeAsBytesSync(_png);
      File(p.join(dir.path, 'song.mp3')).writeAsBytesSync([1, 2, 3]);
      describer = _FakeDescriber();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    void setUpWith(List<dynamic> responses) {
      http = ScriptedHttp(responses.cast());
      container = ProviderContainer(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(MemoryKeyStore('sk-ant-k')),
          previewProvider.overrideWithValue(FakePreviewController()),
          assistantClientFactoryProvider.overrideWithValue(
            (_, k) => ClaudeClient(apiKey: k, httpClient: http.client),
          ),
          imageDescriberFactoryProvider.overrideWithValue((_, _) => describer),
          introRendererProvider.overrideWithValue((_) => _fakeIntro),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(projectEditorProvider.notifier)
          .opened(threeClips(), p.join(dir.path, 'project'));
    }

    test('a picture is copied in, described, and usable in an intro', () async {
      setUpWith([
        ScriptedHttp.ok(
          sseTools([
            (
              't1',
              'add_title',
              '{"template":"logo-pop","placement":"before",'
                  '"fields":{"logo":"img1","name":"Umair"}}',
            ),
          ]),
        ),
        ScriptedHttp.ok(sseText('Added a bouncing logo intro.')),
      ]);
      await container
          .read(chatProvider.notifier)
          .send(
            'Make an intro with my logo',
            attachments: [p.join(dir.path, 'my logo.png')],
          );
      final project = container.read(projectEditorProvider).project;
      final image = project.media.singleWhere((m) => m.kind == MediaKind.image);
      expect(describer.calls, 1);
      expect(image.description, contains('red square'));
      expect(image.name, 'my logo');
      expect(
        File(p.join(dir.path, 'project', image.path)).existsSync(),
        isTrue,
      );
      // The assistant was told about it.
      final sent = jsonEncode(http.requests.first['messages']);
      expect(sent, contains('img1: picture'));
      expect(sent, contains('red square'));
      // The intro uses it, and it all is one undo step.
      final intro = project.mediaById(project.clips.first.mediaId)!;
      expect(intro.title!.fields['logo'], image.path);
      expect(container.read(projectEditorProvider).undoStack, hasLength(1));
      final user = container
          .read(chatProvider)
          .entries
          .firstWhere((e) => e.role == ChatRole.user);
      expect(user.attachments, [p.join(dir.path, 'my logo.png')]);
    });

    test('an audio file is offered to the assistant as file1', () async {
      setUpWith([ScriptedHttp.ok(sseText('Which part should it play under?'))]);
      await container
          .read(chatProvider.notifier)
          .send(
            'Use this as background music',
            attachments: [p.join(dir.path, 'song.mp3')],
          );
      final sent = jsonEncode(http.requests.first['messages']);
      expect(sent, contains('file1: audio file'));
      expect(describer.calls, 0);
    });
  });
}
