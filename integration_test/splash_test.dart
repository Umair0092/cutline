import 'package:cutline/app.dart';
import 'package:cutline/startup/startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('splash on the real app, then the editor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Hold the splash on screen long enough for a screenshot.
          splashMinimumProvider.overrideWithValue(const Duration(seconds: 3)),
        ],
        child: const CutlineApp(showSplash: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('splash')), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await saveScreenshot(tester, 'splash');

    for (
      var i = 0;
      i < 60 && find.byKey(const Key('splash')).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Drop a video here'), findsOneWidget);
  });
}
