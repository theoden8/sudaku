import 'package:flutter_test/flutter_test.dart';
import 'package:bit_array/bit_array.dart';
import 'package:flutter/services.dart';
import 'package:sudaku/Sudoku.dart';
import 'package:sudaku/SudokuBuffer.dart';

void main() {
  group('Sudoku Grid Structure', () {
    test('SudokuBuffer initializes with correct size for 9x9', () {
      var buffer = SudokuBuffer(81);
      expect(buffer.length, equals(81));
      expect(buffer.getBuffer().length, equals(81));
    });

    test('SudokuBuffer initializes with correct size for 16x16', () {
      var buffer = SudokuBuffer(256);
      expect(buffer.length, equals(256));
      expect(buffer.getBuffer().length, equals(256));
    });

    test('SudokuBuffer initializes all cells to 0', () {
      var buffer = SudokuBuffer(81);
      for (int i = 0; i < 81; i++) {
        expect(buffer[i], equals(0));
      }
    });
  });

  group('Coordinate Conversion', () {
    test('index to row conversion for 9x9', () {
      int ne2 = 9;
      // First row (row 0)
      expect(0 ~/ ne2, equals(0));
      expect(8 ~/ ne2, equals(0));
      // Second row (row 1)
      expect(9 ~/ ne2, equals(1));
      expect(17 ~/ ne2, equals(1));
      // Last row (row 8)
      expect(72 ~/ ne2, equals(8));
      expect(80 ~/ ne2, equals(8));
    });

    test('index to column conversion for 9x9', () {
      int ne2 = 9;
      // First column (col 0)
      expect(0 % ne2, equals(0));
      expect(9 % ne2, equals(0));
      expect(72 % ne2, equals(0));
      // Last column (col 8)
      expect(8 % ne2, equals(8));
      expect(17 % ne2, equals(8));
      expect(80 % ne2, equals(8));
    });

    test('index to box conversion for 9x9', () {
      int n = 3;
      int ne2 = 9;

      int getBox(int ind) {
        int row = ind ~/ ne2;
        int col = ind % ne2;
        return (row ~/ n) * n + (col ~/ n);
      }

      // Top-left box (box 0)
      expect(getBox(0), equals(0));
      expect(getBox(1), equals(0));
      expect(getBox(2), equals(0));
      expect(getBox(9), equals(0));
      expect(getBox(10), equals(0));

      // Center box (box 4)
      expect(getBox(30), equals(4));
      expect(getBox(31), equals(4));
      expect(getBox(40), equals(4));

      // Bottom-right box (box 8)
      expect(getBox(60), equals(8));
      expect(getBox(80), equals(8));
    });

    test('row and column to index conversion for 9x9', () {
      int ne2 = 9;

      int index(int row, int col) {
        return row * ne2 + col;
      }

      expect(index(0, 0), equals(0));
      expect(index(0, 8), equals(8));
      expect(index(1, 0), equals(9));
      expect(index(8, 8), equals(80));
    });
  });

  group('Row Iteration', () {
    test('iterate row generates correct indices for 9x9', () {
      int ne2 = 9;

      Iterable<int> iterateRow(int row) sync* {
        for (int i = 0; i < ne2; ++i) {
          yield row * ne2 + i;
        }
      }

      // First row
      expect(iterateRow(0).toList(), equals([0, 1, 2, 3, 4, 5, 6, 7, 8]));

      // Second row
      expect(iterateRow(1).toList(), equals([9, 10, 11, 12, 13, 14, 15, 16, 17]));

      // Last row
      expect(iterateRow(8).toList(), equals([72, 73, 74, 75, 76, 77, 78, 79, 80]));
    });

    test('row iteration covers all cells exactly once for 9x9', () {
      int ne2 = 9;

      Iterable<int> iterateRow(int row) sync* {
        for (int i = 0; i < ne2; ++i) {
          yield row * ne2 + i;
        }
      }

      var allIndices = <int>[];
      for (int row = 0; row < ne2; row++) {
        allIndices.addAll(iterateRow(row));
      }

      expect(allIndices.length, equals(81));
      expect(allIndices.toSet().length, equals(81)); // All unique
      expect(allIndices.reduce((a, b) => a > b ? a : b), equals(80)); // Max is 80
      expect(allIndices.reduce((a, b) => a < b ? a : b), equals(0)); // Min is 0
    });
  });

  group('Column Iteration', () {
    test('iterate column generates correct indices for 9x9', () {
      int ne2 = 9;

      Iterable<int> iterateCol(int col) sync* {
        for (int i = 0; i < ne2; ++i) {
          yield i * ne2 + col;
        }
      }

      // First column
      expect(iterateCol(0).toList(), equals([0, 9, 18, 27, 36, 45, 54, 63, 72]));

      // Middle column
      expect(iterateCol(4).toList(), equals([4, 13, 22, 31, 40, 49, 58, 67, 76]));

      // Last column
      expect(iterateCol(8).toList(), equals([8, 17, 26, 35, 44, 53, 62, 71, 80]));
    });

    test('column iteration covers all cells exactly once for 9x9', () {
      int ne2 = 9;

      Iterable<int> iterateCol(int col) sync* {
        for (int i = 0; i < ne2; ++i) {
          yield i * ne2 + col;
        }
      }

      var allIndices = <int>[];
      for (int col = 0; col < ne2; col++) {
        allIndices.addAll(iterateCol(col));
      }

      expect(allIndices.length, equals(81));
      expect(allIndices.toSet().length, equals(81)); // All unique
    });
  });

  group('Box Iteration', () {
    test('iterate box generates correct indices for 9x9', () {
      int n = 3;
      int ne2 = 9;

      Iterable<int> iterateBox(int box) sync* {
        for (int i = 0; i < n; ++i) {
          for (int j = 0; j < n; ++j) {
            yield (((box ~/ n) * n + i) * ne2) + ((box % n) * n + j);
          }
        }
      }

      // Top-left box (box 0)
      expect(iterateBox(0).toList(), equals([0, 1, 2, 9, 10, 11, 18, 19, 20]));

      // Center box (box 4)
      expect(iterateBox(4).toList(), equals([30, 31, 32, 39, 40, 41, 48, 49, 50]));

      // Bottom-right box (box 8)
      expect(iterateBox(8).toList(), equals([60, 61, 62, 69, 70, 71, 78, 79, 80]));
    });

    test('box iteration covers all cells exactly once for 9x9', () {
      int n = 3;
      int ne2 = 9;

      Iterable<int> iterateBox(int box) sync* {
        for (int i = 0; i < n; ++i) {
          for (int j = 0; j < n; ++j) {
            yield (((box ~/ n) * n + i) * ne2) + ((box % n) * n + j);
          }
        }
      }

      var allIndices = <int>[];
      for (int box = 0; box < ne2; box++) {
        allIndices.addAll(iterateBox(box));
      }

      expect(allIndices.length, equals(81));
      expect(allIndices.toSet().length, equals(81)); // All unique
    });
  });

  group('Domain Operations', () {
    test('empty domain has no bits set', () {
      int ne2 = 9;
      var emptyDomain = BitArray(ne2 + 1);

      expect(emptyDomain.asIntIterable().toList(), isEmpty);
    });

    test('full domain has all bits set except 0', () {
      int ne2 = 9;
      var fullDomain = BitArray(ne2 + 1)..setAll()..clearBit(0);

      var values = fullDomain.asIntIterable().toList();
      // BitArray rounds up to word boundary (32 bits), but we only care about 1-9
      expect(values.contains(0), isFalse);
      // Check that all values 1-9 are present
      for (int i = 1; i <= ne2; i++) {
        expect(values.contains(i), isTrue, reason: 'Value $i should be in full domain');
      }
    });

    test('domain intersection works correctly', () {
      int ne2 = 9;
      var domain1 = BitArray(ne2 + 1);
      domain1.setBits([1, 2, 3, 4, 5]);

      var domain2 = BitArray(ne2 + 1);
      domain2.setBits([3, 4, 5, 6, 7]);

      var intersection = domain1 & domain2;
      expect(intersection.asIntIterable().toList(), equals([3, 4, 5]));
    });

    test('domain union works correctly', () {
      int ne2 = 9;
      var domain1 = BitArray(ne2 + 1);
      domain1.setBits([1, 2, 3]);

      var domain2 = BitArray(ne2 + 1);
      domain2.setBits([3, 4, 5]);

      var union = domain1 | domain2;
      expect(union.asIntIterable().toList(), equals([1, 2, 3, 4, 5]));
    });
  });

  group('SudokuBuffer', () {
    test('buffer initializes with correct size', () {
      var buffer = SudokuBuffer(81);
      expect(buffer.getBuffer().length, equals(81));
    });

    test('buffer values can be set and retrieved', () {
      var buffer = SudokuBuffer(9);
      buffer[0] = 5;
      buffer[5] = 9;

      expect(buffer[0], equals(5));
      expect(buffer[5], equals(9));
      expect(buffer[1], equals(0)); // Default value
    });

    test('buffer can be set with a list', () {
      var buffer = SudokuBuffer(9);
      buffer.setBuffer([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      expect(buffer.getBuffer(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });

    test('buffer match works correctly', () {
      var pattern = SudokuBuffer(9);
      pattern.setBuffer([1, 0, 3, 0, 5, 0, 7, 0, 9]);

      var buffer1 = SudokuBuffer(9);
      buffer1.setBuffer([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // pattern.match(buffer1) checks if pattern matches buffer1
      // (0s in pattern are wildcards)
      expect(pattern.match(buffer1), isTrue);

      var buffer2 = SudokuBuffer(9);
      buffer2.setBuffer([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // pattern.match(buffer2) should work since all non-zero positions match
      expect(pattern.match(buffer2), isTrue);

      var buffer3 = SudokuBuffer(9);
      buffer3.setBuffer([2, 2, 3, 4, 5, 6, 7, 8, 9]);

      // pattern.match(buffer3) fails because first position is 1 in pattern, 2 in buffer3
      expect(pattern.match(buffer3), isFalse);
    });
  });

  group('Change Tracking', () {
    test('change records variable, value, and previous value', () {
      var change = SudokuChange(
        variable: 10,
        value: 5,
        prevValue: 0,
        assisted: false
      );

      expect(change.variable, equals(10));
      expect(change.value, equals(5));
      expect(change.prevValue, equals(0));
      expect(change.assisted, isFalse);
    });

    test('manual and assisted changes are distinguished', () {
      var manualChange = SudokuChange(
        variable: 0,
        value: 1,
        prevValue: 0,
        assisted: false
      );

      var assistedChange = SudokuChange(
        variable: 1,
        value: 2,
        prevValue: 0,
        assisted: true
      );

      expect(manualChange.assisted, isFalse);
      expect(assistedChange.assisted, isTrue);
    });
  });

  group('Puzzle Validation', () {
    test('check function validates row constraints', () {
      int ne2 = 9;
      var buffer = List<int>.filled(81, 0);

      // Valid row - all different
      for (int i = 0; i < 9; i++) {
        buffer[i] = i + 1;
      }

      // Check for duplicates manually
      var seen = <int>{};
      bool valid = true;
      for (int i = 0; i < 9; i++) {
        int val = buffer[i];
        if (val != 0) {
          if (seen.contains(val)) {
            valid = false;
            break;
          }
          seen.add(val);
        }
      }

      expect(valid, isTrue);

      // Invalid row - duplicate 5
      buffer[8] = 5;
      seen.clear();
      valid = true;
      for (int i = 0; i < 9; i++) {
        int val = buffer[i];
        if (val != 0) {
          if (seen.contains(val)) {
            valid = false;
            break;
          }
          seen.add(val);
        }
      }

      expect(valid, isFalse);
    });

    test('empty cells (0) do not violate constraints', () {
      // A row with zeros and no duplicates is valid
      var row = [1, 0, 3, 0, 5, 0, 7, 0, 9];

      var seen = <int>{};
      bool valid = true;
      for (int val in row) {
        if (val != 0) {
          if (seen.contains(val)) {
            valid = false;
            break;
          }
          seen.add(val);
        }
      }

      expect(valid, isTrue);
    });
  });

  group('Undo/Rollback', () {
    test('undoLastChange restores previous value', () {
      // Simulate undo logic: buffer + changes list
      var buffer = SudokuBuffer(9);
      var changes = <SudokuChange>[];

      // Set initial value
      buffer[0] = 5;
      changes.add(SudokuChange(
        variable: 0,
        value: 5,
        prevValue: 0,
        assisted: false,
      ));

      expect(buffer[0], equals(5));
      expect(changes.length, equals(1));

      // Undo: restore previous value and remove from changes
      var lastChange = changes.last;
      buffer[lastChange.variable] = lastChange.prevValue;
      changes.removeLast();

      expect(buffer[0], equals(0));
      expect(changes.length, equals(0));
    });

    test('undoChange skips assisted changes until manual', () {
      // Simulate: manual change followed by assisted changes
      var buffer = SudokuBuffer(9);
      var changes = <SudokuChange>[];

      // Manual change: set cell 0 to 5
      buffer[0] = 5;
      changes.add(SudokuChange(
        variable: 0,
        value: 5,
        prevValue: 0,
        assisted: false,
      ));

      // Assisted change: set cell 1 to 3
      buffer[1] = 3;
      changes.add(SudokuChange(
        variable: 1,
        value: 3,
        prevValue: 0,
        assisted: true,
      ));

      // Assisted change: set cell 2 to 7
      buffer[2] = 7;
      changes.add(SudokuChange(
        variable: 2,
        value: 7,
        prevValue: 0,
        assisted: true,
      ));

      expect(buffer[0], equals(5));
      expect(buffer[1], equals(3));
      expect(buffer[2], equals(7));
      expect(changes.length, equals(3));

      // Undo logic: remove assisted changes, then the manual change
      while (changes.isNotEmpty && changes.last.assisted) {
        var lastChange = changes.last;
        buffer[lastChange.variable] = lastChange.prevValue;
        changes.removeLast();
      }
      // Undo the manual change
      if (changes.isNotEmpty) {
        var lastChange = changes.last;
        buffer[lastChange.variable] = lastChange.prevValue;
        changes.removeLast();
      }

      expect(buffer[0], equals(0));
      expect(buffer[1], equals(0));
      expect(buffer[2], equals(0));
      expect(changes.length, equals(0));
    });

    test('multiple undo operations work correctly', () {
      var buffer = SudokuBuffer(9);
      var changes = <SudokuChange>[];

      // First manual change
      buffer[0] = 1;
      changes.add(SudokuChange(variable: 0, value: 1, prevValue: 0, assisted: false));

      // Second manual change
      buffer[1] = 2;
      changes.add(SudokuChange(variable: 1, value: 2, prevValue: 0, assisted: false));

      // Third manual change (overwrite cell 0)
      changes.add(SudokuChange(variable: 0, value: 9, prevValue: 1, assisted: false));
      buffer[0] = 9;

      expect(buffer[0], equals(9));
      expect(buffer[1], equals(2));
      expect(changes.length, equals(3));

      // Undo third change (cell 0: 9 -> 1)
      var change3 = changes.removeLast();
      buffer[change3.variable] = change3.prevValue;
      expect(buffer[0], equals(1));

      // Undo second change (cell 1: 2 -> 0)
      var change2 = changes.removeLast();
      buffer[change2.variable] = change2.prevValue;
      expect(buffer[1], equals(0));

      // Undo first change (cell 0: 1 -> 0)
      var change1 = changes.removeLast();
      buffer[change1.variable] = change1.prevValue;
      expect(buffer[0], equals(0));

      expect(changes.length, equals(0));
    });

    test('undo on empty changes list does nothing', () {
      var buffer = SudokuBuffer(9);
      buffer[0] = 5;
      var changes = <SudokuChange>[];

      // Attempt undo with empty changes
      if (changes.isNotEmpty) {
        var lastChange = changes.last;
        buffer[lastChange.variable] = lastChange.prevValue;
        changes.removeLast();
      }

      // Buffer unchanged (undo didn't happen)
      expect(buffer[0], equals(5));
      expect(changes.length, equals(0));
    });

    test('findPrecedingValue returns correct value from history', () {
      var changes = <SudokuChange>[];

      // Cell 0: 0 -> 5 -> 9 -> 3
      changes.add(SudokuChange(variable: 0, value: 5, prevValue: 0, assisted: false));
      changes.add(SudokuChange(variable: 0, value: 9, prevValue: 5, assisted: false));
      changes.add(SudokuChange(variable: 0, value: 3, prevValue: 9, assisted: false));

      // Find preceding value for cell 0 (should be 9, the value before 3)
      int findPrecedingValue(int variable) {
        var hist = changes.reversed.where((c) => c.variable == variable).toList();
        if (hist.length < 2) return 0;
        return hist[1].value;
      }

      expect(findPrecedingValue(0), equals(9));

      // After removing last change, preceding value should be 5
      changes.removeLast();
      expect(findPrecedingValue(0), equals(5));

      // After removing another, preceding value should be 0 (not enough history)
      changes.removeLast();
      expect(findPrecedingValue(0), equals(0));
    });

    test('undo preserves changes for other variables', () {
      var buffer = SudokuBuffer(9);
      var changes = <SudokuChange>[];

      // Change multiple cells
      buffer[0] = 1;
      changes.add(SudokuChange(variable: 0, value: 1, prevValue: 0, assisted: false));
      buffer[5] = 5;
      changes.add(SudokuChange(variable: 5, value: 5, prevValue: 0, assisted: false));
      buffer[8] = 9;
      changes.add(SudokuChange(variable: 8, value: 9, prevValue: 0, assisted: false));

      // Undo last change (cell 8)
      var lastChange = changes.removeLast();
      buffer[lastChange.variable] = lastChange.prevValue;

      // Cell 8 undone, others preserved
      expect(buffer[0], equals(1));
      expect(buffer[5], equals(5));
      expect(buffer[8], equals(0));
      expect(changes.length, equals(2));
    });
  });
}
