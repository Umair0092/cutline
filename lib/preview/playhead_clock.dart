import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'preview_controller.dart';

/// The playhead time for drawing things over the video. While playing, it
/// moves on every frame between the player's position updates, so
/// animations stay smooth. Notifies listeners whenever [now] changes.
class PlayheadClock extends ChangeNotifier {
  PlayheadClock(PreviewController preview, TickerProvider vsync) {
    _ticker = vsync.createTicker((_) => notifyListeners());
    _position = preview.position;
    _playing = preview.isPlaying;
    _sincePosition.start();
    _positionSub = preview.positionStream.listen((t) {
      _position = t;
      _sincePosition.reset();
      if (!_playing) notifyListeners();
    });
    _playingSub = preview.playingStream.listen((playing) {
      _playing = playing;
      playing ? _ticker.start() : _ticker.stop();
      notifyListeners();
    });
    if (_playing) _ticker.start();
  }

  late final Ticker _ticker;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<bool> _playingSub;
  Duration _position = Duration.zero;
  final _sincePosition = Stopwatch();
  bool _playing = false;

  bool get playing => _playing;

  Duration get now => _playing ? _position + _sincePosition.elapsed : _position;

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_positionSub.cancel());
    unawaited(_playingSub.cancel());
    super.dispose();
  }
}
