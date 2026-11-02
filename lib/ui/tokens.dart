import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Cutline's design tokens ("Studio Glow"): every colour, size, radius and
/// motion value the UI uses. Widgets read these instead of picking their
/// own, so the whole app stays one system.
///
/// Dark-mode depth comes from lighter surfaces, white-alpha strokes and a
/// faint top highlight, the way Linear and Apple's pro apps do it, not from
/// shadows alone (which barely show on near-black).
abstract final class Cut {
  // Surfaces: an "ink" ramp with a slight violet tint, evenly spaced.
  static const canvas = Color(0xFF0B0A10); // behind the video, splash
  static const base = Color(0xFF111017); // window background
  static const surface1 = Color(0xFF17161F); // side panels, timeline
  static const surface2 = Color(0xFF1E1C28); // cards, inputs, rows
  static const surface3 = Color(0xFF262433); // raised, hovered, menus
  static const surface4 = Color(0xFF302D3F); // popovers, selected rows
  static const scrim = Color(0xA305040A); // modal barrier, 64%

  // Strokes and highlights: white with alpha, so they work on any surface.
  static const strokeSubtle = Color(0x0FFFFFFF); // 6%
  static const strokeDefault = Color(0x1AFFFFFF); // 10%
  static const strokeStrong = Color(0x29FFFFFF); // 16%
  static const highlightTop = Color(0x12FFFFFF); // 7%, light from above
  static const hover = Color(0x0AFFFFFF); // 4%
  static const pressed = Color(0x14FFFFFF); // 8%
  static const focusRing = Color(0xFF9F86FF);

  // Text.
  static const textPrimary = Color(0xFFF3F1F8);
  static const textSecondary = Color(0xFFB3ADC4);
  static const textTertiary = Color(0xFF7F7990);
  static const textDisabled = Color(0xFF524D60);

  // Accent: what you can press.
  static const accent = Color(0xFF8B6DFF);
  static const accentHover = Color(0xFF9C82FF);
  static const accentPressed = Color(0xFF7656F2);
  static const accentContainer = Color(0xFF2A2155);
  static const onAccentContainer = Color(0xFFDCD3FF);

  /// The playhead, recording and cut marks.
  static const marker = Color(0xFFFF4F9A);

  // Semantic colours, each with a dark container to sit on.
  static const success = Color(0xFF3DD68C);
  static const successContainer = Color(0xFF10301F);
  static const warning = Color(0xFFFFB547);
  static const warningContainer = Color(0xFF36270C);
  static const error = Color(0xFFFF5D6C);
  static const errorContainer = Color(0xFF3A1218);
  static const info = Color(0xFF4CB8FF);
  static const infoContainer = Color(0xFF0D2A3C);

  // Timeline track colours (one per row, after Final Cut's role colours).
  static const trackVideo = Color(0xFF5B8CFF);
  static const trackWave = Color(0xFF33D1C1);
  static const trackTitle = Color(0xFFB486FF);
  static const trackOverlay = Color(0xFFFF7AC8);
  static const trackVoice = Color(0xFFFFB547);
  static const trackMusic = Color(0xFF7ED957);

  /// The AI's signature gradient. Only for AI: the sparkle, Ask AI, the
  /// composer while it works, edits the AI made.
  static const aurora = [
    Color(0xFF6E5BFF),
    Color(0xFFB14DFF),
    Color(0xFFFF4F9A),
    Color(0xFFFF9F5A),
  ];
  static const auroraStops = [0.0, 0.38, 0.72, 1.0];
  static const auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: aurora,
    stops: auroraStops,
  );
}

/// Font families.
abstract final class CutFonts {
  /// Headings and the wordmark: a grotesque with character.
  static const display = 'Bricolage Grotesque';

  /// Everything else.
  static const ui = 'Inter';

  /// Timecodes and durations, so digits don't jump around.
  static const mono = 'JetBrains Mono';
}

/// The type scale.
abstract final class CutType {
  static TextStyle _s(
    String family,
    double size,
    double height,
    double weight, {
    double tracking = 0,
    Color color = Cut.textPrimary,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height / size,
    letterSpacing: tracking * size,
    color: color,
    fontWeight: _weight(weight),
    fontVariations: [FontVariation('wght', weight)],
  );

  static FontWeight _weight(double w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  static final display = _s(CutFonts.display, 40, 44, 700, tracking: -0.02);
  static final displaySm = _s(CutFonts.display, 32, 36, 700, tracking: -0.02);
  static final headline = _s(CutFonts.display, 28, 32, 700, tracking: -0.015);
  static final headlineSm = _s(CutFonts.display, 22, 28, 700, tracking: -0.01);
  static final title = _s(CutFonts.ui, 18, 24, 600, tracking: -0.01);
  static final titleSm = _s(CutFonts.ui, 15, 20, 600, tracking: -0.005);
  static final body = _s(CutFonts.ui, 14, 20, 400);
  static final bodyStrong = _s(CutFonts.ui, 14, 20, 550);
  static final label = _s(CutFonts.ui, 13, 16, 500);
  static final caption = _s(
    CutFonts.ui,
    12,
    16,
    500,
    tracking: 0.01,
    color: Cut.textSecondary,
  );
  static final overline = _s(
    CutFonts.ui,
    11,
    14,
    600,
    tracking: 0.06,
    color: Cut.textTertiary,
  );
  static final timecode = _s(
    CutFonts.mono,
    13,
    16,
    500,
    color: Cut.textSecondary,
  );
}

/// Spacing on a 4 pt grid.
abstract final class CutSpace {
  static const s0 = 2.0;
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s7 = 32.0;
  static const s8 = 40.0;
  static const s9 = 56.0;
  static const s10 = 72.0;
}

/// Corner radii: bigger things get rounder corners; inner = outer - padding.
abstract final class CutRadii {
  static const xs = 6.0; // chips, tags, timeline clips
  static const sm = 8.0; // desktop buttons, inputs, menu items
  static const md = 12.0; // cards
  static const lg = 16.0; // panels, popovers
  static const xl = 20.0; // dialogs
  static const xxl = 28.0; // sheets, the composer
  static const pill = 999.0;
}

/// Motion: exits are faster than entries.
abstract final class CutMotion {
  static const instant = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const enter = Duration(milliseconds: 320);
  static const exit = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 400);
  static const shimmer = Duration(milliseconds: 1400);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const accelerate = Cubic(0.3, 0, 0.8, 0.15);

  static final snappy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 500,
    ratio: 0.85,
  );
  static final bouncy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.65,
  );
}

/// Elevation: a resting card, a hovered card or menu, a popover or dialog.
abstract final class CutShadows {
  static const e1 = [
    BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const e2 = [
    BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const e3 = [
    BoxShadow(color: Color(0x73000000), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 16)),
  ];
}
