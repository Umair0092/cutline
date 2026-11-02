// Renders the app icons from the logo the splash screen draws.
// Run with tool/make_icons.sh, which also makes the .ico and the size set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cutline/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(String path, int size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('make icons', () async {
    final out = Platform.environment['ICON_DIR'] ?? 'build/icons';
    // macOS: Apple's grid puts the shape at 824 of 1024 px, with room for
    // a soft shadow.
    await _write('$out/macos-1024.png', 1024, (c) {
      const inset = 100.0;
      final shape = RRect.fromRectAndRadius(
        const Rect.fromLTWH(inset, inset, 824, 824),
        const Radius.circular(824 * 0.24),
      );
      c.drawRRect(
        shape.shift(const Offset(0, 10)),
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      c.translate(inset, inset);
      paintCutlineLogo(c, const Size.square(824));
    });
    // Windows and the README: the logo edge to edge.
    await _write('$out/full-1024.png', 1024, (c) {
      paintCutlineLogo(c, const Size.square(1024));
    });
  });
}
