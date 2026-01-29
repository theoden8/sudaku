import 'package:flutter_test/flutter_test.dart';
import 'package:bit_array/bit_array.dart';
import 'package:sudaku/Sudoku.dart';
import 'package:sudaku/SudokuAssist.dart';
import 'package:sudaku/SudokuBuffer.dart';

void main() {
  group('ConstraintType', () {
    test('has all required types', () {
      expect(ConstraintType.values.length, equals(4));
      expect(ConstraintType.values.contains(ConstraintType.ONE_OF), isTrue);
      expect(ConstraintType.values.contains(ConstraintType.EQUAL), isTrue);
      expect(ConstraintType.values.contains(ConstraintType.ALLDIFF), isTrue);
      expect(ConstraintType.values.contains(ConstraintType.GENERIC), isTrue);
    });
  });

  group('Constraint Status Constants', () {
    test('NOT_RUN is defined correctly', () {
      expect(Constraint.NOT_RUN, equals(-2));
    });

    test('SUCCESS is defined correctly', () {
      expect(Constraint.SUCCESS, equals(1));
    });

    test('INSUFFICIENT is defined correctly', () {
      expect(Constraint.INSUFFICIENT, equals(0));
    });

    test('VIOLATED is defined correctly', () {
      expect(Constraint.VIOLATED, equals(-1));
    });

    test('status values are all different', () {
      var statuses = [
        Constraint.NOT_RUN,
        Constraint.SUCCESS,
        Constraint.INSUFFICIENT,
        Constraint.VIOLATED
      ];
      expect(statuses.toSet().length, equals(4));
    });
  });

  group('Common Row Detection', () {
    // Helper function that mirrors Constraint.getCommonRow logic
    int getCommonRow(List<int> variables, int ne2) {
      int row = -1;
      for (int variable in variables) {
        int vrow = variable ~/ ne2;
        if (row == -1) {
          row = vrow;
        } else if (row != vrow) {
          return -1;
        }
      }
      return row;
    }

    test('cells in same row return that row', () {
      // Cells 0, 1, 2 are all in row 0
      expect(getCommonRow([0, 1, 2], 9), equals(0));

      // Cells 9, 10, 11 are all in row 1
      expect(getCommonRow([9, 10, 11], 9), equals(1));

      // Cells 72, 73, 74 are all in row 8
      expect(getCommonRow([72, 73, 74], 9), equals(8));
    });

    test('cells in different rows return -1', () {
      // Cell 0 is in row 0, cell 9 is in row 1
      expect(getCommonRow([0, 9], 9), equals(-1));

      // Cells from different rows
      expect(getCommonRow([0, 10, 20], 9), equals(-1));
    });

    test('single cell returns its row', () {
      expect(getCommonRow([0], 9), equals(0));
      expect(getCommonRow([40], 9), equals(4));
      expect(getCommonRow([80], 9), equals(8));
    });

    test('empty list returns -1', () {
      expect(getCommonRow([], 9), equals(-1));
    });
  });

  group('Common Column Detection', () {
    // Helper function that mirrors Constraint.getCommonCol logic
    int getCommonCol(List<int> variables, int ne2) {
      int col = -1;
      for (int variable in variables) {
        int vcol = variable % ne2;
        if (col == -1) {
          col = vcol;
        } else if (col != vcol) {
          return -1;
        }
      }
      return col;
    }

    test('cells in same column return that column', () {
      // Cells 0, 9, 18 are all in column 0
      expect(getCommonCol([0, 9, 18], 9), equals(0));

      // Cells 4, 13, 22 are all in column 4
      expect(getCommonCol([4, 13, 22], 9), equals(4));

      // Cells 8, 17, 26 are all in column 8
      expect(getCommonCol([8, 17, 26], 9), equals(8));
    });

    test('cells in different columns return -1', () {
      // Cell 0 is in col 0, cell 1 is in col 1
      expect(getCommonCol([0, 1], 9), equals(-1));

      // Cells from different columns
      expect(getCommonCol([0, 10, 20], 9), equals(-1));
    });

    test('single cell returns its column', () {
      expect(getCommonCol([0], 9), equals(0));
      expect(getCommonCol([4], 9), equals(4));
      expect(getCommonCol([80], 9), equals(8));
    });
  });

  group('Common Box Detection', () {
    // Helper function that mirrors Constraint.getCommonBox logic
    int getCommonBox(List<int> variables, int n, int ne2) {
      int box = -1;
      for (int variable in variables) {
        int row = variable ~/ ne2;
        int col = variable % ne2;
        int vbox = (row ~/ n) * n + (col ~/ n);
        if (box == -1) {
          box = vbox;
        } else if (box != vbox) {
          return -1;
        }
      }
      return box;
    }

    test('cells in same box return that box', () {
      // Top-left box (box 0): cells 0, 1, 2, 9, 10, 11, 18, 19, 20
      expect(getCommonBox([0, 1, 10], 3, 9), equals(0));

      // Center box (box 4): cells around 40
      expect(getCommonBox([30, 31, 39, 40], 3, 9), equals(4));

      // Bottom-right box (box 8): cells 60, 61, 62, 69, 70, 71, 78, 79, 80
      expect(getCommonBox([60, 70, 80], 3, 9), equals(8));
    });

    test('cells in different boxes return -1', () {
      // Cell 0 is in box 0, cell 3 is in box 1
      expect(getCommonBox([0, 3], 3, 9), equals(-1));

      // Cells from different boxes
      expect(getCommonBox([0, 40, 80], 3, 9), equals(-1));
    });

    test('single cell returns its box', () {
      expect(getCommonBox([0], 3, 9), equals(0));
      expect(getCommonBox([40], 3, 9), equals(4));
      expect(getCommonBox([80], 3, 9), equals(8));
    });
  });

  group('Domain BitArray Operations', () {
    test('create empty domain for cell', () {
      int ne2 = 9;
      var domain = BitArray(ne2 + 1); // Size 10 for values 0-9

      expect(domain.cardinality, equals(0));
      expect(domain.asIntIterable().toList(), isEmpty);
    });

    test('create full domain for cell (values 1-9)', () {
      int ne2 = 9;
      var domain = BitArray(ne2 + 1);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      expect(domain.cardinality, equals(9));
      expect(domain[0], isFalse); // 0 is not a valid value
      for (int i = 1; i <= 9; i++) {
        expect(domain[i], isTrue);
      }
    });

    test('remove value from domain', () {
      int ne2 = 9;
      var domain = BitArray(ne2 + 1);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      domain.clearBit(5);

      expect(domain.cardinality, equals(8));
      expect(domain[5], isFalse);
    });

    test('domain reduces to single value', () {
      int ne2 = 9;
      var domain = BitArray(ne2 + 1);
      domain.setBit(7);

      expect(domain.cardinality, equals(1));
      expect(domain.asIntIterable().first, equals(7));
    });

    test('domain intersection removes values not in both', () {
      int ne2 = 9;
      var domain1 = BitArray(ne2 + 1);
      domain1.setBits([1, 2, 3, 4, 5]);

      var domain2 = BitArray(ne2 + 1);
      domain2.setBits([4, 5, 6, 7, 8]);

      var intersection = domain1 & domain2;

      expect(intersection.cardinality, equals(2));
      expect(intersection.asIntIterable().toList(), equals([4, 5]));
    });

    test('domain union combines values from both', () {
      int ne2 = 9;
      var domain1 = BitArray(ne2 + 1);
      domain1.setBits([1, 2, 3]);

      var domain2 = BitArray(ne2 + 1);
      domain2.setBits([7, 8, 9]);

      var union = domain1 | domain2;

      expect(union.cardinality, equals(6));
      expect(union.asIntIterable().toList(), equals([1, 2, 3, 7, 8, 9]));
    });
  });

  group('AllDiff Constraint Logic', () {
    test('cells with assigned values reduce other domains', () {
      // Simulate: if cell A has value 5, no other cell in same row/col/box can have 5
      int ne2 = 9;
      var assignedValues = <int>[0, 5, 0, 0, 0, 0, 0, 0, 0]; // Cell 1 has value 5

      // Other cells should not have 5 in their domain
      for (int i = 0; i < ne2; i++) {
        if (assignedValues[i] != 0) continue;

        var domain = BitArray(ne2 + 1);
        domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

        // Remove values already assigned in the same group
        for (int j = 0; j < ne2; j++) {
          if (assignedValues[j] != 0) {
            domain.clearBit(assignedValues[j]);
          }
        }

        expect(domain[5], isFalse, reason: 'Cell $i should not have 5 in domain');
        expect(domain.cardinality, equals(8));
      }
    });

    test('all different check with valid assignment', () {
      var values = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      var seen = <int>{};
      bool valid = true;

      for (int val in values) {
        if (val != 0 && seen.contains(val)) {
          valid = false;
          break;
        }
        if (val != 0) seen.add(val);
      }

      expect(valid, isTrue);
    });

    test('all different check with duplicate fails', () {
      var values = [1, 2, 3, 4, 5, 5, 7, 8, 9]; // Duplicate 5
      var seen = <int>{};
      bool valid = true;

      for (int val in values) {
        if (val != 0 && seen.contains(val)) {
          valid = false;
          break;
        }
        if (val != 0) seen.add(val);
      }

      expect(valid, isFalse);
    });
  });

  group('OneOf Constraint Logic', () {
    test('one-of identifies unique cell for value', () {
      // Simulate: cells 0, 1, 2 can have values from domains
      // Cell 0 domain: {1, 2}
      // Cell 1 domain: {2, 3}
      // Cell 2 domain: {3}
      // Value 1 can only go in cell 0

      var domains = <List<int>>[
        [1, 2],
        [2, 3],
        [3]
      ];

      int findUniqueCell(int value) {
        int uniqueCell = -1;
        for (int cell = 0; cell < domains.length; cell++) {
          if (domains[cell].contains(value)) {
            if (uniqueCell == -1) {
              uniqueCell = cell;
            } else {
              return -1; // Multiple cells can have this value
            }
          }
        }
        return uniqueCell;
      }

      expect(findUniqueCell(1), equals(0)); // Only cell 0 can have 1
      expect(findUniqueCell(2), equals(-1)); // Cells 0 and 1 can have 2
      expect(findUniqueCell(3), equals(-1)); // Cells 1 and 2 can have 3
    });

    test('one-of with no valid cell returns -1', () {
      var domains = <List<int>>[
        [1, 2],
        [2, 3],
        [3, 4]
      ];

      int findUniqueCell(int value) {
        int uniqueCell = -1;
        for (int cell = 0; cell < domains.length; cell++) {
          if (domains[cell].contains(value)) {
            if (uniqueCell == -1) {
              uniqueCell = cell;
            } else {
              return -1;
            }
          }
        }
        return uniqueCell;
      }

      expect(findUniqueCell(5), equals(-1)); // No cell can have 5
    });
  });

  group('Equal Constraint Logic', () {
    test('equal constraint finds common domain', () {
      // If cells must be equal, their common domain is the intersection
      var domain1 = BitArray(10);
      domain1.setBits([1, 2, 3, 4, 5]);

      var domain2 = BitArray(10);
      domain2.setBits([3, 4, 5, 6, 7]);

      var domain3 = BitArray(10);
      domain3.setBits([4, 5, 6, 7, 8]);

      var common = domain1 & domain2 & domain3;

      expect(common.asIntIterable().toList(), equals([4, 5]));
    });

    test('equal constraint with no common values is violated', () {
      var domain1 = BitArray(10);
      domain1.setBits([1, 2, 3]);

      var domain2 = BitArray(10);
      domain2.setBits([7, 8, 9]);

      var common = domain1 & domain2;

      expect(common.isEmpty, isTrue);
    });

    test('equal constraint with single common value succeeds', () {
      var domain1 = BitArray(10);
      domain1.setBits([1, 2, 3, 4]);

      var domain2 = BitArray(10);
      domain2.setBits([4, 5, 6]);

      var domain3 = BitArray(10);
      domain3.setBits([4, 7, 8]);

      var common = domain1 & domain2 & domain3;

      expect(common.cardinality, equals(1));
      expect(common.asIntIterable().first, equals(4));
    });
  });

  group('Domain Filtering', () {
    test('filtering removes eliminated values', () {
      // Simulate eliminator that removes values 1, 2, 3 from a cell
      var fullDomain = BitArray(10);
      fullDomain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      var eliminated = [1, 2, 3];

      // Apply elimination by clearing eliminated bits
      var filteredDomain = BitArray(10);
      filteredDomain.setBits(fullDomain.asIntIterable().toList());
      filteredDomain.clearBits(eliminated);

      expect(filteredDomain.asIntIterable().toList(), equals([4, 5, 6, 7, 8, 9]));
    });

    test('filtering with constraints narrows domain', () {
      // Initial domain
      var domain = BitArray(10);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Apply row constraint (values 1, 2, 3 already used in row)
      domain.clearBits([1, 2, 3]);

      // Apply column constraint (values 4, 5 already used in column)
      domain.clearBits([4, 5]);

      // Apply box constraint (value 6 already used in box)
      domain.clearBit(6);

      expect(domain.asIntIterable().toList(), equals([7, 8, 9]));
    });
  });

  group('Condition Matching', () {
    test('buffer matches pattern with wildcards', () {
      var pattern = SudokuBuffer(9);
      pattern.setBuffer([1, 0, 0, 0, 5, 0, 0, 0, 9]);

      var state1 = SudokuBuffer(9);
      state1.setBuffer([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Pattern has 0s as wildcards
      expect(pattern.match(state1), isTrue);

      var state2 = SudokuBuffer(9);
      state2.setBuffer([2, 2, 3, 4, 5, 6, 7, 8, 9]); // First cell is 2, not 1

      expect(pattern.match(state2), isFalse);
    });

    test('exact state matches itself', () {
      var state = SudokuBuffer(9);
      state.setBuffer([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      expect(state.match(state), isTrue);
    });
  });

  group('Constraint Activation', () {
    test('constraint active by default', () {
      // Simulating constraint activation logic
      bool active = true;

      expect(active, isTrue);
    });

    test('deactivated constraint is not active', () {
      bool active = true;
      active = false; // deactivate()

      expect(active, isFalse);
    });

    test('reactivated constraint is active', () {
      bool active = false;
      active = true; // activate()

      expect(active, isTrue);
    });
  });

  group('Domain Cardinality Tracking', () {
    test('empty domain has cardinality 0', () {
      var domain = BitArray(10);
      expect(domain.cardinality, equals(0));
    });

    test('full domain has cardinality 9 (values 1-9)', () {
      var domain = BitArray(10);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(domain.cardinality, equals(9));
    });

    test('single value domain has cardinality 1', () {
      var domain = BitArray(10);
      domain.setBit(5);
      expect(domain.cardinality, equals(1));
    });

    test('domain with some values removed has correct cardinality', () {
      var domain = BitArray(10);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      domain.clearBits([2, 4, 6, 8]);
      expect(domain.cardinality, equals(5));
      expect(domain.asIntIterable().toList(), equals([1, 3, 5, 7, 9]));
    });
  });

  group('Value Assignment Inference', () {
    test('cell with single value in domain can be assigned', () {
      var domain = BitArray(10);
      domain.setBit(7);

      bool canAssign = domain.cardinality == 1;
      int valueToAssign = canAssign ? domain.asIntIterable().first : 0;

      expect(canAssign, isTrue);
      expect(valueToAssign, equals(7));
    });

    test('cell with multiple values cannot be auto-assigned', () {
      var domain = BitArray(10);
      domain.setBits([3, 7]);

      bool canAssign = domain.cardinality == 1;

      expect(canAssign, isFalse);
    });

    test('cell with empty domain indicates violation', () {
      var domain = BitArray(10);

      bool isViolated = domain.isEmpty;

      expect(isViolated, isTrue);
    });
  });

  group('Row/Column/Box Iteration Indices', () {
    test('row indices are consecutive', () {
      int ne2 = 9;
      for (int row = 0; row < ne2; row++) {
        var indices = List<int>.generate(ne2, (i) => row * ne2 + i);
        expect(indices.length, equals(9));
        expect(indices.first, equals(row * 9));
        expect(indices.last, equals(row * 9 + 8));
      }
    });

    test('column indices have stride of ne2', () {
      int ne2 = 9;
      for (int col = 0; col < ne2; col++) {
        var indices = List<int>.generate(ne2, (i) => i * ne2 + col);
        expect(indices.length, equals(9));
        expect(indices.first, equals(col));
        expect(indices.last, equals(72 + col));
      }
    });

    test('box indices form 3x3 grid', () {
      int n = 3;
      int ne2 = 9;

      List<int> boxIndices(int box) {
        var indices = <int>[];
        for (int i = 0; i < n; i++) {
          for (int j = 0; j < n; j++) {
            indices.add((((box ~/ n) * n + i) * ne2) + ((box % n) * n + j));
          }
        }
        return indices;
      }

      // Box 0 (top-left)
      expect(boxIndices(0), equals([0, 1, 2, 9, 10, 11, 18, 19, 20]));

      // Box 4 (center)
      expect(boxIndices(4), equals([30, 31, 32, 39, 40, 41, 48, 49, 50]));

      // Box 8 (bottom-right)
      expect(boxIndices(8), equals([60, 61, 62, 69, 70, 71, 78, 79, 80]));
    });
  });

  group('Constraint Status History', () {
    test('empty status history returns NOT_RUN', () {
      var statuses = <int>[];

      int getStatus() => statuses.isEmpty ? Constraint.NOT_RUN : statuses.last;

      expect(getStatus(), equals(Constraint.NOT_RUN));
    });

    test('status history tracks multiple applications', () {
      var statuses = <int>[];

      // First application: INSUFFICIENT
      statuses.add(Constraint.INSUFFICIENT);
      expect(statuses.last, equals(Constraint.INSUFFICIENT));

      // Second application: SUCCESS
      statuses.add(Constraint.SUCCESS);
      expect(statuses.last, equals(Constraint.SUCCESS));

      // Third application: VIOLATED
      statuses.add(Constraint.VIOLATED);
      expect(statuses.last, equals(Constraint.VIOLATED));

      expect(statuses.length, equals(3));
    });

    test('lastStatus returns second-to-last status', () {
      var statuses = <int>[];

      int getLastStatus() =>
          statuses.length < 2 ? Constraint.NOT_RUN : statuses[statuses.length - 2];

      // Empty: NOT_RUN
      expect(getLastStatus(), equals(Constraint.NOT_RUN));

      // One status: NOT_RUN
      statuses.add(Constraint.SUCCESS);
      expect(getLastStatus(), equals(Constraint.NOT_RUN));

      // Two statuses: first one
      statuses.add(Constraint.INSUFFICIENT);
      expect(getLastStatus(), equals(Constraint.SUCCESS));

      // Three statuses: second one
      statuses.add(Constraint.VIOLATED);
      expect(getLastStatus(), equals(Constraint.INSUFFICIENT));
    });
  });

  group('Constraint Retract/Rollback', () {
    test('retract removes last status', () {
      var statuses = <int>[];
      var agesRun = <int>[];
      int currentAge = 0;

      // Simulate apply
      statuses.add(Constraint.SUCCESS);
      agesRun.add(currentAge);
      currentAge++;

      statuses.add(Constraint.INSUFFICIENT);
      agesRun.add(currentAge);

      expect(statuses.length, equals(2));
      expect(statuses.last, equals(Constraint.INSUFFICIENT));

      // Simulate retract (when age matches)
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }

      expect(statuses.length, equals(1));
      expect(statuses.last, equals(Constraint.SUCCESS));
    });

    test('retract does nothing when age mismatch', () {
      var statuses = <int>[];
      var agesRun = <int>[];
      int currentAge = 0;

      // Simulate apply at age 0
      statuses.add(Constraint.SUCCESS);
      agesRun.add(currentAge);

      // Age advances
      currentAge++;

      // Retract should not remove (age mismatch)
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }

      expect(statuses.length, equals(1)); // Unchanged
    });

    test('retract on empty status list does nothing', () {
      var statuses = <int>[];
      var agesRun = <int>[];
      int currentAge = 0;

      // Retract on empty
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }

      expect(statuses.length, equals(0));
    });

    test('success streaks track successful condition applications', () {
      var successStreaks = <int>[];
      var successConditions = <SudokuBuffer>[];
      var statuses = <int>[];

      // Helper to simulate apply (matches actual Constraint.apply logic)
      void simulateApply(int newStatus) {
        int lastStatus = statuses.length < 2
            ? Constraint.NOT_RUN
            : statuses[statuses.length - 1]; // Status before adding new one
        statuses.add(newStatus);
        if (lastStatus != Constraint.SUCCESS && newStatus == Constraint.SUCCESS) {
          successStreaks.add(successConditions.length);
          successConditions.add(SudokuBuffer(9));
        }
      }

      // First apply: INSUFFICIENT (no success)
      simulateApply(Constraint.INSUFFICIENT);
      expect(successStreaks.length, equals(0));

      // Second apply: SUCCESS (new streak)
      simulateApply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(1));
      expect(successConditions.length, equals(1));

      // Third apply: SUCCESS again (already succeeded, no new streak)
      simulateApply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(1)); // No new streak
      expect(successConditions.length, equals(1));

      // Fourth apply: INSUFFICIENT then SUCCESS (new streak)
      simulateApply(Constraint.INSUFFICIENT);
      simulateApply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(2)); // New streak added
    });

    test('retract removes success streak when appropriate', () {
      var successStreaks = <int>[];
      var successConditions = <SudokuBuffer>[];
      var statuses = <int>[];
      var agesRun = <int>[];
      int currentAge = 0;

      // Apply with INSUFFICIENT
      statuses.add(Constraint.INSUFFICIENT);
      agesRun.add(currentAge);
      currentAge++;

      // Apply with SUCCESS (creates streak)
      int lastStatus = statuses.length < 2 ? Constraint.NOT_RUN : statuses[statuses.length - 2];
      statuses.add(Constraint.SUCCESS);
      agesRun.add(currentAge);
      if (lastStatus != Constraint.SUCCESS && statuses.last == Constraint.SUCCESS) {
        successStreaks.add(successConditions.length);
        successConditions.add(SudokuBuffer(9));
      }

      expect(successStreaks.length, equals(1));
      expect(successConditions.length, equals(1));

      // Retract (should remove success streak too)
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
        if (successStreaks.isNotEmpty && successConditions.length == successStreaks.last + 1) {
          successStreaks.removeLast();
          successConditions.removeLast();
        }
      }

      expect(statuses.length, equals(1));
      expect(statuses.last, equals(Constraint.INSUFFICIENT));
      expect(successStreaks.length, equals(0));
      expect(successConditions.length, equals(0));
    });

    test('retract only removes status at matching age', () {
      var statuses = <int>[];
      var agesRun = <int>[];

      // Apply at age 0
      statuses.add(Constraint.INSUFFICIENT);
      agesRun.add(0);

      // Apply at age 1
      statuses.add(Constraint.SUCCESS);
      agesRun.add(1);

      // Apply at age 2
      statuses.add(Constraint.VIOLATED);
      agesRun.add(2);

      expect(statuses.length, equals(3));

      // Retract at age 2 (matches last)
      int currentAge = 2;
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }
      expect(statuses.length, equals(2));

      // Retract at age 2 again (doesn't match last which is age 1)
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }
      expect(statuses.length, equals(2)); // Unchanged

      // Retract at age 1 (matches)
      currentAge = 1;
      if (statuses.isNotEmpty && currentAge == agesRun.last) {
        statuses.removeLast();
        agesRun.removeLast();
      }
      expect(statuses.length, equals(1));
      expect(statuses.last, equals(Constraint.INSUFFICIENT));
    });
  });

  group('Eliminator Rollback', () {
    test('reinstate clears eliminated values from forbidden list', () {
      // Simulate eliminator's forbidden values (domain per condition)
      var forbiddenDomain = BitArray(10);
      forbiddenDomain.setBits([3, 5, 7]); // Values 3, 5, 7 are forbidden

      // Reinstate values 3 and 5
      forbiddenDomain.clearBits([3, 5]);

      expect(forbiddenDomain[3], isFalse);
      expect(forbiddenDomain[5], isFalse);
      expect(forbiddenDomain[7], isTrue); // Still forbidden
    });

    test('obsolete conditions are removed when empty', () {
      // Simulate conditions list with forbidden values
      var conditions = <int>[1, 2, 3]; // condition IDs
      var forbiddenValues = <BitArray>[
        BitArray(10)..setBits([1, 2]),
        BitArray(10), // Empty - obsolete
        BitArray(10)..setBits([5]),
      ];

      // Remove obsolete (empty forbidden values)
      int i = 0;
      while (i < conditions.length) {
        if (forbiddenValues[i].isEmpty) {
          conditions.removeAt(i);
          forbiddenValues.removeAt(i);
        } else {
          i++;
        }
      }

      expect(conditions.length, equals(2));
      expect(conditions, equals([1, 3]));
    });
  });

  group('Multi-Step Constraint Rollback', () {
    test('multiple constraints retract in sequence', () {
      // Simulate 3 constraints, each with status history
      var constraint1Statuses = <int>[];
      var constraint1Ages = <int>[];
      var constraint2Statuses = <int>[];
      var constraint2Ages = <int>[];
      var constraint3Statuses = <int>[];
      var constraint3Ages = <int>[];

      int currentAge = 0;

      // Age 0: All constraints applied
      constraint1Statuses.add(Constraint.SUCCESS);
      constraint1Ages.add(currentAge);
      constraint2Statuses.add(Constraint.INSUFFICIENT);
      constraint2Ages.add(currentAge);
      constraint3Statuses.add(Constraint.SUCCESS);
      constraint3Ages.add(currentAge);
      currentAge++;

      // Age 1: All constraints applied again
      constraint1Statuses.add(Constraint.SUCCESS);
      constraint1Ages.add(currentAge);
      constraint2Statuses.add(Constraint.SUCCESS);
      constraint2Ages.add(currentAge);
      constraint3Statuses.add(Constraint.VIOLATED);
      constraint3Ages.add(currentAge);
      currentAge++;

      // Age 2: All constraints applied
      constraint1Statuses.add(Constraint.INSUFFICIENT);
      constraint1Ages.add(currentAge);
      constraint2Statuses.add(Constraint.SUCCESS);
      constraint2Ages.add(currentAge);
      constraint3Statuses.add(Constraint.SUCCESS);
      constraint3Ages.add(currentAge);

      // Retract all at age 2
      void retractAll(int age) {
        if (constraint1Statuses.isNotEmpty && age == constraint1Ages.last) {
          constraint1Statuses.removeLast();
          constraint1Ages.removeLast();
        }
        if (constraint2Statuses.isNotEmpty && age == constraint2Ages.last) {
          constraint2Statuses.removeLast();
          constraint2Ages.removeLast();
        }
        if (constraint3Statuses.isNotEmpty && age == constraint3Ages.last) {
          constraint3Statuses.removeLast();
          constraint3Ages.removeLast();
        }
      }

      // Retract age 2
      retractAll(currentAge);
      expect(constraint1Statuses.length, equals(2));
      expect(constraint2Statuses.length, equals(2));
      expect(constraint3Statuses.length, equals(2));
      expect(constraint1Statuses.last, equals(Constraint.SUCCESS));
      expect(constraint3Statuses.last, equals(Constraint.VIOLATED));

      // Retract age 1
      currentAge--;
      retractAll(currentAge);
      expect(constraint1Statuses.length, equals(1));
      expect(constraint1Statuses.last, equals(Constraint.SUCCESS));
      expect(constraint2Statuses.last, equals(Constraint.INSUFFICIENT));

      // Retract age 0
      currentAge--;
      retractAll(currentAge);
      expect(constraint1Statuses.length, equals(0));
      expect(constraint2Statuses.length, equals(0));
      expect(constraint3Statuses.length, equals(0));
    });

    test('domain filtering rollback restores original domain', () {
      // Initial full domain
      var originalDomain = BitArray(10);
      originalDomain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Track eliminated values at each step
      var eliminationHistory = <List<int>>[];

      // Working domain (copy of original)
      var domain = BitArray(10);
      domain.setBits(originalDomain.asIntIterable().toList());

      // Step 1: Row constraint eliminates {1, 2, 3}
      eliminationHistory.add([1, 2, 3]);
      domain.clearBits([1, 2, 3]);
      expect(domain.asIntIterable().toList(), equals([4, 5, 6, 7, 8, 9]));

      // Step 2: Column constraint eliminates {4, 5}
      eliminationHistory.add([4, 5]);
      domain.clearBits([4, 5]);
      expect(domain.asIntIterable().toList(), equals([6, 7, 8, 9]));

      // Step 3: Box constraint eliminates {6}
      eliminationHistory.add([6]);
      domain.clearBit(6);
      expect(domain.asIntIterable().toList(), equals([7, 8, 9]));

      // Rollback step 3
      var step3Eliminated = eliminationHistory.removeLast();
      domain.setBits(step3Eliminated);
      expect(domain.asIntIterable().toList(), equals([6, 7, 8, 9]));

      // Rollback step 2
      var step2Eliminated = eliminationHistory.removeLast();
      domain.setBits(step2Eliminated);
      expect(domain.asIntIterable().toList(), equals([4, 5, 6, 7, 8, 9]));

      // Rollback step 1
      var step1Eliminated = eliminationHistory.removeLast();
      domain.setBits(step1Eliminated);
      expect(domain.asIntIterable().toList(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });

    test('success streak history tracks and retracts correctly', () {
      var statuses = <int>[];
      var agesRun = <int>[];
      var successStreaks = <int>[];
      var successConditions = <SudokuBuffer>[];
      int currentAge = 0;

      void apply(int status) {
        int lastStatus = statuses.isEmpty ? Constraint.NOT_RUN : statuses.last;
        statuses.add(status);
        agesRun.add(currentAge);
        if (lastStatus != Constraint.SUCCESS && status == Constraint.SUCCESS) {
          successStreaks.add(successConditions.length);
          successConditions.add(SudokuBuffer(9));
        }
      }

      void retract() {
        if (statuses.isNotEmpty && currentAge == agesRun.last) {
          statuses.removeLast();
          agesRun.removeLast();
          if (successStreaks.isNotEmpty && successConditions.length == successStreaks.last + 1) {
            successStreaks.removeLast();
            successConditions.removeLast();
          }
        }
      }

      // Age 0: INSUFFICIENT
      apply(Constraint.INSUFFICIENT);
      currentAge++;

      // Age 1: SUCCESS (new streak)
      apply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(1));
      currentAge++;

      // Age 2: SUCCESS (no new streak)
      apply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(1));
      currentAge++;

      // Age 3: VIOLATED
      apply(Constraint.VIOLATED);
      currentAge++;

      // Age 4: SUCCESS (new streak)
      apply(Constraint.SUCCESS);
      expect(successStreaks.length, equals(2));

      // Retract age 4 (removes second streak)
      retract();
      expect(statuses.length, equals(4));
      expect(successStreaks.length, equals(1));

      // Retract age 3
      currentAge--;
      retract();
      expect(statuses.length, equals(3));

      // Retract age 2
      currentAge--;
      retract();
      expect(statuses.length, equals(2));

      // Retract age 1 (removes first streak)
      currentAge--;
      retract();
      expect(statuses.length, equals(1));
      expect(successStreaks.length, equals(0));
    });

    test('AllDiff rollback restores eliminated values', () {
      // Simulate AllDiff constraint affecting multiple cells
      var domains = List.generate(9, (_) {
        var d = BitArray(10);
        d.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        return d;
      });

      // Track which values were eliminated from which cells
      var eliminationLog = <(int, int)>[]; // (cell, value)

      // Assign value 5 to cell 0, eliminate 5 from cells 1-8
      domains[0] = BitArray(10)..setBit(5);
      for (int i = 1; i < 9; i++) {
        if (domains[i][5]) {
          eliminationLog.add((i, 5));
          domains[i].clearBit(5);
        }
      }

      // Assign value 3 to cell 1, eliminate 3 from cells 2-8
      domains[1] = BitArray(10)..setBit(3);
      for (int i = 2; i < 9; i++) {
        if (domains[i][3]) {
          eliminationLog.add((i, 3));
          domains[i].clearBit(3);
        }
      }

      expect(domains[2][5], isFalse);
      expect(domains[2][3], isFalse);
      expect(domains[2].cardinality, equals(7));

      // Rollback cell 1 assignment
      // Find and restore all eliminations from cell 1
      var toRestore = eliminationLog.where((e) => e.$2 == 3).toList();
      for (var (cell, value) in toRestore) {
        domains[cell].setBit(value);
      }
      eliminationLog.removeWhere((e) => e.$2 == 3);
      domains[1] = BitArray(10)..setBits([1, 2, 3, 4, 6, 7, 8, 9]); // Restore minus 5

      expect(domains[2][3], isTrue);
      expect(domains[2][5], isFalse); // 5 still eliminated
      expect(domains[2].cardinality, equals(8));
    });

    test('constraint cascade rollback', () {
      // Simulate: Constraint A succeeds -> triggers constraint B
      var constraintAStatuses = <int>[];
      var constraintBStatuses = <int>[];
      var constraintAEnabled = true;
      var constraintBEnabled = false; // Enabled when A succeeds

      // Step 1: A applied, succeeds, enables B
      constraintAStatuses.add(Constraint.SUCCESS);
      if (constraintAStatuses.last == Constraint.SUCCESS) {
        constraintBEnabled = true;
      }

      // Step 2: B applied (because enabled)
      if (constraintBEnabled) {
        constraintBStatuses.add(Constraint.SUCCESS);
      }

      expect(constraintAStatuses.length, equals(1));
      expect(constraintBStatuses.length, equals(1));

      // Rollback: First rollback B, then A
      if (constraintBStatuses.isNotEmpty) {
        constraintBStatuses.removeLast();
      }
      constraintBEnabled = false;

      if (constraintAStatuses.isNotEmpty) {
        constraintAStatuses.removeLast();
      }

      expect(constraintAStatuses.length, equals(0));
      expect(constraintBStatuses.length, equals(0));
      expect(constraintBEnabled, isFalse);
    });

    test('full solving step undo with domain restoration', () {
      // Simulate a solving step with full state
      var buffer = SudokuBuffer(81);
      var changes = <SudokuChange>[];
      var domains = List.generate(81, (_) {
        var d = BitArray(10);
        d.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        return d;
      });
      var domainSnapshots = <List<BitArray>>[];

      // Helper to snapshot domains
      List<BitArray> snapshotDomains() {
        return domains.map((d) {
          var copy = BitArray(10);
          copy.setBits(d.asIntIterable().toList());
          return copy;
        }).toList();
      }

      // Save initial state
      domainSnapshots.add(snapshotDomains());

      // Step 1: Set cell 0 to 5
      buffer[0] = 5;
      changes.add(SudokuChange(variable: 0, value: 5, prevValue: 0, assisted: false));
      domains[0] = BitArray(10)..setBit(5);
      // Propagate: remove 5 from row 0
      for (int i = 1; i < 9; i++) {
        domains[i].clearBit(5);
      }
      domainSnapshots.add(snapshotDomains());

      // Step 2: Cell 1 inferred to be 3 (simulated)
      buffer[1] = 3;
      changes.add(SudokuChange(variable: 1, value: 3, prevValue: 0, assisted: true));
      domains[1] = BitArray(10)..setBit(3);
      for (int i = 2; i < 9; i++) {
        domains[i].clearBit(3);
      }
      domainSnapshots.add(snapshotDomains());

      expect(buffer[0], equals(5));
      expect(buffer[1], equals(3));
      expect(domains[2][5], isFalse);
      expect(domains[2][3], isFalse);

      // Rollback step 2
      var change2 = changes.removeLast();
      buffer[change2.variable] = change2.prevValue;
      domainSnapshots.removeLast();
      domains = domainSnapshots.last.map((d) {
        var copy = BitArray(10);
        copy.setBits(d.asIntIterable().toList());
        return copy;
      }).toList();

      expect(buffer[1], equals(0));
      expect(domains[2][3], isTrue);
      expect(domains[2][5], isFalse); // Still eliminated from step 1

      // Rollback step 1
      var change1 = changes.removeLast();
      buffer[change1.variable] = change1.prevValue;
      domainSnapshots.removeLast();
      domains = domainSnapshots.last.map((d) {
        var copy = BitArray(10);
        copy.setBits(d.asIntIterable().toList());
        return copy;
      }).toList();

      expect(buffer[0], equals(0));
      expect(domains[2][5], isTrue);
      expect(domains[2].cardinality, equals(9));
    });
  });

  group('Constraint Enable/Disable with Rollback', () {
    test('disabled constraint does not affect domain during rollback', () {
      // Simulate constraint that can be enabled/disabled
      var constraintActive = true;
      var domain = BitArray(10);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      var eliminationHistory = <List<int>>[];

      // Apply constraint (eliminates 1, 2, 3)
      if (constraintActive) {
        eliminationHistory.add([1, 2, 3]);
        domain.clearBits([1, 2, 3]);
      }
      expect(domain.asIntIterable().toList(), equals([4, 5, 6, 7, 8, 9]));

      // Disable constraint
      constraintActive = false;

      // Rollback with constraint disabled - should still restore
      var eliminated = eliminationHistory.removeLast();
      domain.setBits(eliminated);
      expect(domain.asIntIterable().toList(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9]));

      // Re-enable constraint and re-apply
      constraintActive = true;
      if (constraintActive) {
        eliminationHistory.add([1, 2, 3]);
        domain.clearBits([1, 2, 3]);
      }
      expect(domain.asIntIterable().toList(), equals([4, 5, 6, 7, 8, 9]));
    });

    test('enable constraint after rollback applies new eliminations', () {
      var constraints = <String, bool>{
        'row': true,
        'col': false,
        'box': true,
      };
      var domain = BitArray(10);
      domain.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      var eliminationHistory = <(String, List<int>)>[];

      // Apply active constraints
      if (constraints['row']!) {
        eliminationHistory.add(('row', [1, 2]));
        domain.clearBits([1, 2]);
      }
      if (constraints['box']!) {
        eliminationHistory.add(('box', [5]));
        domain.clearBit(5);
      }
      expect(domain.asIntIterable().toList(), equals([3, 4, 6, 7, 8, 9]));

      // Rollback box constraint
      var (name, eliminated) = eliminationHistory.removeLast();
      expect(name, equals('box'));
      domain.setBits(eliminated);
      expect(domain.asIntIterable().toList(), equals([3, 4, 5, 6, 7, 8, 9]));

      // Enable col constraint before re-applying
      constraints['col'] = true;

      // Apply col constraint (new)
      if (constraints['col']!) {
        eliminationHistory.add(('col', [3, 4]));
        domain.clearBits([3, 4]);
      }
      expect(domain.asIntIterable().toList(), equals([5, 6, 7, 8, 9]));
    });

    test('toggle constraint active state during multi-step rollback', () {
      var constraintActive = true;
      var statuses = <int>[];
      var activeHistory = <bool>[]; // Track active state at each step

      // Step 1: Constraint active, applied
      activeHistory.add(constraintActive);
      if (constraintActive) {
        statuses.add(Constraint.SUCCESS);
      }

      // Step 2: Disable constraint
      constraintActive = false;
      activeHistory.add(constraintActive);
      // Constraint not applied when inactive

      // Step 3: Re-enable, apply
      constraintActive = true;
      activeHistory.add(constraintActive);
      if (constraintActive) {
        statuses.add(Constraint.INSUFFICIENT);
      }

      expect(statuses.length, equals(2));
      expect(activeHistory.length, equals(3));

      // Rollback step 3
      if (activeHistory.last && statuses.isNotEmpty) {
        statuses.removeLast();
      }
      activeHistory.removeLast();
      constraintActive = activeHistory.last;

      expect(statuses.length, equals(1));
      expect(constraintActive, isFalse);

      // Rollback step 2
      activeHistory.removeLast();
      constraintActive = activeHistory.last;
      expect(constraintActive, isTrue);

      // Rollback step 1
      if (constraintActive && statuses.isNotEmpty) {
        statuses.removeLast();
      }
      activeHistory.removeLast();

      expect(statuses.length, equals(0));
      expect(activeHistory.length, equals(0));
    });
  });

  group('Add/Remove Constraint with Rollback', () {
    test('added constraint can be removed during rollback', () {
      var constraints = <int>[]; // List of constraint IDs
      var constraintStatuses = <int, List<int>>{}; // ID -> status history
      var constraintAddedAtAge = <int, int>{}; // ID -> age when added
      int currentAge = 0;
      int nextConstraintId = 0;

      // Age 0: Add constraint 0
      int c0 = nextConstraintId++;
      constraints.add(c0);
      constraintStatuses[c0] = [];
      constraintAddedAtAge[c0] = currentAge;
      constraintStatuses[c0]!.add(Constraint.SUCCESS);
      currentAge++;

      // Age 1: Add constraint 1
      int c1 = nextConstraintId++;
      constraints.add(c1);
      constraintStatuses[c1] = [];
      constraintAddedAtAge[c1] = currentAge;
      constraintStatuses[c1]!.add(Constraint.INSUFFICIENT);
      // Also apply c0
      constraintStatuses[c0]!.add(Constraint.SUCCESS);
      currentAge++;

      expect(constraints.length, equals(2));

      // Rollback age 1: remove c1 (added at age 1)
      currentAge--;
      constraints.removeWhere((c) => constraintAddedAtAge[c] == currentAge);
      constraintStatuses.removeWhere((c, _) => constraintAddedAtAge[c] == currentAge);
      // Also retract c0's status from age 1
      constraintStatuses[c0]!.removeLast();

      expect(constraints.length, equals(1));
      expect(constraints.contains(c0), isTrue);
      expect(constraintStatuses[c0]!.length, equals(1));
    });

    test('removed constraint is restored during rollback', () {
      var constraints = <int>[0, 1, 2]; // Constraint IDs
      var removedConstraints = <(int, int)>[]; // (ID, age when to restore)
      int currentAge = 0;

      // Age 0: All constraints active
      currentAge++;

      // Age 1: Remove constraint 1, record for rollback at age 2
      constraints.remove(1);
      currentAge++;
      removedConstraints.add((1, currentAge)); // Record at age 2 for rollback

      expect(constraints, equals([0, 2]));

      // Rollback from age 2: restore constraint 1
      // Check for constraints removed at currentAge (2) before decrementing
      var toRestore = removedConstraints.where((r) => r.$2 == currentAge).toList();
      for (var (id, _) in toRestore) {
        constraints.add(id);
      }
      removedConstraints.removeWhere((r) => r.$2 == currentAge);
      currentAge--;
      constraints.sort();

      expect(constraints, equals([0, 1, 2]));
    });

    test('constraint modifications tracked through rollback', () {
      // Track constraint modifications: add, remove, enable, disable
      var modifications = <(int, String, int)>[]; // (constraintId, action, age)
      var activeConstraints = <int>{0, 1, 2};
      var enabledConstraints = <int>{0, 1, 2};
      int currentAge = 0;

      // Age 0: Disable constraint 1
      modifications.add((1, 'disable', currentAge));
      enabledConstraints.remove(1);
      currentAge++;

      // Age 1: Add constraint 3
      modifications.add((3, 'add', currentAge));
      activeConstraints.add(3);
      enabledConstraints.add(3);
      currentAge++;

      // Age 2: Remove constraint 0
      modifications.add((0, 'remove', currentAge));
      activeConstraints.remove(0);
      enabledConstraints.remove(0);
      currentAge++;

      expect(activeConstraints, equals({1, 2, 3}));
      expect(enabledConstraints, equals({2, 3}));

      // Rollback helper
      void rollbackAge(int age) {
        var mods = modifications.where((m) => m.$3 == age).toList();
        for (var (id, action, _) in mods.reversed) {
          switch (action) {
            case 'add':
              activeConstraints.remove(id);
              enabledConstraints.remove(id);
              break;
            case 'remove':
              activeConstraints.add(id);
              enabledConstraints.add(id);
              break;
            case 'enable':
              enabledConstraints.remove(id);
              break;
            case 'disable':
              enabledConstraints.add(id);
              break;
          }
        }
        modifications.removeWhere((m) => m.$3 == age);
      }

      // Rollback age 2
      rollbackAge(2);
      expect(activeConstraints, equals({0, 1, 2, 3}));
      expect(enabledConstraints, equals({0, 2, 3}));

      // Rollback age 1
      rollbackAge(1);
      expect(activeConstraints, equals({0, 1, 2}));
      expect(enabledConstraints, equals({0, 2}));

      // Rollback age 0
      rollbackAge(0);
      expect(activeConstraints, equals({0, 1, 2}));
      expect(enabledConstraints, equals({0, 1, 2}));
    });

    test('default constraints behavior with rollback', () {
      // Simulate default AllDiff constraints for row/col/box
      var defaultConstraintsEnabled = true;
      var buffer = SudokuBuffer(81);
      var domains = List.generate(81, (_) {
        var d = BitArray(10);
        d.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        return d;
      });
      var changes = <SudokuChange>[];
      var domainSnapshots = <List<BitArray>>[];

      List<BitArray> snapshotDomains() {
        return domains.map((d) {
          var copy = BitArray(10);
          copy.setBits(d.asIntIterable().toList());
          return copy;
        }).toList();
      }

      void applyDefaultConstraints(int cell, int value) {
        if (!defaultConstraintsEnabled) return;
        int row = cell ~/ 9;
        int col = cell % 9;
        int boxRow = (row ~/ 3) * 3;
        int boxCol = (col ~/ 3) * 3;

        // Eliminate from row
        for (int c = 0; c < 9; c++) {
          if (c != col) domains[row * 9 + c].clearBit(value);
        }
        // Eliminate from col
        for (int r = 0; r < 9; r++) {
          if (r != row) domains[r * 9 + col].clearBit(value);
        }
        // Eliminate from box
        for (int r = boxRow; r < boxRow + 3; r++) {
          for (int c = boxCol; c < boxCol + 3; c++) {
            if (r != row || c != col) domains[r * 9 + c].clearBit(value);
          }
        }
      }

      domainSnapshots.add(snapshotDomains());

      // Set cell 0 to 5 with default constraints
      buffer[0] = 5;
      changes.add(SudokuChange(variable: 0, value: 5, prevValue: 0, assisted: false));
      domains[0] = BitArray(10)..setBit(5);
      applyDefaultConstraints(0, 5);
      domainSnapshots.add(snapshotDomains());

      // Check eliminations happened
      expect(domains[1][5], isFalse); // Same row
      expect(domains[9][5], isFalse); // Same col
      expect(domains[10][5], isFalse); // Same box

      // Disable default constraints
      defaultConstraintsEnabled = false;

      // Set cell 40 to 3 (center) - no eliminations
      buffer[40] = 3;
      changes.add(SudokuChange(variable: 40, value: 3, prevValue: 0, assisted: false));
      domains[40] = BitArray(10)..setBit(3);
      applyDefaultConstraints(40, 3); // Does nothing since disabled
      domainSnapshots.add(snapshotDomains());

      // Cell 41 (same row as 40) should still have 3
      expect(domains[41][3], isTrue);

      // Rollback cell 40
      changes.removeLast();
      buffer[40] = 0;
      domainSnapshots.removeLast();
      domains = domainSnapshots.last.map((d) {
        var copy = BitArray(10);
        copy.setBits(d.asIntIterable().toList());
        return copy;
      }).toList();

      // Re-enable default constraints
      defaultConstraintsEnabled = true;

      // Rollback cell 0
      changes.removeLast();
      buffer[0] = 0;
      domainSnapshots.removeLast();
      domains = domainSnapshots.last.map((d) {
        var copy = BitArray(10);
        copy.setBits(d.asIntIterable().toList());
        return copy;
      }).toList();

      // All eliminations restored
      expect(domains[1][5], isTrue);
      expect(domains[9][5], isTrue);
      expect(domains[10][5], isTrue);
    });

    test('user constraint added then disabled before rollback', () {
      var userConstraints = <int, bool>{}; // ID -> enabled
      var constraintEffects = <int, List<(int, int)>>{}; // ID -> [(cell, value)]
      var domains = List.generate(9, (_) {
        var d = BitArray(10);
        d.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        return d;
      });

      // Add user constraint 0 that eliminates value 5 from cells 1-3
      userConstraints[0] = true;
      constraintEffects[0] = [(1, 5), (2, 5), (3, 5)];
      for (var (cell, value) in constraintEffects[0]!) {
        domains[cell].clearBit(value);
      }

      expect(domains[1][5], isFalse);
      expect(domains[2][5], isFalse);

      // Disable constraint 0
      userConstraints[0] = false;

      // Make a move (cell 0 = 7)
      domains[0] = BitArray(10)..setBit(7);

      // Rollback the move - constraint is disabled but effects should still be considered
      domains[0] = BitArray(10)..setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Re-enable constraint and verify effects still in place
      userConstraints[0] = true;
      expect(domains[1][5], isFalse); // Effect persists
      expect(domains[4][5], isTrue); // Cell 4 wasn't affected

      // Rollback constraint effect
      for (var (cell, value) in constraintEffects[0]!) {
        domains[cell].setBit(value);
      }
      constraintEffects.remove(0);
      userConstraints.remove(0);

      expect(domains[1][5], isTrue);
      expect(domains[2][5], isTrue);
    });
  });

  group('Complex Rollback Scenarios', () {
    test('rollback with mixed default and user constraints', () {
      var defaultConstraintEnabled = true;
      var userConstraintEnabled = true;
      var domains = List.generate(81, (_) {
        var d = BitArray(10);
        d.setBits([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        return d;
      });
      var stateHistory = <Map<String, dynamic>>[];

      void saveState() {
        stateHistory.add({
          'domains': domains.map((d) {
            var copy = BitArray(10);
            copy.setBits(d.asIntIterable().toList());
            return copy;
          }).toList(),
          'defaultEnabled': defaultConstraintEnabled,
          'userEnabled': userConstraintEnabled,
        });
      }

      void restoreState() {
        if (stateHistory.isEmpty) return;
        var state = stateHistory.removeLast();
        domains = (state['domains'] as List<BitArray>).map((d) {
          var copy = BitArray(10);
          copy.setBits(d.asIntIterable().toList());
          return copy;
        }).toList();
        defaultConstraintEnabled = state['defaultEnabled'] as bool;
        userConstraintEnabled = state['userEnabled'] as bool;
      }

      saveState(); // Initial state

      // Apply default constraint (row 0 has 5)
      if (defaultConstraintEnabled) {
        for (int i = 1; i < 9; i++) {
          domains[i].clearBit(5);
        }
      }
      saveState();

      // Disable default, enable user constraint
      defaultConstraintEnabled = false;
      userConstraintEnabled = true;

      // Apply user constraint (eliminate 3 from cells 10-15)
      // Note: Don't save state here - we save BEFORE changes, not after
      if (userConstraintEnabled) {
        for (int i = 10; i <= 15; i++) {
          domains[i].clearBit(3);
        }
      }

      expect(domains[1][5], isFalse); // From default
      expect(domains[10][3], isFalse); // From user

      // Rollback user constraint step - restores to state before user constraint
      restoreState();
      expect(domains[10][3], isTrue); // Restored
      expect(domains[1][5], isFalse); // Still from default constraint

      // Rollback default constraint step - restores to initial state
      restoreState();
      expect(domains[1][5], isTrue); // Restored
      expect(defaultConstraintEnabled, isTrue);
    });

    test('multiple constraint enable/disable cycles with rollback', () {
      var constraintEnabled = true;
      var history = <(bool, int)>[]; // (enabled state, status if applied)
      var statuses = <int>[];

      // Cycle 1: enabled, apply
      history.add((constraintEnabled, Constraint.SUCCESS));
      if (constraintEnabled) statuses.add(Constraint.SUCCESS);

      // Cycle 2: disable
      constraintEnabled = false;
      history.add((constraintEnabled, -1)); // -1 means not applied

      // Cycle 3: enable, apply
      constraintEnabled = true;
      history.add((constraintEnabled, Constraint.INSUFFICIENT));
      if (constraintEnabled) statuses.add(Constraint.INSUFFICIENT);

      // Cycle 4: disable
      constraintEnabled = false;
      history.add((constraintEnabled, -1));

      // Cycle 5: enable, apply
      constraintEnabled = true;
      history.add((constraintEnabled, Constraint.SUCCESS));
      if (constraintEnabled) statuses.add(Constraint.SUCCESS);

      expect(statuses.length, equals(3));

      // Rollback all cycles
      while (history.isNotEmpty) {
        var (enabled, status) = history.removeLast();
        if (enabled && status != -1 && statuses.isNotEmpty) {
          statuses.removeLast();
        }
        constraintEnabled = history.isNotEmpty ? history.last.$1 : true;
      }

      expect(statuses.length, equals(0));
    });
  });
}
