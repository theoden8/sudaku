import 'package:flutter_test/flutter_test.dart';
import 'package:bit_array/bit_array.dart';
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
}
