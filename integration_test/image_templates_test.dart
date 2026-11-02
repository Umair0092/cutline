import 'dart:io';
import 'dart:ui' as ui;

import 'package:cutline/model/title_item.dart';
import 'package:cutline/titles/templates.dart';
import 'package:cutline/titles/title_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Renders the picture templates at a few moments, with a real logo and
/// photo, into SCREENSHOT_DIR for a visual check.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['SCREENSHOT_DIR'];
  final media = '${Directory.current.path}/test_media';

  testWidgets('picture templates draw the logo and photo', (tester) async {
    await tester.runAsync(() async {
      for (final tpl in titleTemplates) {
        final picture = tpl.fields.where((f) => f.kind == FieldKind.image);
        if (picture.isEmpty) continue;
        final key = picture.first.key;
        final spec = TitleSpec(
          templateId: tpl.id,
          fields: {
            key: key == 'photo' ? '$media/photo.jpg' : '$media/logo.png',
            'name': 'Umair Codes',
            'caption': 'Sunset in Hunza',
            'subcaption': 'Gilgit-Baltistan, 2026',
          },
          duration: tpl.defaultDuration,
        );
        final total = tpl.defaultDuration.inMilliseconds / 1000;
        for (final t in [0.4, 0.9, 1.4, 2.0, total - 0.2]) {
          for (final (w, h) in [(1280, 720), (720, 1280)]) {
            if (h > w && t != 2.0) continue;
            final image = await renderTitleFrame(spec, w, h, t);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            expect(png, isNotNull);
            if (dir != null) {
              File('$dir/pic-${tpl.id}-${w}x$h-${t.toStringAsFixed(1)}.png')
                  .writeAsBytesSync(png!.buffer.asUint8List());
            }
          }
        }
      }
    });
  });
}
