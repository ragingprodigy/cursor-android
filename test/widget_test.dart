import 'package:cursor/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Cursor smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CursorApp());

    expect(find.text('Cursor'), findsOneWidget);
  });
}
