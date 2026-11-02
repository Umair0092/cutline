import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../ai/chat_controller.dart';
import '../../editing/project_editor.dart';
import '../../library/project_library.dart';
import '../../media/image_import.dart';
import '../../media/media_probe.dart';
import '../../model/project.dart';
import '../../storage/chat_store.dart';
import '../../storage/project_store.dart';
import '../import_actions.dart';
import '../navigation.dart';

/// Ways to start an edit from the home screen. Each one makes a new edit
/// in the library, opens the editor and, for the AI starts, hands the
/// assistant its first message so it gets going straight away.

const _videoGroup = XTypeGroup(
  label: 'Videos',
  extensions: videoExtensions,
  mimeTypes: ['video/*'],
  uniformTypeIdentifiers: ['public.mpeg-4', 'com.apple.quicktime-movie'],
);

const _imageGroup = XTypeGroup(
  label: 'Pictures',
  extensions: imageExtensions,
  mimeTypes: ['image/*'],
  uniformTypeIdentifiers: ['public.image'],
);

/// What the assistant is asked when you start from photos.
const photosPrompt =
    'Make a video from these photos: one photo showcase each, in order, '
    'with gentle motion.';

bool isVideoPath(String path) => videoExtensions.contains(
  p.extension(path).replaceFirst('.', '').toLowerCase(),
);

bool isImagePath(String path) => imageExtensions.contains(
  p.extension(path).replaceFirst('.', '').toLowerCase(),
);

/// Picks a video, makes a new edit in the library from it, and opens it.
/// With a [prompt], the assistant starts on it as soon as the editor opens.
Future<void> startNewEdit(
  WidgetRef ref,
  BuildContext context, {
  String? prompt,
}) async {
  final files = await openFiles(acceptedTypeGroups: const [_videoGroup]);
  if (files.isEmpty || !context.mounted) return;
  await startFromVideos(ref, context, [
    for (final f in files) f.path,
  ], prompt: prompt);
}

/// Starts a new edit from [paths] (videos), named after the first one, and
/// opens it (unless [open] is false). Returns whether the edit was made.
Future<bool> startFromVideos(
  WidgetRef ref,
  BuildContext context,
  List<String> paths, {
  String? prompt,
  bool open = true,
}) async {
  if (paths.isEmpty) return false;
  ref.read(projectEditorProvider.notifier).newProject();
  ref.read(chatProvider.notifier).clear();
  await importVideos(ref, context, paths);
  final project = ref.read(projectEditorProvider).project;
  if (project.clips.isEmpty) return false;
  await saveNewToLibrary(
    ref,
    project.copyWith(name: p.basenameWithoutExtension(paths.first)),
  );
  _ask(ref, prompt);
  if (open) await showEditor();
  return true;
}

/// Picks pictures and starts an edit with no video: the assistant turns
/// them into a photo showcase (or a logo intro, if [prompt] asks for one).
Future<void> startFromPhotos(
  WidgetRef ref,
  BuildContext context, {
  String prompt = photosPrompt,
}) async {
  final files = await openFiles(acceptedTypeGroups: const [_imageGroup]);
  if (files.isEmpty || !context.mounted) return;
  await startFromPictures(ref, [for (final f in files) f.path], prompt: prompt);
}

/// Starts an empty edit and sends [paths] (pictures) to the assistant.
Future<void> startFromPictures(
  WidgetRef ref,
  List<String> paths, {
  String prompt = photosPrompt,
}) async {
  if (paths.isEmpty) return;
  ref.read(projectEditorProvider.notifier).newProject();
  ref.read(chatProvider.notifier).clear();
  await saveNewToLibrary(
    ref,
    Project(name: paths.length == 1 ? 'Logo intro' : 'Photo story'),
  );
  _ask(ref, prompt, attachments: paths);
  await showEditor();
}

/// Files dropped on the home screen: videos start an edit; pictures alone
/// start a photo edit; pictures with videos go to the assistant with them.
Future<void> startFromDrop(
  WidgetRef ref,
  BuildContext context,
  List<String> paths,
) async {
  final videos = paths.where(isVideoPath).toList();
  final pictures = paths.where(isImagePath).toList();
  if (videos.isEmpty && pictures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drop a video (mp4, mov, m4v) or some pictures.'),
      ),
    );
    return;
  }
  if (videos.isEmpty) return startFromPictures(ref, pictures);
  ref.read(projectEditorProvider.notifier).newProject();
  ref.read(chatProvider.notifier).clear();
  await importVideos(ref, context, videos);
  final project = ref.read(projectEditorProvider).project;
  if (project.clips.isEmpty) return;
  await saveNewToLibrary(
    ref,
    project.copyWith(name: p.basenameWithoutExtension(videos.first)),
  );
  if (pictures.isNotEmpty) {
    _ask(ref, 'Here are some pictures for this video.', attachments: pictures);
  }
  await showEditor();
}

/// Starts an edit on the sample clip (made on first use).
Future<void> startWithSample(
  WidgetRef ref,
  BuildContext context,
  Future<String?> Function() makeSample,
) async {
  final path = await makeSample();
  if (path == null || !context.mounted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The sample needs FFmpeg, which wasn\'t found.'),
        ),
      );
    }
    return;
  }
  await startFromVideos(ref, context, [path]);
}

void _ask(
  WidgetRef ref,
  String? prompt, {
  List<String> attachments = const [],
}) {
  if ((prompt == null || prompt.trim().isEmpty) && attachments.isEmpty) return;
  // The editor opens while the assistant works on it.
  unawaited(
    ref
        .read(chatProvider.notifier)
        .send(prompt ?? '', attachments: attachments),
  );
}

Future<void> openLibraryProject(
  WidgetRef ref,
  BuildContext context,
  String path,
) async {
  try {
    final project = await const ProjectStore().load(path);
    ref.read(projectEditorProvider.notifier).opened(project, path);
    ref.read(chatProvider.notifier).load(await const ChatStore().load(path));
  } on ProjectFileException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return;
  }
  await showEditor();
}

/// Desktop: open a .cutline saved somewhere else; it's remembered on the
/// dashboard from then on.
Future<void> openProjectFile(WidgetRef ref, BuildContext context) async {
  final String? path;
  if (Platform.isWindows) {
    path = await getDirectoryPath(confirmButtonText: 'Open');
  } else {
    path = (await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Cutline project',
          extensions: ['cutline'],
          uniformTypeIdentifiers: ['com.umair0092.cutline.project'],
        ),
      ],
    ))?.path;
  }
  if (path == null || !context.mounted) return;
  (await ref.read(projectLibraryProvider.future)).remember(path);
  ref.invalidate(projectListProvider);
  if (context.mounted) await openLibraryProject(ref, context, path);
}

/// Copies an edit (with its chat and the files Cutline made for it) to a
/// new one in the library named "(name) copy".
Future<void> duplicateProject(WidgetRef ref, ProjectSummary summary) async {
  final library = await ref.read(projectLibraryProvider.future);
  final name = '${summary.name.isEmpty ? 'Untitled' : summary.name} copy';
  final path = library.newPath(name);
  await const ProjectStore().save(
    summary.project.copyWith(name: name),
    path,
    previousPath: summary.path,
  );
  try {
    await const ChatStore().save(
      path,
      await const ChatStore().load(summary.path),
    );
  } on Object {
    // A copy without the chat is still a good copy.
  }
  ref.invalidate(projectListProvider);
}
