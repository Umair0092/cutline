import 'package:cutline/model/media_asset.dart';
import 'package:cutline/model/project.dart';
import 'package:cutline/model/video_clip.dart';

Duration s(num seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

const video = MediaAsset(
  id: 'm1',
  path: '/videos/talk.mp4',
  kind: MediaKind.video,
  duration: Duration(seconds: 60),
  width: 1920,
  height: 1080,
  hasAudio: true,
);

/// A 60s source split into three clips: 0–10, 20–40, 50–60 (40s total).
Project threeClips() => Project(
  media: const [video],
  clips: [
    VideoClip(id: 'a', mediaId: 'm1', sourceStart: s(0), sourceEnd: s(10)),
    VideoClip(id: 'b', mediaId: 'm1', sourceStart: s(20), sourceEnd: s(40)),
    VideoClip(id: 'c', mediaId: 'm1', sourceStart: s(50), sourceEnd: s(60)),
  ],
);
