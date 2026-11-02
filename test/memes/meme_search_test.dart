import 'dart:convert';
import 'dart:io';

import 'package:cutline/memes/meme_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  test('nameWords splits file names into lowercase words', () {
    expect(nameWords('This-is_fine 2.GIF'), ['this', 'is', 'fine', '2']);
    expect(nameWords('reactions/bruh.mp4'), ['reactions', 'bruh']);
  });

  group('LocalMemes', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('memes');
      for (final f in [
        'this is fine.gif',
        'reactions/bruh.mp4',
        'fine-dog.png',
        'notes.txt',
      ]) {
        File(p.join(dir.path, f))
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
      }
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('an empty search lists every meme file', () {
      final all = LocalMemes(dir.path).search('');
      expect(
        [for (final m in all) m.title],
        ['bruh', 'fine-dog', 'this is fine'],
      );
      expect(all.every((m) => m.isLocal), isTrue);
    });

    test('best matches first; folder names count as tags', () {
      final r = LocalMemes(dir.path).search('this is fine');
      expect(r.first.title, 'this is fine');
      expect([for (final m in r) m.title], contains('fine-dog'));
      expect(LocalMemes(dir.path).search('react').single.title, 'bruh');
      expect(LocalMemes(dir.path).search('deadline'), isEmpty);
    });

    test('a missing folder finds nothing', () {
      expect(LocalMemes(p.join(dir.path, 'nope')).search('x'), isEmpty);
    });
  });

  group('GIPHY', () {
    final body = {
      'data': [
        {
          'id': 'abc123',
          'title': 'This Is Fine GIF',
          'images': {
            'fixed_width_small': {'url': 'https://g/small.gif'},
            'downsized_medium': {
              'url': 'https://g/medium.gif',
              'width': '480',
              'height': '270',
            },
          },
        },
        {'id': 'nofile', 'title': '', 'images': <String, dynamic>{}},
      ],
    };

    test('parseGiphy keeps results with a file to download', () {
      final memes = parseGiphy(body);
      expect(memes, hasLength(1));
      expect(memes.single.source, 'https://g/medium.gif');
      expect(memes.single.preview, 'https://g/small.gif');
      expect((memes.single.width, memes.single.height), (480, 270));
      expect(memes.single.isLocal, isFalse);
    });

    test('search sends the key and query; errors are readable', () async {
      late Uri asked;
      final ok = GiphyClient(
        'KEY',
        client: MockClient((r) async {
          asked = r.url;
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await ok.search('this is fine', stickers: true);
      expect(asked.path, '/v1/stickers/search');
      expect(asked.queryParameters['api_key'], 'KEY');
      expect(asked.queryParameters['q'], 'this is fine');

      final bad = GiphyClient(
        'KEY',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      expect(
        () => bad.search('x'),
        throwsA(
          isA<MemeSearchException>().having(
            (e) => e.message,
            'message',
            contains('key'),
          ),
        ),
      );
    });

    test('fetchMeme downloads once into assets/', () async {
      final work = Directory.systemTemp.createTempSync('work');
      addTearDown(() => work.deleteSync(recursive: true));
      var downloads = 0;
      final client = MockClient((_) async {
        downloads++;
        return http.Response.bytes([71, 73, 70], 200);
      });
      final meme = parseGiphy(body).single;
      final a = await fetchMeme(meme, work.path, client: client);
      final b = await fetchMeme(meme, work.path, client: client);
      expect(a, p.join(work.path, 'assets', 'giphy-abc123.gif'));
      expect(b, a);
      expect(downloads, 1);
      expect(File(a).readAsBytesSync(), [71, 73, 70]);
    });
  });
}
