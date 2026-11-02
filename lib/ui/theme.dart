import 'dart:io';

import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Old names, kept so older screens still read sensibly. New code uses
/// [Cut] directly.
abstract final class Palette {
  static const room = Cut.base;
  static const bench = Cut.surface1;
  static const benchHigh = Cut.surface3;
  static const rule = Cut.strokeDefault;
  static const paper = Cut.textPrimary;
  static const dust = Cut.textSecondary;
  static const cut = Cut.accent;
  static const marker = Cut.marker;
}

abstract final class Radii {
  static const chip = CutRadii.sm;
  static const control = CutRadii.md;
  static const card = CutRadii.lg;
  static const sheet = CutRadii.xxl;
}

/// The wordmark and big headings.
const displayFont = CutFonts.display;

/// Phones get touch ripples; desktops get quiet hover and press states.
final bool _touch = Platform.isAndroid || Platform.isIOS;

ThemeData cutlineTheme() {
  const scheme = ColorScheme.dark(
    primary: Cut.accent,
    onPrimary: Colors.white,
    primaryContainer: Cut.accentContainer,
    onPrimaryContainer: Cut.onAccentContainer,
    secondary: Cut.marker,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF3B1A33),
    onSecondaryContainer: Cut.textPrimary,
    tertiary: Color(0xFFC6B6FF),
    onTertiary: Cut.canvas,
    tertiaryContainer: Color(0xFF3A2F66),
    onTertiaryContainer: Cut.onAccentContainer,
    error: Cut.error,
    onError: Colors.white,
    errorContainer: Cut.errorContainer,
    onErrorContainer: Color(0xFFFFC9CF),
    surface: Cut.base,
    onSurface: Cut.textPrimary,
    onSurfaceVariant: Cut.textSecondary,
    surfaceDim: Cut.canvas,
    surfaceBright: Cut.surface4,
    surfaceContainerLowest: Cut.canvas,
    surfaceContainerLow: Cut.surface1,
    surfaceContainer: Cut.surface2,
    surfaceContainerHigh: Cut.surface3,
    surfaceContainerHighest: Cut.surface4,
    outline: Cut.strokeStrong,
    outlineVariant: Cut.strokeDefault,
    inverseSurface: Cut.textPrimary,
    onInverseSurface: Cut.base,
    shadow: Colors.black,
    scrim: Cut.scrim,
  );

  final text = TextTheme(
    displayLarge: CutType.display,
    displayMedium: CutType.display,
    displaySmall: CutType.displaySm,
    headlineLarge: CutType.headline,
    headlineMedium: CutType.headline,
    headlineSmall: CutType.headlineSm,
    titleLarge: CutType.title,
    titleMedium: CutType.titleSm,
    titleSmall: CutType.titleSm.copyWith(fontSize: 14),
    bodyLarge: CutType.body.copyWith(fontSize: 15, height: 22 / 15),
    bodyMedium: CutType.body,
    bodySmall: CutType.caption,
    labelLarge: CutType.label.copyWith(fontSize: 14),
    labelMedium: CutType.label,
    labelSmall: CutType.overline.copyWith(letterSpacing: 0.3),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: CutFonts.ui,
    scaffoldBackgroundColor: Cut.base,
    canvasColor: Cut.base,
    visualDensity: _touch ? VisualDensity.standard : VisualDensity.compact,
    splashFactory: _touch ? InkSparkle.splashFactory : NoSplash.splashFactory,
    hoverColor: Cut.hover,
    highlightColor: _touch ? Colors.transparent : Cut.pressed,
    splashColor: _touch ? const Color(0x22FFFFFF) : Colors.transparent,
    focusColor: const Color(0x339F86FF),
    textTheme: text,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );

  OutlinedBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  final controlRadius = _touch ? CutRadii.md : CutRadii.sm;
  final controlHeight = _touch ? 48.0 : 36.0;

  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    dividerTheme: const DividerThemeData(
      color: Cut.strokeSubtle,
      space: 1,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: Cut.textSecondary, size: 20),
    cardTheme: CardThemeData(
      color: Cut.surface2,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CutRadii.lg),
        side: const BorderSide(color: Cut.strokeSubtle),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            minimumSize: Size(64, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: rounded(controlRadius),
            textStyle: CutType.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.disabled)) return Cut.surface3;
              if (s.contains(WidgetState.pressed)) return Cut.accentPressed;
              if (s.contains(WidgetState.hovered)) return Cut.accentHover;
              return Cut.accent;
            }),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(64, controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: rounded(controlRadius),
        foregroundColor: Cut.textPrimary,
        side: const BorderSide(color: Cut.strokeStrong),
        textStyle: CutType.label.copyWith(fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(48, controlHeight),
        foregroundColor: Cut.onAccentContainer,
        shape: rounded(controlRadius),
        textStyle: CutType.label.copyWith(fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Cut.textSecondary,
        shape: rounded(controlRadius),
        hoverColor: Cut.hover,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Cut.surface2,
        selectedBackgroundColor: Cut.surface4,
        selectedForegroundColor: Cut.textPrimary,
        foregroundColor: Cut.textSecondary,
        side: const BorderSide(color: Cut.strokeSubtle),
        shape: rounded(CutRadii.pill),
        textStyle: CutType.label,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Cut.surface2,
      hoverColor: Cut.surface3,
      isDense: !_touch,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: CutType.body.copyWith(color: Cut.textTertiary),
      labelStyle: CutType.body.copyWith(color: Cut.textSecondary),
      floatingLabelStyle: CutType.caption.copyWith(color: Cut.accentHover),
      prefixIconColor: Cut.textTertiary,
      suffixIconColor: Cut.textTertiary,
      border: field(Cut.strokeSubtle),
      enabledBorder: field(Cut.strokeSubtle),
      focusedBorder: field(Cut.accent, 1.5),
      errorBorder: field(Cut.error),
      disabledBorder: field(Colors.transparent),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Cut.surface2,
      surfaceTintColor: Colors.transparent,
      barrierColor: Cut.scrim,
      elevation: 0,
      titleTextStyle: CutType.headlineSm,
      contentTextStyle: CutType.body.copyWith(color: Cut.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _touch ? CutRadii.xxl : CutRadii.xl,
        ),
        side: const BorderSide(color: Cut.strokeDefault),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Cut.surface1,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Cut.scrim,
      dragHandleColor: Cut.strokeStrong,
      dragHandleSize: Size(36, 4),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CutRadii.xxl)),
        side: BorderSide(color: Cut.strokeSubtle),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cut.surface4,
      elevation: 0,
      contentTextStyle: CutType.body,
      actionTextColor: Cut.accentHover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CutRadii.md),
        side: const BorderSide(color: Cut.strokeDefault),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Cut.surface2,
      selectedColor: Cut.accentContainer,
      labelStyle: CutType.label.copyWith(color: Cut.textPrimary),
      shape: rounded(CutRadii.pill),
      side: const BorderSide(color: Cut.strokeDefault),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      activeTrackColor: Cut.accent,
      inactiveTrackColor: Cut.surface4,
      thumbColor: Colors.white,
      overlayColor: const Color(0x228B6DFF),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 8,
        elevation: 2,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      valueIndicatorColor: Cut.surface4,
      valueIndicatorTextStyle: CutType.timecode.copyWith(
        color: Cut.textPrimary,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.white : Cut.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Cut.accent : Cut.surface4,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: rounded(CutRadii.xs / 1.5),
      side: const BorderSide(color: Cut.strokeStrong, width: 1.5),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelColor: Cut.textPrimary,
      unselectedLabelColor: Cut.textTertiary,
      labelStyle: CutType.titleSm.copyWith(fontSize: 13),
      unselectedLabelStyle: CutType.label,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: Cut.surface4,
        borderRadius: BorderRadius.circular(CutRadii.pill),
        border: Border.all(color: Cut.strokeSubtle),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: Cut.surface4,
        borderRadius: BorderRadius.circular(CutRadii.sm),
        border: Border.all(color: Cut.strokeDefault),
        boxShadow: CutShadows.e2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: CutType.caption.copyWith(color: Cut.textPrimary),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Cut.surface3),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Cut.strokeDefault),
        ),
        shape: WidgetStatePropertyAll(rounded(CutRadii.md)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        shape: rounded(CutRadii.sm),
        textStyle: CutType.body,
        minimumSize: const Size(160, 34),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Cut.surface3,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CutRadii.md),
        side: const BorderSide(color: Cut.strokeDefault),
      ),
      textStyle: CutType.body,
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded(CutRadii.md),
      iconColor: Cut.textSecondary,
      titleTextStyle: CutType.bodyStrong,
      subtitleTextStyle: CutType.caption,
      minVerticalPadding: 10,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Cut.accent,
      linearTrackColor: Cut.surface4,
      circularTrackColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Cut.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      extendedTextStyle: CutType.label.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      shape: rounded(CutRadii.xl),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Cut.surface1,
      indicatorColor: Cut.accentContainer,
      labelTextStyle: WidgetStatePropertyAll(CutType.caption),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(6),
      radius: Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(Cut.strokeStrong),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Cut.accent,
      selectionColor: Color(0x558B6DFF),
      selectionHandleColor: Cut.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Cut.base,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: CutType.title,
      foregroundColor: Cut.textPrimary,
    ),
  );
}
