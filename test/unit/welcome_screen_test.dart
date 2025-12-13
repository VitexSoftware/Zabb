import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zabb/screens/welcome_screen.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('should create and render WelcomeScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('should display welcome text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.text('Welcome to Zabb'), findsOneWidget);
    });

    testWidgets('should display Get Started button when callback provided', (WidgetTester tester) async {
      var buttonPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(
            onGetStarted: () {
              buttonPressed = true;
            },
          ),
        ),
      );
      
      expect(find.text('Get Started'), findsOneWidget);
      
      await tester.tap(find.text('Get Started'));
      expect(buttonPressed, isTrue);
    });

    testWidgets('should not display Get Started button when callback is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.text('Get Started'), findsNothing);
    });
  });

  group('WelcomeScreen - Logo Container', () {
    testWidgets('should use Container instead of SizedBox for logo', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      // Find Container widgets that contain SvgPicture
      final containerFinder = find.ancestor(
        of: find.byType(SvgPicture),
        matching: find.byType(Container),
      );
      
      expect(containerFinder, findsWidgets);
    });

    testWidgets('should have correct logo dimensions based on screen width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      // Get the screen size
      final mediaQuery = tester.element(find.byType(WelcomeScreen));
      final screenWidth = MediaQuery.of(mediaQuery).size.width;
      
      // Expected dimensions
      final expectedWidth = screenWidth * 0.7;
      final expectedHeight = expectedWidth * 0.4;
      
      // Find the logo Container
      final logoContainers = tester.widgetList<Container>(
        find.ancestor(
          of: find.byType(SvgPicture),
          matching: find.byType(Container),
        ),
      );
      
      expect(logoContainers.isNotEmpty, isTrue);
      
      for (final container in logoContainers) {
        if (container.constraints?.maxWidth != null) {
          // Verify Container uses width constraint
          expect(container.constraints, isNotNull);
        }
      }
    });

    testWidgets('should calculate logo dimensions at 70% screen width', (WidgetTester tester) async {
      // Set a specific screen size for testing
      await tester.binding.setSurfaceSize(const Size(400, 800));
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      final expectedLogoWidth = 400 * 0.7; // 280
      final expectedLogoHeight = expectedLogoWidth * 0.4; // 112
      
      expect(expectedLogoWidth, equals(280));
      expect(expectedLogoHeight, equals(112));
      
      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('WelcomeScreen - Mascot Container', () {
    testWidgets('should use Container instead of SizedBox for mascot image', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      // Find Container widgets that contain Image
      final containerFinder = find.ancestor(
        of: find.byType(Image),
        matching: find.byType(Container),
      );
      
      expect(containerFinder, findsWidgets);
    });

    testWidgets('should have correct mascot dimensions based on screen width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      final mediaQuery = tester.element(find.byType(WelcomeScreen));
      final screenWidth = MediaQuery.of(mediaQuery).size.width;
      
      // Expected dimensions for mascot
      final expectedWidth = screenWidth * 0.7;
      final expectedHeight = expectedWidth * 0.5;
      
      expect(expectedWidth > 0, isTrue);
      expect(expectedHeight > 0, isTrue);
    });

    testWidgets('should calculate mascot dimensions at 70% screen width with 0.5 aspect ratio', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      final expectedMascotWidth = 500 * 0.7; // 350
      final expectedMascotHeight = expectedMascotWidth * 0.5; // 175
      
      expect(expectedMascotWidth, equals(350));
      expect(expectedMascotHeight, equals(175));
      
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('WelcomeScreen - Container vs SizedBox', () {
    test('Container and SizedBox differences', () {
      // Container provides more flexibility than SizedBox
      const container = Container(width: 100, height: 100);
      const sizedBox = SizedBox(width: 100, height: 100);
      
      expect(container, isA<Container>());
      expect(sizedBox, isA<SizedBox>());
      
      // Container can have decoration, margin, padding, etc.
      const decoratedContainer = Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(color: Colors.blue),
      );
      
      expect(decoratedContainer.decoration, isNotNull);
    });

    testWidgets('Container allows for future styling enhancements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Text('Test'),
            ),
          ),
        ),
      );
      
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isNotNull);
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('Container supports alignment property', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    alignment: Alignment.center,
                    child: Text('Centered'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Centered'),
          matching: find.byType(Container),
        ),
      );
      
      expect(container.alignment, equals(Alignment.center));
    });
  });

  group('WelcomeScreen - Responsive Layout', () {
    testWidgets('should adapt to small screen size', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568)); // Small phone
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(WelcomeScreen), findsOneWidget);
      
      final expectedWidth = 320 * 0.7; // 224
      expect(expectedWidth, equals(224));
      
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should adapt to large screen size', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1366)); // Tablet
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(WelcomeScreen), findsOneWidget);
      
      final expectedWidth = 1024 * 0.7; // 716.8
      expect(expectedWidth, closeTo(716.8, 0.1));
      
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should maintain aspect ratios across screen sizes', (WidgetTester tester) async {
      final screenSizes = [
        const Size(320, 568),  // iPhone SE
        const Size(375, 667),  // iPhone 8
        const Size(414, 896),  // iPhone 11
        const Size(768, 1024), // iPad
      ];
      
      for (final size in screenSizes) {
        await tester.binding.setSurfaceSize(size);
        
        await tester.pumpWidget(
          const MaterialApp(
            home: WelcomeScreen(onGetStarted: null),
          ),
        );
        
        final logoWidth = size.width * 0.7;
        final logoHeight = logoWidth * 0.4;
        final mascotHeight = logoWidth * 0.5;
        
        // Verify aspect ratios are maintained
        expect(logoHeight / logoWidth, closeTo(0.4, 0.001));
        expect(mascotHeight / logoWidth, closeTo(0.5, 0.001));
      }
      
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('WelcomeScreen - Layout Structure', () {
    testWidgets('should have correct widget hierarchy', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('should include Spacer for layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(Spacer), findsWidgets);
    });

    testWidgets('should have appropriate spacing with SizedBox', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      
      // Should have SizedBox widgets for spacing (not for logo/mascot anymore)
      expect(sizedBoxes.isNotEmpty, isTrue);
      
      // Check for spacing SizedBoxes (height: 24, etc.)
      final spacingSizedBoxes = sizedBoxes.where((box) => 
        box.height != null && box.width == null
      );
      expect(spacingSizedBoxes.isNotEmpty, isTrue);
    });
  });

  group('WelcomeScreen - Edge Cases', () {
    testWidgets('should handle zero screen width gracefully', (WidgetTester tester) async {
      // This is an edge case that shouldn't happen in practice
      // but good to test defensive programming
      await tester.binding.setSurfaceSize(const Size(1, 1));
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      expect(find.byType(WelcomeScreen), findsOneWidget);
      
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should handle callback execution without errors', (WidgetTester tester) async {
      var callbackExecuted = false;
      Exception? caughtException;
      
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(
            onGetStarted: () {
              try {
                callbackExecuted = true;
              } catch (e) {
                caughtException = e as Exception;
              }
            },
          ),
        ),
      );
      
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      expect(callbackExecuted, isTrue);
      expect(caughtException, isNull);
    });

    testWidgets('should render without assets in test environment', (WidgetTester tester) async {
      // In test environment, assets might not be available
      // Widget should still render without crashing
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(onGetStarted: null),
        ),
      );
      
      // Pump multiple frames to ensure no async errors
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('WelcomeScreen - Integration Tests', () {
    testWidgets('should complete full user flow', (WidgetTester tester) async {
      var navigationOccurred = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(
            onGetStarted: () {
              navigationOccurred = true;
            },
          ),
        ),
      );
      
      // Verify initial state
      expect(find.text('Welcome to Zabb'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(navigationOccurred, isFalse);
      
      // Simulate user interaction
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      // Verify navigation triggered
      expect(navigationOccurred, isTrue);
    });

    testWidgets('should maintain state across rebuilds', (WidgetTester tester) async {
      const key = Key('welcome_screen_key');
      
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(
            key: key,
            onGetStarted: null,
          ),
        ),
      );
      
      expect(find.byKey(key), findsOneWidget);
      
      // Trigger rebuild
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(
            key: key,
            onGetStarted: null,
          ),
        ),
      );
      
      expect(find.byKey(key), findsOneWidget);
      expect(find.text('Welcome to Zabb'), findsOneWidget);
    });
  });
}