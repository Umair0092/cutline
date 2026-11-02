import 'package:flutter/material.dart';

/// Cutline's "cutting room" palette: quiet violet-graphite surfaces so the
/// video is always the brightest thing on screen. Violet marks anything
/// you can act on; pink is kept for the playhead, recording and cut marks.
abstract final class Palette {
  static const room = Color(0xFF15131C); // the background
  static const bench = Color(0xFF1E1B28); // panels, cards, sheets
  static const benchHigh = Color(0xFF262233); // raised controls
  static const rule = Color(0xFF2E2A3B); // 1 px lines
  static const paper = Color(0xFFECE8F4); // text
  static const dust = Color(0xFF9A93AD); // muted text
  static const cut = Color(0xFF7B61FF); // actions
  static const marker = Color(0xFFFF4F9A); // playhead, record, cut marks
}

/// Corner radii grow with the size of the thing.
abstract final class Radii {
  static const chip = 8.0;
  static const control = 12.0;
  static const card = 14.0;
  static const sheet = 24.0;
}

/// The wordmark and the dashboard's big heading use Bebas Neue, which reads
/// like the lettering on a film slate. Everything else is Inter.
const displayFont = 'Bebas Neue';

ThemeData cutlineTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.cut,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF3A2F7A),
    onPrimaryContainer: Palette.paper,
    secondary: Palette.marker,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF3B2A44),
    onSecondaryContainer: Palette.paper,
    tertiary: Color(0xFFB9A8FF),
    tertiaryContainer: Color(0xFF4A3B6E),
    error: Color(0xFFFF6B6B),
    surface: Palette.room,
    onSurface: Palette.paper,
    onSurfaceVariant: Palette.dust,
    surfaceContainerLowest: Color(0xFF0F0D15),
    surfaceContainerLow: Color(0xFF19171F),
    surfaceContainer: Palette.bench,
    surfaceContainerHigh: Palette.benchHigh,
    surfaceContainerHighest: Color(0xFF302B40),
    outline: Color(0xFF4A445C),
    outlineVariant: Palette.rule,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Palette.room,
    visualDensity: VisualDensity.standard,
  );
  OutlinedBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.paper,
      displayColor: Palette.paper,
    ),
    dividerTheme: const DividerThemeData(color: Palette.rule, space: 1),
    cardTheme: CardThemeData(
      color: Palette.bench,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: Palette.rule),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded(Radii.control),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded(Radii.control),
        side: const BorderSide(color: Palette.rule),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: rounded(Radii.control)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.bench,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: const BorderSide(color: Palette.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: const BorderSide(color: Palette.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: const BorderSide(color: Palette.cut, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.bench,
      shape: rounded(Radii.sheet),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.bench,
      dragHandleColor: Color(0xFF4A445C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.benchHigh,
      contentTextStyle: const TextStyle(color: Palette.paper),
      shape: rounded(Radii.control),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: rounded(Radii.chip),
      side: const BorderSide(color: Palette.rule),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 3,
      inactiveTrackColor: Palette.rule,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    tabBarTheme: const TabBarThemeData(
      dividerColor: Palette.rule,
      labelColor: Palette.paper,
      unselectedLabelColor: Palette.dust,
      indicatorColor: Palette.cut,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Palette.benchHigh,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: Palette.rule),
      ),
      textStyle: const TextStyle(color: Palette.paper, fontSize: 12),
    ),
  );
}
