import 'package:flutter/material.dart';

import 'ui/editor_screen.dart';

class CutlineApp extends StatelessWidget {
  const CutlineApp({super.key});

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
      home: const EditorScreen(),
    );
  }
}
