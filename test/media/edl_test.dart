import 'package:cutline/media/edl.dart';
import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures.dart';

void main() {
  test('empty project has no EDL', () {
    expect(buildEdl(const Project()), isNull);
  });

  test('one entry per clip, in timeline order', () {
    expect(
      buildEdl(threeClips()),
      'edl://%16%/videos/talk.mp4,start=0.000000,length=10.000000;'
      '%16%/videos/talk.mp4,start=20.000000,length=20.000000;'
      '%16%/videos/talk.mp4,start=50.000000,length=10.000000',
    );
  });

  test('length prefix counts bytes, so commas and non-ASCII names work', () {
    const path = '/v/café, take 2.mp4';
    final p = Project(
      media: const [MediaAsset(id: 'm', path: path, kind: MediaKind.video)],
      clips: [
        VideoClip(id: 'c', mediaId: 'm', sourceStart: s(0), sourceEnd: s(1)),
      ],
    );
    // "é" is 2 bytes in UTF-8, so 19 characters are 20 bytes.
    expect(buildEdl(p), startsWith('edl://%20%$path,'));
  });

  test('project-relative paths resolve against the project folder', () {
    final p = Project(
      media: const [
        MediaAsset(id: 'm', path: 'assets/rec.mp4', kind: MediaKind.video),
      ],
      clips: [
        VideoClip(id: 'c', mediaId: 'm', sourceStart: s(0), sourceEnd: s(1)),
      ],
    );
    expect(
      buildEdl(p, projectPath: '/p/X.cutline'),
      contains('/p/X.cutline/assets/rec.mp4'),
    );
  });
}
