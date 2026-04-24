import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/main.dart';

void main() {
  group('Root routing', () {
    testWidgets('shows WelcomeScreen when not configured',
        (WidgetTester tester) async {
      // Use a tall viewport so image-heavy screens don't overflow.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({'zbx_configured': false});
      await tester.pumpWidget(const ZabbixApp());
      await tester.pumpAndSettle();
      expect(find.text('Configure Server'), findsOneWidget);
    });

    testWidgets('shows LoginScreen when already configured',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'zbx_configured': true});
      await tester.pumpWidget(const ZabbixApp());
      await tester.pumpAndSettle();
      expect(find.text('Login to Zabbix'), findsOneWidget);
    });
  });
}
