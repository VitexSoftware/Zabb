import 'package:flutter_test/flutter_test.dart';
import 'package:zabb/main.dart';

void main() {
  testWidgets('Welcome screen shows configure button on first run', (WidgetTester tester) async {
    await tester.pumpWidget(const ZabbixApp());
    expect(find.text('Configure Server'), findsOneWidget);
  });
}
