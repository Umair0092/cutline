import 'dart:async';

import 'package:flutter/material.dart';

import 'editor_screen.dart';

/// The app's navigator, so menus (which sit above it) can open dialogs and
/// screens.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Called when the editor closes, e.g. to save and refresh the dashboard.
final editorClosed = StreamController<void>.broadcast();

bool _editorOpen = false;

/// Opens the editor over the dashboard, unless it's already showing (or
/// there's no dashboard, as in tests).
Future<void> showEditor() async {
  final nav = appNavigatorKey.currentState;
  if (_editorOpen || nav == null || !_hasDashboard) return;
  _editorOpen = true;
  await nav.push(
    MaterialPageRoute<void>(
      builder: (_) => const EditorScreen(),
      settings: const RouteSettings(name: 'editor'),
    ),
  );
  _editorOpen = false;
  editorClosed.add(null);
}

/// Set by the dashboard while it's the home screen.
bool _hasDashboard = false;
void setHasDashboard(bool value) => _hasDashboard = value;
