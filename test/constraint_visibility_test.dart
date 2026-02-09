import 'package:bit_array/bit_array.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudaku/Sudoku.dart';
import 'package:sudaku/SudokuAssist.dart';
import 'package:sudaku/demo_data.dart';

void main() {
  group('Constraint Visibility Logic', () {
    late Sudoku sd;

    setUp(() {
      // Create puzzle from demo using the demo constructor
      final puzzle = parseDemoPuzzle(demoPuzzle9x9);
      sd = Sudoku.demo(3, puzzle, () {});
    });

    test('satisfied constraints are hidden when no contradiction', () {
      // Add a simple OneOf constraint that will be satisfied
      // Cell 0 has value 4 (from the demo puzzle hints)
      final oneOfVars = BitArray(sd.ne4)..setBit(0)..setBit(9)..setBit(18);
      final constraint = ConstraintOneOf(sd, oneOfVars, 4);
      sd.assist.addConstraint(constraint);

      sd.assist.apply();

      // Verify constraint is satisfied (cell 0 already has value 4)
      expect(constraint.status, equals(Constraint.SUCCESS));

      // No contradiction - no violated constraints
      final hasViolatedConstraint = sd.assist.constraints.any((c) => c.status == Constraint.VIOLATED);
      expect(hasViolatedConstraint, isFalse);

      // No contradiction - no empty domains for empty cells
      final hasEmptyDomain = Iterable<int>.generate(sd.ne4)
          .any((i) => sd[i] == 0 && sd.assist.getDomain(i).isEmpty);
      expect(hasEmptyDomain, isFalse);

      // With no contradiction, satisfied constraint should be filtered out
      final visibleConstraints = sd.assist.constraints.where((c) {
        if (c.status != Constraint.SUCCESS) return true;
        return false; // No contradiction, so hide SUCCESS
      }).toList();

      expect(visibleConstraints, isEmpty);
    });

    test('VIOLATED constraint triggers showing last satisfied constraint', () {
      // Add a OneOf constraint that will be satisfied first
      // Cell 0 already has value 4
      final oneOfVars = BitArray(sd.ne4)..setBit(0);
      final satisfiedConstraint = ConstraintOneOf(sd, oneOfVars, 4);
      sd.assist.addConstraint(satisfiedConstraint);

      sd.assist.apply();

      // OneOf should be satisfied (cell 0 has value 4)
      expect(satisfiedConstraint.status, equals(Constraint.SUCCESS));

      // Add an Equal constraint on two cells that will have different values
      // This will be violated when the cells have different values
      final equalVars = BitArray(sd.ne4)..setBit(9)..setBit(10);
      final violatedConstraint = ConstraintEqual(sd, equalVars);
      sd.assist.addConstraint(violatedConstraint);

      // Set cells to different values (violates Equal constraint)
      sd[9] = 5;
      sd[10] = 7;
      sd.assist.apply();

      // Equal should be VIOLATED (5 != 7)
      expect(violatedConstraint.status, equals(Constraint.VIOLATED));

      // Check the visibility logic
      final hasViolatedConstraintCheck = sd.assist.constraints.any((c) => c.status == Constraint.VIOLATED);
      expect(hasViolatedConstraintCheck, isTrue);

      // Find last satisfied constraint
      final satisfiedConstraints = sd.assist.constraints
          .where((c) => c.status == Constraint.SUCCESS)
          .toList();
      final lastSatisfied = satisfiedConstraints.isNotEmpty ? satisfiedConstraints.last : null;

      expect(lastSatisfied, equals(satisfiedConstraint));

      // With contradiction, visibility filter should include:
      // 1. Non-SUCCESS constraints (including VIOLATED)
      // 2. The last satisfied constraint
      final visibleConstraints = sd.assist.constraints.where((c) {
        if (c.status != Constraint.SUCCESS) return true;
        if (hasViolatedConstraintCheck && c == lastSatisfied) return true;
        return false;
      }).toList();

      // Should show violatedConstraint (VIOLATED) and satisfiedConstraint (last SUCCESS)
      expect(visibleConstraints.length, equals(2));
      expect(visibleConstraints.contains(violatedConstraint), isTrue);
      expect(visibleConstraints.contains(satisfiedConstraint), isTrue);
    });

    test('multiple satisfied constraints - only last one shown on contradiction', () {
      // Add multiple constraints that will all be satisfied
      // Cell 0 has value 4, so OneOf(4) will be satisfied
      final oneOf1Vars = BitArray(sd.ne4)..setBit(0);
      final constraint1 = ConstraintOneOf(sd, oneOf1Vars, 4);
      sd.assist.addConstraint(constraint1);

      // Cell 4 (row 0, col 4) has value 3, so OneOf(3) will be satisfied
      final oneOf2Vars = BitArray(sd.ne4)..setBit(4);
      final constraint2 = ConstraintOneOf(sd, oneOf2Vars, 3);
      sd.assist.addConstraint(constraint2);

      // Cell 27 (row 3, col 0) has value 1, so OneOf(1) will be satisfied
      final oneOf3Vars = BitArray(sd.ne4)..setBit(27);
      final constraint3 = ConstraintOneOf(sd, oneOf3Vars, 1);
      sd.assist.addConstraint(constraint3);

      sd.assist.apply();

      expect(constraint1.status, equals(Constraint.SUCCESS));
      expect(constraint2.status, equals(Constraint.SUCCESS));
      expect(constraint3.status, equals(Constraint.SUCCESS));

      // Now add an Equal constraint that will be violated
      final equalVars = BitArray(sd.ne4)..setBit(9)..setBit(10);
      final violatedConstraint = ConstraintEqual(sd, equalVars);
      sd.assist.addConstraint(violatedConstraint);

      // Violate it by setting cells to different values
      sd[9] = 7;
      sd[10] = 5;
      sd.assist.apply();

      expect(violatedConstraint.status, equals(Constraint.VIOLATED));

      // Find last satisfied
      final satisfiedConstraints = sd.assist.constraints
          .where((c) => c.status == Constraint.SUCCESS)
          .toList();
      final lastSatisfied = satisfiedConstraints.last;

      // Last satisfied should be constraint3 (the last one added and satisfied)
      expect(lastSatisfied, equals(constraint3));

      // Visibility check
      final hasContradiction = sd.assist.constraints.any((c) => c.status == Constraint.VIOLATED);
      final visibleConstraints = sd.assist.constraints.where((c) {
        if (c.status != Constraint.SUCCESS) return true;
        if (hasContradiction && c == lastSatisfied) return true;
        return false;
      }).toList();

      // Should show: violatedConstraint (VIOLATED) + constraint3 (last SUCCESS)
      // constraint1 and constraint2 should be hidden
      expect(visibleConstraints.length, equals(2));
      expect(visibleConstraints.contains(violatedConstraint), isTrue);
      expect(visibleConstraints.contains(constraint3), isTrue);
      expect(visibleConstraints.contains(constraint1), isFalse);
      expect(visibleConstraints.contains(constraint2), isFalse);
    });

    test('empty domain (dead-end) triggers showing last satisfied constraint', () {
      sd.assist.hintConstrained = true;
      sd.assist.hintContradictions = true;

      // Add a OneOf constraint that will be satisfied
      // Cell 0 already has value 4
      final oneOfVars = BitArray(sd.ne4)..setBit(0);
      final satisfiedConstraint = ConstraintOneOf(sd, oneOfVars, 4);
      sd.assist.addConstraint(satisfiedConstraint);

      sd.assist.apply();
      expect(satisfiedConstraint.status, equals(Constraint.SUCCESS));

      // Create an empty domain situation by eliminating all values for an empty cell
      // Cell 9 (row 1, col 0) is empty
      final cell9Domain = sd.assist.getDomain(9);
      final allValues = cell9Domain.asIntIterable().toList();

      // Eliminate all values from cell 9
      sd.assist.elim[9].invertBits(allValues);

      // Check that cell 9 now has empty domain
      final domainAfter = sd.assist.getDomain(9);
      expect(domainAfter.isEmpty, isTrue);

      // Check for empty domain contradiction
      final hasEmptyDomain = sd.assist.hintContradictions &&
          Iterable<int>.generate(sd.ne4).any((i) => sd[i] == 0 && sd.assist.getDomain(i).isEmpty);
      expect(hasEmptyDomain, isTrue);

      // Find last satisfied constraint
      final satisfiedConstraints = sd.assist.constraints
          .where((c) => c.status == Constraint.SUCCESS)
          .toList();
      final lastSatisfied = satisfiedConstraints.isNotEmpty ? satisfiedConstraints.last : null;

      expect(lastSatisfied, equals(satisfiedConstraint));

      // Visibility check - with empty domain contradiction
      final hasViolatedConstraint = sd.assist.constraints.any((c) => c.status == Constraint.VIOLATED);
      final hasContradiction = hasViolatedConstraint || hasEmptyDomain;
      expect(hasContradiction, isTrue);

      final visibleConstraints = sd.assist.constraints.where((c) {
        if (c.status != Constraint.SUCCESS) return true;
        if (hasContradiction && c == lastSatisfied) return true;
        return false;
      }).toList();

      // Should show the last satisfied constraint because there's a contradiction
      expect(visibleConstraints.contains(satisfiedConstraint), isTrue);
    });
  });
}
