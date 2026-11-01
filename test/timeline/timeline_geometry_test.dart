import 'package:cutline/timeline/timeline_geometry.dart';
import 'package:cutline/timeline/timeline_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  // Clips: a 0–10s, b 10–30s, c 30–40s on the timeline.
  // At 10 px/s with 16 px padding: a 16–116, b 116–316, c 316–416.
  final g = TimelineGeometry(project: threeClips(), pixelsPerSecond: 10);

  test('time and x convert both ways', () {
    expect(g.xOf(s(0)), 16);
    expect(g.xOf(s(10)), 116);
    expect(g.timeAt(116), s(10));
    expect(g.timeAt(0), Duration.zero, reason: 'clamped at 0');
  });

  test('hitClip finds edges and bodies', () {
    expect(g.hitClip(18), (index: 0, zone: ClipZone.leftEdge));
    expect(g.hitClip(60), (index: 0, zone: ClipZone.body));
    expect(g.hitClip(112), (index: 0, zone: ClipZone.rightEdge));
    expect(g.hitClip(200), (index: 1, zone: ClipZone.body));
    expect(g.hitClip(500), isNull);
  });

  test('snap pulls within 8 px, otherwise leaves the time alone', () {
    expect(g.snap(s(10.5), [s(10)]), s(10), reason: '5 px away');
    expect(g.snap(s(12), [s(10)]), s(12), reason: '20 px away');
    expect(g.snap(s(10.5), [s(9.9), s(10.4)]), s(10.4), reason: 'nearest');
  });

  test('dropIndex uses clip midpoints', () {
    // Dragging c (index 2): before a's middle -> slot 0, after b's -> 2.
    expect(g.dropIndex(30, 2), 0);
    expect(g.dropIndex(150, 2), 1);
    expect(g.dropIndex(250, 2), 2);
  });

  group('trim drags', () {
    test('right edge changes the end, clamped to the source', () {
      var r = trimResult(
        threeClips(),
        TrimDrag(index: 0, left: false, edgeTime: s(8)),
      );
      expect((r.sourceStart, r.sourceEnd), (s(0), s(8)));

      // Clip c plays 50–60s of a 60s file; it can't grow past 60s.
      r = trimResult(
        threeClips(),
        TrimDrag(index: 2, left: false, edgeTime: s(45)),
      );
      expect(r.sourceEnd, s(60));
    });

    test('left edge can reveal earlier footage but not before 0', () {
      // Clip b starts at 10s on the timeline and plays from 20s.
      var r = trimResult(
        threeClips(),
        TrimDrag(index: 1, left: true, edgeTime: s(5)),
      );
      expect(r.sourceStart, s(15));
      r = trimResult(
        threeClips(),
        TrimDrag(index: 0, left: true, edgeTime: Duration.zero),
      );
      expect(r.sourceStart, s(0));
    });

    test('never shorter than the minimum clip length', () {
      final r = trimResult(
        threeClips(),
        TrimDrag(index: 0, left: false, edgeTime: s(0)),
      );
      expect(r.sourceEnd - r.sourceStart, const Duration(milliseconds: 100));
    });
  });

  test('layout follows a left trim, leaving later clips in place', () {
    final boxes = layoutClips(
      g,
      drag: TrimDrag(index: 1, left: true, edgeTime: s(15)),
    );
    expect(boxes[1].left, 166, reason: 'edge follows the pointer');
    expect(boxes[1].right, 316);
    expect(boxes[2].left, 316);
  });

  test('layout adds a floating copy for a move drag', () {
    final boxes = layoutClips(
      g,
      drag: const MoveDrag(index: 0, dx: 50, x: 100),
    );
    expect(boxes, hasLength(4));
    expect(boxes.last.floating, isTrue);
    expect(boxes.last.left, 66);
  });
}
