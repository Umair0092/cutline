import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../ai/chat_controller.dart';
import '../editing/project_editor.dart';
import '../media/media_previews.dart';
import '../media/media_probe.dart';
import '../model/project.dart';
import '../storage/chat_store.dart';
import '../storage/project_store.dart';
import '../ui/import_actions.dart';
import '../ui/navigation.dart';
import '../ui/settings_dialog.dart';
import '../ui/splash_screen.dart';
import '../ui/theme.dart';
import '../ui/time_format.dart';
import 'project_library.dart';

/// The home screen: start a new edit or pick up a past one.
class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);
    setHasDashboard(true);
    final projects = ref.watch(projectListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 16.0 : 40.0;
    return Scaffold(
      key: const Key('dashboard'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                  sliver: const SliverToBoxAdapter(child: _Header()),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 28, pad, 16),
                  sliver: SliverToBoxAdapter(
                    child: _NewEdit(compact: width < 600),
                  ),
                ),
                ...switch (projects) {
                  AsyncData(:final value) when value.isEmpty => [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      sliver: const SliverToBoxAdapter(child: _Empty()),
                    ),
                  ],
                  AsyncData(:final value) => [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Your edits',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
                      // Cards are exactly as tall as a 16:9 frame plus the
                      // text under it, whatever the column width.
                      sliver: SliverLayoutBuilder(
                        builder: (context, c) {
                          const gap = 14.0;
                          final cols = (c.crossAxisExtent / (300 + gap))
                              .ceil()
                              .clamp(1, 6);
                          final w =
                              (c.crossAxisExtent - gap * (cols - 1)) / cols;
                          return SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: gap,
                                  mainAxisExtent: w * 9 / 16 + 92,
                                ),
                            itemCount: value.length,
                            itemBuilder: (_, i) =>
                                ProjectCard(summary: value[i]),
                          );
                        },
                      ),
                    ),
                  ],
                  AsyncError() => [
                    const SliverToBoxAdapter(
                      child: Center(child: Text('Couldn\'t read your edits.')),
                    ),
                  ],
                  _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CutlineLogo(size: 34),
        const SizedBox(width: 10),
        Text(
          'Cutline',
          style: const TextStyle(
            fontFamily: displayFont,
            fontSize: 34,
            height: 1,
            letterSpacing: 1.2,
            color: Palette.paper,
          ),
        ),
        const Spacer(),
        IconButton(
          key: const Key('dashboard-settings'),
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => showSettings(context),
        ),
      ],
    );
  }
}

/// The main action: pick a video and start editing it.
class _NewEdit extends ConsumerWidget {
  const _NewEdit({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final open = Platform.isAndroid || Platform.isIOS
        ? null
        : OutlinedButton.icon(
            key: const Key('open-project-file'),
            onPressed: () => openProjectFile(ref, context),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('Open a project file'),
          );
    return Material(
      color: Palette.bench,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: Palette.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('new-edit'),
        onTap: () => startNewEdit(ref, context),
        child: Padding(
          padding: EdgeInsets.all(compact ? 18 : 24),
          child: Row(
            children: [
              Container(
                width: compact ? 52 : 64,
                height: compact ? 52 : 64,
                decoration: BoxDecoration(
                  color: Palette.cut,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New edit',
                      style: TextStyle(
                        fontFamily: displayFont,
                        fontSize: compact ? 30 : 38,
                        height: 1,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a video, then tell Cutline what to change.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Palette.dust,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact && open != null) ...[
                const SizedBox(width: 16),
                open,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Text(
      'Your edits will show up here, and save themselves as you work.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Palette.dust),
    ),
  );
}

/// A past edit: a frame from it, its fingerprint, its name and when it
/// was last changed.
class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      key: Key('project-${p.basename(summary.path)}'),
      color: Palette.bench,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: Palette.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openLibraryProject(ref, context, summary.path),
        onLongPress: () => _menu(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _Thumbnail(summary: summary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: SizedBox(
                height: 14,
                child: EditFingerprint(project: summary.project),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${timeAgo(summary.modified)}, '
                          '${formatPlayerTime(summary.duration).split('.').first} long',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Palette.dust,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onPressed: () => _menu(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final library = await ref.read(projectLibraryProvider.future);
    if (!context.mounted) return;
    final inLibrary = library.contains(summary.path);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(inLibrary ? 'Delete' : 'Remove from this list'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      final name = await _askName(context, summary.name);
      if (name == null || name.isEmpty) return;
      await const ProjectStore().save(
        summary.project.copyWith(name: name),
        summary.path,
      );
      ref.invalidate(projectListProvider);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            inLibrary
                ? 'Delete "${summary.name}"?'
                : 'Remove "${summary.name}"?',
          ),
          content: Text(
            inLibrary
                ? 'The edit and the files Cutline made for it (intros, '
                      'recordings, downloaded memes) are deleted. Your '
                      'original videos stay where they are.'
                : 'It stays on disk where you saved it; it just won\'t be '
                      'listed here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(inLibrary ? 'Delete' : 'Remove'),
            ),
          ],
        ),
      );
      if (ok ?? false) {
        library.delete(summary.path);
        ref.invalidate(projectListProvider);
      }
    }
  }
}

Future<String?> _askName(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename edit'),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = summary.project;
    // A frame from the first clip that isn't a generated intro.
    final clip = project.clips
        .where((c) => project.mediaById(c.mediaId)?.title == null)
        .firstOrNull;
    final media = clip == null ? null : project.mediaById(clip.mediaId);
    final preview = media == null
        ? null
        : ref
              .watch(
                mediaPreviewProvider(
                  ProjectStore.resolve(media.path, summary.path),
                ),
              )
              .value;
    final image = preview?.thumbnailAt(
      clip!.sourceStart + const Duration(seconds: 1),
    );
    return ColoredBox(
      color: const Color(0xFF0F0D15),
      child: image != null
          ? RawImage(image: image, fit: BoxFit.cover)
          : const Center(
              child: Icon(Icons.movie_outlined, color: Palette.rule, size: 36),
            ),
    );
  }
}

/// A tiny picture of the edit: clips as segments (gaps are cuts), intros in
/// a lighter violet, and pink ticks where memes, titles and voiceovers sit.
class EditFingerprint extends StatelessWidget {
  const EditFingerprint({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FingerprintPainter(project));
}

class _FingerprintPainter extends CustomPainter {
  _FingerprintPainter(this.project);

  final Project project;

  @override
  void paint(Canvas canvas, Size size) {
    final total = project.duration.inMicroseconds;
    final barTop = size.height * 0.45;
    final bar = Rect.fromLTWH(0, barTop, size.width, size.height - barTop);
    if (total <= 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = Palette.rule,
      );
      return;
    }
    double x(Duration t) => t.inMicroseconds / total * size.width;
    final starts = project.clipStarts;
    for (var i = 0; i < project.clips.length; i++) {
      final c = project.clips[i];
      final intro = project.mediaById(c.mediaId)?.title != null;
      final left = x(starts[i]) + (i == 0 ? 0 : 1);
      final right =
          x(starts[i] + c.duration) - (i == project.clips.length - 1 ? 0 : 1);
      if (right <= left) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, bar.top, right, bar.bottom),
          const Radius.circular(2),
        ),
        Paint()
          ..color = intro
              ? const Color(0xFFB9A8FF)
              : Palette.cut.withValues(alpha: 0.75),
      );
    }
    final marks = [
      for (final o in project.overlays) o.start,
      for (final t in project.titles) t.start,
      for (final a in project.audio) a.start,
    ];
    final tick = Paint()
      ..color = Palette.marker
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final m in marks) {
      final mx = x(m).clamp(1.0, size.width - 1);
      canvas.drawLine(Offset(mx, 1), Offset(mx, barTop - 2), tick);
    }
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) => old.project != project;
}

String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'Yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return '${t.day} ${_months[t.month - 1]}${t.year == (now ?? DateTime.now()).year ? '' : ' ${t.year}'}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Picks a video, makes a new edit in the library from it, and opens it.
Future<void> startNewEdit(WidgetRef ref, BuildContext context) async {
  final files = await openFiles(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Videos',
        extensions: videoExtensions,
        mimeTypes: ['video/*'],
        uniformTypeIdentifiers: ['public.mpeg-4', 'com.apple.quicktime-movie'],
      ),
    ],
  );
  if (files.isEmpty || !context.mounted) return;
  ref.read(projectEditorProvider.notifier).newProject();
  ref.read(chatProvider.notifier).clear();
  await importVideos(ref, context, [for (final f in files) f.path]);
  final project = ref.read(projectEditorProvider).project;
  if (project.clips.isEmpty) return;
  await saveNewToLibrary(
    ref,
    project.copyWith(name: p.basenameWithoutExtension(files.first.path)),
  );
  await showEditor();
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
