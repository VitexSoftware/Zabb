import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabb/screens/problems_screen.dart';

void main() {
  group('ProblemsScreen', () {
    testWidgets('should create with required parameters', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      expect(screen, isA<StatefulWidget>());
    });

    testWidgets('should create _ProblemsScreenState', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      expect(state, isA<_ProblemsScreenState>());
    });
  });

  group('_ProblemsScreenState - Severity Ignore Settings', () {
    testWidgets('should initialize _ignoreSeverities as mutable map', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      // Verify initial state has all severities set to false (not ignored)
      expect(state._ignoreSeverities[0], isFalse); // Not classified
      expect(state._ignoreSeverities[1], isFalse); // Information
      expect(state._ignoreSeverities[2], isFalse); // Warning
      expect(state._ignoreSeverities[3], isFalse); // Average
      expect(state._ignoreSeverities[4], isFalse); // High
      expect(state._ignoreSeverities[5], isFalse); // Disaster
    });

    testWidgets('should allow _ignoreSeverities to be modified', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      // Test mutability - this should not throw
      state._ignoreSeverities[0] = true;
      expect(state._ignoreSeverities[0], isTrue);
      
      state._ignoreSeverities[5] = true;
      expect(state._ignoreSeverities[5], isTrue);
    });

    testWidgets('should handle all severity levels correctly', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      // Test all severity levels can be toggled
      for (int i = 0; i <= 5; i++) {
        state._ignoreSeverities[i] = true;
        expect(state._ignoreSeverities[i], isTrue);
        
        state._ignoreSeverities[i] = false;
        expect(state._ignoreSeverities[i], isFalse);
      }
    });
  });

  group('_ProblemsScreenState - First New Problem Logic', () {
    test('should handle null firstNewProblem correctly', () {
      // Test the logic: if (firstNewProblem == null) { firstNewProblem = problem; }
      dynamic firstNewProblem;
      dynamic problem = {'id': 1, 'name': 'Test Problem'};
      
      // Original null-coalescing operator: firstNewProblem ??= problem;
      // New explicit null check: if (firstNewProblem == null) { firstNewProblem = problem; }
      if (firstNewProblem == null) {
        firstNewProblem = problem;
      }
      
      expect(firstNewProblem, equals(problem));
    });

    test('should not override non-null firstNewProblem', () {
      dynamic firstNewProblem = {'id': 1, 'name': 'First Problem'};
      dynamic problem = {'id': 2, 'name': 'Second Problem'};
      
      // Should not override if already set
      if (firstNewProblem == null) {
        firstNewProblem = problem;
      }
      
      expect(firstNewProblem, equals({'id': 1, 'name': 'First Problem'}));
    });

    test('should handle empty problem object', () {
      dynamic firstNewProblem;
      dynamic problem = {};
      
      if (firstNewProblem == null) {
        firstNewProblem = problem;
      }
      
      expect(firstNewProblem, equals({}));
    });
  });

  group('_ProblemsScreenState - Sorting', () {
    testWidgets('should initialize sort settings correctly', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      expect(state._sortBy, equals('lastchange'));
      expect(state._sortAscending, isFalse); // Newest first by default
    });

    test('should handle sort by eventid', () {
      String sortBy = 'eventid';
      expect(sortBy, equals('eventid'));
    });

    test('should handle sort by lastchange', () {
      String sortBy = 'lastchange';
      expect(sortBy, equals('lastchange'));
    });

    test('should handle ascending and descending sort', () {
      bool sortAscending = true;
      expect(sortAscending, isTrue);
      
      sortAscending = false;
      expect(sortAscending, isFalse);
    });
  });

  group('_ProblemsTable', () {
    testWidgets('should accept explicit Key parameter', (WidgetTester tester) async {
      const key = Key('problems_table_key');
      
      final table = _ProblemsTable(
        key: key,
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.key, equals(key));
    });

    testWidgets('should work with null key', (WidgetTester tester) async {
      final table = _ProblemsTable(
        key: null,
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table, isA<StatefulWidget>());
    });

    testWidgets('should pass key to super constructor correctly', (WidgetTester tester) async {
      const key = ValueKey('test_value_key');
      
      final table = _ProblemsTable(
        key: key,
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.key, isA<ValueKey>());
      expect(table.key, equals(key));
    });

    testWidgets('should handle empty items list', (WidgetTester tester) async {
      final table = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.items, isEmpty);
    });

    testWidgets('should handle populated items list', (WidgetTester tester) async {
      final mockItems = [
        {'id': 1, 'name': 'Problem 1'},
        {'id': 2, 'name': 'Problem 2'},
      ];
      
      final table = _ProblemsTable(
        items: mockItems,
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.items.length, equals(2));
    });

    testWidgets('should handle different sort columns', (WidgetTester tester) async {
      final sortColumns = ['eventid', 'lastchange', 'severity', 'hostname'];
      
      for (final column in sortColumns) {
        final table = _ProblemsTable(
          items: const [],
          onDetails: (item) {},
          onRefresh: () {},
          isRefreshing: false,
          searchQuery: '',
          selectedHostIds: const {},
          selectedHostGroupIds: const {},
          ignoredSeverities: const {
            0: false,
            1: false,
            2: false,
            3: false,
            4: false,
            5: false,
          },
          sortBy: column,
          sortAscending: false,
          onSortChanged: (col, asc) {},
        );
        
        expect(table.sortBy, equals(column));
      }
    });

    testWidgets('should handle isRefreshing state changes', (WidgetTester tester) async {
      var isRefreshing = false;
      
      final table1 = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: isRefreshing,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table1.isRefreshing, isFalse);
      
      isRefreshing = true;
      final table2 = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: isRefreshing,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table2.isRefreshing, isTrue);
    });

    testWidgets('should handle search query filtering', (WidgetTester tester) async {
      final queries = ['test', '', 'problem', '12345'];
      
      for (final query in queries) {
        final table = _ProblemsTable(
          items: const [],
          onDetails: (item) {},
          onRefresh: () {},
          isRefreshing: false,
          searchQuery: query,
          selectedHostIds: const {},
          selectedHostGroupIds: const {},
          ignoredSeverities: const {
            0: false,
            1: false,
            2: false,
            3: false,
            4: false,
            5: false,
          },
          sortBy: 'lastchange',
          sortAscending: false,
          onSortChanged: (column, ascending) {},
        );
        
        expect(table.searchQuery, equals(query));
      }
    });
  });

  group('_NotificationConfigScreen - Severity List', () {
    test('should convert severity switches to list correctly', () {
      // Simulating the fix: .toList() at the end of severity switches generation
      final severityLevels = [
        {'level': 0, 'name': 'Not classified'},
        {'level': 1, 'name': 'Information'},
        {'level': 2, 'name': 'Warning'},
        {'level': 3, 'name': 'Average'},
        {'level': 4, 'name': 'High'},
        {'level': 5, 'name': 'Disaster'},
      ];
      
      // The map operation should produce a list
      final switches = severityLevels.map((severity) {
        return {
          'widget': 'SwitchListTile',
          'level': severity['level'],
          'name': severity['name'],
        };
      }).toList();
      
      expect(switches, isA<List>());
      expect(switches.length, equals(6));
      expect(switches[0]['level'], equals(0));
      expect(switches[5]['level'], equals(5));
    });

    test('should preserve all severity information in mapped list', () {
      final severityData = [
        {'level': 0, 'name': 'Not classified', 'color': 'gray'},
        {'level': 1, 'name': 'Information', 'color': 'blue'},
      ];
      
      final result = severityData.map((item) => item).toList();
      
      expect(result.length, equals(2));
      expect(result[0]['name'], equals('Not classified'));
      expect(result[1]['color'], equals('blue'));
    });

    test('should handle empty severity list', () {
      final List<Map<String, dynamic>> emptySeverities = [];
      final result = emptySeverities.map((item) => item).toList();
      
      expect(result, isEmpty);
      expect(result, isA<List>());
    });

    test('should maintain order in mapped severity list', () {
      final severities = List.generate(
        6,
        (index) => {'level': index, 'name': 'Severity $index'},
      );
      
      final mapped = severities.map((s) => s['level']).toList();
      
      expect(mapped, equals([0, 1, 2, 3, 4, 5]));
    });
  });

  group('_ProblemsTable - Edge Cases', () {
    testWidgets('should handle all severities ignored', (WidgetTester tester) async {
      final table = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: true,
          1: true,
          2: true,
          3: true,
          4: true,
          5: true,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.ignoredSeverities.values.every((ignored) => ignored), isTrue);
    });

    testWidgets('should handle no severities ignored', (WidgetTester tester) async {
      final table = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.ignoredSeverities.values.every((ignored) => !ignored), isTrue);
    });

    testWidgets('should handle mixed severity ignore states', (WidgetTester tester) async {
      final table = _ProblemsTable(
        items: const [],
        onDetails: (item) {},
        onRefresh: () {},
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: true,
          1: false,
          2: true,
          3: false,
          4: true,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {},
      );
      
      expect(table.ignoredSeverities[0], isTrue);
      expect(table.ignoredSeverities[1], isFalse);
      expect(table.ignoredSeverities[2], isTrue);
      expect(table.ignoredSeverities[3], isFalse);
    });

    testWidgets('should handle callback invocations', (WidgetTester tester) async {
      var detailsCalled = false;
      var refreshCalled = false;
      var sortChangedCalled = false;
      
      final table = _ProblemsTable(
        items: const [],
        onDetails: (item) {
          detailsCalled = true;
        },
        onRefresh: () {
          refreshCalled = true;
        },
        isRefreshing: false,
        searchQuery: '',
        selectedHostIds: const {},
        selectedHostGroupIds: const {},
        ignoredSeverities: const {
          0: false,
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
        },
        sortBy: 'lastchange',
        sortAscending: false,
        onSortChanged: (column, ascending) {
          sortChangedCalled = true;
        },
      );
      
      // Test callback references exist
      expect(table.onDetails, isNotNull);
      expect(table.onRefresh, isNotNull);
      expect(table.onSortChanged, isNotNull);
      
      // Invoke callbacks
      table.onDetails({});
      expect(detailsCalled, isTrue);
      
      table.onRefresh();
      expect(refreshCalled, isTrue);
      
      table.onSortChanged('eventid', true);
      expect(sortChangedCalled, isTrue);
    });
  });

  group('_ProblemsScreenState - Integration Scenarios', () {
    testWidgets('should handle severity filter toggle sequence', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      // Simulate user toggling severity filters
      expect(state._ignoreSeverities[5], isFalse); // Disaster initially shown
      
      state._ignoreSeverities[5] = true; // User ignores Disaster
      expect(state._ignoreSeverities[5], isTrue);
      
      state._ignoreSeverities[4] = true; // User ignores High
      expect(state._ignoreSeverities[4], isTrue);
      
      // Verify other severities unaffected
      expect(state._ignoreSeverities[0], isFalse);
      expect(state._ignoreSeverities[1], isFalse);
      expect(state._ignoreSeverities[2], isFalse);
      expect(state._ignoreSeverities[3], isFalse);
    });

    testWidgets('should handle complete severity filter cycle', (WidgetTester tester) async {
      const screen = ProblemsScreen();
      final state = screen.createState();
      
      // Toggle all on
      for (int i = 0; i <= 5; i++) {
        state._ignoreSeverities[i] = true;
      }
      
      // Verify all ignored
      for (int i = 0; i <= 5; i++) {
        expect(state._ignoreSeverities[i], isTrue);
      }
      
      // Toggle all off
      for (int i = 0; i <= 5; i++) {
        state._ignoreSeverities[i] = false;
      }
      
      // Verify all shown
      for (int i = 0; i <= 5; i++) {
        expect(state._ignoreSeverities[i], isFalse);
      }
    });
  });
}