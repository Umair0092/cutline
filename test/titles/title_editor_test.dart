import 'package:cutline/model/title_item.dart';
import 'package:cutline/titles/title_actions.dart';
import 'package:cutline/titles/title_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TitleEdit?> open(WidgetTester tester, {TitleSpec? initial}) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TitleEdit? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showTitleEditor(context, initial: initial),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return result;
  }

  testWidgets('fill in the name and colour, choose placement, add', (
    tester,
  ) async {
    TitleEdit? result;
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showTitleEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const Key('field-title')),
      'Weekly Rails Tips',
    );
    await tester.enterText(find.byKey(const Key('field-subtitle')), 'by Umair');
    await tester.tap(find.byKey(const Key('swatch-accent-#00B894')));
    await tester.tap(find.text('Over the start'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('title-save')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(result!.placement, TitlePlacement.over);
    expect(result!.spec.templateId, 'clean-card');
    expect(result!.spec.fields, {
      'title': 'Weekly Rails Tips',
      'subtitle': 'by Umair',
      'accent': '#00B894',
    });
    expect(result!.spec.duration, const Duration(seconds: 4));
  });

  testWidgets('editing keeps the values and hides placement', (tester) async {
    await open(
      tester,
      initial: const TitleSpec(
        templateId: 'lower-third',
        fields: {'name': 'Umair Hassan'},
        duration: Duration(seconds: 5),
      ),
    );
    expect(find.text('Edit title'), findsOneWidget);
    expect(find.text('Before the video'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('field-name')))
          .controller!
          .text,
      'Umair Hassan',
    );
  });
}
