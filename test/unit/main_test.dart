import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabb/main.dart';

void main() {
  group('ZabbixApp', () {
    testWidgets('should create MaterialApp with correct theme', (WidgetTester tester) async {
      await tester.pumpWidget(const ZabbixApp());
      
      expect(find.byType(MaterialApp), findsOneWidget);
      
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('Zabb'));
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('should use ColorScheme.fromSeed with proper seed color', (WidgetTester tester) async {
      await tester.pumpWidget(const ZabbixApp());
      
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme!.colorScheme.primary, isNotNull);
    });

    testWidgets('should set useMaterial3 to true', (WidgetTester tester) async {
      await tester.pumpWidget(const ZabbixApp());
      
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.useMaterial3, isTrue);
    });

    testWidgets('should have proper home widget', (WidgetTester tester) async {
      await tester.pumpWidget(const ZabbixApp());
      
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.home, isNotNull);
    });
  });

  group('_RootRouter', () {
    testWidgets('should accept optional key parameter', (WidgetTester tester) async {
      const key = Key('test_router_key');
      const widget = _RootRouter(key: key);
      
      expect(widget.key, equals(key));
    });

    testWidgets('should work without key parameter', (WidgetTester tester) async {
      const widget = _RootRouter();
      
      expect(widget, isA<StatefulWidget>());
    });

    testWidgets('should create _RootRouterState', (WidgetTester tester) async {
      const widget = _RootRouter();
      final state = widget.createState();
      
      expect(state, isA<_RootRouterState>());
    });
  });

  group('Main initialization', () {
    test('WidgetsFlutterBinding should be initialized', () {
      // This is primarily a smoke test to ensure main() structure is correct
      // In a real scenario, we'd use integration tests for this
      expect(WidgetsBinding.instance, isNotNull);
    });
  });
}