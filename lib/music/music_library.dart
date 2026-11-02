import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../media/ffmpeg.dart';
import '../model/audio_item.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../storage/project_store.dart';

/// Music or a sound effect: from Openverse (free, Creative Commons, no key
/// needed) or a file on your computer.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.source,
    this.artist = '',
    this.duration = Duration.zero,
    this.license = '',
    this.page = '',
    this.genres = const [],
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    source: json['source'] as String,
    artist: json['artist'] as String? ?? '',
    duration: Duration(milliseconds: json['ms'] as int? ?? 0),
    license: json['license'] as String? ?? '',
    page: json['page'] as String? ?? '',
    genres: [for (final g in json['genres'] as List? ?? const []) '$g'],
  );

  final String id;
  final String title;

  /// A local path, or the URL to download.
  final String source;
  final String artist;
  final Duration duration;

  /// e.g. "CC BY 4.0"; empty for your own files.
  final String license;

  /// Where the track lives online, for the credit.
  final String page;
  final List<String> genres;

  bool get isLocal => !source.startsWith('http');

  /// What to put in the video description, as most CC licenses ask.
  String get credit => [
    '"$title"',
    if (artist.isNotEmpty) 'by $artist',
    if (license.isNotEmpty) '($license)',
    if (page.isNotEmpty) page,
  ].join(' ');

  Map<String, dynamic> toStoredJson() => {
    'id': id,
    'title': title,
    'source': source,
    if (artist.isNotEmpty) 'artist': artist,
    if (duration > Duration.zero) 'ms': duration.inMilliseconds,
    if (license.isNotEmpty) 'license': license,
    if (page.isNotEmpty) 'page': page,
    if (genres.isNotEmpty) 'genres': genres,
  };

  /// What the assistant sees.
  Map<String, dynamic> toJson() => {
    'title': title,
    if (artist.isNotEmpty) 'artist': artist,
    if (duration > Duration.zero) 'seconds': duration.inSeconds,
    if (genres.isNotEmpty) 'genres': genres.take(4).toList(),
    'from': isLocal ? 'your file' : 'Openverse',
  };
}

class MusicException implements Exception {
  MusicException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum TrackKind { music, sound }

/// Openverse's audio search: Creative Commons music (Jamendo, ccMixter,
/// Free Music Archive) and sound effects (Freesound). No account needed.
class OpenverseClient {
  OpenverseClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Future<List<Track>> search(
    String query, {
    TrackKind kind = TrackKind.music,
    int limit = 8,
  }) async {
    final uri = Uri.https('api.openverse.org', '/v1/audio/', {
      'q': query.length > 80 ? query.substring(0, 80) : query,
      'page_size': '${limit * 2}',
      'category': kind == TrackKind.music ? 'music' : 'sound_effect',
      // Licenses that allow use in a video, including ones you earn from.
      'license_type': 'commercial,modification',
      'mature': 'false',
    });
    final http.Response r;
    try {
      r = await _http
          .get(uri, headers: {'user-agent': 'Cutline/1.0 (video editor)'})
          .timeout(const Duration(seconds: 10));
    } on Exception {
      throw MusicException(
        'Can\'t reach the music library. Check your connection.',
      );
    }
    if (r.statusCode == 429) {
      throw MusicException('The music library is busy. Try again in a minute.');
    }
    if (r.statusCode != 200) {
      throw MusicException('Music search failed (${r.statusCode}).');
    }
    final results =
        (jsonDecode(r.body) as Map<String, dynamic>)['results']
            as List<dynamic>;
    final out = <Track>[];
    for (final raw in results.cast<Map<String, dynamic>>()) {
      final url = raw['url'] as String?;
      final ms = raw['duration'] as int? ?? 0;
      if (url == null || url.isEmpty) continue;
      // Music shorter than 30 s is usually a jingle or a preview.
      if (kind == TrackKind.music && ms > 0 && ms < 30000) continue;
      if (kind == TrackKind.sound && ms > 30000) continue;
      final license = [
        'CC',
        (raw['license'] as String? ?? '').toUpperCase(),
        raw['license_version'] ?? '',
      ].join(' ').trim();
      out.add(
        Track(
          id: 'ov-${raw['id']}',
          title: (raw['title'] as String? ?? 'Untitled').trim(),
          source: url,
          artist: (raw['creator'] as String? ?? '').trim(),
          duration: Duration(milliseconds: ms),
          license: (raw['license'] as String?) == 'cc0'
              ? 'CC0'
              : license == 'CC'
              ? ''
              : license,
          page: raw['foreign_landing_url'] as String? ?? '',
          genres: [for (final g in raw['genres'] as List? ?? const []) '$g'],
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }
}

/// The Internet Archive's netlabel collection: albums released under
/// Creative Commons. Used for music when Openverse is slow, down or finds
/// nothing. Each album gives one track (its first of a usable length).
class ArchiveMusicClient {
  ArchiveMusicClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _ua = {'user-agent': 'Cutline/1.0 (video editor)'};

  Future<List<Track>> search(String query, {int limit = 6}) async {
    final words = query
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(6)
        .join(' ');
    if (words.isEmpty) return const [];
    final uri = Uri.https('archive.org', '/advancedsearch.php', {
      'q':
          '($words) AND mediatype:audio AND collection:netlabels '
          'AND licenseurl:*creativecommons*',
      'fl[]': ['identifier', 'title', 'creator', 'licenseurl', 'subject'],
      'rows': '${limit * 2}',
      'sort[]': 'downloads desc',
      'output': 'json',
    });
    final http.Response r;
    try {
      r = await _http
          .get(uri, headers: _ua)
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw MusicException(
        'Can\'t reach the music library. Check your connection.',
      );
    }
    if (r.statusCode != 200) {
      throw MusicException('Music search failed (${r.statusCode}).');
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final docs = ((body['response'] as Map?)?['docs'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        // "No derivatives" licenses don't allow putting music in a video.
        .where((d) => !'${d['licenseurl']}'.contains('-nd'))
        .take(limit)
        .toList();
    final tracks = await Future.wait(docs.map(_firstTrack));
    return [for (final t in tracks) ?t];
  }

  Future<Track?> _firstTrack(Map<String, dynamic> doc) async {
    final id = '${doc['identifier']}';
    try {
      final r = await _http
          .get(Uri.https('archive.org', '/metadata/$id/files'), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final files =
          ((jsonDecode(r.body) as Map<String, dynamic>)['result'] as List? ??
                  const [])
              .cast<Map<String, dynamic>>();
      for (final f in files) {
        final name = '${f['name']}';
        final seconds = double.tryParse('${f['length'] ?? ''}') ?? 0;
        if (!name.endsWith('.mp3') || seconds < 45 || seconds > 900) continue;
        return Track(
          id: 'ia-$id-${name.hashCode.toUnsigned(32)}',
          title: '${f['title'] ?? p.basenameWithoutExtension(name)}'.trim(),
          source: Uri.https('archive.org', '/download/$id/$name').toString(),
          artist: '${f['creator'] ?? doc['creator'] ?? ''}'.trim(),
          duration: Duration(milliseconds: (seconds * 1000).round()),
          license: _licenseName('${doc['licenseurl'] ?? ''}'),
          page: 'https://archive.org/details/$id',
          genres: [
            for (final g
                in doc['subject'] is List
                    ? (doc['subject'] as List)
                    : ['${doc['subject'] ?? ''}'])
              if ('$g'.isNotEmpty && '$g'.length < 20) '$g'.toLowerCase(),
          ].take(4).toList(),
        );
      }
    } on Exception {
      return null;
    }
    return null;
  }
}

/// "http://creativecommons.org/licenses/by-nc/3.0/" → "CC BY-NC 3.0".
String _licenseName(String url) {
  if (url.contains('publicdomain')) return 'CC0';
  final m = RegExp(r'licenses/([a-z-]+)/(\d\.\d)').firstMatch(url);
  if (m == null) return 'Creative Commons';
  return 'CC ${m[1]!.toUpperCase()} ${m[2]}';
}

/// Music from Openverse, falling back to the Internet Archive when Openverse is slow,
/// down or finds nothing. Sound effects come from Openverse (Freesound).
Future<List<Track>> searchTracks(
  String query, {
  TrackKind kind = TrackKind.music,
  OpenverseClient? openverse,
  ArchiveMusicClient? archive,
}) async {
  MusicException? problem;
  try {
    final found = await (openverse ?? OpenverseClient()).search(
      query,
      kind: kind,
    );
    if (found.isNotEmpty || kind == TrackKind.sound) return found;
  } on MusicException catch (e) {
    if (kind == TrackKind.sound) rethrow;
    problem = e;
  }
  try {
    return await (archive ?? ArchiveMusicClient()).search(query);
  } on MusicException {
    throw problem ?? MusicException('Music search failed. Try again.');
  }
}

/// Finds music or sounds. Tests override this.
final trackFinderProvider =
    Provider<Future<List<Track>> Function(String, {TrackKind kind})>(
      (_) =>
          (query, {kind = TrackKind.music}) => searchTracks(query, kind: kind),
    );

const audioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'opus'];

/// Copies or downloads [track] into the project's `assets/` folder and
/// returns its path relative to the project.
Future<String> fetchTrack(
  Track track,
  String workPath, {
  http.Client? client,
}) async {
  final safe = track.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (track.isLocal) {
    final ext = p.extension(track.source).toLowerCase();
    final rel = '${ProjectStore.assetsDir}/music-$safe$ext';
    final file = File(p.join(workPath, rel));
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      File(track.source).copySync(file.path);
    }
    return rel;
  }
  final rel = '${ProjectStore.assetsDir}/music-$safe.mp3';
  final file = File(p.join(workPath, rel));
  if (file.existsSync() && file.lengthSync() > 0) return rel;
  final http.Response r;
  try {
    r = await (client ?? http.Client())
        .get(
          Uri.parse(track.source),
          headers: {'user-agent': 'Cutline/1.0 (video editor)'},
        )
        .timeout(const Duration(minutes: 2));
  } on Exception {
    throw MusicException('Couldn\'t download "${track.title}".');
  }
  if (r.statusCode != 200 || r.bodyBytes.length < 1024) {
    throw MusicException(
      'Couldn\'t download "${track.title}" (${r.statusCode}).',
    );
  }
  file.parent.createSync(recursive: true);
  File('${file.path}.part')
    ..writeAsBytesSync(r.bodyBytes)
    ..renameSync(file.path);
  return rel;
}

/// Length of an audio file, read from FFmpeg's banner.
Future<Duration> probeAudioLength(String ffmpeg, String path) async {
  final r = await Process.run(ffmpeg, ['-hide_banner', '-i', path]);
  final m = RegExp(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)')
      .firstMatch('${r.stderr}');
  if (m == null) throw MusicException('${p.basename(path)} isn\'t audio.');
  final s =
      int.parse(m[1]!) * 3600 + int.parse(m[2]!) * 60 + double.parse(m[3]!);
  final length = Duration(microseconds: (s * 1e6).round());
  if (length < minClipDuration) {
    throw MusicException('${p.basename(path)} is too short.');
  }
  return length;
}

/// Gets [track] into the project and returns its media entry, reusing the
/// one already there.
Future<MediaAsset> trackMedia(
  Project project,
  String workPath,
  Track track,
) async {
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) throw MusicException('FFmpeg is missing.');
  final rel = await fetchTrack(track, workPath);
  final existing = project.media.where((m) => m.path == rel).firstOrNull;
  if (existing != null) return existing;
  final length = await probeAudioLength(ffmpeg, p.join(workPath, rel));
  return MediaAsset(
    id: newId(),
    path: rel,
    kind: MediaKind.audio,
    duration: length,
    hasAudio: true,
    name: track.title,
    credit: track.isLocal ? null : track.credit,
  );
}

/// Commands that lay [media] as background music from [from] to [to]
/// (default: the whole video), repeating it if it's shorter, fading in at
/// the start and out at the end.
List<EditCommand> musicCommands(
  Project project,
  MediaAsset media, {
  Duration from = Duration.zero,
  Duration? to,
  Duration sourceStart = Duration.zero,
  double volume = 1,
  bool loop = true,
}) {
  final end = to == null || to > project.duration ? project.duration : to;
  if (end - from < minClipDuration) {
    throw MusicException('There\'s no room for music there.');
  }
  final commands = <EditCommand>[
    if (project.mediaById(media.id) == null) AddMedia(media),
  ];
  const fadeIn = Duration(milliseconds: 1500);
  const fadeOut = Duration(seconds: 3);
  var at = from;
  var offset = sourceStart < media.duration ? sourceStart : Duration.zero;
  while (end - at >= minClipDuration) {
    final available = media.duration - offset;
    final length = available < end - at ? available : end - at;
    final last = at + length >= end || !loop;
    commands.add(
      AddAudio(
        AudioItem(
          id: newId(),
          mediaId: media.id,
          role: AudioRole.music,
          start: at,
          sourceStart: offset,
          sourceEnd: offset + length,
          volume: volume,
          fadeIn: at == from ? _shorter(fadeIn, length ~/ 4) : Duration.zero,
          fadeOut: last ? _shorter(fadeOut, length ~/ 3) : Duration.zero,
        ),
      ),
    );
    if (last) break;
    at += length;
    offset = Duration.zero;
  }
  return commands;
}

Duration _shorter(Duration a, Duration b) => a < b ? a : b;

/// Commands for one sound effect at [start].
List<EditCommand> soundCommands(
  Project project,
  MediaAsset media,
  Duration start, {
  double volume = 1,
}) {
  final room = project.duration - start;
  if (room < minClipDuration) {
    throw MusicException('That\'s past the end of the video.');
  }
  final length = media.duration < room ? media.duration : room;
  return [
    if (project.mediaById(media.id) == null) AddMedia(media),
    AddAudio(
      AudioItem(
        id: newId(),
        mediaId: media.id,
        role: AudioRole.effect,
        start: start,
        sourceStart: Duration.zero,
        sourceEnd: length,
        volume: volume,
      ),
    ),
  ];
}
