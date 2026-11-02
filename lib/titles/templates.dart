import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:characters/characters.dart';

import 'package:flutter/painting.dart';

part 'image_templates.dart';

enum FieldKind {
  text,
  color,
  font,

  /// A picture in the project (a logo, a photo): its path, relative to the
  /// project folder.
  image,
}

/// Finds the decoded picture for an image field's value. Null while it
/// loads or when there's none.
typedef ImageLookup = ui.Image? Function(String value);

class TemplateField {
  const TemplateField(this.key, this.label, this.kind, this.defaultValue);

  final String key;
  final String label;
  final FieldKind kind;
  final String defaultValue;
}

/// Fonts bundled with the app (see pubspec.yaml).
const titleFonts = ['Inter', 'Bebas Neue', 'Playfair Display'];

/// Field values with the template's defaults filled in.
class TitleValues {
  TitleValues(this.template, Map<String, String> raw, {ImageLookup? image})
    : _image = image, // ignore: prefer_initializing_formals
      _values = {
        for (final f in template.fields) f.key: raw[f.key] ?? f.defaultValue,
      };

  final TitleTemplate template;
  final Map<String, String> _values;
  final ImageLookup? _image;

  /// The picture in an image field, or null (none chosen, or loading).
  ui.Image? image(String key) {
    final v = _values[key];
    if (v == null || v.isEmpty) return null;
    return _image?.call(v);
  }

  /// Whether an image field has a picture chosen (loaded or not).
  bool hasImage(String key) => (_values[key] ?? '').isNotEmpty;

  String text(String key) => _values[key] ?? '';

  Color color(String key) =>
      parseHexColor(_values[key]) ?? const Color(0xFFFFFFFF);

  String font(String key) {
    final f = _values[key];
    return titleFonts.contains(f) ? f! : titleFonts.first;
  }
}

/// "#RRGGBB" or "#AARRGGBB" (the # is optional). Null if it isn't one.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

String toHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// An animated title. [paint] draws one frame at [t] seconds into a title
/// lasting [total] seconds. It is pure drawing, so the same code makes the
/// live preview and the exported frames.
abstract class TitleTemplate {
  const TitleTemplate();

  String get id;
  String get name;
  String get description;

  /// True for a full-screen card, false for a see-through overlay such as a
  /// lower third.
  bool get fullFrame;
  Duration get defaultDuration;
  List<TemplateField> get fields;

  /// The colour field a saved brand colour fills in, if any.
  String? get brandField;

  void paint(Canvas canvas, Size size, double t, double total, TitleValues v);
}

const titleTemplates = <TitleTemplate>[
  CleanCard(),
  BoldKinetic(),
  LowerThird(),
  LogoReveal(),
  LogoSpin(),
  LogoPop(),
  LogoShine(),
  LogoCorner(),
  PhotoShowcase(),
];

TitleTemplate? templateById(String id) =>
    titleTemplates.where((t) => t.id == id).firstOrNull;

// ---------------------------------------------------------------------------
// Helpers

double _clamp01(double x) => x.clamp(0.0, 1.0).toDouble();

/// 0→1 between [from] and [to] seconds, eased.
double _ease(double t, double from, double to) {
  final x = _clamp01((t - from) / (to - from));
  return 1 - math.pow(1 - x, 3).toDouble();
}

/// Fades everything out over the last [seconds].
double _outro(double t, double total, [double seconds = 0.5]) =>
    _clamp01((total - t) / seconds);

TextStyle _style(
  String font,
  double size,
  Color color, {
  double weight = 700,
}) => TextStyle(
  fontFamily: font,
  fontSize: size,
  color: color,
  height: 1.1,
  fontVariations: [FontVariation('wght', weight)],
);

TextPainter _layout(String text, TextStyle style, double maxWidth) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

void _drawText(
  Canvas canvas,
  TextPainter tp,
  Offset center, {
  double opacity = 1,
  double dy = 0,
}) {
  if (opacity <= 0) return;
  canvas.saveLayer(
    null,
    Paint()..color = Color.fromRGBO(0, 0, 0, _clamp01(opacity)),
  );
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 - dy));
  canvas.restore();
}

// ---------------------------------------------------------------------------
// Templates

class CleanCard extends TitleTemplate {
  const CleanCard();

  @override
  String? get brandField => 'accent';

  @override
  String get id => 'clean-card';
  @override
  String get name => 'Clean title card';
  @override
  String get description => 'Your title and name on a plain background.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 4);
  @override
  List<TemplateField> get fields => const [
    TemplateField('title', 'Title', FieldKind.text, 'My Video'),
    TemplateField('subtitle', 'Subtitle', FieldKind.text, 'by Your Name'),
    TemplateField('background', 'Background', FieldKind.color, '#111318'),
    TemplateField('accent', 'Accent', FieldKind.color, '#6C5CE7'),
    TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
    TemplateField('font', 'Font', FieldKind.font, 'Inter'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = size.height / 1080;
    final out = _outro(t, total);
    canvas.drawRect(Offset.zero & size, Paint()..color = v.color('background'));
    final center = size.center(Offset.zero);

    final title = _layout(
      v.text('title'),
      _style(v.font('font'), 110 * u, v.color('textColor')),
      size.width * 0.85,
    );
    final a = _ease(t, 0, 0.7);
    _drawText(
      canvas,
      title,
      center - Offset(0, 40 * u),
      opacity: a * out,
      dy: (1 - a) * 40 * u,
    );

    final line = _ease(t, 0.35, 1.0) * out;
    final lineW = title.width * 0.6 * line;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(0, title.height / 2 - 10 * u),
          width: lineW,
          height: 6 * u,
        ),
        Radius.circular(3 * u),
      ),
      Paint()..color = v.color('accent').withValues(alpha: out),
    );

    final sub = _layout(
      v.text('subtitle'),
      _style(
        v.font('font'),
        46 * u,
        v.color('textColor').withValues(alpha: 0.8),
        weight: 400,
      ),
      size.width * 0.85,
    );
    final b = _ease(t, 0.3, 1.0);
    _drawText(
      canvas,
      sub,
      center + Offset(0, title.height / 2 + 50 * u),
      opacity: b * out,
      dy: (1 - b) * 30 * u,
    );
  }
}

class BoldKinetic extends TitleTemplate {
  const BoldKinetic();

  @override
  String? get brandField => 'background';

  @override
  String get id => 'bold-kinetic';
  @override
  String get name => 'Bold kinetic text';
  @override
  String get description => 'Big words that pop in one by one.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 4);
  @override
  List<TemplateField> get fields => const [
    TemplateField('title', 'Title', FieldKind.text, 'Let\'s get started'),
    TemplateField('name', 'Name', FieldKind.text, 'Your Name'),
    TemplateField('background', 'Background', FieldKind.color, '#FF4757'),
    TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
    TemplateField('font', 'Font', FieldKind.font, 'Bebas Neue'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = size.height / 1080;
    final out = _outro(t, total, 0.4);
    canvas.drawRect(Offset.zero & size, Paint()..color = v.color('background'));
    final words = v.text('title').toUpperCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return;

    final style = _style(
      v.font('font'),
      170 * u,
      v.color('textColor'),
      weight: 800,
    );
    final painters = [
      for (final w in words) _layout(w, style, size.width * 0.9),
    ];
    final lineH = painters.first.height * 0.95;
    final top = size.height / 2 - lineH * words.length / 2 - 30 * u;
    const step = 0.22;
    for (var i = 0; i < painters.length; i++) {
      final p = _ease(t, i * step, i * step + 0.35);
      if (p <= 0) continue;
      final scale = 1.35 - 0.35 * p;
      final c = Offset(size.width / 2, top + lineH * (i + 0.5));
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(scale)
        ..translate(-c.dx, -c.dy);
      _drawText(canvas, painters[i], c, opacity: p * out);
      canvas.restore();
    }

    final barP = _ease(t, words.length * step, words.length * step + 0.5) * out;
    final barY = top + lineH * words.length + 20 * u;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, barY, size.width * 0.4 * barP, 10 * u),
      Paint()..color = v.color('textColor'),
    );
    final name = _layout(
      v.text('name'),
      _style('Inter', 40 * u, v.color('textColor'), weight: 600),
      size.width * 0.8,
    );
    _drawText(
      canvas,
      name,
      Offset(size.width / 2, barY + 60 * u),
      opacity: barP,
    );
  }
}

class LowerThird extends TitleTemplate {
  const LowerThird();

  @override
  String? get brandField => 'barColor';

  @override
  String get id => 'lower-third';
  @override
  String get name => 'Lower third';
  @override
  String get description => 'Your name and role in a bar at the bottom left.';
  @override
  bool get fullFrame => false;
  @override
  Duration get defaultDuration => const Duration(seconds: 5);
  @override
  List<TemplateField> get fields => const [
    TemplateField('name', 'Name', FieldKind.text, 'Your Name'),
    TemplateField('role', 'Role', FieldKind.text, 'Software Engineer'),
    TemplateField('barColor', 'Bar', FieldKind.color, '#6C5CE7'),
    TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
    TemplateField('font', 'Font', FieldKind.font, 'Inter'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = size.height / 1080;
    final inP = _ease(t, 0, 0.5);
    final outP = 1 - _ease(t, total - 0.5, total);
    final p = math.min(inP, outP);
    if (p <= 0) return;

    final name = TextPainter(
      text: TextSpan(
        text: v.text('name'),
        style: _style(v.font('font'), 56 * u, v.color('textColor')),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.6);
    final role = TextPainter(
      text: TextSpan(
        text: v.text('role'),
        style: _style(
          v.font('font'),
          32 * u,
          v.color('textColor').withValues(alpha: 0.85),
          weight: 400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.6);

    final pad = 28 * u;
    final w = math.max(name.width, role.width) + pad * 2;
    final h = name.height + role.height + pad * 1.5;
    final left = 80 * u;
    final top = size.height - 120 * u - h;
    final shift = (1 - p) * (w + left);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, top - 10 * u, left + w + 20 * u, h + 20 * u),
    );
    canvas.translate(-shift, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h),
        Radius.circular(10 * u),
      ),
      Paint()..color = v.color('barColor').withValues(alpha: 0.92),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, top, 8 * u, h),
      Paint()..color = v.color('textColor'),
    );
    name.paint(canvas, Offset(left + pad, top + pad * 0.6));
    role.paint(
      canvas,
      Offset(left + pad, top + pad * 0.6 + name.height + 4 * u),
    );
    canvas.restore();
  }
}

class LogoReveal extends TitleTemplate {
  const LogoReveal();

  @override
  String? get brandField => 'accent';

  @override
  String get id => 'logo-reveal';
  @override
  String get name => 'Logo reveal';
  @override
  String get description =>
      'A circle with your logo (or initials) grows, then your name.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 4);
  @override
  List<TemplateField> get fields => const [
    TemplateField('logo', 'Logo (optional)', FieldKind.image, ''),
    TemplateField('name', 'Name', FieldKind.text, 'Your Name'),
    TemplateField('subtitle', 'Subtitle', FieldKind.text, 'Weekly videos'),
    TemplateField('background', 'Background', FieldKind.color, '#0B0D12'),
    TemplateField('accent', 'Accent', FieldKind.color, '#00B894'),
    TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
    TemplateField('font', 'Font', FieldKind.font, 'Playfair Display'),
  ];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = size.height / 1080;
    final out = _outro(t, total);
    canvas.drawRect(Offset.zero & size, Paint()..color = v.color('background'));
    final c = size.center(Offset.zero) - Offset(0, 90 * u);

    final grow = _ease(t, 0, 0.8);
    final r = 130 * u * grow;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = v.color('accent').withValues(alpha: out),
    );
    canvas.drawCircle(
      c,
      r + 14 * u * _ease(t, 0.4, 1.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u
        ..color = v.color('accent').withValues(alpha: 0.5 * out),
    );
    final logo = v.image('logo');
    if (logo != null && r > 0) {
      final inner = Rect.fromCircle(center: c, radius: r * 0.72);
      canvas
        ..save()
        ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      _drawImage(
        canvas,
        logo,
        _contain(logo, inner),
        opacity: _ease(t, 0.3, 0.8) * out,
      );
      canvas.restore();
    } else {
      final ini = _layout(
        initials(v.text('name')),
        _style(v.font('font'), 120 * u, v.color('textColor')),
        260 * u,
      );
      _drawText(canvas, ini, c, opacity: _ease(t, 0.4, 0.9) * out);
    }

    final name = _layout(
      v.text('name'),
      _style(v.font('font'), 84 * u, v.color('textColor')),
      size.width * 0.85,
    );
    final a = _ease(t, 0.8, 1.4);
    _drawText(
      canvas,
      name,
      c + Offset(0, 230 * u),
      opacity: a * out,
      dy: (1 - a) * 30 * u,
    );
    final sub = _layout(
      v.text('subtitle'),
      _style(
        'Inter',
        38 * u,
        v.color('textColor').withValues(alpha: 0.75),
        weight: 400,
      ),
      size.width * 0.85,
    );
    final b = _ease(t, 1.0, 1.6);
    _drawText(
      canvas,
      sub,
      c + Offset(0, 320 * u),
      opacity: b * out,
      dy: (1 - b) * 20 * u,
    );
  }
}
