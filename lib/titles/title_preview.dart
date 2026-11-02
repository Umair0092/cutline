import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../model/title_item.dart';
import '../preview/playhead_clock.dart';
import '../preview/preview_controller.dart';
import 'templates.dart';
import 'title_images.dart';

/// Paints one title at local time [t] (seconds).
class TitlePainter extends CustomPainter {
  TitlePainter(this.spec, this.t, {this.projectPath})
    : super(repaint: TitleImages.instance);

  final TitleSpec spec;
  final double t;

  /// Where image fields' relative paths are found.
  final String? projectPath;

  @override
  void paint(Canvas canvas, Size size) {
    final template = templateById(spec.templateId);
    if (template == null) return;
    canvas.clipRect(Offset.zero & size);
    template.paint(
      canvas,
      size,
      t,
      spec.duration.inMicroseconds / 1e6,
      titleValues(spec, projectPath),
    );
  }

  @override
  bool shouldRepaint(TitlePainter old) =>
      old.spec != spec || old.t != t || old.projectPath != projectPath;
}

/// Draws the titles that are on screen at the playhead, over the video.
class TitleLayer extends ConsumerStatefulWidget {
  const TitleLayer({super.key});

  @override
  ConsumerState<TitleLayer> createState() => _TitleLayerState();
}

class _TitleLayerState extends ConsumerState<TitleLayer>
    with SingleTickerProviderStateMixin {
  late final PlayheadClock _clock = PlayheadClock(
    ref.read(previewProvider),
    this,
  );

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ref.watch(
      projectEditorProvider.select((s) => s.project.titles),
    );
    final workPath = ref.watch(projectEditorProvider.select((s) => s.workPath));
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: _clock,
        builder: (context, _) {
          final now = _clock.now;
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final TitleItem title in titles)
                if (now >= title.start && now < title.end)
                  CustomPaint(
                    key: Key('title-${title.id}'),
                    painter: TitlePainter(
                      title.spec,
                      (now - title.start).inMicroseconds / 1e6,
                      projectPath: workPath,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
