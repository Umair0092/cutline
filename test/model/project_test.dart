import 'dart:convert';

import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  test('duration and clip starts follow the main track', () {
    final p = threeClips();
    expect(p.duration, s(40));
    expect(p.clipStarts, [s(0), s(10), s(30)]);
  });

  test('clipAt maps timeline time to source time', () {
    final p = threeClips();
    expect(p.clipAt(s(5)), (index: 0, sourceTime: s(5)));
    expect(p.clipAt(s(10)), (index: 1, sourceTime: s(20)));
    expect(p.clipAt(s(35)), (index: 2, sourceTime: s(55)));
    expect(p.clipAt(s(40)), isNull);
  });

  test('round-trips through JSON', () {
    final p = threeClips().copyWith(
      name: 'Talk',
      overlays: [
        OverlayItem(
          id: 'o1',
          mediaId: 'm1',
          start: s(3),
          duration: s(2),
          transform: const OverlayTransform(x: 0.8, y: 0.8, scale: 0.2),
        ),
      ],
      audio: [
        AudioItem(
          id: 'v1',
          mediaId: 'm1',
          role: AudioRole.voiceover,
          start: s(1),
          sourceStart: s(0),
          sourceEnd: s(4),
        ),
      ],
    );
    final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
    expect(Project.fromJson(json), p);
  });

  test('times are stored as whole microseconds', () {
    final json = threeClips().toJson();
    final clips = json['clips'] as List<dynamic>;
    expect((clips.first as Map<String, dynamic>)['sourceEnd'], 10000000);
  });
}
