import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../library/project_library.dart';
import '../../media/media_previews.dart';
import '../../model/media_asset.dart';
import '../../model/project.dart';
import '../../model/video_clip.dart';
import '../../storage/project_store.dart';
import '../time_format.dart';
import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';
import 'start_actions.dart';

/// Edits deleted a moment ago: hidden from the grid while the "Undo"
/// snackbar shows, and only removed from disk once it's gone.
final pendingDeletes = ValueNotifier<Set<String>>(const {});

/// A past edit: a frame from it (scrub it with the pointer), how long it
/// is, its fingerprint, its name and when it was last changed.
class ProjectCard extends ConsumerStatefulWidget {
  const ProjectCard({super.key, required this.summary, this.compact = false});

  final ProjectSummary summary;

  /// Phone layout: no hover, the menu opens as a sheet.
  final bool compact;

  /// How tall the text under the thumbnail is.
  static double footerHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(38) + 46;

  @override
  ConsumerState<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<ProjectCard> {
  bool _hover = false;
  bool _down = false;
  double? _scrub;
  final _moreKey = GlobalKey();

  ProjectSummary get summary => widget.summary;

  void _open() => openLibraryProject(ref, context, summary.path);

  @override
  Widget build(BuildContext context) {
    final lifted = _hover && !widget.compact;
    final r = BorderRadius.circular(CutRadii.lg);
    final wash = ref.watch(_cardTintProvider(summary.path));
    return Semantics(
      button: true,
      label: 'Open ${summary.name}',
      child: MouseRegion(
        key: Key('project-${p.basename(summary.path)}'),
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _down = false;
          _scrub = null;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: _open,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() => _down = false);
            _showSheet();
          },
          onSecondaryTapUp: widget.compact
              ? null
              : (d) => _showMenu(d.globalPosition),
          child: AnimatedScale(
            scale: _down ? 0.98 : 1,
            duration: _down ? CutMotion.instant : CutMotion.normal,
            curve: _down ? Curves.linear : Curves.easeOutBack,
            child: AnimatedContainer(
              duration: CutMotion.normal,
              curve: CutMotion.standard,
              transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
              decoration: BoxDecoration(
                color: lifted ? Cut.surface3 : Cut.surface2,
                borderRadius: r,
                border: Border.all(
                  color: lifted ? Cut.strokeDefault : Cut.strokeSubtle,
                ),
                boxShadow: lifted ? CutShadows.e2 : CutShadows.e1,
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: r,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0FFFFFFF), Color(0x00FFFFFF)],
                  stops: [0, 0.2],
                ),
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  children: [
                    // The thumbnail's colour, washed faintly behind the
                    // text (Spotify-style).
                    if (wash != null)
                      Positioned(
                        left: -40,
                        right: -40,
                        bottom: -90,
                        height: 200,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  wash.withValues(alpha: lifted ? 0.16 : 0.10),
                                  wash.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _thumbnailArea(lifted),
                        ),
                        Expanded(child: _footer(lifted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnailArea(bool lifted) => LayoutBuilder(
    builder: (context, box) => MouseRegion(
      onHover: widget.compact
          ? null
          : (e) => setState(
              () => _scrub = (e.localPosition.dx / box.maxWidth).clamp(0, 1),
            ),
      onExit: (_) => setState(() => _scrub = null),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProjectThumbnail(summary: summary, scrub: _scrub),
          // A soft shade at the bottom so the chip reads on any frame.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x59000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: lifted ? 1 : 0,
              duration: CutMotion.fast,
              child: AnimatedScale(
                scale: lifted ? 1 : 0.85,
                duration: CutMotion.normal,
                curve: CutMotion.decelerate,
                child: const GlassPanel(
                  radius: CutRadii.pill,
                  blur: 12,
                  padding: EdgeInsets.all(12),
                  child: Icon(CutIcons.play, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
          if (summary.duration > Duration.zero)
            Positioned(
              right: 8,
              bottom: 8,
              child: _DurationChip(summary.duration),
            ),
          if (_scrub case final s?)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: s,
                child: const ColoredBox(color: Cut.marker),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _footer(bool lifted) {
    final res = _resolution(summary.project);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              height: 8,
              child: EditFingerprint(project: summary.project),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        summary.name.isEmpty ? 'Untitled' : summary.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.titleSm.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Edited ${_lower(timeAgo(summary.modified))}',
                          ?res,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CutType.caption.copyWith(
                          color: Cut.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: lifted || widget.compact ? 1 : 0,
                  duration: CutMotion.fast,
                  child: CutIconButton(
                    key: _moreKey,
                    icon: CutIcons.more,
                    tooltip: 'More',
                    size: widget.compact ? 36 : 28,
                    onPressed: () {
                      if (widget.compact) {
                        _showSheet();
                      } else {
                        final box =
                            _moreKey.currentContext!.findRenderObject()!
                                as RenderBox;
                        _showMenu(
                          box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final inLibrary = await _inLibrary();
    if (!mounted) return;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        _item('open', CutIcons.playCircle, 'Open'),
        _item('rename', CutIcons.rename, 'Rename…'),
        _item('duplicate', CutIcons.duplicate, 'Duplicate'),
        const PopupMenuDivider(),
        _item(
          'delete',
          CutIcons.trash,
          inLibrary ? 'Delete' : 'Remove from this list',
          danger: true,
        ),
      ],
    );
    if (action != null) await _act(action, inLibrary);
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
  }) => PopupMenuItem(
    value: value,
    height: 36,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? Cut.error : Cut.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: CutType.label.copyWith(
            fontSize: 14,
            color: danger ? Cut.error : Cut.textPrimary,
          ),
        ),
      ],
    ),
  );

  Future<void> _showSheet() async {
    final inLibrary = await _inLibrary();
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(CutRadii.sm),
                    child: SizedBox(
                      width: 96,
                      height: 54,
                      child: ProjectThumbnail(summary: summary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.name.isEmpty ? 'Untitled' : summary.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CutType.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Edited ${_lower(timeAgo(summary.modified))}',
                          style: CutType.caption.copyWith(
                            color: Cut.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SheetAction(CutIcons.rename, 'Rename', 'rename'),
              _SheetAction(CutIcons.duplicate, 'Duplicate', 'duplicate'),
              _SheetAction(
                CutIcons.trash,
                inLibrary ? 'Delete' : 'Remove from this list',
                'delete',
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
    if (action != null) await _act(action, inLibrary);
  }

  Future<bool> _inLibrary() async =>
      (await ref.read(projectLibraryProvider.future)).contains(summary.path);

  Future<void> _act(String action, bool inLibrary) async {
    switch (action) {
      case 'open':
        _open();
      case 'rename':
        final name = await askEditName(context, summary.name);
        if (name == null || name.isEmpty || name == summary.name) return;
        await const ProjectStore().save(
          summary.project.copyWith(name: name),
          summary.path,
        );
        ref.invalidate(projectListProvider);
      case 'duplicate':
        await duplicateProject(ref, summary);
      case 'delete':
        if (!mounted) return;
        deleteWithUndo(context, ref, summary, inLibrary: inLibrary);
    }
  }
}

/// Hides an edit and offers Undo for a few seconds; deletes it (or forgets
/// it, for one saved elsewhere) once the offer is gone.
void deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  ProjectSummary summary, {
  required bool inLibrary,
}) {
  final path = summary.path;
  pendingDeletes.value = {...pendingDeletes.value, path};
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final name = summary.name.isEmpty ? 'Untitled' : summary.name;
  final bar = messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(inLibrary ? 'Deleted "$name"' : 'Removed "$name"'),
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    ),
  );
  unawaited(
    bar.closed.then((reason) async {
      if (reason != SnackBarClosedReason.action) {
        try {
          (await ref.read(projectLibraryProvider.future)).delete(path);
        } on Object {
          // Already gone, or the disk said no; it shows again if so.
        }
        ref.invalidate(projectListProvider);
      }
      pendingDeletes.value = {...pendingDeletes.value}..remove(path);
    }),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction(this.icon, this.label, this.value, {this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Cut.error : Cut.textPrimary;
    return ListTile(
      minTileHeight: 52,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CutRadii.md),
      ),
      leading: Icon(icon, size: 22, color: danger ? Cut.error : null),
      title: Text(label, style: CutType.bodyStrong.copyWith(color: color)),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

Future<String?> askEditName(BuildContext context, String current) async {
  final controller = TextEditingController(text: current);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: current.length,
  );
  final name = await showDialog<String>(
    context: context,
    builder: (context) => CutDialog(
      title: 'Rename edit',
      icon: CutIcons.rename,
      width: 440,
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
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
    ),
  );
  controller.dispose();
  return name;
}

String _lower(String s) => s.isEmpty || s.startsWith(RegExp('[0-9]'))
    ? s
    : s[0].toLowerCase() + s.substring(1);

String? _resolution(Project project) {
  final video = project.media
      .where((m) => m.kind == MediaKind.video && m.title == null)
      .where((m) => m.width > 0 && m.height > 0)
      .firstOrNull;
  if (video == null) return null;
  final short = math.min(video.width, video.height);
  return short >= 2160 ? '4K' : '${short}p';
}

class _DurationChip extends StatelessWidget {
  const _DurationChip(this.duration);

  final Duration duration;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xB30B0A10),
      borderRadius: BorderRadius.circular(CutRadii.xs),
      border: Border.all(color: Cut.strokeSubtle),
    ),
    child: TimecodeText(
      formatPlayerTime(duration).split('.').first,
      style: CutType.timecode.copyWith(fontSize: 11, height: 1.2),
      color: Cut.textPrimary,
    ),
  );
}

/// The non-intro clips of [project], each with where it starts.
List<(VideoClip, Duration)> _realClips(Project project) {
  final starts = project.clipStarts;
  return [
    for (final (i, c) in project.clips.indexed)
      if (project.mediaById(c.mediaId)?.title == null) (c, starts[i]),
  ];
}

/// A frame from the edit: by default one second into its first real clip;
/// with [scrub] (0–1) the frame that far through the edit. Edits made from
/// pictures show their first picture.
class ProjectThumbnail extends ConsumerWidget {
  const ProjectThumbnail({super.key, required this.summary, this.scrub});

  final ProjectSummary summary;
  final double? scrub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = summary.project;
    final clips = _realClips(project);
    ui.Image? image;
    if (clips.isNotEmpty) {
      var (clip, _) = clips.first;
      var at = clip.sourceStart + const Duration(seconds: 1);
      if (scrub case final s?) {
        final total = clips.fold(Duration.zero, (t, c) => t + c.$1.duration);
        var left = total * s;
        for (final (c, _) in clips) {
          clip = c;
          if (left <= c.duration) break;
          left -= c.duration;
        }
        at = clip.sourceStart + (left > clip.duration ? clip.duration : left);
      }
      final media = project.mediaById(clip.mediaId);
      if (media != null) {
        image = ref
            .watch(
              mediaPreviewProvider(
                ProjectStore.resolve(media.path, summary.path),
              ),
            )
            .value
            ?.thumbnailAt(at);
      }
    }
    if (image != null) {
      return ColoredBox(
        color: Cut.canvas,
        child: RawImage(image: image, fit: BoxFit.cover),
      );
    }
    final picture = project.media
        .where((m) => m.kind == MediaKind.image)
        .firstOrNull;
    if (picture != null) {
      final file = File(ProjectStore.resolve(picture.path, summary.path));
      if (file.existsSync()) {
        return ColoredBox(
          color: Cut.canvas,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 640,
            errorBuilder: (_, _, _) => _Placeholder(summary.name),
          ),
        );
      }
    }
    return _Placeholder(summary.name);
  }
}

/// No frame yet: a quiet gradient tinted by the name, with a film icon.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = (name.hashCode % 360).toDouble().abs();
    final tint = HSLColor.fromAHSL(1, hue, 0.45, 0.22).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(Cut.surface1, tint, 0.55)!, Cut.canvas],
        ),
      ),
      child: Center(
        child: Icon(
          CutIcons.film,
          size: 32,
          color: Cut.textPrimary.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

/// A card's tint: the average colour of its resting thumbnail, pushed to a
/// pleasant saturation. Null until the thumbnail is ready.
final _cardTintProvider = Provider.family<Color?, String>((ref, path) {
  final summary = ref
      .watch(projectListProvider)
      .value
      ?.where((s) => s.path == path)
      .firstOrNull;
  if (summary == null) return null;
  final clips = _realClips(summary.project);
  if (clips.isEmpty) return null;
  final (clip, _) = clips.first;
  final media = summary.project.mediaById(clip.mediaId);
  if (media == null) return null;
  final image = ref
      .watch(
        mediaPreviewProvider(ProjectStore.resolve(media.path, summary.path)),
      )
      .value
      ?.thumbnailAt(clip.sourceStart + const Duration(seconds: 1));
  if (image == null) return null;
  final known = _tints[image];
  if (known != null) return known;
  unawaited(
    _averageColor(image).then((c) {
      if (c == null) return;
      _tints[image] = c;
      ref.invalidateSelf();
    }),
  );
  return null;
});

final _tints = Expando<Color>('card tint');

Future<Color?> _averageColor(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  final pixels = data.lengthInBytes ~/ 4;
  final step = math.max(1, pixels ~/ 2000);
  var r = 0.0, g = 0.0, b = 0.0, weight = 0.0;
  for (var i = 0; i < pixels; i += step) {
    final o = i * 4;
    final pr = data.getUint8(o), pg = data.getUint8(o + 1);
    final pb = data.getUint8(o + 2);
    // Colourful pixels count more than grey ones.
    final w =
        1 + (math.max(pr, math.max(pg, pb)) - math.min(pr, math.min(pg, pb)));
    r += pr * w;
    g += pg * w;
    b += pb * w;
    weight += w;
  }
  if (weight == 0) return null;
  final avg = Color.fromARGB(
    255,
    (r / weight).round(),
    (g / weight).round(),
    (b / weight).round(),
  );
  final hsl = HSLColor.fromColor(avg);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 0.9))
      .withLightness(0.58)
      .toColor();
}

/// A tiny picture of the edit: clips as segments (gaps are cuts), intros in
/// the title colour, and ticks where memes, titles and sounds sit.
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
    final bar = Rect.fromLTWH(0, size.height - 3, size.width, 3);
    if (total <= 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = Cut.strokeDefault,
      );
      return;
    }
    double x(Duration t) => t.inMicroseconds / total * size.width;
    final starts = project.clipStarts;
    for (var i = 0; i < project.clips.length; i++) {
      final c = project.clips[i];
      final intro = project.mediaById(c.mediaId)?.title != null;
      final left = x(starts[i]) + (i == 0 ? 0 : 1.5);
      final right =
          x(starts[i] + c.duration) - (i == project.clips.length - 1 ? 0 : 1.5);
      if (right <= left) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, bar.top, right, bar.bottom),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = (intro ? Cut.trackTitle : Cut.trackVideo).withValues(
            alpha: 0.8,
          ),
      );
    }
    void ticks(Iterable<Duration> at, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final m in at) {
        final mx = x(m).clamp(1.0, size.width - 1);
        canvas.drawLine(Offset(mx, 1), Offset(mx, bar.top - 2), paint);
      }
    }

    ticks([for (final o in project.overlays) o.start], Cut.trackOverlay);
    ticks([for (final t in project.titles) t.start], Cut.trackTitle);
    ticks([for (final a in project.audio) a.start], Cut.trackVoice);
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
