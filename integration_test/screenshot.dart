import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the SCREENSHOTS environment variable is set, saves what the app
/// window shows to `<temp>/cutline_screenshots/<name>.png`. On macOS the temp
/// folder is inside the app sandbox container.
Future<void> saveScreenshot(WidgetTester tester, String name) async {
  if (Platform.environment['SCREENSHOTS'] == null) return;
  final dir = Directory('${Directory.systemTemp.path}/cutline_screenshots')
    ..createSync(recursive: true);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & view.flutterView.physicalSize,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
