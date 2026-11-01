import 'package:cutline/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'screenshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app opens the editor', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CutlineApp()));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);
    await saveScreenshot(tester, 'editor');
  });
}
