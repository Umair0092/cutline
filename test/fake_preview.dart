import 'dart:async';

import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';

class FakePreviewController implements PreviewController {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  @override
  Duration position = Duration.zero;
  @override
  bool isPlaying = false;
  int toggles = 0;

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> togglePlay() async {
    toggles++;
    isPlaying = !isPlaying;
    _playing.add(isPlaying);
  }

  double volume = 1;

  @override
  Future<void> play() async {
    if (!isPlaying) await togglePlay();
  }

  @override
  Future<void> pause() async {
    if (isPlaying) await togglePlay();
  }

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> seek(Duration to) async {
    position = to;
    _position.add(to);
  }

  @override
  Widget buildVideo() =>
      const ColoredBox(key: Key('video'), color: Colors.black);
}
