part of 'templates.dart';

// Templates built around a picture you upload: your logo or a photo.
// Sizes use the frame's short side, so they work for wide and tall video.

double _unit(Size size) => math.min(size.width, size.height) / 1080;

/// An overshooting ease: goes a little past 1, then settles.
double _back(double t, double from, double to, [double overshoot = 1.9]) {
  final x = _clamp01((t - from) / (to - from)) - 1;
  return 1 + (overshoot + 1) * x * x * x + overshoot * x * x;
}

/// A ball dropped onto the floor: 0 at the top, 1 on the floor, with two
/// smaller bounces.
double _bounce(double t, double from, double to) {
  var x = _clamp01((t - from) / (to - from));
  const n = 7.5625;
  const d = 2.75;
  if (x < 1 / d) return n * x * x;
  if (x < 2 / d) return n * (x -= 1.5 / d) * x + 0.75;
  if (x < 2.5 / d) return n * (x -= 2.25 / d) * x + 0.9375;
  return n * (x -= 2.625 / d) * x + 0.984375;
}

/// [image] drawn to fit inside [box] (keeping its shape), centred.
Rect _contain(ui.Image image, Rect box) {
  final k = math.min(box.width / image.width, box.height / image.height);
  return Rect.fromCenter(
    center: box.center,
    width: image.width * k,
    height: image.height * k,
  );
}

/// The part of [image] that fills [box] completely (cropping the rest).
Rect _coverSource(ui.Image image, Size box) {
  final k = math.max(box.width / image.width, box.height / image.height);
  final w = box.width / k;
  final h = box.height / k;
  return Rect.fromLTWH((image.width - w) / 2, (image.height - h) / 2, w, h);
}

Rect _whole(ui.Image image) =>
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

final _smooth = Paint()
  ..filterQuality = FilterQuality.high
  ..isAntiAlias = true;

/// Draws [image] into [dst] at [opacity].
void _drawImage(
  Canvas canvas,
  ui.Image image,
  Rect dst, {
  double opacity = 1,
  Rect? src,
}) {
  if (opacity <= 0) return;
  final paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true
    ..color = Color.fromRGBO(0, 0, 0, _clamp01(opacity));
  canvas.drawImageRect(image, src ?? _whole(image), dst, paint);
}

/// A soft glow in [color] shaped like the picture (its see-through parts
/// stay dark), for logos.
void _glow(
  Canvas canvas,
  ui.Image image,
  Rect dst,
  Color color,
  double sigma,
  double opacity,
) {
  if (opacity <= 0 || sigma <= 0) return;
  canvas.saveLayer(
    dst.inflate(sigma * 3),
    Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: _clamp01(opacity)),
        BlendMode.srcIn,
      ),
  );
  canvas.drawImageRect(image, _whole(image), dst, _smooth);
  canvas.restore();
}

/// When there's no picture yet: a dashed rounded square with a mountain
/// icon, so the layout and motion still show.
void _placeholder(Canvas canvas, Rect box, Color color, double u) {
  final r = RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.18));
  canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.18));
  canvas.drawRRect(
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * u
      ..color = color.withValues(alpha: 0.7),
  );
  final c = box.center;
  final w = box.width * 0.42;
  final path = Path()
    ..moveTo(c.dx - w / 2, c.dy + w * 0.3)
    ..lineTo(c.dx - w * 0.12, c.dy - w * 0.15)
    ..lineTo(c.dx + w * 0.08, c.dy + w * 0.08)
    ..lineTo(c.dx + w * 0.22, c.dy - w * 0.04)
    ..lineTo(c.dx + w / 2, c.dy + w * 0.3)
    ..close();
  canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.8));
  canvas.drawCircle(
    Offset(c.dx + w * 0.22, c.dy - w * 0.3),
    w * 0.09,
    Paint()..color = color.withValues(alpha: 0.8),
  );
}

/// A full-frame background: [base] with a soft pool of [accent] light
/// behind the centre.
void _spotlight(Canvas canvas, Size size, Color base, Color accent, double k) {
  canvas.drawRect(Offset.zero & size, Paint()..color = base);
  final c = size.center(Offset.zero);
  final r = math.max(size.width, size.height) * 0.6;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          accent.withValues(alpha: 0.38 * k),
          accent.withValues(alpha: 0.08 * k),
          accent.withValues(alpha: 0),
        ],
        [0, 0.45, 1],
      ),
  );
}

TextPainter _tracked(String text, TextStyle style, double spacing, double w) =>
    _layout(text, style.copyWith(letterSpacing: spacing), w);

const _logoFields = [
  TemplateField('logo', 'Logo', FieldKind.image, ''),
  TemplateField('name', 'Name', FieldKind.text, 'Your Channel'),
  TemplateField('tagline', 'Tagline', FieldKind.text, 'New videos every week'),
  TemplateField('background', 'Background', FieldKind.color, '#0B0A12'),
  TemplateField('accent', 'Accent', FieldKind.color, '#7B61FF'),
  TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
  TemplateField('font', 'Font', FieldKind.font, 'Inter'),
];

/// Name and tagline under a logo, sliding up from [from] seconds.
void _caption(
  Canvas canvas,
  Size size,
  double t,
  double from,
  Offset top,
  TitleValues v,
  double out,
) {
  final u = _unit(size);
  final name = v.text('name');
  final tag = v.text('tagline');
  final a = _ease(t, from, from + 0.6);
  // Letters start wide apart and close up: a quietly cinematic touch.
  final spacing = (1 - a) * 18 * u;
  final namePainter = _tracked(
    name,
    _style(v.font('font'), 76 * u, v.color('textColor'), weight: 800),
    spacing,
    size.width * 0.9,
  );
  _drawText(
    canvas,
    namePainter,
    top + Offset(0, namePainter.height / 2),
    opacity: a * out,
    dy: (1 - a) * 26 * u,
  );
  if (tag.isEmpty) return;
  final b = _ease(t, from + 0.2, from + 0.8);
  final tagPainter = _layout(
    tag,
    _style(
      'Inter',
      34 * u,
      v.color('textColor').withValues(alpha: 0.72),
      weight: 450,
    ),
    size.width * 0.85,
  );
  _drawText(
    canvas,
    tagPainter,
    top + Offset(0, namePainter.height + 18 * u + tagPainter.height / 2),
    opacity: b * out,
    dy: (1 - b) * 18 * u,
  );
}

/// Your logo spins in with an overshoot, a ring bursts out, then your
/// channel name.
class LogoSpin extends TitleTemplate {
  const LogoSpin();

  @override
  String get id => 'logo-spin';
  @override
  String get name => 'Logo spin';
  @override
  String get description =>
      'Your logo spins in and pops, a ring of light bursts, then your name.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 4);
  @override
  String? get brandField => 'accent';
  @override
  List<TemplateField> get fields => _logoFields;

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = _unit(size);
    final out = _outro(t, total, 0.5);
    final accent = v.color('accent');
    _spotlight(canvas, size, v.color('background'), accent, _ease(t, 0, 1));

    final hasText = v.text('name').isNotEmpty;
    final c = size.center(Offset.zero) - Offset(0, hasText ? 80 * u : 0);
    final grow = _back(t, 0.1, 1.0, 1.6);
    final spin = 1 - _ease(t, 0.1, 1.1);
    final side = 360 * u;
    final exit = 1 - 0.15 * (1 - out);

    // The ring of light at the moment it lands.
    final burst = _ease(t, 0.75, 1.6);
    if (burst > 0 && burst < 1) {
      canvas.drawCircle(
        c,
        side * (0.45 + 0.55 * burst),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * u * (1 - burst)
          ..color = accent.withValues(alpha: 0.9 * (1 - burst)),
      );
      // Sparks flying out.
      for (var i = 0; i < 14; i++) {
        final a = i / 14 * 2 * math.pi + 0.3;
        final d = side * (0.5 + 0.7 * burst);
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * d,
          (6 - 4 * burst) * u,
          Paint()..color = accent.withValues(alpha: 1 - burst),
        );
      }
    }

    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-spin * 2 * math.pi)
      ..scale(math.max(0, grow) * exit)
      ..translate(-c.dx, -c.dy);
    final box = Rect.fromCenter(center: c, width: side, height: side);
    final logo = v.image('logo');
    if (logo != null) {
      final dst = _contain(logo, box);
      _glow(canvas, logo, dst, accent, 28 * u, 0.85 * out);
      _drawImage(canvas, logo, dst, opacity: out);
    } else {
      _placeholder(canvas, box.deflate(side * 0.12), accent, u);
    }
    canvas.restore();

    if (hasText) {
      _caption(canvas, size, t, 1.15, c + Offset(0, side / 2 + 40 * u), v, out);
    }
  }
}

/// Your logo drops in and bounces with a squash, confetti flies, then your
/// name pops in letter by letter.
class LogoPop extends TitleTemplate {
  const LogoPop();

  @override
  String get id => 'logo-pop';
  @override
  String get name => 'Logo bounce';
  @override
  String get description =>
      'Your logo drops in and bounces, with confetti and a playful name.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 4);
  @override
  String? get brandField => 'accent';
  @override
  List<TemplateField> get fields => const [
    TemplateField('logo', 'Logo', FieldKind.image, ''),
    TemplateField('name', 'Name', FieldKind.text, 'Your Channel'),
    TemplateField('tagline', 'Tagline', FieldKind.text, ''),
    TemplateField('background', 'Background', FieldKind.color, '#FFD23F'),
    TemplateField('accent', 'Accent', FieldKind.color, '#FF4F9A'),
    TemplateField('textColor', 'Text', FieldKind.color, '#1B1531'),
    TemplateField('font', 'Font', FieldKind.font, 'Bebas Neue'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = _unit(size);
    final out = _outro(t, total, 0.4);
    final accent = v.color('accent');
    canvas.drawRect(Offset.zero & size, Paint()..color = v.color('background'));

    final hasText = v.text('name').isNotEmpty;
    final floor = size.height / 2 + (hasText ? 60 : 150) * u;
    final side = 320 * u;
    final drop = _bounce(t, 0, 1.1);
    final y = -side + (floor - side / 2 + side) * drop;
    // A quick squash each time it hits the floor (the bounces land at
    // these points of the drop), smaller every time.
    final fall = _clamp01(t / 1.1);
    var impact = 0.0;
    for (final (hit, strength) in [
      (1 / 2.75, 1.0),
      (2 / 2.75, 0.55),
      (2.5 / 2.75, 0.3),
      (1.0, 0.15),
    ]) {
      final d = (fall - hit) / 0.035;
      impact += strength * math.exp(-d * d);
    }
    final squash = 1 - 0.2 * impact.clamp(0.0, 1.0);
    final c = Offset(size.width / 2, y);

    // Its shadow grows as it gets close.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, floor + 16 * u),
        width: side * 0.9 * drop,
        height: 26 * u * drop,
      ),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.18 * out)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * u),
    );

    // Confetti from the first landing.
    final party = _ease(t, 0.36, 1.8);
    if (party > 0) {
      final rnd = math.Random(7);
      for (var i = 0; i < 36; i++) {
        final a = -math.pi * (0.1 + 0.8 * rnd.nextDouble());
        final speed = (500 + 700 * rnd.nextDouble()) * u;
        final x0 = size.width / 2 + (rnd.nextDouble() - 0.5) * side;
        final p = Offset(
          x0 + math.cos(a) * speed * party,
          floor -
              side * 0.3 +
              math.sin(a) * speed * party +
              900 * u * party * party,
        );
        final colors = [accent, v.color('textColor'), const Color(0xFFFFFFFF)];
        canvas
          ..save()
          ..translate(p.dx, p.dy)
          ..rotate(party * 8 * (rnd.nextDouble() - 0.5));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 18 * u, height: 9 * u),
            Radius.circular(2 * u),
          ),
          Paint()..color = colors[i % 3].withValues(alpha: (1 - party) * out),
        );
        canvas.restore();
      }
    }

    canvas
      ..save()
      ..translate(c.dx, c.dy + side / 2)
      ..scale(1 / squash * out, squash * out)
      ..translate(-c.dx, -c.dy - side / 2);
    final box = Rect.fromCenter(center: c, width: side, height: side);
    final logo = v.image('logo');
    if (logo != null) {
      _drawImage(canvas, logo, _contain(logo, box));
    } else {
      _placeholder(canvas, box.deflate(side * 0.1), v.color('textColor'), u);
    }
    canvas.restore();

    if (!hasText) return;
    // The name pops in one letter at a time.
    final letters = v.text('name').toUpperCase().characters.toList();
    final style = _style(
      v.font('font'),
      110 * u,
      v.color('textColor'),
      weight: 800,
    );
    final painters = [for (final l in letters) _layout(l, style, size.width)];
    final width = painters.fold(0.0, (w, p) => w + p.width);
    var x = (size.width - width) / 2;
    final top = floor + 50 * u;
    for (var i = 0; i < painters.length; i++) {
      final k = _back(t, 1.0 + i * 0.05, 1.35 + i * 0.05, 2.4);
      final p = painters[i];
      final cc = Offset(x + p.width / 2, top + p.height / 2);
      if (k > 0) {
        canvas
          ..save()
          ..translate(cc.dx, cc.dy)
          ..scale(k)
          ..translate(-cc.dx, -cc.dy);
        _drawText(canvas, p, cc, opacity: out);
        canvas.restore();
      }
      x += p.width;
    }
    final tag = v.text('tagline');
    if (tag.isNotEmpty) {
      final b = _ease(t, 1.6, 2.1);
      final tp = _layout(
        tag,
        _style('Inter', 36 * u, v.color('textColor'), weight: 600),
        size.width * 0.85,
      );
      _drawText(
        canvas,
        tp,
        Offset(size.width / 2, top + painters.first.height + 30 * u),
        opacity: b * out,
      );
    }
  }
}

/// Cinematic: your logo comes out of a blur, a beam of light sweeps across
/// it, and the name tracks in.
class LogoShine extends TitleTemplate {
  const LogoShine();

  @override
  String get id => 'logo-shine';
  @override
  String get name => 'Logo shine';
  @override
  String get description =>
      'Cinematic: your logo sharpens out of a blur and a light sweeps across '
      'it.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 5);
  @override
  String? get brandField => 'accent';
  @override
  List<TemplateField> get fields => const [
    TemplateField('logo', 'Logo', FieldKind.image, ''),
    TemplateField('name', 'Name', FieldKind.text, 'Your Channel'),
    TemplateField('tagline', 'Tagline', FieldKind.text, 'Presents'),
    TemplateField('background', 'Background', FieldKind.color, '#050507'),
    TemplateField('accent', 'Accent', FieldKind.color, '#F5C26B'),
    TemplateField('textColor', 'Text', FieldKind.color, '#F4F1EA'),
    TemplateField('font', 'Font', FieldKind.font, 'Playfair Display'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = _unit(size);
    final out = _outro(t, total, 0.8);
    final accent = v.color('accent');
    _spotlight(
      canvas,
      size,
      v.color('background'),
      accent,
      0.6 * _ease(t, 0.2, 2) * out,
    );

    final hasText = v.text('name').isNotEmpty;
    final c = size.center(Offset.zero) - Offset(0, hasText ? 70 * u : 0);
    final side = 380 * u;
    final zoom = 0.86 + 0.14 * _ease(t, 0, 2.4) + 0.03 * (t / total);
    final box = Rect.fromCenter(
      center: c,
      width: side * zoom,
      height: side * zoom,
    );
    final sharp = _ease(t, 0, 1.3);
    final logo = v.image('logo');

    canvas.saveLayer(
      null,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 1e-3 + 22 * u * (1 - sharp),
          sigmaY: 1e-3 + 22 * u * (1 - sharp),
        )
        ..color = Color.fromRGBO(0, 0, 0, _clamp01(sharp * 1.4) * out),
    );
    final Rect dst;
    if (logo != null) {
      dst = _contain(logo, box);
      _glow(canvas, logo, dst, accent, 40 * u, 0.35 * sharp);
      _drawImage(canvas, logo, dst);
    } else {
      dst = box.deflate(side * 0.14);
      _placeholder(canvas, dst, accent, u);
    }
    canvas.restore();

    // The light sweep: a bright diagonal band, only where the logo is.
    final sweep = _ease(t, 1.3, 2.3);
    if (sweep > 0 && sweep < 1 && logo != null) {
      final x = dst.left - dst.width * 0.5 + dst.width * 2 * sweep;
      canvas.saveLayer(dst.inflate(4), Paint());
      _drawImage(canvas, logo, dst);
      canvas.drawRect(
        dst.inflate(4),
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = ui.Gradient.linear(
            Offset(x - dst.width * 0.25, dst.top),
            Offset(x + dst.width * 0.25, dst.bottom),
            [
              const Color(0xFFFFFFFF).withValues(alpha: 0),
              const Color(0xFFFFFFFF).withValues(alpha: 0.85),
              const Color(0xFFFFFFFF).withValues(alpha: 0),
            ],
            [0, 0.5, 1],
          ),
      );
      canvas.restore();
    }

    if (hasText) {
      _caption(canvas, size, t, 1.6, c + Offset(0, side / 2 + 40 * u), v, out);
    }
  }
}

/// Your logo small in a corner over the video, like a TV channel's.
class LogoCorner extends TitleTemplate {
  const LogoCorner();

  @override
  String get id => 'logo-corner';
  @override
  String get name => 'Corner logo';
  @override
  String get description =>
      'Your logo small in a corner over the video, like a channel watermark.';
  @override
  bool get fullFrame => false;
  @override
  Duration get defaultDuration => const Duration(seconds: 10);
  @override
  String? get brandField => null;
  @override
  List<TemplateField> get fields => const [
    TemplateField('logo', 'Logo', FieldKind.image, ''),
    TemplateField('corner', 'Corner', FieldKind.text, 'bottom-right'),
    TemplateField('opacity', 'Opacity (0–100)', FieldKind.text, '85'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = _unit(size);
    final logo = v.image('logo');
    if (logo == null) return;
    final p = math.min(_ease(t, 0, 0.6), 1 - _ease(t, total - 0.6, total));
    if (p <= 0) return;
    final opacity =
        (double.tryParse(v.text('opacity')) ?? 85).clamp(10, 100) / 100;
    final corner = v.text('corner');
    final side = 150 * u;
    final margin = 48 * u;
    final left = corner.contains('left');
    final top = corner.contains('top');
    final box = Rect.fromLTWH(
      left ? margin : size.width - margin - side,
      top ? margin : size.height - margin - side,
      side,
      side,
    );
    final dst = _contain(logo, box);
    final k = 0.85 + 0.15 * p;
    canvas
      ..save()
      ..translate(dst.center.dx, dst.center.dy)
      ..scale(k)
      ..translate(-dst.center.dx, -dst.center.dy);
    _drawImage(canvas, logo, dst, opacity: opacity * p);
    canvas.restore();
  }
}

/// A photo as a full-screen shot: a blurred copy fills the frame, the
/// photo itself slowly zooms (the "Ken Burns" move), with a caption.
class PhotoShowcase extends TitleTemplate {
  const PhotoShowcase();

  @override
  String get id => 'photo-showcase';
  @override
  String get name => 'Photo showcase';
  @override
  String get description =>
      'A photo on screen with a slow zoom, a blurred backdrop and a caption.';
  @override
  bool get fullFrame => true;
  @override
  Duration get defaultDuration => const Duration(seconds: 5);
  @override
  String? get brandField => 'accent';
  @override
  List<TemplateField> get fields => const [
    TemplateField('photo', 'Photo', FieldKind.image, ''),
    TemplateField('caption', 'Caption', FieldKind.text, ''),
    TemplateField('subcaption', 'Small text', FieldKind.text, ''),
    TemplateField(
      'motion',
      'Motion (zoom-in, zoom-out, pan)',
      FieldKind.text,
      'zoom-in',
    ),
    TemplateField('accent', 'Accent', FieldKind.color, '#7B61FF'),
    TemplateField('textColor', 'Text', FieldKind.color, '#FFFFFF'),
    TemplateField('font', 'Font', FieldKind.font, 'Inter'),
  ];

  @override
  void paint(Canvas canvas, Size size, double t, double total, TitleValues v) {
    final u = _unit(size);
    final frame = Offset.zero & size;
    canvas.drawRect(frame, Paint()..color = const Color(0xFF0B0A12));
    final photo = v.image('photo');
    final fadeIn = _ease(t, 0, 0.5);
    final out = _outro(t, total, 0.5);
    final k = t / total;

    if (photo != null) {
      // Backdrop: the same photo, filling the frame, blurred and dimmed.
      canvas.saveLayer(
        frame,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 40 * u, sigmaY: 40 * u),
      );
      _drawImage(
        canvas,
        photo,
        frame.inflate(60 * u),
        src: _coverSource(photo, frame.inflate(60 * u).size),
        opacity: fadeIn,
      );
      canvas.restore();
      canvas.drawRect(
        frame,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
      );

      // The photo: contained, rounded, with a soft shadow, slowly moving.
      final motion = v.text('motion');
      final zoom = switch (motion) {
        'zoom-out' => 1.12 - 0.12 * k,
        'pan' => 1.08,
        _ => 1.0 + 0.1 * k,
      };
      final pan = motion == 'pan' ? (k - 0.5) * 0.06 * size.width : 0.0;
      final area = frame.deflate(math.min(size.width, size.height) * 0.07);
      final dst = _contain(photo, area);
      final rr = RRect.fromRectAndRadius(dst, Radius.circular(24 * u));
      canvas.drawRRect(
        rr.shift(Offset(0, 18 * u)),
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.45 * fadeIn)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * u),
      );
      canvas
        ..save()
        ..clipRRect(rr);
      final moving = Rect.fromCenter(
        center: dst.center + Offset(pan, 0),
        width: dst.width * zoom,
        height: dst.height * zoom,
      );
      _drawImage(canvas, photo, moving, opacity: fadeIn);
      canvas.restore();
    } else {
      _placeholder(
        canvas,
        Rect.fromCenter(center: frame.center, width: 320 * u, height: 320 * u),
        v.color('accent'),
        u,
      );
    }

    // Caption on a dark gradient at the bottom.
    final caption = v.text('caption');
    final sub = v.text('subcaption');
    if (caption.isEmpty && sub.isEmpty) {
      if (out < 1) {
        canvas.drawRect(
          frame,
          Paint()..color = const Color(0xFF000000).withValues(alpha: 1 - out),
        );
      }
      return;
    }
    final scrimTop = size.height * 0.62;
    canvas.drawRect(
      Rect.fromLTRB(0, scrimTop, size.width, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, scrimTop),
          Offset(0, size.height),
          [
            const Color(0xFF000000).withValues(alpha: 0),
            const Color(0xFF000000).withValues(alpha: 0.7),
          ],
        ),
    );
    final a = _ease(t, 0.4, 1.0);
    final left = 80 * u;
    var y = size.height - 90 * u;
    if (sub.isNotEmpty) {
      final sp = TextPainter(
        text: TextSpan(
          text: sub,
          style: _style(
            'Inter',
            32 * u,
            v.color('textColor').withValues(alpha: 0.8),
            weight: 450,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: size.width - left * 2);
      y -= sp.height;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, _ease(t, 0.6, 1.2) * out),
      );
      sp.paint(canvas, Offset(left, y));
      canvas.restore();
      y -= 10 * u;
    }
    if (caption.isNotEmpty) {
      final cp = TextPainter(
        text: TextSpan(
          text: caption,
          style: _style(
            v.font('font'),
            64 * u,
            v.color('textColor'),
            weight: 800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: size.width - left * 2);
      y -= cp.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y - 22 * u, 90 * u * a, 8 * u),
          Radius.circular(4 * u),
        ),
        Paint()..color = v.color('accent').withValues(alpha: out),
      );
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a * out));
      cp.paint(canvas, Offset(left + (1 - a) * 30 * u, y));
      canvas.restore();
    }
    if (out < 1) {
      canvas.drawRect(
        frame,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 1 - out),
      );
    }
  }
}
