import '../model/project.dart';
import '../storage/project_store.dart';

/// Builds an mpv EDL (edit decision list) for the main track.
///
/// mpv plays an EDL as one continuous video, so the player's position is
/// the timeline position and cuts play back without seeking hiccups.
/// Paths use mpv's `%length%path` form so commas and semicolons in file
/// names are safe. Returns null for an empty project.
String? buildEdl(Project project, {String? projectPath}) {
  if (project.clips.isEmpty) return null;
  final parts = <String>[];
  for (final clip in project.clips) {
    final media = project.mediaById(clip.mediaId);
    if (media == null) continue;
    final path = ProjectStore.resolve(media.path, projectPath);
    parts.add(
      '%${_utf8Length(path)}%$path'
      ',start=${_seconds(clip.sourceStart)}'
      ',length=${_seconds(clip.duration)}',
    );
  }
  if (parts.isEmpty) return null;
  return 'edl://${parts.join(';')}';
}

String _seconds(Duration d) =>
    (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);

/// mpv counts the length prefix in bytes, not characters.
int _utf8Length(String s) {
  var n = 0;
  for (final rune in s.runes) {
    n += rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
  }
  return n;
}
