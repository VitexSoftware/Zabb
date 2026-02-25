import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the "Close All" popup dismiss functionality.
///
/// These tests verify the close-all behavior using a standalone widget
/// that mirrors the popup stacking logic from ProblemsScreen, without
/// requiring the full Zabbix API / AuthService dependencies.

/// A minimal widget that simulates stacking problem popup dialogs
/// with the same close-all logic as ProblemsScreen._showNewProblemPopup.
class _PopupTestWidget extends StatefulWidget {
  const _PopupTestWidget();

  @override
  State<_PopupTestWidget> createState() => _PopupTestWidgetState();
}

class _PopupTestWidgetState extends State<_PopupTestWidget> {
  int openPopupCount = 0;

  void showProblemPopup(String problemName) {
    setState(() {
      openPopupCount++;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('New Problem Detected'),
        content: Text(problemName),
        actions: [
          if (openPopupCount > 1)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .popUntil((route) => route is! DialogRoute);
                setState(() {
                  openPopupCount = 0;
                });
              },
              child: Text('Close All ($openPopupCount)'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                openPopupCount--;
              });
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Open popups: $openPopupCount'),
            ElevatedButton(
              onPressed: () => showProblemPopup('Test Problem'),
              child: const Text('Show Popup'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Problem popup Close All button', () {
    testWidgets('single popup shows only Dismiss, no Close All',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PopupTestWidget()));

      // Open one popup
      await tester.tap(find.text('Show Popup'));
      await tester.pumpAndSettle();

      // Verify popup is shown
      expect(find.text('New Problem Detected'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      // "Close All" should NOT be visible with only 1 popup
      expect(find.textContaining('Close All'), findsNothing);
    });

    testWidgets('two stacked popups show Close All button on the top one',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PopupTestWidget()));

      // Open first popup
      await tester.tap(find.text('Show Popup'));
      await tester.pumpAndSettle();

      // The dialog covers the button, so we need to access the state directly
      final state = tester.state<_PopupTestWidgetState>(
          find.byType(_PopupTestWidget));

      // Open second popup via state
      state.showProblemPopup('Second Problem');
      await tester.pumpAndSettle();

      // "Close All (2)" should be visible on the topmost popup
      expect(find.text('Close All (2)'), findsOneWidget);
    });

    testWidgets('Close All dismisses all stacked popups',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PopupTestWidget()));

      final state = tester.state<_PopupTestWidgetState>(
          find.byType(_PopupTestWidget));

      // Open three popups
      state.showProblemPopup('Problem 1');
      await tester.pumpAndSettle();
      state.showProblemPopup('Problem 2');
      await tester.pumpAndSettle();
      state.showProblemPopup('Problem 3');
      await tester.pumpAndSettle();

      expect(state.openPopupCount, 3);
      expect(find.text('Close All (3)'), findsOneWidget);

      // Tap "Close All (3)"
      await tester.tap(find.text('Close All (3)'));
      await tester.pumpAndSettle();

      // All dialogs should be dismissed
      expect(find.text('New Problem Detected'), findsNothing);
      expect(state.openPopupCount, 0);

      // Back to main screen
      expect(find.text('Open popups: 0'), findsOneWidget);
    });

    testWidgets('Dismiss closes only the topmost popup',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PopupTestWidget()));

      final state = tester.state<_PopupTestWidgetState>(
          find.byType(_PopupTestWidget));

      // Open two popups
      state.showProblemPopup('Problem 1');
      await tester.pumpAndSettle();
      state.showProblemPopup('Problem 2');
      await tester.pumpAndSettle();

      expect(state.openPopupCount, 2);

      // Dismiss the top popup (last = topmost in the widget tree)
      await tester.tap(find.text('Dismiss').last);
      await tester.pumpAndSettle();

      // One popup should remain
      expect(state.openPopupCount, 1);
      expect(find.text('New Problem Detected'), findsOneWidget);

      // The remaining popup should NOT show "Close All" (only 1 left)
      expect(find.textContaining('Close All'), findsNothing);
    });
  });
}
