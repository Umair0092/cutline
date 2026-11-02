import 'package:flutter/material.dart';

import 'library/dashboard.dart';
import 'ui/app_menu.dart';
import 'ui/navigation.dart';
import 'onboarding/onboarding.dart';
import 'ui/editor_screen.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

class CutlineApp extends StatelessWidget {
  const CutlineApp({super.key, this.showSplash = false});

  /// The real app starts with the splash screen; tests go straight to the
  /// editor.
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cutline',
      debugShowCheckedModeBanner: false,
      theme: cutlineTheme(),
      darkTheme: cutlineTheme(),
      themeMode: ThemeMode.dark,
      navigatorKey: appNavigatorKey,
      // The menus sit above the navigator so they work on every screen;
      // they get their own overlay for submenus and tooltips.
      builder: (context, child) => Overlay(
        initialEntries: [OverlayEntry(builder: (_) => AppMenu(child: child!))],
      ),
      home: showSplash
          ? const StartupGate(child: FirstRunGuide(child: Dashboard()))
          : const EditorScreen(),
    );
  }
}
