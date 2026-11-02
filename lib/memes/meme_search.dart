import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../overlays/overlay_media.dart';
import '../storage/project_store.dart';
import '../transcript/transcription_service.dart';

/// One meme you can put on the video: a file in your memes folder, or a
/// GIF or sticker from GIPHY.
class Meme {
  const Meme({
    required this.id,
    required this.title,
    required this.preview,
    required this.source,
    this.width = 0,
    this.height = 0,
  });

  /// Unique per source: the file path for local memes, the GIPHY id.
  final String id;
  final String title;

  /// A local path or a URL to show in the browser.
  final String preview;

  /// Local path, or the URL to download.
  final String source;
  final int width;
  final int height;

  bool get isLocal => !source.startsWith('http');

  factory Meme.fromJson(Map<String, dynamic> json) => Meme(
    id: json['id'] as String,
    title: json['title'] as String,
    preview: json['preview'] as String,
    source: json['source'] as String,
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
  );

  /// Everything, for saving in the chat history.
  Map<String, dynamic> toStoredJson() => {
    'id': id,
    'title': title,
    'preview': preview,
    'source': source,
    if (width > 0) 'width': width,
    if (height > 0) 'height': height,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (isLocal) 'from': 'your memes' else 'from': 'GIPHY',
  };
}

class MemeSearchException implements Exception {
  MemeSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Words in a name, lowercased: "this-is_fine 2.gif" -> this, is, fine, 2.
List<String> nameWords(String name) => p
    .withoutExtension(name)
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Your own memes: pictures, GIFs and short videos in a folder, found by
/// the words in their file names.
class LocalMemes {
  const LocalMemes(this.folder);

  final String folder;

  List<Meme> search(String query) {
    final dir = Directory(folder);
    if (!dir.existsSync()) return const [];
    final words = nameWords(query);
    final scored = <(int, Meme)>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (overlayKindOf(f.path) == null) continue;
      // Folder names count as tags too: reactions/this is fine.gif.
      final tags = nameWords(p.relative(f.path, from: folder));
      final hits = words.where((w) => tags.any((t) => t.startsWith(w))).length;
      if (words.isNotEmpty && hits == 0) continue;
      scored.add((
        hits,
        Meme(
          id: f.path,
          title: p.basenameWithoutExtension(f.path),
          preview: f.path,
          source: f.path,
        ),
      ));
    }
    scored.sort((a, b) {
      final byHits = b.$1.compareTo(a.$1);
      return byHits != 0 ? byHits : a.$2.title.compareTo(b.$2.title);
    });
    return [for (final (_, m) in scored) m];
  }
}

/// GIPHY search. Needs your own (free) API key from developers.giphy.com.
class GiphyClient {
  GiphyClient(this.apiKey, {http.Client? client})
    : _http = client ?? http.Client();

  final String apiKey;
  final http.Client _http;

  Future<List<Meme>> search(
    String query, {
    bool stickers = false,
    int limit = 24,
  }) async {
    final uri = Uri.https(
      'api.giphy.com',
      '/v1/${stickers ? 'stickers' : 'gifs'}/search',
      {
        'api_key': apiKey,
        'q': query.length > 50 ? query.substring(0, 50) : query,
        'limit': '$limit',
        'rating': 'pg-13',
        'lang': 'en',
      },
    );
    final http.Response r;
    try {
      r = await _http.get(uri).timeout(const Duration(seconds: 15));
    } on Exception {
      throw MemeSearchException('Couldn\'t reach GIPHY. Check your internet.');
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw MemeSearchException('GIPHY didn\'t accept the API key.');
    }
    if (r.statusCode == 429) {
      throw MemeSearchException(
        'GIPHY\'s limit for this key is used up. Try again in a while.',
      );
    }
    if (r.statusCode != 200) {
      throw MemeSearchException('GIPHY search failed (${r.statusCode}).');
    }
    return parseGiphy(jsonDecode(r.body) as Map<String, dynamic>);
  }
}

/// Turns a GIPHY search response into memes. Downloads the "downsized
/// medium" GIF (under 5 MB) when there is one, which keeps stickers
/// see-through and keeps projects small.
List<Meme> parseGiphy(Map<String, dynamic> body) {
  final out = <Meme>[];
  for (final item in (body['data'] as List? ?? const [])) {
    if (item is! Map<String, dynamic>) continue;
    final images = item['images'] as Map<String, dynamic>? ?? const {};
    Map<String, dynamic>? pick(String name) =>
        images[name] as Map<String, dynamic>?;
    final full = pick('downsized_medium') ?? pick('original');
    final small = pick('fixed_width_small') ?? pick('fixed_width') ?? full;
    final url = full?['url'] as String?;
    if (url == null || small?['url'] == null) continue;
    out.add(
      Meme(
        id: item['id'] as String,
        title: (item['title'] as String?)?.trim().isNotEmpty ?? false
            ? item['title'] as String
            : 'GIF',
        preview: small!['url'] as String,
        source: url,
        width: int.tryParse('${full!['width']}') ?? 0,
        height: int.tryParse('${full['height']}') ?? 0,
      ),
    );
  }
  return out;
}

/// Makes a meme a file the project can use. GIPHY memes are downloaded
/// into the project's `assets/` folder once, so the project works
/// offline later; local memes are used where they are.
Future<String> fetchMeme(
  Meme meme,
  String workPath, {
  http.Client? client,
}) async {
  if (meme.isLocal) return meme.source;
  final safe = meme.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  // Flat in assets/: saving to a new place copies that folder's files.
  final rel = '${ProjectStore.assetsDir}/giphy-$safe.gif';
  final file = File(p.join(workPath, rel));
  if (file.existsSync() && file.lengthSync() > 0) return file.path;
  final http.Response r;
  try {
    r = await (client ?? http.Client())
        .get(Uri.parse(meme.source))
        .timeout(const Duration(seconds: 60));
  } on Exception {
    throw MemeSearchException('Couldn\'t download the meme.');
  }
  if (r.statusCode != 200) {
    throw MemeSearchException('Couldn\'t download the meme (${r.statusCode}).');
  }
  file.parent.createSync(recursive: true);
  final part = File('${file.path}.part')..writeAsBytesSync(r.bodyBytes);
  part.renameSync(file.path);
  return file.path;
}

/// Keeps the GIPHY key in the system keychain, next to the AI keys.
class GiphyKeyStore {
  const GiphyKeyStore([this._storage = _defaultStorage]);

  final FlutterSecureStorage _storage;
  static const _defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _key = 'giphy_api_key';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) =>
      _storage.write(key: _key, value: value.trim());
  Future<void> delete() => _storage.delete(key: _key);
}

final giphyKeyStoreProvider = Provider<GiphyKeyStore>(
  (_) => const GiphyKeyStore(),
);

final giphyKeyProvider = AsyncNotifierProvider<GiphyKeyNotifier, String?>(
  GiphyKeyNotifier.new,
);

class GiphyKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      final key = await ref.read(giphyKeyStoreProvider).read();
      return key == null || key.isEmpty ? null : key;
    } on Object {
      return null;
    }
  }

  Future<void> save(String key) async {
    await ref.read(giphyKeyStoreProvider).write(key);
    state = AsyncData(key.trim());
  }

  Future<void> remove() async {
    await ref.read(giphyKeyStoreProvider).delete();
    state = const AsyncData(null);
  }
}

/// Where your own memes live: a "Memes" folder in the app's support
/// folder, made on first use.
final memesFolderProvider = FutureProvider<String>((ref) async {
  final dir = Directory(
    p.join(await ref.watch(supportDirProvider.future), 'Memes'),
  );
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir.path;
});

/// Searches your memes first, then GIPHY when there's a key. GIPHY errors
/// come back as [MemeResults.error] so your own memes still show.
class MemeResults {
  const MemeResults(this.local, this.online, {this.error});

  final List<Meme> local;
  final List<Meme> online;
  final String? error;

  List<Meme> get all => [...local, ...online];
}

typedef GiphyClientFactory = GiphyClient Function(String key);

final giphyClientFactoryProvider = Provider<GiphyClientFactory>(
  (_) => GiphyClient.new,
);
