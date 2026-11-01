import 'package:cutline/editing/commands.dart';
import 'package:cutline/editing/edit_command.dart';
import 'package:cutline/model/audio_item.dart';
import 'package:cutline/model/overlay_item.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

List<(Duration, Duration)> ranges(List<VideoClip> clips) => [
  for (final c in clips) (c.sourceStart, c.sourceEnd),
];

void main() {
  group('SplitAt', () {
    test('splits the clip under the playhead', () {
      final p = SplitAt(s(15), newClipId: 'b2').apply(threeClips());
      expect(p.clips.map((c) => c.id), ['a', 'b', 'b2', 'c']);
      expect(ranges(p.clips).sublist(1, 3), [(s(20), s(25)), (s(25), s(40))]);
      expect(p.duration, s(40));
    });

    test('refuses to split right on a cut or past the end', () {
      expect(
        () => SplitAt(s(10)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
      expect(
        () => SplitAt(s(41)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
    });
  });

  group('TrimClip', () {
    test('moves one edge', () {
      final p = const TrimClip(
        'b',
        sourceEnd: Duration(seconds: 30),
      ).apply(threeClips());
      expect(ranges(p.clips)[1], (s(20), s(30)));
      expect(p.duration, s(30));
    });

    test('cannot go past the source or make a tiny clip', () {
      expect(
        () => TrimClip('c', sourceEnd: s(61)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
      expect(
        () => TrimClip('a', sourceEnd: s(0.05)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
    });
  });

  test('inserting a clip moves later overlays and audio along', () {
    final p =
        AddClip(
          VideoClip(id: 'x', mediaId: 'm1', sourceStart: s(0), sourceEnd: s(3)),
          index: 1,
        ).apply(
          threeClips().copyWith(
            overlays: [
              OverlayItem(
                id: 'early',
                mediaId: 'm1',
                start: s(2),
                duration: s(1),
              ),
              OverlayItem(
                id: 'late',
                mediaId: 'm1',
                start: s(15),
                duration: s(1),
              ),
            ],
          ),
        );
    expect(
      {for (final o in p.overlays) o.id: o.start},
      {'early': s(2), 'late': s(18)},
    );
  });

  test('RemoveClip and MoveClip', () {
    var p = const RemoveClip('b').apply(threeClips());
    expect(p.clips.map((c) => c.id), ['a', 'c']);
    p = const MoveClip('c', 0).apply(p);
    expect(p.clips.map((c) => c.id), ['c', 'a']);
    expect(
      () => const RemoveClip('zzz').apply(p),
      throwsA(isA<EditException>()),
    );
  });

  group('RemoveRange', () {
    test('cuts inside one clip', () {
      final p = RemoveRange(s(2), s(4)).apply(threeClips());
      expect(ranges(p.clips), [
        (s(0), s(2)),
        (s(4), s(10)),
        (s(20), s(40)),
        (s(50), s(60)),
      ]);
      expect(p.duration, s(38));
      expect(p.clips[0].id, 'a');
      expect(p.clips[1].id, isNot('a'));
    });

    test('cuts across clips', () {
      // Timeline 5..35 covers the end of a, all of b and the start of c.
      final p = RemoveRange(s(5), s(35)).apply(threeClips());
      expect(ranges(p.clips), [(s(0), s(5)), (s(55), s(60))]);
      expect(p.duration, s(10));
    });

    test('shifts overlays and audio after the cut, drops ones inside it', () {
      final p = RemoveRange(s(10), s(30)).apply(
        threeClips().copyWith(
          overlays: [
            OverlayItem(
              id: 'inside',
              mediaId: 'm1',
              start: s(12),
              duration: s(2),
            ),
            OverlayItem(
              id: 'after',
              mediaId: 'm1',
              start: s(32),
              duration: s(2),
            ),
            OverlayItem(
              id: 'before',
              mediaId: 'm1',
              start: s(1),
              duration: s(2),
            ),
          ],
          audio: [
            AudioItem(
              id: 'vo',
              mediaId: 'm1',
              role: AudioRole.voiceover,
              start: s(31),
              sourceStart: s(0),
              sourceEnd: s(3),
            ),
          ],
        ),
      );
      expect(
        {for (final o in p.overlays) o.id: o.start},
        {'after': s(12), 'before': s(1)},
      );
      expect(p.audio.single.start, s(11));
    });

    test('refuses to remove everything or nothing', () {
      expect(
        () => RemoveRange(s(0), s(40)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
      expect(
        () => RemoveRange(s(50), s(55)).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
    });
  });

  group('overlays', () {
    final overlay = OverlayItem(
      id: 'o',
      mediaId: 'm1',
      start: s(5),
      duration: s(3),
    );

    test('add, update and remove', () {
      var p = AddOverlay(overlay).apply(threeClips());
      p = UpdateOverlay(
        'o',
        start: s(6),
        transform: const OverlayTransform(x: 0.9),
      ).apply(p);
      expect(p.overlays.single.start, s(6));
      expect(p.overlays.single.transform.x, 0.9);
      p = const RemoveOverlay('o').apply(p);
      expect(p.overlays, isEmpty);
    });

    test('cannot start after the video ends', () {
      expect(
        () => AddOverlay(overlay.copyWith(start: s(45))).apply(threeClips()),
        throwsA(isA<EditException>()),
      );
    });
  });
}
