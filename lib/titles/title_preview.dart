import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../model/title_item.dart';
import '../preview/preview_controller.dart';
import 'templates.dart';

/// Paints one title at local time [t] (seconds).
class TitlePainter extends CustomPainter {
  TitlePainter(this.spec, this.t);

  final TitleSpec spec;
  final double t;

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
      TitleValues(template, spec.fields),
    );
  }

  @override
  bool shouldRepaint(TitlePainter old) => old.spec != spec || old.t != t;
}

/// Draws the titles that are on screen at the playhead, over the video.
/// While playing, time is extrapolated between the player's position
/// updates so animations stay smooth.
class TitleLayer extends ConsumerStatefulWidget {
  const TitleLayer({super.key});

  @override
  ConsumerState<TitleLayer> createState() => _TitleLayerState();
}

class _TitleLayerState extends ConsumerState<TitleLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  Duration _position = Duration.zero;
  final _sincePosition = Stopwatch();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final preview = ref.read(previewProvider);
    _position = preview.position;
    _playing = preview.isPlaying;
    _sincePosition.start();
    _positionSub = preview.positionStream.listen((t) {
      _position = t;
      _sincePosition.reset();
      if (!_playing) setState(() {});
    });
    _playingSub = preview.playingStream.listen((playing) {
      _playing = playing;
      playing ? _ticker.start() : _ticker.stop();
      setState(() {});
    });
    if (_playing) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_positionSub?.cancel());
    unawaited(_playingSub?.cancel());
    super.dispose();
  }

  Duration get _now =>
      _playing ? _position + _sincePosition.elapsed : _position;

  @override
  Widget build(BuildContext context) {
    final titles = ref.watch(
      projectEditorProvider.select((s) => s.project.titles),
    );
    final now = _now;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final TitleItem title in titles)
            if (now >= title.start && now < title.end)
              CustomPaint(
                key: Key('title-${title.id}'),
                painter: TitlePainter(
                  title.spec,
                  (now - title.start).inMicroseconds / 1e6,
                ),
              ),
        ],
      ),
    );
  }
}
