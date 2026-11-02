import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../ai/api_key_store.dart';
import '../ai/assistant_client.dart';
import '../editing/project_editor.dart';
import '../media/ffmpeg.dart';
import '../settings/preferences.dart';
import '../transcript/transcription_service.dart';
import '../ui/import_actions.dart';
import '../ui/settings_dialog.dart';
import '../ui/splash_screen.dart';

/// The first-run guide: connect the assistant, get the speech model, try
/// an edit. Shown once on first launch, and from Help → Getting Started.
Future<void> showOnboarding(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const OnboardingDialog(),
);

/// Shows the guide on first launch.
class FirstRunGuide extends ConsumerStatefulWidget {
  const FirstRunGuide({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstRunGuide> createState() => _FirstRunGuideState();
}

class _FirstRunGuideState extends ConsumerState<FirstRunGuide> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    ref.read(preferencesProvider.future).then((prefs) {
      if (!prefs.onboarded && mounted) showOnboarding(context);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  double? _download;
  String? _downloadError;
  bool _modelReady = false;
  bool _sampleBusy = false;

  @override
  void initState() {
    super.initState();
    ref.read(speechEngineProvider.future).then((e) {
      if (mounted) setState(() => _modelReady = e.modelReady);
    }, onError: (_) {});
  }

  Future<void> _downloadModel() async {
    setState(() {
      _download = 0;
      _downloadError = null;
    });
    try {
      final engine = await ref.read(speechEngineProvider.future);
      await engine.downloadModel((v) {
        if (mounted) setState(() => _download = v);
      });
      if (mounted) setState(() => _modelReady = true);
    } on Exception catch (e) {
      if (mounted) setState(() => _downloadError = '$e');
    } finally {
      if (mounted) setState(() => _download = null);
    }
  }

  /// Makes a 20-second test video (colour bars and a tone) and imports it,
  /// so there's something to try an edit on.
  Future<void> _openSample() async {
    final ffmpeg = const FfmpegLocator().find();
    if (ffmpeg == null) return;
    setState(() => _sampleBusy = true);
    final dir = await ref.read(supportDirProvider.future);
    final path = p.join(dir, 'Sample video.mp4');
    if (!File(path).existsSync()) {
      final encoder = Platform.isMacOS ? 'h264_videotoolbox' : 'mpeg4';
      await Process.run(ffmpeg, [
        '-loglevel',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=1280x720:rate=30:duration=20',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=20',
        '-c:v',
        encoder,
        '-b:v',
        '4M',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        path,
      ]);
    }
    if (!mounted) return;
    setState(() => _sampleBusy = false);
    if (ref.read(projectEditorProvider).project.clips.isEmpty) {
      await importVideos(ref, context, [path]);
    }
    await _finish();
  }

  Future<void> _finish() async {
    try {
      final prefs = await ref.read(preferencesProvider.future);
      await ref
          .read(preferencesProvider.notifier)
          .save(prefs.copyWith(onboarded: true));
    } on Object {
      // Not remembering only means the guide shows again next time.
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(apiKeyProvider).value != null;
    final provider =
        ref.watch(preferencesProvider).value?.provider ?? AiProvider.groq;
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('onboarding'),
      scrollable: true,
      title: Row(
        children: [
          const CutlineLogo(size: 36),
          const SizedBox(width: 12),
          Text('Welcome to Cutline', style: theme.textTheme.titleLarge),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Three quick steps and you can edit by telling Cutline what '
              'you want.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _Step(
              number: 1,
              done: hasKey,
              title: 'Connect the assistant',
              body: provider == AiProvider.groq
                  ? 'Groq is free. Make a key at console.groq.com/keys and '
                        'paste it in Settings.'
                  : 'Paste your ${provider.label} key in Settings.',
              actions: [
                if (provider == AiProvider.groq)
                  TextButton(
                    onPressed: () =>
                        launchUrl(Uri.parse('https://console.groq.com/keys')),
                    child: const Text('Get a free key'),
                  ),
                FilledButton.tonal(
                  key: const Key('onboarding-settings'),
                  onPressed: () => showSettings(context),
                  child: Text(hasKey ? 'Change key' : 'Add key'),
                ),
              ],
            ),
            _Step(
              number: 2,
              done: _modelReady,
              title: 'Get the speech model',
              body:
                  'So Cutline can find moments by what you say. It runs on '
                  'your computer; 148 MB, downloaded once.',
              detail: _downloadError,
              progress: _download,
              actions: [
                if (!_modelReady)
                  FilledButton.tonal(
                    key: const Key('onboarding-model'),
                    onPressed: _download == null ? _downloadModel : null,
                    child: const Text('Download'),
                  ),
              ],
            ),
            _Step(
              number: 3,
              done: false,
              title: 'Try an edit',
              body:
                  'Import one of your videos, or open a sample. Then type '
                  'something like "Cut the first 5 seconds" in the '
                  'assistant on the right.',
              actions: [
                FilledButton.tonal(
                  key: const Key('onboarding-sample'),
                  onPressed: _sampleBusy ? null : _openSample,
                  child: Text(_sampleBusy ? 'Making it…' : 'Open a sample'),
                ),
                FilledButton(
                  key: const Key('onboarding-import'),
                  onPressed: () async {
                    await _finish();
                    if (context.mounted) {
                      await pickAndImportVideos(ref, context);
                    }
                  },
                  child: const Text('Import my video'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('onboarding-done'),
          onPressed: _finish,
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.done,
    required this.title,
    required this.body,
    this.actions = const [],
    this.progress,
    this.detail,
  });

  final int number;
  final bool done;
  final String title;
  final String body;
  final List<Widget> actions;
  final double? progress;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: done
                ? colors.primary
                : colors.surfaceContainerHighest,
            child: done
                ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                : Text('$number', style: text.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: text.bodySmall),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(value: progress),
                  ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(detail!, style: TextStyle(color: colors.error)),
                  ),
                if (actions.isNotEmpty && !done)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, runSpacing: 6, children: actions),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
