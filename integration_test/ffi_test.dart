import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudaku/SudokuAssist.dart';
import 'package:sudaku/sudoku_native.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Native FFI Tests', () {
    test('Generate 4x4 puzzle', () {
      final puzzle = SudokuNative.generate(n: 2, seed: 12345, difficulty: 1.0)!;

      expect(puzzle.length, 16);

      // Count hints (non-zero values)
      final hints = puzzle.where((v) => v != 0).length;
      expect(hints, greaterThan(0));
      expect(hints, lessThan(16));

      // Values should be in range 0-4
      for (final v in puzzle) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(4));
      }
    });

    test('Generate 9x9 puzzle', () {
      final puzzle = SudokuNative.generate(n: 3, seed: 12345, difficulty: 1.0)!;

      expect(puzzle.length, 81);

      final hints = puzzle.where((v) => v != 0).length;
      expect(hints, greaterThan(0));
      expect(hints, lessThan(81));

      for (final v in puzzle) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(9));
      }
    });

    test('Generate 16x16 puzzle', () {
      final puzzle = SudokuNative.generate(
        n: 4,
        seed: 12345,
        difficulty: 0.5, // Lower difficulty for faster generation
        timeoutMs: 10000,
      )!;

      expect(puzzle.length, 256);

      final hints = puzzle.where((v) => v != 0).length;
      expect(hints, greaterThan(0));

      for (final v in puzzle) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(16));
      }
    });

    test('Solve puzzle', () {
      // Generate a puzzle
      final puzzle = SudokuNative.generate(n: 3, seed: 99999, difficulty: 1.0)!;
      final original = List<int>.from(puzzle);

      // Solve it
      final result = SudokuNative.solve(puzzle, 3);

      expect(result, 1); // COMPLETE

      // Solution should have no zeros
      expect(puzzle.where((v) => v == 0).length, 0);

      // Original hints should be preserved
      for (int i = 0; i < 81; i++) {
        if (original[i] != 0) {
          expect(puzzle[i], original[i]);
        }
      }
    });

    test('Difficulty estimation', () {
      final puzzle = SudokuNative.generate(n: 3, seed: 11111, difficulty: 1.0)!;

      final stats = SudokuNative.estimateDifficulty(puzzle, 3, numSamples: 25);

      expect(stats, isNotNull);
      expect(stats!['minForwards'], greaterThan(0));
      expect(stats['maxForwards'], greaterThanOrEqualTo(stats['minForwards']!));
      expect(stats['avgForwards'], greaterThanOrEqualTo(stats['minForwards']!));
      expect(stats['avgForwards'], lessThanOrEqualTo(stats['maxForwards']!));
    });

    test('Difficulty parameter affects hint count', () {
      // Easy puzzle (many hints)
      final easy = SudokuNative.generate(n: 3, seed: 1000, difficulty: 0.0)!;
      final easyHints = easy.where((v) => v != 0).length;

      // Hard puzzle (few hints)
      final hard = SudokuNative.generate(n: 3, seed: 1000, difficulty: 1.0)!;
      final hardHints = hard.where((v) => v != 0).length;

      // Easy should have more hints than hard
      expect(easyHints, greaterThan(hardHints));
    });

    test('Same seed produces same puzzle', () {
      final puzzle1 = SudokuNative.generate(n: 3, seed: 42, difficulty: 0.5)!;
      final puzzle2 = SudokuNative.generate(n: 3, seed: 42, difficulty: 0.5)!;

      expect(puzzle1, equals(puzzle2));
    });

    test('Different seeds produce different puzzles', () {
      final puzzle1 = SudokuNative.generate(n: 3, seed: 100, difficulty: 0.5)!;
      final puzzle2 = SudokuNative.generate(n: 3, seed: 200, difficulty: 0.5)!;

      expect(puzzle1, isNot(equals(puzzle2)));
    });

    test('Difficulty estimation is deterministic for same puzzle', () {
      // Generate a puzzle
      final puzzle = SudokuNative.generate(n: 3, seed: 77777, difficulty: 1.0)!;

      // Estimate difficulty multiple times
      final stats1 = SudokuNative.estimateDifficulty(puzzle, 3, numSamples: 25);
      final stats2 = SudokuNative.estimateDifficulty(puzzle, 3, numSamples: 25);
      final stats3 = SudokuNative.estimateDifficulty(puzzle, 3, numSamples: 25);

      // Results should be identical (deterministic)
      expect(stats1, isNotNull);
      expect(stats2, isNotNull);
      expect(stats3, isNotNull);
      expect(stats1!['avgForwards'], stats2!['avgForwards']);
      expect(stats2['avgForwards'], stats3!['avgForwards']);
      expect(stats1['minForwards'], stats2['minForwards']);
      expect(stats1['maxForwards'], stats2['maxForwards']);
    });
  });

  group('Trivial Puzzle Filtering', () {
    test('trivialAllowed=false returns null for trivially solvable puzzles', () {
      // Some seeds produce trivially solvable puzzles
      // trivialAllowed=false should return null for these
      int nullCount = 0;

      for (int seed = 1; seed <= 100; seed++) {
        final puzzle = SudokuNative.generate(
          n: 3,
          seed: seed,
          difficulty: 1.0,
          trivialAllowed: false,
        );
        if (puzzle == null) {
          nullCount++;
        }
      }

      // Some puzzles should be filtered out (returned as null)
      expect(nullCount, greaterThan(0),
          reason: 'Expected some puzzles to be filtered as trivially solvable');
    });

    test('Puzzles returned with trivialAllowed=false are not trivially solvable', () {
      // When a puzzle is returned with trivialAllowed=false,
      // it should not be trivially auto-solvable
      int triviallySolvable = 0;
      int validPuzzles = 0;

      for (int seed = 1; seed <= 1000; seed++) {
        final puzzle = SudokuNative.generate(
          n: 3,
          seed: seed,
          difficulty: 1.0,
          trivialAllowed: false,
        );
        if (puzzle != null) {
          validPuzzles++;
          if (SudokuAssist.isTriviallyAutoSolvable(puzzle, 3)) {
            triviallySolvable++;
          }
        }
      }

      // None of the returned puzzles should be trivially solvable
      expect(triviallySolvable, 0,
          reason: '$triviallySolvable out of $validPuzzles returned puzzles were trivially auto-solvable');
      // Should still get some valid puzzles
      expect(validPuzzles, greaterThan(0),
          reason: 'Expected at least some non-trivial puzzles to be generated');
    });

    test('4x4 puzzles can be trivially auto-solvable (expected)', () {
      // 4x4 puzzles are intentionally allowed to be trivial
      final puzzle = SudokuNative.generate(n: 2, seed: 12345, difficulty: 1.0)!;
      final result = SudokuAssist.isTriviallyAutoSolvable(puzzle, 2);
      // Just verify it doesn't crash - 4x4 puzzles are often trivial
      expect(result, isA<bool>());
    });
  });
}
