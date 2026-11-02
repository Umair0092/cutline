import 'package:cutline/ai/api_key_store.dart';
import 'package:cutline/app.dart';
import 'package:cutline/editing/project_editor.dart';
import 'package:cutline/preview/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/fake_claude.dart';
import '../fake_preview.dart';
import '../fixtures.dart';

void main() {
  // A Pixel 8 in portrait: 1080 x 2400 pixels at 2.625x.
  Future<ProviderContainer> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
        previewProvider.overrideWithValue(FakePreviewController()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CutlineApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('phone: video on top, timeline below, no desktop menu bar', (
    tester,
  ) async {
    final container = await pumpPhone(tester);
    expect(find.byKey(const Key('compact-top-bar')), findsOneWidget);
    expect(find.byType(MenuBar), findsNothing);
    expect(find.byKey(const Key('sidebar')), findsNothing);

    container.read(projectEditorProvider.notifier).opened(threeClips(), '/p');
    await tester.pumpAndSettle();
    final preview = tester.getRect(find.byKey(const Key('preview')));
    final timeline = tester.getRect(find.byKey(const Key('timeline')));
    expect(preview.width, closeTo(1080 / 2.625, 1));
    expect(timeline.top, greaterThanOrEqualTo(preview.bottom));
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
  });

  testWidgets('phone: the assistant opens in a sheet; the menu has Settings', (
    tester,
  ) async {
    await pumpPhone(tester);
    await tester.tap(find.byKey(const Key('open-assistant')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar')), findsOneWidget);
    expect(find.text('Memes'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // outside the sheet
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('compact-menu')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(PopupMenuItem<VoidCallback>, 'Import Video…'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(PopupMenuItem<VoidCallback>, 'Settings…'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(PopupMenuItem<VoidCallback>, 'Export…'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
