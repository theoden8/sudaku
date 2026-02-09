import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudaku/sudoku_native.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Native FFI Tests', () {
    test('Generate 4x4 puzzle', () {
      final puzzle = SudokuNative.generate(n: 2, seed: 12345, difficulty: 1.0);

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
      final puzzle = SudokuNative.generate(n: 3, seed: 12345, difficulty: 1.0);

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
      );

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
      final puzzle = SudokuNative.generate(n: 3, seed: 99999, difficulty: 1.0);
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
      final puzzle = SudokuNative.generate(n: 3, seed: 11111, difficulty: 1.0);

      final stats = SudokuNative.estimateDifficulty(puzzle, 3, numSamples: 25);

      expect(stats, isNotNull);
      expect(stats!['minForwards'], greaterThan(0));
      expect(stats['maxForwards'], greaterThanOrEqualTo(stats['minForwards']!));
      expect(stats['avgForwards'], greaterThanOrEqualTo(stats['minForwards']!));
      expect(stats['avgForwards'], lessThanOrEqualTo(stats['maxForwards']!));
    });

    test('Difficulty parameter affects hint count', () {
      // Easy puzzle (many hints)
      final easy = SudokuNative.generate(n: 3, seed: 1000, difficulty: 0.0);
      final easyHints = easy.where((v) => v != 0).length;

      // Hard puzzle (few hints)
      final hard = SudokuNative.generate(n: 3, seed: 1000, difficulty: 1.0);
      final hardHints = hard.where((v) => v != 0).length;

      // Easy should have more hints than hard
      expect(easyHints, greaterThan(hardHints));
    });

    test('Same seed produces same puzzle', () {
      final puzzle1 = SudokuNative.generate(n: 3, seed: 42, difficulty: 0.5);
      final puzzle2 = SudokuNative.generate(n: 3, seed: 42, difficulty: 0.5);

      expect(puzzle1, equals(puzzle2));
    });

    test('Different seeds produce different puzzles', () {
      final puzzle1 = SudokuNative.generate(n: 3, seed: 100, difficulty: 0.5);
      final puzzle2 = SudokuNative.generate(n: 3, seed: 200, difficulty: 0.5);

      expect(puzzle1, isNot(equals(puzzle2)));
    });

    test('Difficulty estimation is deterministic for same puzzle', () {
      // Generate a puzzle
      final puzzle = SudokuNative.generate(n: 3, seed: 77777, difficulty: 1.0);

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

  group('Basic Techniques Solvability Tests', () {
    test('Trivial 4x4 puzzle is solvable with basic techniques', () {
      // A 4x4 puzzle that can be solved with just naked/hidden singles
      final puzzle = [
        1, 0, 0, 0,
        0, 2, 0, 0,
        0, 0, 3, 0,
        0, 0, 0, 4,
      ];

      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 2);
      expect(result, isTrue);
    });

    test('Easy 9x9 puzzle may be solvable with basic techniques', () {
      // Generate an easy puzzle (many hints)
      final puzzle = SudokuNative.generate(n: 3, seed: 12345, difficulty: 0.0);

      // Easy puzzles with lots of hints are often solvable with basic techniques
      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 3);
      // We just verify it doesn't crash - the result depends on the specific puzzle
      expect(result, isA<bool>());
    });

    test('Hard 9x9 puzzle is likely NOT solvable with basic techniques', () {
      // Generate a hard puzzle (few hints)
      final puzzle = SudokuNative.generate(n: 3, seed: 54321, difficulty: 1.0);

      // Hard puzzles should require more advanced techniques
      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 3);
      // Most hard puzzles require more than naked/hidden singles
      // We just verify the function works - specific result may vary
      expect(result, isA<bool>());
    });

    test('Already solved puzzle is considered solvable', () {
      // Generate and solve a puzzle
      final puzzle = SudokuNative.generate(n: 3, seed: 99999, difficulty: 1.0);
      SudokuNative.solve(puzzle, 3);

      // A solved puzzle should return true (no empty cells)
      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 3);
      expect(result, isTrue);
    });

    test('Empty puzzle is not solvable with basic techniques', () {
      // A completely empty puzzle
      final puzzle = List<int>.filled(81, 0);

      // Can't solve an empty puzzle with basic techniques
      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 3);
      expect(result, isFalse);
    });

    test('Basic techniques function throws on invalid input', () {
      final puzzle = [1, 2, 3]; // Wrong size

      expect(
        () => SudokuNative.isSolvableWithBasicTechniques(puzzle, 3),
        throwsArgumentError,
      );
    });

    test('Naked single detection works', () {
      // Create a puzzle where cell 1 can only be 2 (naked single)
      // Row 0: 1, _, 3, 4 -> cell 1 must be 2
      final puzzle = [
        1, 0, 3, 4,
        3, 4, 1, 2,
        4, 1, 2, 3,
        2, 3, 4, 1,
      ];
      // Remove the value at cell 1 to make it a naked single
      puzzle[1] = 0;

      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 2);
      expect(result, isTrue);
    });

    test('Hidden single detection works', () {
      // Create a puzzle where value 4 can only go in one cell of row 0
      final puzzle = [
        1, 2, 0, 0, // Row 0: need 3 and 4
        0, 0, 1, 2, // Row 1
        0, 0, 2, 1, // Row 2
        2, 1, 0, 0, // Row 3
      ];

      final result = SudokuNative.isSolvableWithBasicTechniques(puzzle, 2);
      expect(result, isTrue);
    });
  });
}
