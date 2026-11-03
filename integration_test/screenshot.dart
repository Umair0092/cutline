import 'dart:io';
import 'dart:ui' as ui;

import 'package:cutline/ui/widgets/cut_widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the SCREENSHOT_DIR environment variable is set, saves what the app
/// window shows to `<SCREENSHOT_DIR>/<name>.png`.
/// With [settle] false it doesn't wait for animations to finish (for
/// screens with a spinner that keeps going).
Future<void> saveScreenshot(
  WidgetTester tester,
  String name, {
  bool settle = true,
}) async {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null) return;
  // Capturing a frame offscreen while backdrop blurs sit over the video
  // texture can stall for good, so glass is drawn without blur while the
  // picture is taken (it looks almost the same on these dark surfaces).
  GlassPanel.debugNoBlur.value = true;
  await tester.pump();
  try {
    await _save(tester, dir, name, settle);
  } finally {
    GlassPanel.debugNoBlur.value = false;
  }
}

Future<void> _save(
  WidgetTester tester,
  String dir,
  String name,
  bool settle,
) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & view.flutterView.physicalSize,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
