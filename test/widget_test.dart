import 'package:cutline/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor shows preview, sidebar and timeline', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: CutlineApp()));

    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.byKey(const Key('sidebar')), findsOneWidget);
    expect(find.byKey(const Key('timeline')), findsOneWidget);
  });
}
