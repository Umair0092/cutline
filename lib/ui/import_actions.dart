import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../editing/project_editor.dart';
import '../media/media_probe.dart';
import '../model/video_clip.dart';

const _videoTypes = XTypeGroup(
  label: 'Videos',
  extensions: videoExtensions,
  uniformTypeIdentifiers: ['public.mpeg-4', 'com.apple.quicktime-movie'],
);

/// Adds videos to the end of the main track as one undo step.
Future<void> importVideos(
  WidgetRef ref,
  BuildContext context,
  List<String> paths,
) async {
  if (paths.isEmpty) return;
  final commands = <EditCommand>[];
  final errors = <String>[];
  for (final path in paths) {
    try {
      final asset = await probeVideo(path);
      commands
        ..add(AddMedia(asset))
        ..add(
          AddClip(
            VideoClip(
              id: newId(),
              mediaId: asset.id,
              sourceStart: Duration.zero,
              sourceEnd: asset.duration,
            ),
          ),
        );
    } on MediaProbeException catch (e) {
      errors.add(e.message);
    }
  }
  try {
    ref
        .read(projectEditorProvider.notifier)
        .runAll(paths.length == 1 ? 'Import video' : 'Import videos', commands);
  } on EditException catch (e) {
    errors.add(e.message);
  }
  if (errors.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
  }
}

Future<void> pickAndImportVideos(WidgetRef ref, BuildContext context) async {
  final files = await openFiles(acceptedTypeGroups: [_videoTypes]);
  if (!context.mounted) return;
  await importVideos(ref, context, [for (final f in files) f.path]);
}
