import 'package:uuid/uuid.dart';

import '../model/audio_item.dart';
import '../model/media_asset.dart';
import '../model/overlay_item.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../model/video_clip.dart';
import 'edit_command.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Shortest clip we allow, so trims and splits never leave a zero-length clip.
const minClipDuration = Duration(milliseconds: 100);

String formatTime(Duration d) {
  final ms = d.inMilliseconds;
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) / 1000;
  return '$minutes:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
}

VideoClip _clip(Project p, String id) {
  final i = p.clipIndex(id);
  if (i < 0) throw EditException('There is no clip with id $id.');
  return p.clips[i];
}

List<VideoClip> _replaceClip(Project p, String id, List<VideoClip> with_) {
  final i = p.clipIndex(id);
  return [...p.clips.sublist(0, i), ...with_, ...p.clips.sublist(i + 1)];
}

class RenameProject extends EditCommand {
  const RenameProject(this.name);
  final String name;

  @override
  String get label => 'Rename project';

  @override
  Project apply(Project project) {
    if (name.trim().isEmpty) throw EditException('The name is empty.');
    return project.copyWith(name: name.trim());
  }
}

class AddMedia extends EditCommand {
  const AddMedia(this.asset);
  final MediaAsset asset;

  @override
  String get label => 'Add media';

  @override
  Project apply(Project project) {
    if (project.mediaById(asset.id) != null) {
      throw EditException('Media ${asset.id} is already in the project.');
    }
    return project.copyWith(media: [...project.media, asset]);
  }
}

/// Adds a clip to the main track, at the end unless [index] is given.
class AddClip extends EditCommand {
  const AddClip(this.clip, {this.index});
  final VideoClip clip;
  final int? index;

  @override
  String get label => 'Add clip';

  @override
  Project apply(Project project) {
    final media = project.mediaById(clip.mediaId);
    if (media == null) throw EditException('Unknown media ${clip.mediaId}.');
    if (clip.sourceStart < Duration.zero ||
        clip.sourceEnd > media.duration ||
        clip.duration < minClipDuration) {
      throw EditException('The clip range is outside the source video.');
    }
    final i = index ?? project.clips.length;
    if (i < 0 || i > project.clips.length) {
      throw EditException('Clip position $i is out of range.');
    }
    // Things placed on the timeline after the insert point move along with
    // the video they belong to.
    final at = i == project.clips.length
        ? project.duration
        : project.clipStarts[i];
    Duration shift(Duration t) => t >= at ? t + clip.duration : t;
    return project.copyWith(
      clips: [...project.clips]..insert(i, clip),
      overlays: [
        for (final o in project.overlays) o.copyWith(start: shift(o.start)),
      ],
      audio: [for (final a in project.audio) a.copyWith(start: shift(a.start))],
      titles: [
        for (final t in project.titles) t.copyWith(start: shift(t.start)),
      ],
    );
  }
}

class RemoveClip extends EditCommand {
  const RemoveClip(this.clipId);
  final String clipId;

  @override
  String get label => 'Delete clip';

  @override
  Project apply(Project project) {
    _clip(project, clipId);
    return project.copyWith(clips: _replaceClip(project, clipId, []));
  }
}

/// Changes which part of the source a clip plays. Pass only the edge you
/// want to move.
class TrimClip extends EditCommand {
  const TrimClip(this.clipId, {this.sourceStart, this.sourceEnd});
  final String clipId;
  final Duration? sourceStart;
  final Duration? sourceEnd;

  @override
  String get label => 'Trim clip';

  @override
  Project apply(Project project) {
    final clip = _clip(project, clipId);
    final media = project.mediaById(clip.mediaId)!;
    final start = sourceStart ?? clip.sourceStart;
    final end = sourceEnd ?? clip.sourceEnd;
    if (start < Duration.zero || end > media.duration) {
      throw EditException('The trim goes past the ends of the source video.');
    }
    if (end - start < minClipDuration) {
      throw EditException('The clip would be too short.');
    }
    final trimmed = clip.copyWith(sourceStart: start, sourceEnd: end);
    return project.copyWith(clips: _replaceClip(project, clipId, [trimmed]));
  }
}

/// Splits the clip under [time] (timeline time) into two.
class SplitAt extends EditCommand {
  SplitAt(this.time, {String? newClipId}) : newClipId = newClipId ?? newId();
  final Duration time;
  final String newClipId;

  @override
  String get label => 'Split clip';

  @override
  Project apply(Project project) {
    final hit = project.clipAt(time);
    if (hit == null) {
      throw EditException('${formatTime(time)} is past the end of the video.');
    }
    final clip = project.clips[hit.index];
    final at = hit.sourceTime;
    if (at - clip.sourceStart < minClipDuration ||
        clip.sourceEnd - at < minClipDuration) {
      throw EditException('${formatTime(time)} is too close to a cut.');
    }
    return project.copyWith(
      clips: _replaceClip(project, clip.id, [
        clip.copyWith(sourceEnd: at),
        clip.copyWith(id: newClipId, sourceStart: at),
      ]),
    );
  }
}

class SetClipVolume extends EditCommand {
  const SetClipVolume(this.clipId, this.volume);
  final String clipId;
  final double volume;

  @override
  String get label => volume == 0 ? 'Mute clip' : 'Change clip volume';

  @override
  Project apply(Project project) {
    final clip = _clip(project, clipId);
    if (volume < 0 || volume > 2) {
      throw EditException('Volume must be between 0 and 2.');
    }
    return project.copyWith(
      clips: _replaceClip(project, clipId, [clip.copyWith(volume: volume)]),
    );
  }
}

class MoveClip extends EditCommand {
  const MoveClip(this.clipId, this.toIndex);
  final String clipId;
  final int toIndex;

  @override
  String get label => 'Move clip';

  @override
  Project apply(Project project) {
    final clip = _clip(project, clipId);
    final rest = [...project.clips]..removeWhere((c) => c.id == clipId);
    if (toIndex < 0 || toIndex > rest.length) {
      throw EditException('Clip position $toIndex is out of range.');
    }
    return project.copyWith(clips: rest..insert(toIndex, clip));
  }
}

/// Removes everything between [start] and [end] on the timeline, across as
/// many clips as needed, and closes the gap. Overlays and audio after the
/// cut move left with the video; ones inside the cut are removed.
class RemoveRange extends EditCommand {
  const RemoveRange(this.start, this.end);
  final Duration start;
  final Duration end;

  @override
  String get label => 'Cut ${formatTime(start)}–${formatTime(end)}';

  @override
  Project apply(Project project) {
    final total = project.duration;
    final from = start < Duration.zero ? Duration.zero : start;
    final to = end > total ? total : end;
    if (to - from <= Duration.zero) {
      throw EditException(
        'Nothing to cut between ${formatTime(start)} and ${formatTime(end)}.',
      );
    }
    if (to - from >= total) {
      throw EditException('That would remove the whole video.');
    }

    final clips = <VideoClip>[];
    var t = Duration.zero;
    for (final clip in project.clips) {
      final clipStart = t;
      final clipEnd = t + clip.duration;
      t = clipEnd;
      if (clipEnd <= from || clipStart >= to) {
        clips.add(clip);
        continue;
      }
      final keepBefore = from - clipStart;
      final keepAfter = clipEnd - to;
      if (keepBefore >= minClipDuration) {
        clips.add(clip.copyWith(sourceEnd: clip.sourceStart + keepBefore));
      }
      if (keepAfter >= minClipDuration) {
        clips.add(
          clip.copyWith(
            id: keepBefore >= minClipDuration ? newId() : clip.id,
            sourceStart: clip.sourceEnd - keepAfter,
          ),
        );
      }
    }

    final removed = to - from;
    Duration shift(Duration at) => at >= to ? at - removed : at;
    bool inside(Duration s, Duration e) => s >= from && e <= to;

    return project.copyWith(
      clips: clips,
      overlays: [
        for (final o in project.overlays)
          if (!inside(o.start, o.end)) o.copyWith(start: shift(o.start)),
      ],
      audio: [
        for (final a in project.audio)
          if (!inside(a.start, a.end)) a.copyWith(start: shift(a.start)),
      ],
      titles: [
        for (final t in project.titles)
          if (!inside(t.start, t.end)) t.copyWith(start: shift(t.start)),
      ],
    );
  }
}

class AddOverlay extends EditCommand {
  const AddOverlay(this.overlay);
  final OverlayItem overlay;

  @override
  String get label => 'Add overlay';

  @override
  Project apply(Project project) {
    if (project.mediaById(overlay.mediaId) == null) {
      throw EditException('Unknown media ${overlay.mediaId}.');
    }
    _checkSpan(project, overlay.start, overlay.duration);
    return project.copyWith(overlays: [...project.overlays, overlay]);
  }
}

class UpdateOverlay extends EditCommand {
  const UpdateOverlay(
    this.overlayId, {
    this.start,
    this.duration,
    this.transform,
  });
  final String overlayId;
  final Duration? start;
  final Duration? duration;
  final OverlayTransform? transform;

  @override
  String get label => 'Change overlay';

  @override
  Project apply(Project project) {
    final o = project.overlays.where((o) => o.id == overlayId).firstOrNull;
    if (o == null) throw EditException('There is no overlay $overlayId.');
    final updated = o.copyWith(
      start: start ?? o.start,
      duration: duration ?? o.duration,
      transform: transform ?? o.transform,
    );
    _checkSpan(project, updated.start, updated.duration);
    return project.copyWith(
      overlays: [
        for (final x in project.overlays) x.id == overlayId ? updated : x,
      ],
    );
  }
}

class RemoveOverlay extends EditCommand {
  const RemoveOverlay(this.overlayId);
  final String overlayId;

  @override
  String get label => 'Delete overlay';

  @override
  Project apply(Project project) {
    if (!project.overlays.any((o) => o.id == overlayId)) {
      throw EditException('There is no overlay $overlayId.');
    }
    return project.copyWith(
      overlays: project.overlays.where((o) => o.id != overlayId).toList(),
    );
  }
}

class AddAudio extends EditCommand {
  const AddAudio(this.item);
  final AudioItem item;

  @override
  String get label => 'Add audio';

  @override
  Project apply(Project project) {
    if (project.mediaById(item.mediaId) == null) {
      throw EditException('Unknown media ${item.mediaId}.');
    }
    if (item.start < Duration.zero || item.duration < minClipDuration) {
      throw EditException('The audio timing is invalid.');
    }
    return project.copyWith(audio: [...project.audio, item]);
  }
}

class RemoveAudio extends EditCommand {
  const RemoveAudio(this.itemId);
  final String itemId;

  @override
  String get label => 'Delete audio';

  @override
  Project apply(Project project) {
    if (!project.audio.any((a) => a.id == itemId)) {
      throw EditException('There is no audio item $itemId.');
    }
    return project.copyWith(
      audio: project.audio.where((a) => a.id != itemId).toList(),
    );
  }
}

void _checkSpan(Project project, Duration start, Duration duration) {
  if (start < Duration.zero || duration < minClipDuration) {
    throw EditException('The timing is invalid.');
  }
  if (start >= project.duration) {
    throw EditException(
      '${formatTime(start)} is past the end of the video '
      '(${formatTime(project.duration)}).',
    );
  }
}

class AddTitle extends EditCommand {
  const AddTitle(this.title);
  final TitleItem title;

  @override
  String get label => 'Add title';

  @override
  Project apply(Project project) {
    _checkSpan(project, title.start, title.spec.duration);
    return project.copyWith(titles: [...project.titles, title]);
  }
}

class UpdateTitle extends EditCommand {
  const UpdateTitle(this.titleId, {this.spec, this.start});
  final String titleId;
  final TitleSpec? spec;
  final Duration? start;

  @override
  String get label =>
      start != null && spec == null ? 'Move title' : 'Edit title';

  @override
  Project apply(Project project) {
    final t = project.titles.where((t) => t.id == titleId).firstOrNull;
    if (t == null) throw EditException('There is no title $titleId.');
    final updated = t.copyWith(spec: spec ?? t.spec, start: start ?? t.start);
    _checkSpan(project, updated.start, updated.spec.duration);
    return project.copyWith(
      titles: [for (final x in project.titles) x.id == titleId ? updated : x],
    );
  }
}

class RemoveTitle extends EditCommand {
  const RemoveTitle(this.titleId);
  final String titleId;

  @override
  String get label => 'Delete title';

  @override
  Project apply(Project project) {
    if (!project.titles.any((t) => t.id == titleId)) {
      throw EditException('There is no title $titleId.');
    }
    return project.copyWith(
      titles: project.titles.where((t) => t.id != titleId).toList(),
    );
  }
}

/// Points a generated intro at a newly rendered file (after its text,
/// colours or length changed). Clips using it are stretched to the new
/// length.
class ReplaceGeneratedMedia extends EditCommand {
  const ReplaceGeneratedMedia(this.updated);
  final MediaAsset updated;

  @override
  String get label => 'Edit intro';

  @override
  Project apply(Project project) {
    if (project.mediaById(updated.id) == null) {
      throw EditException('Unknown media ${updated.id}.');
    }
    return project.copyWith(
      media: [for (final m in project.media) m.id == updated.id ? updated : m],
      clips: [
        for (final c in project.clips)
          c.mediaId == updated.id
              ? c.copyWith(
                  sourceStart: Duration.zero,
                  sourceEnd: updated.duration,
                )
              : c,
      ],
    );
  }
}

/// Several commands applied as one, with one label.
class Batch extends EditCommand {
  const Batch(this.label, this.commands);

  @override
  final String label;
  final List<EditCommand> commands;

  @override
  Project apply(Project project) =>
      commands.fold(project, (p, c) => c.apply(p));
}
