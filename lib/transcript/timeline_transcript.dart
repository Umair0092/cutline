import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editing/project_editor.dart';
import '../storage/project_store.dart';
import 'transcript.dart';
import 'transcription_service.dart';

/// Absolute paths of the project's videos that have sound.
List<String> spokenMediaPaths(EditorState state) => [
  for (final m in state.project.media)
    if (m.hasAudio) ProjectStore.resolve(m.path, state.projectPath),
];

/// The transcript lines on the timeline (after cuts) for the open project.
final timelineTranscriptProvider = Provider<List<TranscriptLine>>((ref) {
  final state = ref.watch(projectEditorProvider);
  ref.watch(transcriptsProvider);
  return timelineLines(
    state.project,
    ref.read(transcriptsProvider.notifier).ready,
    projectPath: state.projectPath,
  );
});
