import 'package:flutter/material.dart';

import 'ui/app_menu.dart';
import 'ui/editor_screen.dart';
import 'ui/splash_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: showSplash
          ? const StartupGate(child: AppMenu(child: EditorScreen()))
          : const AppMenu(child: EditorScreen()),
    );
  }
}
