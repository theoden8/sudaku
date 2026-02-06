import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
