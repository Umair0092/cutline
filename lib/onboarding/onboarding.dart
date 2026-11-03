import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../ai/api_key_store.dart';
import '../ai/assistant_client.dart';
import '../editing/project_editor.dart';
import '../media/ffmpeg.dart';
import '../media/media_probe.dart';
import '../settings/preferences.dart';
import '../transcript/transcription_service.dart';
import '../ui/home/start_actions.dart';
import '../ui/home/wordmark.dart';
import '../ui/import_actions.dart';
import '../ui/navigation.dart';
import '../ui/settings_dialog.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';

/// The first-run guide, in three short steps: what Cutline does, which AI
/// to use, and getting something on the timeline. Shown once on first
/// launch, and again from Help → Getting Started.
Future<void> showOnboarding(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Getting started',
  barrierColor: Cut.scrim,
  transitionDuration: CutMotion.enter,
  pageBuilder: (_, _, _) => const OnboardingDialog(),
  transitionBuilder: (context, animation, _, child) {
    final t = CurvedAnimation(parent: animation, curve: CutMotion.decelerate);
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - t.value) * 8),
          child: Transform.scale(scale: 0.96 + 0.04 * t.value, child: child),
        ),
      ),
    );
  },
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

/// Makes a 20-second test video (colour bars and a tone) once, so there's
/// something to try an edit on. Null when FFmpeg is missing.
Future<String?> makeSampleVideo(WidgetRef ref) async {
  final ffmpeg = const FfmpegLocator().find();
  if (ffmpeg == null) return null;
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
  return File(path).existsSync() ? path : null;
}

class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  static const _steps = 3;
  final _pages = PageController();
  int _step = 0;

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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int step) {
    final to = step.clamp(0, _steps - 1);
    setState(() => _step = to);
    if (!_pages.hasClients) return;
    if (reduceEffects(context)) {
      _pages.jumpToPage(to);
    } else {
      _pages.animateToPage(
        to,
        duration: CutMotion.enter,
        curve: CutMotion.decelerate,
      );
    }
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

  Future<void> _setProvider(AiProvider provider) async {
    final prefs = await ref.read(preferencesProvider.future);
    if (prefs.provider == provider) return;
    await ref
        .read(preferencesProvider.notifier)
        .save(prefs.copyWith(provider: provider));
  }

  /// Puts videos on the timeline: in the editor, into the open edit; on the
  /// home screen, as a new edit that opens once the guide closes.
  Future<void> _start(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;
    if (editorOpen) {
      if (ref.read(projectEditorProvider).project.clips.isEmpty) {
        await importVideos(ref, context, paths);
      }
      await _finish();
      return;
    }
    final ok = await startFromVideos(ref, context, paths, open: false);
    await _finish();
    if (ok) await showEditor();
  }

  Future<void> _openSample() async {
    setState(() => _sampleBusy = true);
    final path = await makeSampleVideo(ref);
    if (!mounted) return;
    setState(() => _sampleBusy = false);
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The sample needs FFmpeg, which wasn\'t found.'),
        ),
      );
      return;
    }
    await _start([path]);
  }

  Future<void> _importVideo() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Videos', extensions: videoExtensions),
      ],
    );
    await _start([for (final f in files) f.path]);
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
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 600;
    final body = _body(phone);
    if (phone) {
      return Material(
        key: const Key('onboarding'),
        color: Cut.canvas,
        child: SafeArea(child: body),
      );
    }
    return Center(
      child: Material(
        key: const Key('onboarding'),
        type: MaterialType.transparency,
        child: Container(
          width: 620,
          height: math.min(640, size.height - 48),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Cut.surface1,
            borderRadius: BorderRadius.circular(CutRadii.xl + 4),
            border: Border.all(color: Cut.strokeDefault),
            boxShadow: CutShadows.e3,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _body(bool phone) {
    final pad = phone ? CutSpace.s5 : CutSpace.s7;
    return Stack(
      children: [
        // The aurora glow sits behind the welcome and fades as you move on.
        Positioned(
          top: phone ? -200 : -260,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _step == 0 ? 1 : 0.45,
              duration: CutMotion.page,
              child: Center(child: AuroraGlow(size: phone ? 520 : 640)),
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 16, pad - 8, 0),
              child: Row(
                children: [
                  const CutlineWordmark(size: 20, background: Cut.surface1),
                  const Spacer(),
                  TextButton(
                    key: const Key('onboarding-done'),
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Cut.textSecondary,
                    ),
                    child: Text(_step == _steps - 1 ? 'Close' : 'Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _page(pad, _welcome(phone)),
                  _page(pad, _pickAi(phone)),
                  _page(pad, _tryIt(phone)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, phone ? 16 : 24),
              child: _footer(phone),
            ),
          ],
        ),
      ],
    );
  }

  Widget _page(double pad, Widget child) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  Widget _footer(bool phone) {
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _steps; i++)
          AnimatedContainer(
            duration: CutMotion.normal,
            curve: CutMotion.decelerate,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _step ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _step ? Cut.accent : Cut.strokeStrong,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
    final last = _step == _steps - 1;
    final next = SizedBox(
      height: 48,
      child: FilledButton(
        key: const Key('onboarding-next'),
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
        onPressed: last ? _finish : () => _go(_step + 1),
        child: Text(switch (_step) {
          0 => 'Get started',
          1 => 'Continue',
          _ => 'Done',
        }),
      ),
    );
    final back = AnimatedOpacity(
      opacity: _step == 0 ? 0 : 1,
      duration: CutMotion.fast,
      child: TextButton(
        onPressed: _step == 0 ? null : () => _go(_step - 1),
        style: TextButton.styleFrom(
          foregroundColor: Cut.textSecondary,
          minimumSize: const Size(64, 48),
        ),
        child: const Text('Back'),
      ),
    );
    if (phone) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: dots),
          const SizedBox(height: 16),
          next,
          if (_step > 0) back,
        ],
      );
    }
    return Row(
      children: [dots, const Spacer(), back, const SizedBox(width: 8), next],
    );
  }

  // Step 1: what Cutline is.
  Widget _welcome(bool phone) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _EditLoop(),
      SizedBox(height: phone ? 28 : 32),
      Text(
        'Edit video by talking to it.',
        textAlign: TextAlign.center,
        style: phone ? CutType.displaySm : CutType.display,
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(
          'Say what you want changed, like "cut the silences" or "add an '
          'intro with my logo", and watch the timeline follow. You can '
          'always tweak it by hand.',
          textAlign: TextAlign.center,
          style: CutType.body.copyWith(
            color: Cut.textSecondary,
            fontSize: 15,
            height: 22 / 15,
          ),
        ),
      ),
    ],
  );

  // Step 2: which AI.
  Widget _pickAi(bool phone) {
    final hasKey = ref.watch(apiKeyProvider).value != null;
    final provider =
        ref.watch(preferencesProvider).value?.provider ?? AiProvider.groq;
    final builtIn = ref.read(apiKeyProvider.notifier).usingBuiltIn;
    final cards = [
      _ChoiceCard(
        key: const Key('onboarding-groq'),
        selected: provider == AiProvider.groq,
        icon: CutIcons.ai,
        title: 'Free (Groq)',
        badge: 'Recommended',
        body: 'Fast and free. Good for everyday edits.',
        onTap: () => _setProvider(AiProvider.groq),
      ),
      _ChoiceCard(
        key: const Key('onboarding-claude'),
        selected: provider == AiProvider.claude,
        icon: CutIcons.key,
        title: 'Use my own key',
        body: 'Claude by Anthropic, with your API key.',
        onTap: () => _setProvider(AiProvider.claude),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          step: 'Step 2 of 3',
          title: 'Connect the assistant',
          body:
              'Pick the AI that does your edits. You can switch any time '
              'in Settings.',
          phone: phone,
        ),
        const SizedBox(height: 24),
        if (phone) ...[
          cards[0],
          const SizedBox(height: 12),
          cards[1],
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
          ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: CutMotion.normal,
          child: hasKey
              ? _StatusRow(
                  key: const ValueKey('ready'),
                  ok: true,
                  text: builtIn
                      ? 'Ready: this copy comes with a free key.'
                      : 'Ready: your ${provider.label} key is saved.',
                  actions: [
                    TextButton(
                      key: const Key('onboarding-settings'),
                      onPressed: () => showSettings(context),
                      child: const Text('Change key'),
                    ),
                  ],
                )
              : _StatusRow(
                  key: ValueKey('need-${provider.name}'),
                  ok: false,
                  text: provider == AiProvider.groq
                      ? 'Make a free key at console.groq.com, then paste it.'
                      : 'Paste your key from ${provider.consoleUrl}.',
                  actions: [
                    if (provider == AiProvider.groq)
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://console.groq.com/keys'),
                        ),
                        child: const Text('Get a free key'),
                      ),
                    FilledButton.tonal(
                      key: const Key('onboarding-settings'),
                      onPressed: () => showSettings(context),
                      child: const Text('Add key'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(CutIcons.lock, size: 14, color: Cut.textTertiary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your videos stay on this computer. The AI gets what you type '
                'and a summary of the edit.',
                style: CutType.caption.copyWith(color: Cut.textTertiary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 3: get something on the timeline.
  Widget _tryIt(bool phone) {
    final download = _download;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          step: 'Step 3 of 3',
          title: 'Try an edit',
          body:
              'Open the sample or one of your videos, then type something '
              'like "Cut the first 5 seconds" to the assistant.',
          phone: phone,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                key: const Key('onboarding-sample'),
                icon: CutIcons.playCircle,
                color: Cut.trackVideo,
                title: _sampleBusy ? 'Making it…' : 'Open a sample',
                body: '20 s of colour bars',
                onTap: _sampleBusy ? null : _openSample,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                key: const Key('onboarding-import'),
                icon: CutIcons.upload,
                color: Cut.accent,
                title: 'Import my video',
                body: 'mp4, mov or m4v',
                onTap: _importVideo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CutSurface(
          level: 2,
          radius: CutRadii.lg,
          shadow: false,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (_modelReady ? Cut.success : Cut.trackWave).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(CutRadii.sm + 2),
                ),
                child: Icon(
                  _modelReady ? CutIcons.check : CutIcons.transcript,
                  size: 18,
                  color: _modelReady ? Cut.success : Cut.trackWave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modelReady
                          ? 'Speech model ready'
                          : 'Get the speech model',
                      style: CutType.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _downloadError ??
                          'Finds moments by what you say. Runs on your '
                              'computer; 148 MB, once.',
                      style: CutType.caption.copyWith(
                        color: _downloadError != null
                            ? Cut.error
                            : Cut.textTertiary,
                      ),
                    ),
                    if (download != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: download,
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_modelReady) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  key: const Key('onboarding-model'),
                  onPressed: download == null ? _downloadModel : null,
                  child: Text(
                    download == null
                        ? 'Download'
                        : '${(download * 100).round()}%',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.step,
    required this.title,
    required this.body,
    required this.phone,
  });

  final String step;
  final String title;
  final String body;
  final bool phone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(step.toUpperCase(), style: CutType.overline),
      const SizedBox(height: 8),
      Text(title, style: phone ? CutType.headlineSm : CutType.headline),
      const SizedBox(height: 6),
      Text(body, style: CutType.body.copyWith(color: Cut.textSecondary)),
    ],
  );
}

/// One of the two AI choices: the selected one gets an aurora ring and a
/// check.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = CutRadii.lg;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: AuroraBorder(
          radius: r,
          active: selected,
          opacity: selected ? 1 : 0,
          child: AnimatedContainer(
            duration: CutMotion.normal,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? Cut.surface3 : Cut.surface2,
              borderRadius: BorderRadius.circular(r - 1.5),
              boxShadow: selected ? CutShadows.e2 : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Cut.surface4,
                        borderRadius: BorderRadius.circular(CutRadii.sm + 2),
                      ),
                      alignment: Alignment.center,
                      child: icon == CutIcons.ai
                          ? const AuroraIcon(size: 18)
                          : Icon(icon, size: 18, color: Cut.textSecondary),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: CutMotion.fast,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? Cut.accent : null,
                        border: Border.all(
                          color: selected ? Cut.accent : Cut.strokeStrong,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              CutIcons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: CutType.titleSm),
                    if (badge != null)
                      CutBadge(
                        badge!,
                        color: Cut.success,
                        background: Cut.successContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: CutType.caption.copyWith(color: Cut.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    super.key,
    required this.ok,
    required this.text,
    required this.actions,
  });

  final bool ok;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final message = Row(
      children: [
        Icon(
          ok ? CutIcons.checkCircle : CutIcons.key,
          size: 16,
          color: ok ? Cut.success : Cut.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: CutType.label.copyWith(
              color: ok ? Cut.success : Cut.textSecondary,
            ),
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, a) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          a,
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: ok ? Cut.successContainer : Cut.surface2,
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(
          color: ok ? Cut.success.withValues(alpha: 0.25) : Cut.strokeSubtle,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 460
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: message,
                  ),
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              )
            : Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 12),
                  buttons,
                ],
              ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    hoverLift: 2,
    child: CutSurface(
      level: 3,
      radius: CutRadii.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(CutRadii.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 14),
          Text(title, style: CutType.titleSm),
          const SizedBox(height: 2),
          Text(body, style: CutType.caption.copyWith(color: Cut.textTertiary)),
        ],
      ),
    ),
  );
}

/// A tiny looping picture of how Cutline works: a request is typed to the
/// assistant, the silences in the timeline light up and close, and a
/// "done" note appears. Plays a few times, then rests on the result.
class _EditLoop extends StatefulWidget {
  const _EditLoop();

  @override
  State<_EditLoop> createState() => _EditLoopState();
}

class _EditLoopState extends State<_EditLoop>
    with SingleTickerProviderStateMixin {
  static const _loops = 3;
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  int _played = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      if (++_played < _loops) {
        _c.forward(from: 0);
      } else {
        // Rest on the finished edit.
        _c.value = 0.9;
      }
    });
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceEffects(context)) {
      _played = _loops;
      _c.value = 0.9;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _prompt = 'Cut the silences';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Fade out at the very end of each loop so it restarts cleanly.
          final fade =
              (t > 0.95 && _played < _loops - 1 ? 1 - (t - 0.95) / 0.05 : 1.0)
                  .clamp(0.0, 1.0);
          final typed = (_prompt.length * (t / 0.28)).floor().clamp(
            0,
            _prompt.length,
          );
          final sent = t >= 0.32;
          final close = Curves.easeInOutCubic.transform(
            ((t - 0.5) / 0.22).clamp(0.0, 1.0),
          );
          final light = ((t - 0.36) / 0.1).clamp(0.0, 1.0);
          final done = Curves.easeOut.transform(
            ((t - 0.74) / 0.1).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: fade,
            child: CutSurface(
              level: 2,
              radius: CutRadii.xl,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The request, typed into a little composer.
                  AuroraBorder(
                    radius: CutRadii.pill,
                    width: 1.2,
                    active: !sent || t < 0.5,
                    opacity: 0.8,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Cut.surface3,
                        borderRadius: BorderRadius.circular(CutRadii.pill),
                      ),
                      child: Row(
                        children: [
                          const AuroraIcon(size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: _prompt.substring(0, typed)),
                                  if (!sent && (t * 12).floor().isEven)
                                    const TextSpan(
                                      text: '|',
                                      style: TextStyle(color: Cut.accent),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              style: CutType.label.copyWith(fontSize: 14),
                            ),
                          ),
                          AnimatedContainer(
                            duration: CutMotion.fast,
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: typed == _prompt.length && !sent
                                  ? Cut.accent
                                  : Cut.surface4,
                            ),
                            child: const Icon(
                              CutIcons.send,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: CustomPaint(
                      painter: _LoopTimeline(
                        light: light,
                        close: close,
                        playhead: t,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: Opacity(
                      opacity: done,
                      child: Transform.translate(
                        offset: Offset(0, (1 - done) * 6),
                        child: Row(
                          children: [
                            const Icon(
                              CutIcons.checkCircle,
                              size: 14,
                              color: Cut.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '3 silences cut',
                              style: CutType.caption.copyWith(
                                color: Cut.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            const TimecodeText('0:42 → 0:36'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoopTimeline extends CustomPainter {
  _LoopTimeline({
    required this.light,
    required this.close,
    required this.playhead,
  });

  /// How lit the silences are (0–1), how far they've closed (0–1), and
  /// where the playhead is (0–1 of the loop).
  final double light;
  final double close;
  final double playhead;

  static const _clips = [0.25, 0.19, 0.27, 0.14];
  static const _gaps = [0.05, 0.06, 0.04];

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    var x = 0.0;
    final rnd = math.Random(7);
    for (var i = 0; i < _clips.length; i++) {
      final w = _clips[i] * size.width;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, w - 2, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Color.alphaBlend(
            Cut.trackVideo.withValues(alpha: 0.22),
            Cut.surface3,
          ),
      );
      canvas.drawRRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Cut.trackVideo.withValues(alpha: 0.55),
      );
      // A waveform inside the clip.
      final bars = Paint()
        ..color = Cut.trackVideo.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var bx = x + 6; bx < x + w - 8; bx += 4) {
        final a = 0.2 + rnd.nextDouble() * 0.6;
        canvas.drawLine(
          Offset(bx, h / 2 - a * h * 0.32),
          Offset(bx, h / 2 + a * h * 0.32),
          bars,
        );
      }
      x += w;
      if (i < _gaps.length) {
        final gw = _gaps[i] * size.width * (1 - close);
        if (gw > 1) {
          final gap = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 4, gw - 2, h - 8),
            const Radius.circular(4),
          );
          canvas.drawRRect(
            gap,
            Paint()
              ..color = Color.lerp(
                Cut.surface3,
                Cut.marker.withValues(alpha: 0.4),
                light,
              )!,
          );
          // A flat line: nothing being said.
          canvas.drawLine(
            Offset(x + 3, h / 2),
            Offset(x + gw - 5, h / 2),
            Paint()
              ..color = Cut.textTertiary.withValues(alpha: 0.6)
              ..strokeWidth = 1.5,
          );
        }
        x += gw;
      }
    }
    // The playhead sweeps across while the request is typed.
    final px = (playhead / 0.32).clamp(0.0, 1.0) * x;
    if (playhead < 0.34) {
      final paint = Paint()
        ..color = Cut.marker
        ..strokeWidth = 2;
      canvas.drawLine(Offset(px, -4), Offset(px, h + 4), paint);
      canvas.drawCircle(Offset(px, -4), 3.5, Paint()..color = Cut.marker);
    }
  }

  @override
  bool shouldRepaint(_LoopTimeline old) =>
      old.light != light || old.close != close || old.playhead != playhead;
}
