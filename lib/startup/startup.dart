import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/api_key_store.dart';
import '../media/ffmpeg.dart';
import '../settings/preferences.dart';
import '../transcript/whisper.dart';

class StartupState {
  const StartupState({
    this.progress = 0,
    this.message = 'Starting…',
    this.done = false,
    this.warnings = const [],
  });

  final double progress;
  final String message;
  final bool done;

  /// Problems worth telling the user about once the editor is open.
  final List<String> warnings;
}

/// One thing to get ready before the editor opens. Returns a warning to show
/// the user, or null if all is well.
typedef StartupTask = ({String label, Future<String?> Function(Ref ref) run});

/// Loads settings and the API key and checks the bundled tools.
final List<StartupTask> defaultStartupTasks = [
  (
    label: 'Loading your settings',
    run: (ref) async {
      await ref.read(preferencesProvider.future);
      return null;
    },
  ),
  (
    label: 'Checking your API key',
    run: (ref) async {
      await ref.read(apiKeyProvider.future);
      return null;
    },
  ),
  (
    label: 'Checking video tools',
    run: (ref) async {
      final missing = [
        if (const FfmpegLocator().find() == null) 'FFmpeg (export)',
        if (findWhisper() == null) 'whisper (transcripts)',
      ];
      return missing.isEmpty
          ? null
          : 'Missing ${missing.join(' and ')}. Those features won\'t work.';
    },
  ),
];

/// Tasks and how long the splash shows at least. Tests override these.
final startupTasksProvider = Provider<List<StartupTask>>(
  (_) => defaultStartupTasks,
);
final splashMinimumProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 1200),
);

final startupProvider = NotifierProvider<StartupController, StartupState>(
  StartupController.new,
);

class StartupController extends Notifier<StartupState> {
  @override
  StartupState build() {
    unawaited(_run());
    return const StartupState();
  }

  Future<void> _run() async {
    // Let build() return first: state set while building would be lost.
    await Future<void>.value();
    final tasks = ref.read(startupTasksProvider);
    final minimum = ref.read(splashMinimumProvider);
    final watch = Stopwatch()..start();
    final warnings = <String>[];

    for (var i = 0; i < tasks.length; i++) {
      state = StartupState(
        progress: i / tasks.length,
        message: '${tasks[i].label}…',
        warnings: warnings,
      );
      try {
        // A slow disk or keychain must never keep the app from opening.
        final warning = await tasks[i]
            .run(ref)
            .timeout(const Duration(seconds: 5));
        if (warning != null) warnings.add(warning);
      } on Object {
        // Each feature reports its own problems later, where it's used.
      }
    }

    state = StartupState(progress: 1, message: 'Ready', warnings: warnings);
    final left = minimum - watch.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
    state = StartupState(
      progress: 1,
      message: 'Ready',
      done: true,
      warnings: warnings,
    );
  }
}
