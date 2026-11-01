import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../editing/commands.dart';
import '../editing/project_editor.dart';
import '../export/exporter.dart';
import '../media/ffmpeg.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../model/video_clip.dart';
import '../storage/project_store.dart';
import 'title_renderer.dart';

enum TitlePlacement {
  /// A full-screen card that plays before the video starts.
  before,

  /// Drawn over the video, starting at a time.
  over,
}

/// Size and rate titles are made at, from the first clip.
({int width, int height, double fps}) projectTitleFormat(Project project) {
  final first = project.clips.isEmpty
      ? null
      : project.mediaById(project.clips.first.mediaId);
  return titleFormat(
    first?.width ?? 0,
    first?.height ?? 0,
    first?.frameRate ?? 30,
  );
}

/// Renders an intro clip into the project's `assets/` folder and returns
/// its media entry (same [id] when replacing).
Future<MediaAsset> renderIntroMedia(
  Project project,
  String workPath,
  TitleSpec spec, {
  String? id,
}) async {
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) throw ExportException('FFmpeg is missing.');
  final f = projectTitleFormat(project);
  final name = 'intro-${newId()}.mp4';
  final dir = Directory(p.join(workPath, ProjectStore.assetsDir))
    ..createSync(recursive: true);
  await TitleRenderer(ffmpeg).renderClip(
    spec,
    p.join(dir.path, name),
    width: f.width,
    height: f.height,
    fps: f.fps,
  );
  return MediaAsset(
    id: id ?? newId(),
    path: '${ProjectStore.assetsDir}/$name',
    kind: MediaKind.video,
    duration: spec.duration,
    width: f.width,
    height: f.height,
    frameRate: f.fps,
    title: spec,
  );
}

/// Adds a title as one undo step. Before-the-video intros are rendered to a
/// clip first, which takes a few seconds.
Future<void> addTitle(
  WidgetRef ref,
  TitleSpec spec,
  TitlePlacement placement, {
  Duration start = Duration.zero,
}) async {
  final editor = ref.read(projectEditorProvider.notifier);
  if (placement == TitlePlacement.over) {
    editor.run(AddTitle(TitleItem(id: newId(), spec: spec, start: start)));
    return;
  }
  final state = ref.read(projectEditorProvider);
  final media = await renderIntroMedia(state.project, state.workPath!, spec);
  editor.runAll('Add intro', [
    AddMedia(media),
    AddClip(
      VideoClip(
        id: newId(),
        mediaId: media.id,
        sourceStart: Duration.zero,
        sourceEnd: media.duration,
      ),
      index: 0,
    ),
  ]);
}

Future<void> updateOverlayTitle(
  WidgetRef ref,
  String titleId,
  TitleSpec spec,
) async => ref
    .read(projectEditorProvider.notifier)
    .run(UpdateTitle(titleId, spec: spec));

Future<void> updateIntroClip(
  WidgetRef ref,
  String mediaId,
  TitleSpec spec,
) async {
  final state = ref.read(projectEditorProvider);
  final media = await renderIntroMedia(
    state.project,
    state.workPath!,
    spec,
    id: mediaId,
  );
  ref.read(projectEditorProvider.notifier).run(ReplaceGeneratedMedia(media));
}
