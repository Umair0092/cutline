import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the ffmpeg executable.
///
/// Looks next to the app first (where the bundled copy goes, see #5), then
/// in common install locations. Apps started from Finder don't get the
/// shell's PATH, so Homebrew's folders are checked by name.
class FfmpegLocator {
  const FfmpegLocator();

  static String? _cached;

  String? find() => _cached ??= _search();

  String? _search() {
    final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final appDir = p.dirname(Platform.resolvedExecutable);
    final candidates = [
      // macOS: Cutline.app/Contents/MacOS/cutline -> Contents/Resources/bin
      p.join(appDir, '..', 'Resources', 'bin', exe),
      // Windows: next to cutline.exe
      p.join(appDir, 'bin', exe),
      if (!Platform.isWindows) ...[
        '/opt/homebrew/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
        '/usr/bin/ffmpeg',
      ],
      ...?Platform.environment['PATH']
          ?.split(Platform.isWindows ? ';' : ':')
          .map((dir) => p.join(dir, exe)),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return p.normalize(c);
    }
    return null;
  }
}
