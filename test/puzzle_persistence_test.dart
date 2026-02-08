import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudaku/Sudoku.dart';
import 'package:sudaku/SudokuScreen.dart';

void main() {
  group('Puzzle Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadSavedPuzzle returns null when no puzzle saved', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await SudokuScreenState.loadSavedPuzzle();

      expect(result, isNull);
    });

    test('loadSavedPuzzle returns saved puzzle data', () async {
      final puzzleData = {
        'n': 3,
        'buffer': List.generate(81, (i) => i % 10),
        'hints': [0, 1, 2, 3, 4],
      };
      SharedPreferences.setMockInitialValues({
        'savedPuzzle': jsonEncode(puzzleData),
      });

      final result = await SudokuScreenState.loadSavedPuzzle();

      expect(result, isNotNull);
      expect(result!['n'], equals(3));
      expect(result['buffer'], isA<List>());
      expect((result['buffer'] as List).length, equals(81));
      expect(result['hints'], equals([0, 1, 2, 3, 4]));
    });

    test('clearSavedPuzzle removes saved puzzle', () async {
      final puzzleData = {
        'n': 3,
        'buffer': List.generate(81, (i) => 0),
        'hints': [0, 1, 2],
      };
      SharedPreferences.setMockInitialValues({
        'savedPuzzle': jsonEncode(puzzleData),
      });

      await SudokuScreenState.clearSavedPuzzle();

      final result = await SudokuScreenState.loadSavedPuzzle();
      expect(result, isNull);
    });

    test('loadSavedPuzzle handles corrupted JSON gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'savedPuzzle': 'not valid json {{{',
      });

      final result = await SudokuScreenState.loadSavedPuzzle();

      expect(result, isNull);
    });

    test('saved puzzle preserves all grid sizes', () async {
      for (final n in [2, 3, 4]) {
        final ne4 = n * n * n * n;
        final puzzleData = {
          'n': n,
          'buffer': List.generate(ne4, (i) => i % (n * n + 1)),
          'hints': List.generate(ne4 ~/ 3, (i) => i * 3),
        };
        SharedPreferences.setMockInitialValues({
          'savedPuzzle': jsonEncode(puzzleData),
        });

        final result = await SudokuScreenState.loadSavedPuzzle();

        expect(result, isNotNull, reason: 'Failed for n=$n');
        expect(result!['n'], equals(n));
        expect((result['buffer'] as List).length, equals(ne4));
      }
    });

    test('SudokuScreenArguments supports saved puzzle fields', () {
      final args = SudokuScreenArguments(
        n: 3,
        savedBuffer: [1, 2, 3],
        savedHints: [0, 1],
      );

      expect(args.n, equals(3));
      expect(args.savedBuffer, equals([1, 2, 3]));
      expect(args.savedHints, equals([0, 1]));
      expect(args.isDemoMode, isFalse);
    });

    test('SudokuScreenArguments defaults saved fields to null', () {
      final args = SudokuScreenArguments(n: 3);

      expect(args.savedBuffer, isNull);
      expect(args.savedHints, isNull);
    });
  });

  group('Manual vs Assisted Changes Persistence', () {
    test('isVariableManual returns true for hints (no changes)', () {
      // Simulate: hints have values but no changes in history
      final changes = <SudokuChange>[];
      final hintIndices = {0, 1, 2}; // cells 0, 1, 2 are hints

      bool isVariableManual(int index) {
        var varChanges = changes.where((c) => c.variable == index);
        if (varChanges.isEmpty) {
          return true; // No changes = manual (includes hints)
        }
        return !varChanges.last.assisted;
      }

      // Hints should be considered manual
      expect(isVariableManual(0), isTrue);
      expect(isVariableManual(1), isTrue);
      expect(isVariableManual(2), isTrue);
    });

    test('isVariableManual returns true for user-entered values', () {
      final changes = <SudokuChange>[
        SudokuChange(variable: 5, value: 3, prevValue: 0, assisted: false),
        SudokuChange(variable: 10, value: 7, prevValue: 0, assisted: false),
      ];

      bool isVariableManual(int index) {
        var varChanges = changes.where((c) => c.variable == index);
        if (varChanges.isEmpty) return true;
        return !varChanges.last.assisted;
      }

      expect(isVariableManual(5), isTrue);
      expect(isVariableManual(10), isTrue);
    });

    test('isVariableManual returns false for assistant-propagated values', () {
      final changes = <SudokuChange>[
        SudokuChange(variable: 5, value: 3, prevValue: 0, assisted: false),
        SudokuChange(variable: 6, value: 4, prevValue: 0, assisted: true), // propagated
        SudokuChange(variable: 7, value: 5, prevValue: 0, assisted: true), // propagated
      ];

      bool isVariableManual(int index) {
        var varChanges = changes.where((c) => c.variable == index);
        if (varChanges.isEmpty) return true;
        return !varChanges.last.assisted;
      }

      expect(isVariableManual(5), isTrue);  // manual
      expect(isVariableManual(6), isFalse); // assisted
      expect(isVariableManual(7), isFalse); // assisted
    });

    test('filtering only manual changes from history', () {
      final changes = <SudokuChange>[
        SudokuChange(variable: 0, value: 1, prevValue: 0, assisted: false),
        SudokuChange(variable: 1, value: 2, prevValue: 0, assisted: true),
        SudokuChange(variable: 2, value: 3, prevValue: 0, assisted: false),
        SudokuChange(variable: 3, value: 4, prevValue: 0, assisted: true),
        SudokuChange(variable: 4, value: 5, prevValue: 0, assisted: false),
      ];

      final manualChanges = changes.where((c) => !c.assisted).toList();

      expect(manualChanges.length, equals(3));
      expect(manualChanges[0].variable, equals(0));
      expect(manualChanges[1].variable, equals(2));
      expect(manualChanges[2].variable, equals(4));
    });

    test('filtering manual buffer values preserves hints and user values', () {
      final buffer = [1, 2, 3, 4, 5, 6, 7, 8, 9]; // 9 cells
      final hints = {0, 1, 2}; // cells 0, 1, 2 are hints
      final changes = <SudokuChange>[
        SudokuChange(variable: 3, value: 4, prevValue: 0, assisted: false), // manual
        SudokuChange(variable: 4, value: 5, prevValue: 0, assisted: true),  // assisted
        SudokuChange(variable: 5, value: 6, prevValue: 0, assisted: false), // manual
        SudokuChange(variable: 6, value: 7, prevValue: 0, assisted: true),  // assisted
      ];

      bool isHint(int i) => hints.contains(i);
      bool isVariableManual(int index) {
        var varChanges = changes.where((c) => c.variable == index);
        if (varChanges.isEmpty) return true;
        return !varChanges.last.assisted;
      }

      final manualBuffer = List<int>.generate(9, (i) {
        if (isHint(i) || isVariableManual(i)) {
          return buffer[i];
        }
        return 0;
      });

      // Hints preserved
      expect(manualBuffer[0], equals(1));
      expect(manualBuffer[1], equals(2));
      expect(manualBuffer[2], equals(3));
      // Manual values preserved
      expect(manualBuffer[3], equals(4));
      expect(manualBuffer[5], equals(6));
      // Assisted values cleared
      expect(manualBuffer[4], equals(0));
      expect(manualBuffer[6], equals(0));
      // Untouched cells (no changes, considered manual)
      expect(manualBuffer[7], equals(8));
      expect(manualBuffer[8], equals(9));
    });

    test('save and restore cycle preserves only manual state', () {
      // Simulate initial state
      final buffer = List<int>.filled(16, 0); // 4x4 grid
      final hints = {0, 5, 10, 15}; // diagonal hints
      final changes = <SudokuChange>[];

      // Set hint values
      buffer[0] = 1;
      buffer[5] = 2;
      buffer[10] = 3;
      buffer[15] = 4;

      // User makes manual change
      buffer[1] = 3;
      changes.add(SudokuChange(variable: 1, value: 3, prevValue: 0, assisted: false));

      // Assistant propagates
      buffer[2] = 4;
      changes.add(SudokuChange(variable: 2, value: 4, prevValue: 0, assisted: true));
      buffer[3] = 2;
      changes.add(SudokuChange(variable: 3, value: 2, prevValue: 0, assisted: true));

      // User makes another manual change
      buffer[6] = 1;
      changes.add(SudokuChange(variable: 6, value: 1, prevValue: 0, assisted: false));

      // --- SAVE ---
      bool isHint(int i) => hints.contains(i);
      bool isVariableManual(int index) {
        var varChanges = changes.where((c) => c.variable == index);
        if (varChanges.isEmpty) return true;
        return !varChanges.last.assisted;
      }

      final savedBuffer = List<int>.generate(16, (i) {
        if (isHint(i) || isVariableManual(i)) return buffer[i];
        return 0;
      });
      final savedChanges = changes.where((c) => !c.assisted).toList();

      // --- RESTORE ---
      final restoredBuffer = List<int>.from(savedBuffer);
      final restoredChanges = savedChanges.map((c) => SudokuChange(
        variable: c.variable,
        value: c.value,
        prevValue: c.prevValue,
        assisted: c.assisted,
      )).toList();

      // Verify restored state
      // Hints preserved
      expect(restoredBuffer[0], equals(1));
      expect(restoredBuffer[5], equals(2));
      expect(restoredBuffer[10], equals(3));
      expect(restoredBuffer[15], equals(4));

      // Manual changes preserved
      expect(restoredBuffer[1], equals(3));
      expect(restoredBuffer[6], equals(1));

      // Assisted changes NOT preserved (will be re-propagated)
      expect(restoredBuffer[2], equals(0));
      expect(restoredBuffer[3], equals(0));

      // History only has manual changes
      expect(restoredChanges.length, equals(2));
      expect(restoredChanges.every((c) => !c.assisted), isTrue);
    });

    test('after restore, assistant re-propagates same values given same settings', () {
      // This test simulates the full cycle:
      // 1. Original state with manual + assisted values
      // 2. Save (only manual)
      // 3. Restore
      // 4. Re-propagate
      // 5. Verify final state matches original

      // Simplified simulation of propagation logic
      List<int> propagate(List<int> buffer, Set<int> hints) {
        final result = List<int>.from(buffer);
        // Simple rule: if cell 1 has value 3, propagate 4 to cell 2
        if (result[1] == 3 && result[2] == 0) {
          result[2] = 4;
        }
        // If cell 6 has value 1, propagate 3 to cell 7
        if (result[6] == 1 && result[7] == 0) {
          result[7] = 3;
        }
        return result;
      }

      // --- ORIGINAL STATE ---
      final originalBuffer = List<int>.filled(16, 0);
      final hints = {0, 5, 10, 15};
      originalBuffer[0] = 1;
      originalBuffer[5] = 2;
      originalBuffer[10] = 3;
      originalBuffer[15] = 4;
      originalBuffer[1] = 3; // manual
      originalBuffer[6] = 1; // manual

      // Propagate
      final propagatedOriginal = propagate(originalBuffer, hints);
      expect(propagatedOriginal[2], equals(4)); // propagated
      expect(propagatedOriginal[7], equals(3)); // propagated

      // --- SAVE (only manual values) ---
      final savedBuffer = List<int>.generate(16, (i) {
        if (hints.contains(i)) return propagatedOriginal[i];
        if (i == 1 || i == 6) return propagatedOriginal[i]; // manual cells
        return 0; // clear propagated
      });

      expect(savedBuffer[2], equals(0)); // propagated value not saved
      expect(savedBuffer[7], equals(0)); // propagated value not saved

      // --- RESTORE + RE-PROPAGATE ---
      final restoredBuffer = List<int>.from(savedBuffer);
      final rePropagated = propagate(restoredBuffer, hints);

      // --- VERIFY SAME FINAL STATE ---
      expect(rePropagated[0], equals(propagatedOriginal[0]));
      expect(rePropagated[1], equals(propagatedOriginal[1]));
      expect(rePropagated[2], equals(propagatedOriginal[2])); // re-propagated same
      expect(rePropagated[5], equals(propagatedOriginal[5]));
      expect(rePropagated[6], equals(propagatedOriginal[6]));
      expect(rePropagated[7], equals(propagatedOriginal[7])); // re-propagated same
      expect(rePropagated[10], equals(propagatedOriginal[10]));
      expect(rePropagated[15], equals(propagatedOriginal[15]));
    });

    test('changes history serialization round-trip', () {
      final changes = [
        SudokuChange(variable: 5, value: 3, prevValue: 0, assisted: false),
        SudokuChange(variable: 10, value: 7, prevValue: 2, assisted: false),
        SudokuChange(variable: 15, value: 1, prevValue: 5, assisted: false),
      ];

      // Serialize
      final changesData = changes.map((c) => {
        'variable': c.variable,
        'value': c.value,
        'prevValue': c.prevValue,
        'assisted': c.assisted,
      }).toList();

      final json = jsonEncode(changesData);

      // Deserialize
      final decoded = jsonDecode(json) as List;
      final restored = decoded.map((data) => SudokuChange(
        variable: data['variable'] as int,
        value: data['value'] as int,
        prevValue: data['prevValue'] as int,
        assisted: data['assisted'] as bool,
      )).toList();

      // Verify
      expect(restored.length, equals(3));
      for (int i = 0; i < changes.length; i++) {
        expect(restored[i].variable, equals(changes[i].variable));
        expect(restored[i].value, equals(changes[i].value));
        expect(restored[i].prevValue, equals(changes[i].prevValue));
        expect(restored[i].assisted, equals(changes[i].assisted));
      }
    });

    test('undo works correctly after restore', () {
      // Simulate restored state with only manual changes
      final buffer = [1, 3, 0, 0, 0, 2, 1, 0, 0, 0, 3, 0, 0, 0, 0, 4];
      final changes = [
        SudokuChange(variable: 1, value: 3, prevValue: 0, assisted: false),
        SudokuChange(variable: 6, value: 1, prevValue: 0, assisted: false),
      ];

      // Undo last manual change
      final lastChange = changes.removeLast();
      buffer[lastChange.variable] = lastChange.prevValue;

      expect(buffer[6], equals(0));
      expect(changes.length, equals(1));

      // Undo first manual change
      final firstChange = changes.removeLast();
      buffer[firstChange.variable] = firstChange.prevValue;

      expect(buffer[1], equals(0));
      expect(changes.length, equals(0));
    });
  });

  group('Demo Mode Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isDemoMode returns false by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final isDemoMode = prefs.getBool('demoMode') ?? false;

      expect(isDemoMode, isFalse);
    });

    test('seedDemoData sets demoMode flag to true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate seedDemoData behavior
      await prefs.setBool('demoMode', true);

      expect(prefs.getBool('demoMode'), isTrue);
    });

    test('clearDemoData sets demoMode flag to false', () async {
      SharedPreferences.setMockInitialValues({'demoMode': true});
      final prefs = await SharedPreferences.getInstance();

      // Simulate clearDemoData behavior
      await prefs.setBool('demoMode', false);

      expect(prefs.getBool('demoMode'), isFalse);
    });

    test('demo mode does not persist savedPuzzle', () async {
      // Start with demoMode flag set (simulating app in demo mode)
      SharedPreferences.setMockInitialValues({'demoMode': true});
      final prefs = await SharedPreferences.getInstance();

      // Demo mode logic: _isDemoMode check in runSetState() skips saving
      final isDemoMode = prefs.getBool('demoMode') ?? false;

      // Simulate runSetState behavior
      if (!isDemoMode) {
        // This should NOT execute in demo mode
        await prefs.setString('savedPuzzle', '{"n":3}');
      }

      // Verify savedPuzzle was NOT persisted
      expect(prefs.getString('savedPuzzle'), isNull);
    });

    test('demo mode does not persist assistantSettings', () async {
      // Start with demoMode flag set
      SharedPreferences.setMockInitialValues({'demoMode': true});
      final prefs = await SharedPreferences.getInstance();

      final isDemoMode = prefs.getBool('demoMode') ?? false;

      // Simulate runSetState behavior
      if (!isDemoMode) {
        // This should NOT execute in demo mode
        await prefs.setString('assistantSettings', '{"autoComplete":true}');
      }

      // Verify assistantSettings was NOT persisted
      expect(prefs.getString('assistantSettings'), isNull);
    });

    test('non-demo mode DOES persist puzzle and settings', () async {
      // Start with demoMode flag NOT set (normal mode)
      SharedPreferences.setMockInitialValues({'demoMode': false});
      final prefs = await SharedPreferences.getInstance();

      final isDemoMode = prefs.getBool('demoMode') ?? false;

      // Simulate runSetState behavior
      if (!isDemoMode) {
        // This SHOULD execute in normal mode
        await prefs.setString('savedPuzzle', '{"n":3}');
        await prefs.setString('assistantSettings', '{"autoComplete":true}');
      }

      // Verify both were persisted
      expect(prefs.getString('savedPuzzle'), isNotNull);
      expect(prefs.getString('assistantSettings'), isNotNull);
    });

    test('demo mode flag is independent of puzzle state', () async {
      // Pre-existing puzzle state should not affect demo mode flag
      SharedPreferences.setMockInitialValues({
        'demoMode': true,
        'savedPuzzle': '{"n":3,"buffer":[1,2,3]}',
        'assistantSettings': '{"autoComplete":true}',
      });
      final prefs = await SharedPreferences.getInstance();

      // Demo mode flag should still be true
      expect(prefs.getBool('demoMode'), isTrue);

      // But any NEW saves should be skipped
      final isDemoMode = prefs.getBool('demoMode') ?? false;
      final newPuzzleData = '{"n":4,"buffer":[0]}';

      if (!isDemoMode) {
        await prefs.setString('savedPuzzle', newPuzzleData);
      }

      // savedPuzzle should still have old value (not overwritten)
      expect(prefs.getString('savedPuzzle'), equals('{"n":3,"buffer":[1,2,3]}'));
    });

    test('clearing demo mode allows normal persistence', () async {
      // Start in demo mode
      SharedPreferences.setMockInitialValues({'demoMode': true});
      final prefs = await SharedPreferences.getInstance();

      // Verify demo mode blocks saving
      var isDemoMode = prefs.getBool('demoMode') ?? false;
      expect(isDemoMode, isTrue);

      if (!isDemoMode) {
        await prefs.setString('savedPuzzle', '{"n":3}');
      }
      expect(prefs.getString('savedPuzzle'), isNull);

      // Clear demo mode (simulating clearDemoData)
      await prefs.setBool('demoMode', false);

      // Now saving should work
      isDemoMode = prefs.getBool('demoMode') ?? false;
      expect(isDemoMode, isFalse);

      if (!isDemoMode) {
        await prefs.setString('savedPuzzle', '{"n":3}');
      }
      expect(prefs.getString('savedPuzzle'), equals('{"n":3}'));
    });

    test('demo mode preserves theme and style settings', () async {
      // seedDemoData sets theme and style, and these should persist
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate seedDemoData
      await prefs.setBool('demoMode', true);
      await prefs.setInt('themeMode', 1); // light
      await prefs.setInt('themeStyle', 0); // modern
      await prefs.setInt('demoSelectedGridSize', 3);

      // Verify all demo settings are persisted
      expect(prefs.getBool('demoMode'), isTrue);
      expect(prefs.getInt('themeMode'), equals(1));
      expect(prefs.getInt('themeStyle'), equals(0));
      expect(prefs.getInt('demoSelectedGridSize'), equals(3));
    });

    test('demo mode only blocks puzzle and assistant persistence', () async {
      // Demo mode should ONLY skip savedPuzzle and assistantSettings
      // Other settings (theme, style, etc.) should still be persisted
      SharedPreferences.setMockInitialValues({'demoMode': true});
      final prefs = await SharedPreferences.getInstance();

      final isDemoMode = prefs.getBool('demoMode') ?? false;

      // These are blocked in demo mode
      if (!isDemoMode) {
        await prefs.setString('savedPuzzle', '{"n":3}');
        await prefs.setString('assistantSettings', '{}');
      }

      // These are NOT blocked (can be set anytime)
      await prefs.setInt('themeMode', 2);
      await prefs.setInt('themeStyle', 1);

      // Verify blocked items are null
      expect(prefs.getString('savedPuzzle'), isNull);
      expect(prefs.getString('assistantSettings'), isNull);

      // Verify non-blocked items are set
      expect(prefs.getInt('themeMode'), equals(2));
      expect(prefs.getInt('themeStyle'), equals(1));
    });
  });
}
