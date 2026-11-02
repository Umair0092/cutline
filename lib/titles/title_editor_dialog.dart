import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../media/image_import.dart';
import '../storage/project_store.dart';

import '../model/title_item.dart';
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
}) => showDialog<TitleEdit>(
  context: context,
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

  bool get _editing => widget.initial != null;

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
    _loop = AnimationController(vsync: this)
      ..addListener(() => setState(() {}));
    _restartLoop();
  }

  void _restartLoop() {
    // Play the animation, hold the last frame briefly, repeat.
    _loop
      ..duration = _duration + const Duration(milliseconds: 800)
      ..repeat();
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
    _restartLoop();
  }

  TextEditingController _controller(TemplateField f) =>
      _controllers.putIfAbsent(
        f.key,
        () => TextEditingController(text: _fields[f.key] ?? f.defaultValue),
      );

  @override
  Widget build(BuildContext context) {
    final seconds = _duration.inMicroseconds / 1e6;
    final t = (_loop.value * (_loop.duration!.inMicroseconds / 1e6))
        .clamp(0.0, seconds - 0.001)
        .toDouble();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_editing ? 'Edit title' : 'Add a title'),
      content: SizedBox(
        width: 860,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: Container(
                      key: const Key('title-preview'),
                      decoration: BoxDecoration(
                        // A checkerboard-ish grey shows what's see-through.
                        color: const Color(0xFF3A3D45),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: CustomPaint(
                        painter: TitlePainter(
                          _spec,
                          t,
                          projectPath: widget.projectPath,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_editing)
                    SegmentedButton<TitlePlacement>(
                      segments: const [
                        ButtonSegment(
                          value: TitlePlacement.before,
                          label: Text('Before the video'),
                        ),
                        ButtonSegment(
                          value: TitlePlacement.over,
                          label: Text('Over the start'),
                        ),
                      ],
                      selected: {_placement},
                      onSelectionChanged: (s) =>
                          setState(() => _placement = s.first),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Length', style: theme.textTheme.bodySmall),
                      Expanded(
                        child: Slider(
                          key: const Key('title-length'),
                          value: seconds,
                          min: 2,
                          max: 10,
                          divisions: 16,
                          label: '${seconds.toStringAsFixed(1)} s',
                          onChanged: (v) {
                            setState(
                              () => _duration = Duration(
                                milliseconds: (v * 1000).round(),
                              ),
                            );
                            _restartLoop();
                          },
                        ),
                      ),
                      Text('${seconds.toStringAsFixed(1)} s'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<TitleTemplate>(
                      key: const Key('title-template'),
                      initialValue: _template,
                      decoration: const InputDecoration(labelText: 'Template'),
                      items: [
                        for (final tpl in titleTemplates)
                          DropdownMenuItem(value: tpl, child: Text(tpl.name)),
                      ],
                      onChanged: (t) => _pickTemplate(t!),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _template.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (final f in _template.fields) _fieldEditor(f),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('title-save'),
          onPressed: () =>
              Navigator.pop(context, (spec: _spec, placement: _placement)),
          child: Text(_editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _fieldEditor(TemplateField f) {
    final value = _fields[f.key] ?? f.defaultValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (f.kind) {
        FieldKind.text => TextField(
          key: Key('field-${f.key}'),
          controller: _controller(f),
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => setState(() => _fields[f.key] = v),
        ),
        FieldKind.font => DropdownButtonFormField<String>(
          key: Key('field-${f.key}'),
          initialValue: titleFonts.contains(value) ? value : titleFonts.first,
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final font in titleFonts)
              DropdownMenuItem(
                value: font,
                child: Text(font, style: TextStyle(fontFamily: font)),
              ),
          ],
          onChanged: (v) => setState(() => _fields[f.key] = v!),
        ),
        FieldKind.image => _ImageField(
          key: Key('field-${f.key}'),
          label: f.label,
          value: value,
          projectPath: widget.projectPath,
          onChanged: (v) => setState(() => _fields[f.key] = v),
        ),
        FieldKind.color => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: Key('field-${f.key}'),
                    controller: _controller(f),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '#RRGGBB',
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
          ],
        ),
      },
    );
  }
}

/// A picture field: a thumbnail of the chosen picture, and buttons to
/// choose or remove one. Picked files are copied into the project.
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

  Future<void> _pick() async {
    final dir = widget.projectPath;
    if (dir == null) return;
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
    setState(() => _busy = true);
    try {
      final media = await importImage(file.path, dir);
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
    final colors = Theme.of(context).colorScheme;
    final has = widget.value.isNotEmpty;
    final path = has
        ? ProjectStore.resolve(widget.value, widget.projectPath)
        : '';
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: has && File(path).existsSync()
              ? Image.file(File(path), fit: BoxFit.contain)
              : Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.projectPath == null || _busy
                        ? null
                        : _pick,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(has ? 'Change' : 'Choose picture'),
                  ),
                  if (has)
                    TextButton(
                      onPressed: () => widget.onChanged(''),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: selected ? 3 : 1,
        ),
      ),
    ),
  );
}
