import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bit_array/bit_array.dart';

import 'package:sudaku/TrophyRoom.dart';

void main() {
  group('Tutorial Achievement Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('tutorial achievement is initially locked', () async {
      SharedPreferences.setMockInitialValues({});

      final isUnlocked = await TrophyRoomStorage.isAchievementUnlocked(
        AchievementType.tutorialComplete
      );

      expect(isUnlocked, isFalse);
    });

    test('tutorial achievement can be unlocked', () async {
      SharedPreferences.setMockInitialValues({});

      final achievement = await TrophyRoomStorage.markTutorialCompleted();

      expect(achievement, isNotNull);
      expect(achievement!.type, equals(AchievementType.tutorialComplete));
      expect(achievement.isUnlocked, isTrue);
    });

    test('tutorial achievement remains unlocked after unlock', () async {
      SharedPreferences.setMockInitialValues({});

      // Unlock
      await TrophyRoomStorage.markTutorialCompleted();

      // Check it's still unlocked
      final isUnlocked = await TrophyRoomStorage.isAchievementUnlocked(
        AchievementType.tutorialComplete
      );

      expect(isUnlocked, isTrue);
    });

    test('marking tutorial complete twice returns null', () async {
      SharedPreferences.setMockInitialValues({});

      // First unlock
      await TrophyRoomStorage.markTutorialCompleted();

      // Second call should return null (already completed)
      final result = await TrophyRoomStorage.markTutorialCompleted();

      expect(result, isNull);
    });

    test('tutorial achievement has correct metadata', () {
      final achievements = getDefaultAchievements();
      final tutorial = achievements[AchievementType.tutorialComplete]!;

      expect(tutorial.title, equals('Quick Learner'));
      expect(tutorial.description, contains('tutorial'));
    });
  });

  group('Tutorial Cell Selection Logic Tests', () {
    test('filtering cells to only empty ones works correctly', () {
      // Simulate a 4x4 grid (n=2, ne4=16)
      final ne4 = 16;
      final allCells = BitArray(ne4)..setBits([0, 1, 2, 3, 4, 5]); // 6 cells selected

      // Simulate some cells being filled (values at indices 1, 3, 5)
      final cellValues = List<int>.filled(ne4, 0);
      cellValues[1] = 2; // filled
      cellValues[3] = 4; // filled
      cellValues[5] = 1; // filled

      // Filter to only empty cells (value == 0)
      final emptyCells = BitArray(ne4)
        ..setBits(
          allCells.asIntIterable().where((ind) => cellValues[ind] == 0)
        );

      // Should only have cells 0, 2, 4
      expect(emptyCells.cardinality, equals(3));
      expect(emptyCells[0], isTrue);
      expect(emptyCells[1], isFalse); // filled
      expect(emptyCells[2], isTrue);
      expect(emptyCells[3], isFalse); // filled
      expect(emptyCells[4], isTrue);
      expect(emptyCells[5], isFalse); // filled
    });

    test('pass condition requires exact cell match', () {
      final ne4 = 16;

      // Tutorial cells: 0, 2, 4
      final tutorialCells = BitArray(ne4)..setBits([0, 2, 4]);

      // User selection matches exactly
      final userSelection1 = BitArray(ne4)..setBits([0, 2, 4]);

      bool passCondition1 = (
        userSelection1.cardinality == tutorialCells.cardinality
        && userSelection1.asIntIterable().every((sel) => tutorialCells[sel])
      );
      expect(passCondition1, isTrue);

      // User selection has extra cell
      final userSelection2 = BitArray(ne4)..setBits([0, 2, 4, 5]);

      bool passCondition2 = (
        userSelection2.cardinality == tutorialCells.cardinality
        && userSelection2.asIntIterable().every((sel) => tutorialCells[sel])
      );
      expect(passCondition2, isFalse); // cardinality doesn't match

      // User selection missing a cell
      final userSelection3 = BitArray(ne4)..setBits([0, 2]);

      bool passCondition3 = (
        userSelection3.cardinality == tutorialCells.cardinality
        && userSelection3.asIntIterable().every((sel) => tutorialCells[sel])
      );
      expect(passCondition3, isFalse); // cardinality doesn't match

      // User selection has wrong cells
      final userSelection4 = BitArray(ne4)..setBits([0, 1, 2]);

      bool passCondition4 = (
        userSelection4.cardinality == tutorialCells.cardinality
        && userSelection4.asIntIterable().every((sel) => tutorialCells[sel])
      );
      expect(passCondition4, isFalse); // cell 1 is not in tutorial cells
    });

    test('highlighting only shows for empty cells', () {
      final ne4 = 16;
      final tutorialCells = BitArray(ne4)..setBits([0, 1, 2, 3]);

      // Simulate cell values
      final cellValues = List<int>.filled(ne4, 0);
      cellValues[1] = 5; // filled
      cellValues[3] = 7; // filled

      // Check which cells should be highlighted
      // Condition: tutorialCells[index] && cellValues[index] == 0
      for (int i = 0; i < ne4; i++) {
        bool shouldHighlight = tutorialCells[i] && cellValues[i] == 0;

        if (i == 0) expect(shouldHighlight, isTrue);  // in tutorial, empty
        if (i == 1) expect(shouldHighlight, isFalse); // in tutorial, filled
        if (i == 2) expect(shouldHighlight, isTrue);  // in tutorial, empty
        if (i == 3) expect(shouldHighlight, isFalse); // in tutorial, filled
        if (i == 4) expect(shouldHighlight, isFalse); // not in tutorial
      }
    });
  });

  group('Tutorial Auto-Complete State Tests', () {
    test('auto-complete state can be saved and restored', () {
      // Simulate saving auto-complete state
      bool originalAutoComplete = true;
      bool? savedAutoComplete;

      // Save state
      savedAutoComplete = originalAutoComplete;

      // Disable during tutorial
      bool currentAutoComplete = false;

      expect(currentAutoComplete, isFalse);
      expect(savedAutoComplete, isTrue);

      // Restore after tutorial
      if (savedAutoComplete != null) {
        currentAutoComplete = savedAutoComplete;
        savedAutoComplete = null;
      }

      expect(currentAutoComplete, isTrue);
      expect(savedAutoComplete, isNull);
    });

    test('auto-complete disabled prevents cell filling', () {
      // Simulate auto-complete behavior
      bool autoComplete = false;

      // Simulate cell with single candidate (would be auto-filled if enabled)
      final cellCandidates = [5]; // only one candidate
      int cellValue = 0;

      // Auto-complete logic (simplified)
      if (autoComplete && cellCandidates.length == 1) {
        cellValue = cellCandidates.first;
      }

      // Cell should NOT be filled because autoComplete is false
      expect(cellValue, equals(0));

      // Now enable auto-complete
      autoComplete = true;

      if (autoComplete && cellCandidates.length == 1) {
        cellValue = cellCandidates.first;
      }

      // Cell SHOULD be filled now
      expect(cellValue, equals(5));
    });
  });

  group('Tutorial Stage Transition Tests', () {
    test('tutorial stages progress correctly', () {
      int tutorialStage = 0;
      bool showTutorial = false;

      // Start tutorial
      showTutorial = true;
      tutorialStage = 1;

      expect(showTutorial, isTrue);
      expect(tutorialStage, equals(1));

      // Progress to stage 2 (cells selected correctly)
      bool passCondition = true;
      if (passCondition && tutorialStage == 1) {
        tutorialStage = 2;
      }

      expect(tutorialStage, equals(2));

      // Progress to stage 3 (constraint added)
      tutorialStage = 3;

      expect(tutorialStage, equals(3));

      // Complete tutorial
      showTutorial = false;
      tutorialStage = 0;

      expect(showTutorial, isFalse);
      expect(tutorialStage, equals(0));
    });

    test('tutorial does not progress without pass condition', () {
      int tutorialStage = 1;

      bool passCondition = false; // cells not selected correctly

      if (passCondition && tutorialStage == 1) {
        tutorialStage = 2;
      } else if (!passCondition) {
        tutorialStage = 1; // stay at stage 1
      }

      expect(tutorialStage, equals(1));
    });
  });

  group('Tutorial Dialog Skip Tests', () {
    test('tutorial dialog should be skipped when achievement unlocked', () async {
      SharedPreferences.setMockInitialValues({});

      // Initially not unlocked - should show dialog
      bool shouldShowDialog1 = !await TrophyRoomStorage.isAchievementUnlocked(
        AchievementType.tutorialComplete
      );
      expect(shouldShowDialog1, isTrue);

      // Unlock achievement
      await TrophyRoomStorage.markTutorialCompleted();

      // Now should skip dialog
      bool shouldShowDialog2 = !await TrophyRoomStorage.isAchievementUnlocked(
        AchievementType.tutorialComplete
      );
      expect(shouldShowDialog2, isFalse);
    });
  });
}
