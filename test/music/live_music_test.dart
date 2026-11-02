import 'dart:io';

import 'package:cutline/media/ffmpeg.dart';
import 'package:cutline/music/music_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Talks to the real music libraries: run with CUTLINE_LIVE=1.
void main() {
  final live = Platform.environment['CUTLINE_LIVE'] == '1';
  final ffmpeg = const FfmpegLocator().find();

  test(
    'finds, downloads and measures a real track',
    () async {
      final found = await searchTracks('calm piano');
      expect(found, isNotEmpty);
      final dir = Directory.systemTemp.createTempSync('cutline_live_music');
      addTearDown(() => dir.deleteSync(recursive: true));
      final rel = await fetchTrack(found.first, dir.path);
      final length = await probeAudioLength(ffmpeg!, p.join(dir.path, rel));
      expect(length, greaterThan(const Duration(seconds: 30)));
      // ignore: avoid_print
      print('${found.first.credit} — $length');
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !live || ffmpeg == null ? 'set CUTLINE_LIVE=1 (needs ffmpeg)' : null,
  );

  test('the Internet Archive on its own', () async {
    final found = await ArchiveMusicClient().search('ambient piano');
    expect(found, isNotEmpty);
    expect(found.first.source, endsWith('.mp3'));
    expect(found.first.license, startsWith('CC'));
    expect(found.first.license, isNot(contains('ND')));
  }, skip: !live ? 'set CUTLINE_LIVE=1' : null);
}
