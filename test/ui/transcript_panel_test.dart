import 'dart:io';

import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:cutline/transcript/transcript.dart';
import 'package:cutline/transcript/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../transcript/transcript_test.dart' show realTranscript, speechProject;
import '../transcript/transcription_service_test.dart' show FakeEngine;

void main() {
  testWidgets('transcript tab: download button, then lines you can click', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final support = Directory.systemTemp.createTempSync('cutline_ui');
    addTearDown(() => support.deleteSync(recursive: true));
    final engine = _RealTextEngine();
    final preview = FakePreviewController();
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        previewProvider.overrideWithValue(preview),
        supportDirProvider.overrideWith((_) async => support.path),
        speechEngineProvider.overrideWith((_) async => engine),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(projectEditorProvider.notifier)
        .opened(speechProject(), '/p');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('tab-transcript')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Download Model & Transcribe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transcribe')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(engine.downloads, 1);
    expect(find.textContaining('um, let me restart,'), findsOneWidget);

    await tester.tap(find.textContaining('um, let me restart,'));
    await tester.pump();
    expect(preview.position, const Duration(milliseconds: 4230));
  });
}

/// Returns the real whisper output for the speech sample.
class _RealTextEngine extends FakeEngine {
  @override
  Future<Transcript> transcribe(String path, void Function(double) p) async =>
      realTranscript();
}
