import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/memes/meme_search.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../fixtures.dart';

class _FakeGiphy extends GiphyClient {
  _FakeGiphy()
    : super('k', client: MockClient((_) async => http.Response('', 500)));

  final queries = <(String, bool)>[];

  @override
  Future<List<Meme>> search(
    String query, {
    bool stickers = false,
    int limit = 24,
  }) async {
    queries.add((query, stickers));
    return [
      Meme(
        id: 'g1',
        title: 'giphy $query',
        preview: 'https://example.invalid/s.gif',
        source: 'https://example.invalid/m.gif',
      ),
    ];
  }
}

void main() {
  late Directory folder;
  setUp(() {
    folder = Directory.systemTemp.createTempSync('memes');
    for (final f in ['this is fine.gif', 'bruh.mp4']) {
      File(p.join(folder.path, f)).writeAsStringSync('x');
    }
  });
  tearDown(() => folder.deleteSync(recursive: true));

  Future<_FakeGiphy> pump(WidgetTester tester, {String? giphyKey}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final giphy = _FakeGiphy();
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        previewProvider.overrideWithValue(FakePreviewController()),
        memesFolderProvider.overrideWith((_) async => folder.path),
        giphyKeyProvider.overrideWith(() => _Key(giphyKey)),
        giphyClientFactoryProvider.overrideWithValue((_) => giphy),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('tab-memes')));
    await tester.pumpAndSettle();
    return giphy;
  }

  testWidgets('shows your memes and searches them by name', (tester) async {
    await pump(tester);
    expect(find.text('Your memes'), findsOneWidget);
    expect(
      find.byKey(Key('meme-${p.join(folder.path, 'bruh.mp4')}')),
      findsOneWidget,
    );
    expect(find.textContaining('Add a free GIPHY key'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('meme-search')), 'fine');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('meme-${p.join(folder.path, 'this is fine.gif')}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('meme-${p.join(folder.path, 'bruh.mp4')}')),
      findsNothing,
    );
  });

  testWidgets('with a GIPHY key, searches GIFs and stickers online', (
    tester,
  ) async {
    final giphy = await pump(tester, giphyKey: 'KEY');
    expect(find.textContaining('Add a free GIPHY key'), findsNothing);
    expect(find.text('Powered by GIPHY'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('meme-search')), 'deadline');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('GIPHY'), findsOneWidget);
    expect(find.byKey(const Key('meme-g1')), findsOneWidget);

    await tester.tap(find.text('Stickers'));
    await tester.pumpAndSettle();
    expect(giphy.queries, [('deadline', false), ('deadline', true)]);
  });
}

class _Key extends GiphyKeyNotifier {
  _Key(this.key);
  final String? key;

  @override
  Future<String?> build() async => key;
}
