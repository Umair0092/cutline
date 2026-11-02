import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../media/ffmpeg.dart';
import '../media/media_probe.dart';
import '../model/media_asset.dart';
import '../model/overlay_item.dart';
import '../model/project.dart';
import '../preview/preview_controller.dart';
import '../timeline/timeline_state.dart';
import 'overlay_media.dart';

const _overlayTypes = XTypeGroup(
  label: 'Images, GIFs and videos',
  extensions: overlayExtensions,
  uniformTypeIdentifiers: [
    'public.image',
    'com.compuserve.gif',
    'public.mpeg-4',
    'com.apple.quicktime-movie',
  ],
);

/// How long a new overlay stays on screen: pictures 3 s, GIFs whole loops
/// filling at least 3 s, videos their own length. Never past the end.
Duration defaultOverlayDuration(MediaAsset media, Duration room) {
  const still = Duration(seconds: 3);
  var d = switch (media.kind) {
    MediaKind.image => still,
    MediaKind.gif when media.duration <= Duration.zero => still,
    MediaKind.gif =>
      media.duration *
          ((still.inMicroseconds / media.duration.inMicroseconds).ceil()),
    _ => media.duration,
  };
  if (d > room) d = room;
  if (d < minClipDuration) d = minClipDuration;
  return d;
}

/// The commands that put [media] on top of the video at [start], centred,
/// above everything already there.
List<EditCommand> overlayCommands(
  Project project,
  MediaAsset media,
  Duration start, {
  OverlayTransform transform = const OverlayTransform(),
  Duration? duration,
  OverlayAnimation animation = OverlayAnimation.pop,
  String? id,
}) {
  final top = project.overlays.fold(-1, (m, o) => o.layer > m ? o.layer : m);
  return [
    if (project.mediaById(media.id) == null) AddMedia(media),
    AddOverlay(
      OverlayItem(
        id: id ?? newId(),
        mediaId: media.id,
        start: start,
        duration:
            duration ?? defaultOverlayDuration(media, project.duration - start),
        transform: transform,
        layer: top + 1,
        animation: animation,
      ),
    ),
  ];
}

/// Puts files on top of the video at the playhead, as one undo step, and
/// selects the last one.
Future<void> addOverlayFiles(
  WidgetRef ref,
  BuildContext context,
  List<String> paths,
) async {
  if (paths.isEmpty) return;
  void show(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) {
    return show('FFmpeg is missing, so overlays can\'t be read.');
  }
  var project = ref.read(projectEditorProvider).project;
  if (project.clips.isEmpty) {
    return show('Import a video first.');
  }
  var at = ref.read(previewProvider).position;
  if (at >= project.duration - minClipDuration) at = Duration.zero;

  final commands = <EditCommand>[];
  final errors = <String>[];
  String? lastId;
  for (final path in paths) {
    try {
      final media = await probeOverlayMedia(ffmpeg, path);
      lastId = newId();
      final add = overlayCommands(project, media, at, id: lastId);
      for (final c in add) {
        project = c.apply(project);
      }
      commands.addAll(add);
    } on MediaProbeException catch (e) {
      errors.add(e.message);
    } on EditException catch (e) {
      errors.add(e.message);
    }
  }
  if (commands.isNotEmpty) {
    ref
        .read(projectEditorProvider.notifier)
        .runAll(paths.length == 1 ? 'Add overlay' : 'Add overlays', commands);
    ref.read(timelineUiProvider.notifier).selectOverlay(lastId);
  }
  if (errors.isNotEmpty) show(errors.join('\n'));
}

Future<void> pickAndAddOverlay(WidgetRef ref, BuildContext context) async {
  final files = await openFiles(acceptedTypeGroups: [_overlayTypes]);
  if (!context.mounted) return;
  await addOverlayFiles(ref, context, [for (final f in files) f.path]);
}
