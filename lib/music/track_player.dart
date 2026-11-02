import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

/// Plays one track at a time to try it out, e.g. from the music cards in
/// the chat. The state is the id of the track playing, or null.
class TrackPlayer extends Notifier<String?> {
  Player? _player;
  StreamSubscription<bool>? _done;

  @override
  String? build() {
    ref.onDispose(() {
      unawaited(_done?.cancel());
      unawaited(_player?.dispose());
    });
    return null;
  }

  Future<void> toggle(String id, String source) async {
    if (state == id) return stop();
    final player = _player ??= Player(
      configuration: const PlayerConfiguration(vo: 'null'),
    );
    _done ??= player.stream.completed.listen((done) {
      if (done) state = null;
    });
    state = id;
    await player.open(Media(source));
  }

  Future<void> stop() async {
    state = null;
    await _player?.stop();
  }
}

final trackPlayerProvider = NotifierProvider<TrackPlayer, String?>(
  TrackPlayer.new,
);
