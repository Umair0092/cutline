import 'dart:async';

import 'package:flutter/material.dart';

import 'editor_screen.dart';
import 'tokens.dart';

/// The app's navigator, so menus (which sit above it) can open dialogs and
/// screens.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Called when the editor closes, e.g. to save and refresh the dashboard.
final editorClosed = StreamController<void>.broadcast();

bool _editorOpen = false;

/// Whether the editor is showing over the dashboard.
bool get editorOpen => _editorOpen;

/// Opens the editor over the dashboard, unless it's already showing (or
/// there's no dashboard, as in tests).
Future<void> showEditor() async {
  final nav = appNavigatorKey.currentState;
  if (_editorOpen || nav == null || !_hasDashboard) return;
  _editorOpen = true;
  await nav.push(_EditorRoute());
  _editorOpen = false;
  editorClosed.add(null);
}

/// Set by the dashboard while it's the home screen.
bool _hasDashboard = false;
void setHasDashboard(bool value) => _hasDashboard = value;

/// Dashboard → editor: the editor grows in from slightly smaller while the
/// dashboard recedes (a shared-axis "zoom" in depth). Going back reverses
/// it, a little faster.
class _EditorRoute extends PageRouteBuilder<void> {
  _EditorRoute()
    : super(
        settings: const RouteSettings(name: 'editor'),
        transitionDuration: CutMotion.page,
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const EditorScreen(),
        transitionsBuilder: (context, animation, secondary, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
            return FadeTransition(opacity: animation, child: child);
          }
          final enter = CurvedAnimation(
            parent: animation,
            curve: CutMotion.decelerate,
            reverseCurve: CutMotion.accelerate,
          );
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(enter),
              child: child,
            ),
          );
        },
      );
}
