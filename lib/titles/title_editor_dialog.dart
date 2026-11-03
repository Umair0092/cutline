import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../media/image_import.dart';
import '../model/title_item.dart';
import '../storage/project_store.dart';
import '../ui/dialogs/dialog_kit.dart';
import '../ui/tokens.dart';
import '../ui/widgets/cut_icons.dart';
import '../ui/widgets/cut_widgets.dart';
import 'templates.dart';
import 'title_actions.dart';
import 'title_preview.dart';

/// What the editor returns: the title and (for new ones) where it goes.
typedef TitleEdit = ({TitleSpec spec, TitlePlacement placement});

/// Opens the title editor. Pass [initial] to edit an existing title; the
/// placement can't change then.
Future<TitleEdit?> showTitleEditor(
  BuildContext context, {
  TitleSpec? initial,
  TitlePlacement? placement,
  double aspectRatio = 16 / 9,
  String? projectPath,
  String? templateId,
}) => showCutModal<TitleEdit>(
  context,
  builder: (_) => TitleEditorDialog(
    initial: initial,
    placement: placement,
    aspectRatio: aspectRatio,
    projectPath: projectPath,
    templateId: templateId,
  ),
);

const _swatches = [
  '#FFFFFF',
  '#111318',
  '#6C5CE7',
  '#00B894',
  '#FF4757',
  '#FDCB6E',
  '#0984E3',
  '#E84393',
];

/// A short name for the gallery cards.
String _shortName(TitleTemplate t) => switch (t.id) {
  'clean-card' => 'Clean',
  'bold-kinetic' => 'Kinetic',
  'lower-third' => 'Lower third',
  'logo-reveal' => 'Reveal',
  'logo-spin' => 'Spin',
  'logo-pop' => 'Bounce',
  'logo-shine' => 'Shine',
  'logo-corner' => 'Corner',
  'photo-showcase' => 'Showcase',
  _ => t.name,
};

bool _usesPicture(TitleTemplate t) =>
    t.fields.any((f) => f.kind == FieldKind.image);

enum _Tab { templates, text, style, timing }

class TitleEditorDialog extends StatefulWidget {
  const TitleEditorDialog({
    super.key,
    this.initial,
    this.placement,
    this.aspectRatio = 16 / 9,
    this.projectPath,
    this.templateId,
  });

  final TitleSpec? initial;
  final TitlePlacement? placement;
  final double aspectRatio;

  /// The project folder: pictures you pick are copied into it.
  final String? projectPath;

  /// The template to start with for a new title.
  final String? templateId;

  @override
  State<TitleEditorDialog> createState() => _TitleEditorDialogState();
}

class _TitleEditorDialogState extends State<TitleEditorDialog>
    with SingleTickerProviderStateMixin {
  late TitleTemplate _template;
  late Map<String, String> _fields;
  late Duration _duration;
  late TitlePlacement _placement;
  late final AnimationController _loop;
  final _controllers = <String, TextEditingController>{};
  bool _playing = true;
  _Tab _tab = _Tab.text;

  bool get _editing => widget.initial != null;

  /// The animation plus a short hold on the last frame.
  static const _hold = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _template =
        templateById(widget.initial?.templateId ?? widget.templateId ?? '') ??
        titleTemplates.first;
    _fields = {...?widget.initial?.fields};
    _duration = widget.initial?.duration ?? _template.defaultDuration;
    _placement =
        widget.placement ??
        (_template.fullFrame ? TitlePlacement.before : TitlePlacement.over);
    _loop = AnimationController(vsync: this);
    _restartLoop();
  }

  void _restartLoop() {
    _loop.duration = _duration + _hold;
    if (_playing) {
      _loop.repeat();
    }
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TitleSpec get _spec => TitleSpec(
    templateId: _template.id,
    fields: {
      for (final f in _template.fields)
        if (_fields[f.key] != null) f.key: _fields[f.key]!,
    },
    duration: _duration,
  );

  void _pickTemplate(TitleTemplate t) {
    if (t.id == _template.id) return;
    setState(() {
      // Keep values for fields both templates share, like the name.
      _fields.removeWhere((k, _) => !t.fields.any((f) => f.key == k));
      _template = t;
      _duration = t.defaultDuration;
      if (!_editing) {
        _placement = t.fullFrame ? TitlePlacement.before : TitlePlacement.over;
      }
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
    });
    _loop.value = 0;
    _restartLoop();
  }

  TextEditingController _controller(TemplateField f) =>
      _controllers.putIfAbsent(
        f.key,
        () => TextEditingController(text: _fields[f.key] ?? f.defaultValue),
      );

  void _save() => Navigator.pop(context, (spec: _spec, placement: _placement));

  double get _seconds => _duration.inMicroseconds / 1e6;

  double get _t => (_loop.value * (_loop.duration!.inMicroseconds / 1e6))
      .clamp(0.0, _seconds - 0.001)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: CutModal(
        width: 1040,
        height: phone ? null : 720,
        title: _editing ? 'Edit title' : 'Add a title',
        subtitle: _editing
            ? _template.name
            : 'Pick a look, type your words, watch it play',
        icon: CutIcons.title,
        iconColor: Cut.trackTitle,
        iconBackground: Cut.trackTitle.withValues(alpha: 0.16),
        scroll: false,
        bodyPadding: EdgeInsets.zero,
        body: phone ? _phoneBody() : _desktopBody(),
        footer: ModalActions(
          leading: phone
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KeyCap(Platform.isMacOS ? '⌘' : 'Ctrl'),
                    const SizedBox(width: 3),
                    const KeyCap('↵'),
                    const SizedBox(width: 8),
                    Text(
                      _editing ? 'to save' : 'to add',
                      style: CutType.caption.copyWith(color: Cut.textTertiary),
                    ),
                  ],
                ),
          actions: [
            QuietButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
            PrimaryButton(
              key: const Key('title-save'),
              label: _editing ? 'Save' : 'Add title',
              icon: _editing ? CutIcons.check : CutIcons.add,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- layout

  Widget _desktopBody() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 0, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _stage()),
                const SizedBox(height: CutSpace.s3),
                _transport(),
                const SizedBox(height: CutSpace.s3),
                _timing(compact: true),
                const SizedBox(height: CutSpace.s4),
                SectionLabel(
                  'Templates',
                  trailing: Text(
                    '${titleTemplates.length} looks',
                    style: CutType.caption.copyWith(color: Cut.textTertiary),
                  ),
                ),
                SizedBox(height: 118, child: _gallery()),
              ],
            ),
          ),
        ),
        const SizedBox(width: CutSpace.s5),
        Container(
          width: 360,
          decoration: const BoxDecoration(
            color: Cut.surface1,
            border: Border(left: BorderSide(color: Cut.strokeSubtle)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _templateHeader(),
                const SizedBox(height: CutSpace.s5),
                ..._textSection(),
                ..._pictureSection(),
                ..._styleSection(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _phoneBody() {
    final tabs = <(_Tab, String, IconData?)>[
      (_Tab.templates, 'Looks', null),
      (_Tab.text, 'Text', null),
      (_Tab.style, 'Style', null),
      (_Tab.timing, 'Timing', null),
    ];
    final List<Widget> content = switch (_tab) {
      _Tab.templates => [
        _templateHeader(),
        const SizedBox(height: CutSpace.s4),
        _galleryGrid(),
      ],
      _Tab.text => [..._textSection(), ..._pictureSection()],
      _Tab.style => _styleSection(),
      _Tab.timing => [_timing(compact: false)],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.3,
            ),
            child: _stage(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _transport(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedPill<_Tab>(
            segments: tabs,
            selected: _tab,
            expand: true,
            onChanged: (t) => setState(() => _tab = t),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_tab),
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- stage

  /// The live preview: the title playing on a dark stage (a checkerboard
  /// shows where an overlay is see-through).
  Widget _stage() => _centerIfDesktop(
    AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        key: const Key('title-preview'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Cut.canvas,
          borderRadius: BorderRadius.circular(CutRadii.md),
          border: Border.all(color: Cut.strokeDefault),
          boxShadow: CutShadows.e2,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_template.fullFrame) const Checkerboard(cell: 12),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => CustomPaint(
                  painter: TitlePainter(
                    _spec,
                    _t,
                    projectPath: widget.projectPath,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CutBadge(
                _template.fullFrame ? 'Full screen' : 'Overlay',
                icon: _template.fullFrame
                    ? DialogIcons.aspect
                    : DialogIcons.placementOver,
                color: Colors.white,
                background: const Color(0x99000000),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _centerIfDesktop(Widget child) =>
      isPhoneLayout(context) ? child : Center(child: child);

  Widget _transport() => Row(
    children: [
      CutIconButton(
        icon: _playing ? CutIcons.pause : CutIcons.play,
        tooltip: _playing ? 'Pause' : 'Play',
        onPressed: _togglePlay,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            void scrub(double dx) {
              if (_playing) _togglePlay();
              final total = _loop.duration!.inMicroseconds;
              final want = (dx / box.maxWidth).clamp(0.0, 1.0) * _seconds;
              _loop.value = (want * 1e6 / total).clamp(0.0, 1.0);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => scrub(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => scrub(d.localPosition.dx),
              child: SizedBox(
                height: 28,
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) =>
                      CustomPaint(painter: _ScrubPainter(_t / _seconds)),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 12),
      AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => TimecodeText(
          '${_t.toStringAsFixed(1)} / ${_seconds.toStringAsFixed(1)} s',
        ),
      ),
    ],
  );

  Widget _timing({required bool compact}) {
    final length = Row(
      children: [
        const Icon(DialogIcons.timer, size: 16, color: Cut.textTertiary),
        const SizedBox(width: 8),
        Text('Length', style: CutType.label.copyWith(color: Cut.textSecondary)),
        Expanded(
          child: Slider(
            key: const Key('title-length'),
            value: _seconds.clamp(2, 10),
            min: 2,
            max: 10,
            divisions: 16,
            label: '${_seconds.toStringAsFixed(1)} s',
            onChanged: (v) {
              setState(
                () => _duration = Duration(milliseconds: (v * 1000).round()),
              );
              _restartLoop();
            },
          ),
        ),
        SizedBox(
          width: 44,
          child: TimecodeText(
            '${_seconds.toStringAsFixed(1)} s',
            color: Cut.textPrimary,
          ),
        ),
      ],
    );
    final placement = _editing
        ? null
        : SegmentedPill<TitlePlacement>(
            segments: const [
              (
                TitlePlacement.before,
                'Before the video',
                DialogIcons.placementBefore,
              ),
              (
                TitlePlacement.over,
                'Over the start',
                DialogIcons.placementOver,
              ),
            ],
            selected: _placement,
            expand: !compact,
            onChanged: (v) => setState(() => _placement = v),
          );
    if (compact) {
      return Row(
        children: [
          if (placement != null) ...[placement, const SizedBox(width: 20)],
          Expanded(child: length),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (placement != null) ...[
          const FieldLabel('Where it goes'),
          placement,
          const SizedBox(height: CutSpace.s5),
        ],
        const FieldLabel('How long'),
        length,
      ],
    );
  }

  // -------------------------------------------------------------- gallery

  Widget _templateHeader() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_template.name, style: CutType.title),
            const SizedBox(height: 3),
            Text(_template.description, style: CutType.caption),
          ],
        ),
      ),
      if (_usesPicture(_template)) ...[
        const SizedBox(width: 8),
        const CutBadge('Picture', icon: CutIcons.image),
      ],
    ],
  );

  Widget _gallery() => ListView.separated(
    key: const Key('title-template'),
    scrollDirection: Axis.horizontal,
    itemCount: titleTemplates.length,
    padding: const EdgeInsets.only(right: 4, top: 2),
    separatorBuilder: (_, _) => const SizedBox(width: 10),
    itemBuilder: (context, i) {
      final t = titleTemplates[i];
      return SizedBox(
        width: 156,
        child: _TemplateCard(
          key: Key('template-${t.id}'),
          template: t,
          selected: t.id == _template.id,
          fields: _fields,
          projectPath: widget.projectPath,
          onTap: () => _pickTemplate(t),
        ),
      );
    },
  );

  Widget _galleryGrid() => LayoutBuilder(
    builder: (context, box) {
      const gap = 10.0;
      final w = (box.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in titleTemplates)
            SizedBox(
              width: w,
              child: _TemplateCard(
                template: t,
                selected: t.id == _template.id,
                fields: _fields,
                projectPath: widget.projectPath,
                animate: true,
                onTap: () => _pickTemplate(t),
              ),
            ),
        ],
      );
    },
  );

  // --------------------------------------------------------------- fields

  List<Widget> _section(String label, List<Widget> children) => children.isEmpty
      ? const []
      : [SectionLabel(label), ...children, const SizedBox(height: CutSpace.s3)];

  List<Widget> _textSection() => _section('Text', [
    for (final f in _template.fields)
      if (f.kind == FieldKind.text) _fieldEditor(f),
  ]);

  List<Widget> _pictureSection() => _section('Pictures', [
    for (final f in _template.fields)
      if (f.kind == FieldKind.image) _fieldEditor(f),
  ]);

  List<Widget> _styleSection() => _section('Style', [
    for (final f in _template.fields)
      if (f.kind == FieldKind.font) _fieldEditor(f),
    for (final f in _template.fields)
      if (f.kind == FieldKind.color) _fieldEditor(f),
  ]);

  Widget _fieldEditor(TemplateField f) {
    final value = _fields[f.key] ?? f.defaultValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: switch (f.kind) {
        FieldKind.text => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(f.label),
            TextField(
              key: Key('field-${f.key}'),
              controller: _controller(f),
              style: CutType.body.copyWith(fontSize: 15),
              decoration: InputDecoration(hintText: f.defaultValue),
              onChanged: (v) => setState(() => _fields[f.key] = v),
            ),
          ],
        ),
        FieldKind.font => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(f.label, icon: DialogIcons.font),
            Row(
              key: Key('field-${f.key}'),
              children: [
                for (final (i, font) in titleFonts.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _FontChip(
                      font: font,
                      selected:
                          (titleFonts.contains(value)
                              ? value
                              : titleFonts.first) ==
                          font,
                      onTap: () => setState(() => _fields[f.key] = font),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        FieldKind.image => _ImageField(
          key: Key('field-${f.key}'),
          label: f.label,
          value: value,
          projectPath: widget.projectPath,
          onChanged: (v) => setState(() => _fields[f.key] = v),
        ),
        FieldKind.color => _colorEditor(f, value),
      },
    );
  }

  Widget _colorEditor(TemplateField f, String value) {
    final current = parseHexColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                f.label,
                style: CutType.label.copyWith(
                  color: Cut.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 104,
              height: 30,
              child: TextField(
                key: Key('field-${f.key}'),
                controller: _controller(f),
                style: CutType.timecode.copyWith(
                  color: Cut.textPrimary,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '#RRGGBB',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 6),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: current,
                        shape: BoxShape.circle,
                        border: Border.all(color: Cut.strokeStrong),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 12,
                  ),
                ),
                onChanged: (v) {
                  if (parseHexColor(v) != null) {
                    setState(() => _fields[f.key] = v.toUpperCase());
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final hex in _swatches)
              _Swatch(
                key: Key('swatch-${f.key}-$hex'),
                color: parseHexColor(hex)!,
                selected: value.toUpperCase() == hex,
                onTap: () => setState(() {
                  _fields[f.key] = hex;
                  _controller(f).text = hex;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

/// The scrub bar under the preview: a track, the played part and a pink
/// playhead.
class _ScrubPainter extends CustomPainter {
  _ScrubPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y - 2, size.width, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(track, Paint()..color = Cut.surface4);
    final x = size.width * fraction.clamp(0, 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 2, x, 4),
        const Radius.circular(2),
      ),
      Paint()..color = Cut.trackTitle.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()
        ..color = Cut.marker.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = Cut.marker);
  }

  @override
  bool shouldRepaint(_ScrubPainter old) => old.fraction != fraction;
}

/// A template in the gallery: a 16:9 card that plays its animation on hover
/// (or always, with [animate]), with its name underneath.
class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    super.key,
    required this.template,
    required this.selected,
    required this.fields,
    required this.projectPath,
    required this.onTap,
    this.animate = false,
  });

  final TitleTemplate template;
  final bool selected;
  final Map<String, String> fields;
  final String? projectPath;
  final VoidCallback onTap;
  final bool animate;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: widget.template.defaultDuration + const Duration(seconds: 1),
  );
  bool _hover = false;

  /// The frame shown at rest: well into the animation, when it reads.
  double get _restT =>
      widget.template.defaultDuration.inMicroseconds / 1e6 * 0.55;

  @override
  void initState() {
    super.initState();
    if (widget.animate && !reduceEffects(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _setHover(bool on) {
    setState(() => _hover = on);
    if (widget.animate) return;
    if (on) {
      _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final total = t.defaultDuration.inMicroseconds / 1e6;
    final spec = TitleSpec(
      templateId: t.id,
      fields: {
        for (final f in t.fields)
          if (widget.fields[f.key] != null &&
              (f.kind == FieldKind.text || f.kind == FieldKind.image))
            f.key: widget.fields[f.key]!,
      },
      duration: t.defaultDuration,
    );
    final selected = widget.selected;
    return Semantics(
      selected: selected,
      label: t.name,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: Pressable(
          onTap: widget.onTap,
          pressedScale: 0.97,
          hoverLift: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: CutMotion.fast,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CutRadii.md),
                  border: Border.all(
                    color: selected
                        ? Cut.accent
                        : _hover
                        ? Cut.strokeStrong
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CutRadii.sm),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!t.fullFrame)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2B3A55), Color(0xFF1A1626)],
                              ),
                            ),
                          ),
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) {
                              final playing = _c.isAnimating;
                              final tt = playing
                                  ? (_c.value *
                                            (_c.duration!.inMicroseconds / 1e6))
                                        .clamp(0.0, total - 0.001)
                                        .toDouble()
                                  : _restT;
                              return CustomPaint(
                                painter: TitlePainter(
                                  spec,
                                  tt,
                                  projectPath: widget.projectPath,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: AnimatedScale(
                            scale: selected ? 1 : 0,
                            duration: CutMotion.normal,
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Cut.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                CutIcons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_usesPicture(t))
                          const Positioned(
                            left: 5,
                            bottom: 5,
                            child: Icon(
                              CutIcons.image,
                              size: 13,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _shortName(t),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CutType.caption.copyWith(
                  color: selected ? Cut.textPrimary : Cut.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final String font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    label: font,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CutMotion.fast,
        height: 58,
        decoration: BoxDecoration(
          color: selected ? Cut.accentContainer : Cut.surface2,
          borderRadius: BorderRadius.circular(CutRadii.md),
          border: Border.all(
            color: selected ? Cut.accent : Cut.strokeSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: font,
                fontSize: 20,
                height: 1.1,
                color: Cut.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              font,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CutType.caption.copyWith(
                fontSize: 10.5,
                color: selected ? Cut.onAccentContainer : Cut.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A picture field: a big drop tile showing the chosen picture on a
/// checkerboard, and buttons to choose or remove one. Picked or dropped
/// files are copied into the project.
class _ImageField extends StatefulWidget {
  const _ImageField({
    super.key,
    required this.label,
    required this.value,
    required this.projectPath,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String? projectPath;
  final ValueChanged<String> onChanged;

  @override
  State<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<_ImageField> {
  bool _busy = false;
  bool _dragging = false;

  Future<void> _pick() async {
    if (widget.projectPath == null) return;
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Pictures',
          extensions: imageExtensions,
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );
    if (file == null) return;
    await _use(file.path);
  }

  Future<void> _use(String path) async {
    final dir = widget.projectPath;
    if (dir == null) return;
    setState(() => _busy = true);
    try {
      final media = await importImage(path, dir);
      widget.onChanged(media.path);
    } on ImageImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.value.isNotEmpty;
    final path = has
        ? ProjectStore.resolve(widget.value, widget.projectPath)
        : '';
    final exists = has && File(path).existsSync();
    final canPick = widget.projectPath != null && !_busy;
    final optional = widget.label.toLowerCase().contains('optional');

    final tile = AnimatedContainer(
      duration: CutMotion.fast,
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CutRadii.md),
        border: Border.all(
          color: _dragging
              ? Cut.accent
              : has
              ? Cut.strokeDefault
              : Cut.strokeStrong,
          width: _dragging ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (exists)
            Checkerboard(
              cell: 8,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            )
          else
            CustomPaint(
              painter: _DashedPainter(
                color: _dragging ? Cut.accent : Cut.strokeStrong,
              ),
              child: Container(
                color: _dragging
                    ? Cut.accent.withValues(alpha: 0.1)
                    : Cut.surface2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CutIcons.addImage,
                      size: 26,
                      color: _dragging ? Cut.accent : Cut.textTertiary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dragging ? 'Drop it' : 'Drop here',
                      style: CutType.caption.copyWith(
                        fontSize: 10.5,
                        color: Cut.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_busy)
            const ColoredBox(
              color: Color(0x99000000),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );

    return DropTarget(
      enable: canPick,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) async {
        setState(() => _dragging = false);
        final image = d.files
            .map((f) => f.path)
            .where(
              (f) => imageExtensions.contains(
                p.extension(f).replaceFirst('.', '').toLowerCase(),
              ),
            )
            .firstOrNull;
        if (image != null) await _use(image);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Cut.surface2,
          borderRadius: BorderRadius.circular(CutRadii.lg),
          border: Border.all(color: Cut.strokeSubtle),
        ),
        child: Row(
          children: [
            Pressable(
              onTap: canPick ? _pick : null,
              pressedScale: 0.96,
              semanticLabel: has ? 'Change picture' : 'Choose picture',
              child: tile,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label.replaceAll(' (optional)', ''),
                    style: CutType.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.projectPath == null
                        ? 'Save the project first to add pictures.'
                        : has
                        ? p.basename(widget.value)
                        : optional
                        ? 'Optional. A PNG with a see-through background '
                              'looks best.'
                        : 'A PNG with a see-through background looks best.',
                    style: CutType.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      QuietButton(
                        label: has ? 'Change' : 'Choose picture',
                        icon: CutIcons.upload,
                        height: 32,
                        onPressed: canPick ? _pick : null,
                      ),
                      if (has)
                        QuietButton(
                          label: 'Remove',
                          danger: true,
                          transparent: true,
                          height: 32,
                          onPressed: () => widget.onChanged(''),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(4),
      const Radius.circular(CutRadii.sm),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    pressedScale: 0.88,
    child: AnimatedContainer(
      duration: CutMotion.fast,
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Cut.textPrimary : Colors.transparent,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Cut.strokeDefault),
        ),
      ),
    ),
  );
}
