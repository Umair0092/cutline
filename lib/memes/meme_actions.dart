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
import '../overlays/overlay_actions.dart';
import '../overlays/overlay_media.dart';
import '../timeline/timeline_state.dart';
import 'meme_search.dart';

/// Downloads (if needed) and reads a meme, and returns the commands that
/// put it on the video at [start]. Shared by the meme browser and the
/// assistant.
Future<List<EditCommand>> memeCommands(
  Project project,
  String workPath,
  Meme meme,
  Duration start, {
  OverlayTransform transform = const OverlayTransform(),
  Duration? duration,
  OverlayAnimation animation = OverlayAnimation.pop,
  String? id,
}) async {
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) throw MemeSearchException('FFmpeg is missing.');
  final path = await fetchMeme(meme, workPath);
  final MediaAsset media;
  try {
    media = await probeOverlayMedia(ffmpeg, path);
  } on MediaProbeException catch (e) {
    throw MemeSearchException(e.message);
  }
  // Downloaded memes are stored relative to the project, like recordings.
  final stored = path.startsWith(workPath)
      ? media.copyWith(path: path.substring(workPath.length + 1))
      : media;
  // Reuse the media entry if this file is already in the project.
  final existing = project.media
      .where((m) => m.path == stored.path)
      .firstOrNull;
  return overlayCommands(
    project,
    existing ?? stored,
    start,
    transform: transform,
    duration: duration,
    animation: animation,
    id: id,
  );
}

/// Puts [meme] on the video at [start] as one undo step and selects it.
Future<void> addMeme(
  WidgetRef ref,
  BuildContext context,
  Meme meme,
  Duration start, {
  OverlayTransform transform = const OverlayTransform(),
}) async {
  void show(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final state = ref.read(projectEditorProvider);
  if (state.project.clips.isEmpty) return show('Import a video first.');
  var at = start;
  if (at >= state.project.duration - minClipDuration) at = Duration.zero;
  if (!meme.isLocal) show('Downloading the meme…');
  try {
    final id = newId();
    final commands = await memeCommands(
      state.project,
      state.workPath!,
      meme,
      at,
      transform: transform,
      id: id,
    );
    ref.read(projectEditorProvider.notifier).runAll('Add meme', commands);
    ref.read(timelineUiProvider.notifier).selectOverlay(id);
    if (!meme.isLocal && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  } on MemeSearchException catch (e) {
    show(e.message);
  } on EditException catch (e) {
    show(e.message);
  }
}
