import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudaku/TrophyRoom.dart';

void main() {
  group('PuzzleRecord Tests', () {
    test('toDotNotation produces correct format for 4x4', () {
      final record = PuzzleRecord(
        id: 'test1',
        n: 2,
        hints: [0, 3, 5, 10, 15],
        hintValues: [1, 4, 2, 3, 1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      final notation = record.toDotNotation();
      expect(notation.length, equals(16));
      expect(notation[0], equals('1'));
      expect(notation[1], equals('.'));
      expect(notation[3], equals('4'));
      expect(notation[5], equals('2'));
    });

    test('toDotNotation produces correct format for 9x9', () {
      final record = PuzzleRecord(
        id: 'test2',
        n: 3,
        hints: [0, 4, 80],
        hintValues: [5, 9, 1],
        completedAt: DateTime.now(),
        moveCount: 50,
      );

      final notation = record.toDotNotation();
      expect(notation.length, equals(81));
      expect(notation[0], equals('5'));
      expect(notation[4], equals('9'));
      expect(notation[80], equals('1'));
      expect(notation[1], equals('.'));
    });

    test('fromDotNotation parses valid 9x9 notation', () {
      // Create a valid 81-character notation: 5 at pos 0, 9 at pos 4, 1 at pos 80
      final buffer = List.filled(81, '.');
      buffer[0] = '5';
      buffer[4] = '9';
      buffer[80] = '1';
      final notation = buffer.join();

      final record = PuzzleRecord.fromDotNotation(notation, 3);

      expect(record, isNotNull);
      expect(record!.n, equals(3));
      expect(record.hints.contains(0), isTrue);
      expect(record.hints.contains(4), isTrue);
      expect(record.hints.contains(80), isTrue);
    });

    test('fromDotNotation returns null for invalid length', () {
      final notation = '123456'; // Too short for any grid
      final record = PuzzleRecord.fromDotNotation(notation, 3);
      expect(record, isNull);
    });

    test('fromDotNotation handles whitespace', () {
      // Create valid 81-char notation with whitespace inserted
      final buffer = List.filled(81, '.');
      buffer[0] = '5';
      buffer[4] = '9';
      buffer[80] = '1';
      final notation = buffer.join();
      final withWhitespace = notation.substring(0, 20) + '\n' + notation.substring(20);
      final record = PuzzleRecord.fromDotNotation(withWhitespace, 3);

      expect(record, isNotNull);
      expect(record!.n, equals(3));
    });

    test('round-trip preserves data', () {
      final original = PuzzleRecord(
        id: 'test3',
        n: 3,
        hints: [0, 10, 20, 30, 40, 50, 60, 70, 80],
        hintValues: [1, 2, 3, 4, 5, 6, 7, 8, 9],
        completedAt: DateTime.now(),
        moveCount: 25,
      );

      final notation = original.toDotNotation();
      final parsed = PuzzleRecord.fromDotNotation(notation, 3);

      expect(parsed, isNotNull);
      expect(parsed!.hints, equals(original.hints));
      expect(parsed.hintValues, equals(original.hintValues));
    });

    test('buildLaunchBuffer creates correct buffer', () {
      final record = PuzzleRecord(
        id: 'test4',
        n: 2,
        hints: [0, 5, 10, 15],
        hintValues: [1, 2, 3, 4],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final buffer = record.buildLaunchBuffer();
      expect(buffer.length, equals(16));
      expect(buffer[0], equals(1));
      expect(buffer[5], equals(2));
      expect(buffer[10], equals(3));
      expect(buffer[15], equals(4));
      expect(buffer[1], equals(0)); // Empty cell
    });

    test('JSON serialization round-trip', () {
      final original = PuzzleRecord(
        id: 'test5',
        n: 3,
        hints: [0, 1, 2],
        hintValues: [5, 6, 7],
        completedAt: DateTime(2024, 1, 15, 10, 30),
        moveCount: 42,
        nickname: 'Test Puzzle',
      );

      final json = original.toJson();
      final restored = PuzzleRecord.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.n, equals(original.n));
      expect(restored.hints, equals(original.hints));
      expect(restored.hintValues, equals(original.hintValues));
      expect(restored.moveCount, equals(original.moveCount));
      expect(restored.nickname, equals(original.nickname));
    });

    test('contentId is consistent for same puzzle', () {
      final record1 = PuzzleRecord(
        id: 'test_1',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final record2 = PuzzleRecord(
        id: 'test_2',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      expect(record1.contentId, equals(record2.contentId));
    });

    test('contentId differs for different puzzles', () {
      final record1 = PuzzleRecord(
        id: 'test_1',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final record2 = PuzzleRecord(
        id: 'test_2',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 4], // Different value
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      expect(record1.contentId, isNot(equals(record2.contentId)));
    });
  });

  group('GamificationStats Tests', () {
    test('default stats are empty', () {
      const stats = GamificationStats();
      expect(stats.totalCompleted, equals(0));
      expect(stats.completedSizes, isEmpty);
      expect(stats.solvedPuzzleIds, isEmpty);
      expect(stats.fastestTimeSeconds, isNull);
      expect(stats.maxDifficultyNormalized, isNull);
      expect(stats.usedAllConstraintTypes, isFalse);
      expect(stats.constraintOnlySizes, isEmpty);
      expect(stats.tutorialCompleted, isFalse);
    });

    test('recordCompletion increments totalCompleted for new puzzle', () {
      const stats = GamificationStats();
      final updated = stats.recordCompletion(
        contentId: 'puzzle_1',
        gridSize: 3,
      );

      expect(updated.totalCompleted, equals(1));
      expect(updated.solvedPuzzleIds, contains('puzzle_1'));
    });

    test('recordCompletion does not increment for duplicate puzzle', () {
      final stats = const GamificationStats().recordCompletion(
        contentId: 'puzzle_1',
        gridSize: 3,
      );

      // Try to add same puzzle again
      final updated = stats.recordCompletion(
        contentId: 'puzzle_1',
        gridSize: 3,
      );

      expect(updated.totalCompleted, equals(1)); // Still 1, not 2
    });

    test('recordCompletion tracks completed sizes', () {
      var stats = const GamificationStats();

      stats = stats.recordCompletion(contentId: 'p1', gridSize: 2);
      expect(stats.completedSizes, equals({2}));

      stats = stats.recordCompletion(contentId: 'p2', gridSize: 3);
      expect(stats.completedSizes, equals({2, 3}));

      stats = stats.recordCompletion(contentId: 'p3', gridSize: 4);
      expect(stats.completedSizes, equals({2, 3, 4}));
    });

    test('recordCompletion tracks fastest time', () {
      var stats = const GamificationStats();

      stats = stats.recordCompletion(contentId: 'p1', gridSize: 3, timeSeconds: 180);
      expect(stats.fastestTimeSeconds, equals(180));

      // Faster time should update
      stats = stats.recordCompletion(contentId: 'p2', gridSize: 3, timeSeconds: 90);
      expect(stats.fastestTimeSeconds, equals(90));

      // Slower time should not update
      stats = stats.recordCompletion(contentId: 'p3', gridSize: 3, timeSeconds: 120);
      expect(stats.fastestTimeSeconds, equals(90));
    });

    test('recordCompletion tracks max difficulty', () {
      var stats = const GamificationStats();

      stats = stats.recordCompletion(contentId: 'p1', gridSize: 3, difficultyNormalized: 0.3);
      expect(stats.maxDifficultyNormalized, equals(0.3));

      // Higher difficulty should update
      stats = stats.recordCompletion(contentId: 'p2', gridSize: 3, difficultyNormalized: 0.6);
      expect(stats.maxDifficultyNormalized, equals(0.6));

      // Lower difficulty should not update
      stats = stats.recordCompletion(contentId: 'p3', gridSize: 3, difficultyNormalized: 0.4);
      expect(stats.maxDifficultyNormalized, equals(0.6));
    });

    test('recordCompletion tracks constraint achievements', () {
      var stats = const GamificationStats();

      stats = stats.recordCompletion(
        contentId: 'p1',
        gridSize: 3,
        usedAllConstraints: true,
      );
      expect(stats.usedAllConstraintTypes, isTrue);

      stats = stats.recordCompletion(
        contentId: 'p2',
        gridSize: 2,
        wasConstraintOnly: true,
      );
      expect(stats.constraintOnlySizes, contains(2));
    });

    test('withTutorialCompleted marks tutorial done', () {
      const stats = GamificationStats();
      final updated = stats.withTutorialCompleted();
      expect(updated.tutorialCompleted, isTrue);
    });

    test('JSON serialization round-trip', () {
      final stats = GamificationStats(
        totalCompleted: 5,
        completedSizes: {2, 3},
        solvedPuzzleIds: {'p1', 'p2', 'p3', 'p4', 'p5'},
        fastestTimeSeconds: 90,
        maxDifficultyNormalized: 0.65,
        usedAllConstraintTypes: true,
        constraintOnlySizes: {2},
        tutorialCompleted: true,
      );

      final json = stats.toJson();
      final restored = GamificationStats.fromJson(json);

      expect(restored.totalCompleted, equals(stats.totalCompleted));
      expect(restored.completedSizes, equals(stats.completedSizes));
      expect(restored.solvedPuzzleIds, equals(stats.solvedPuzzleIds));
      expect(restored.fastestTimeSeconds, equals(stats.fastestTimeSeconds));
      expect(restored.maxDifficultyNormalized, equals(stats.maxDifficultyNormalized));
      expect(restored.usedAllConstraintTypes, equals(stats.usedAllConstraintTypes));
      expect(restored.constraintOnlySizes, equals(stats.constraintOnlySizes));
      expect(restored.tutorialCompleted, equals(stats.tutorialCompleted));
    });
  });

  group('deriveAchievements Tests', () {
    test('empty stats produces no unlocked achievements', () {
      const stats = GamificationStats();
      final achievements = deriveAchievements(stats);

      for (final achievement in achievements.values) {
        expect(achievement.isUnlocked, isFalse,
            reason: '${achievement.type} should not be unlocked with empty stats');
      }
    });

    test('firstSolve requires 9x9 or larger (not 4x4)', () {
      // 4x4 only - should NOT unlock firstSolve
      var stats = const GamificationStats(totalCompleted: 1, completedSizes: {2});
      var achievements = deriveAchievements(stats);
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isFalse);

      // 9x9 - should unlock firstSolve
      stats = const GamificationStats(totalCompleted: 1, completedSizes: {3});
      achievements = deriveAchievements(stats);
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isTrue);

      // 16x16 - should also unlock firstSolve
      stats = const GamificationStats(totalCompleted: 1, completedSizes: {4});
      achievements = deriveAchievements(stats);
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isTrue);
    });

    test('count-based achievements unlock at thresholds', () {
      // At 9 puzzles
      var achievements = deriveAchievements(const GamificationStats(totalCompleted: 9));
      expect(achievements[AchievementType.tenPuzzles]!.isUnlocked, isFalse);
      expect(achievements[AchievementType.tenPuzzles]!.progress, equals(9));

      // At 10 puzzles
      achievements = deriveAchievements(const GamificationStats(totalCompleted: 10));
      expect(achievements[AchievementType.tenPuzzles]!.isUnlocked, isTrue);

      // At 25 puzzles
      achievements = deriveAchievements(const GamificationStats(totalCompleted: 25));
      expect(achievements[AchievementType.twentyFivePuzzles]!.isUnlocked, isTrue);

      // At 50 puzzles
      achievements = deriveAchievements(const GamificationStats(totalCompleted: 50));
      expect(achievements[AchievementType.fiftyPuzzles]!.isUnlocked, isTrue);
    });

    test('size achievements unlock correctly', () {
      var achievements = deriveAchievements(const GamificationStats(completedSizes: {2}));
      expect(achievements[AchievementType.size4x4Master]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.size9x9Master]!.isUnlocked, isFalse);

      achievements = deriveAchievements(const GamificationStats(completedSizes: {3}));
      expect(achievements[AchievementType.size9x9Master]!.isUnlocked, isTrue);

      achievements = deriveAchievements(const GamificationStats(completedSizes: {4}));
      expect(achievements[AchievementType.size16x16Master]!.isUnlocked, isTrue);

      achievements = deriveAchievements(const GamificationStats(completedSizes: {2, 3, 4}));
      expect(achievements[AchievementType.allSizesMaster]!.isUnlocked, isTrue);
    });

    test('speedDemon unlocks for fast time', () {
      // Just over threshold
      var achievements = deriveAchievements(const GamificationStats(fastestTimeSeconds: 120));
      expect(achievements[AchievementType.speedDemon]!.isUnlocked, isFalse);

      // Under threshold
      achievements = deriveAchievements(const GamificationStats(fastestTimeSeconds: 119));
      expect(achievements[AchievementType.speedDemon]!.isUnlocked, isTrue);
    });

    test('constraint achievements unlock correctly', () {
      var achievements = deriveAchievements(const GamificationStats(usedAllConstraintTypes: true));
      expect(achievements[AchievementType.constraintMaster]!.isUnlocked, isTrue);

      // Note: constraintOnly4x4 was removed (too easy)
      achievements = deriveAchievements(const GamificationStats(constraintOnlySizes: {2}));
      expect(achievements[AchievementType.constraintOnly9x9]!.isUnlocked, isFalse);

      achievements = deriveAchievements(const GamificationStats(constraintOnlySizes: {3}));
      expect(achievements[AchievementType.constraintOnly9x9]!.isUnlocked, isTrue);
    });

    test('tutorial achievement unlocks when completed', () {
      var achievements = deriveAchievements(const GamificationStats(tutorialCompleted: false));
      expect(achievements[AchievementType.tutorialComplete]!.isUnlocked, isFalse);

      achievements = deriveAchievements(const GamificationStats(tutorialCompleted: true));
      expect(achievements[AchievementType.tutorialComplete]!.isUnlocked, isTrue);
    });

    test('difficulty tier achievements unlock based on counts', () {
      // No puzzles - nothing unlocked
      var achievements = deriveAchievements(const GamificationStats());
      expect(achievements[AchievementType.easy1]!.isUnlocked, isFalse);
      expect(achievements[AchievementType.hard1]!.isUnlocked, isFalse);

      // 1 easy puzzle
      achievements = deriveAchievements(const GamificationStats(easyCount: 1));
      expect(achievements[AchievementType.easy1]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.easy5]!.isUnlocked, isFalse);

      // 5 hard puzzles
      achievements = deriveAchievements(const GamificationStats(hardCount: 5));
      expect(achievements[AchievementType.hard1]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.hard5]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.hard10]!.isUnlocked, isFalse);

      // 1 extreme puzzle
      achievements = deriveAchievements(const GamificationStats(extremeCount: 1));
      expect(achievements[AchievementType.extreme1]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.extreme3]!.isUnlocked, isFalse);

      // 3 extreme puzzles
      achievements = deriveAchievements(const GamificationStats(extremeCount: 3));
      expect(achievements[AchievementType.extreme3]!.isUnlocked, isTrue);
    });
  });

  group('getNewlyUnlocked Tests', () {
    test('returns empty list when no new achievements', () {
      const stats = GamificationStats();
      final newlyUnlocked = getNewlyUnlocked(stats, stats);
      expect(newlyUnlocked, isEmpty);
    });

    test('returns newly unlocked achievements', () {
      const oldStats = GamificationStats(totalCompleted: 0);
      // firstSolve requires 9x9 or larger
      const newStats = GamificationStats(totalCompleted: 1, completedSizes: {3});

      final newlyUnlocked = getNewlyUnlocked(oldStats, newStats);
      // Should unlock firstSolve and size9x9Master
      expect(newlyUnlocked.any((a) => a.type == AchievementType.firstSolve), isTrue);
      expect(newlyUnlocked.any((a) => a.type == AchievementType.size9x9Master), isTrue);
    });

    test('returns multiple achievements when unlocked together', () {
      const oldStats = GamificationStats(totalCompleted: 0);
      // Use 9x9 so firstSolve can unlock
      const newStats = GamificationStats(
        totalCompleted: 1,
        completedSizes: {3},
        fastestTimeSeconds: 60,
      );

      final newlyUnlocked = getNewlyUnlocked(oldStats, newStats);
      expect(newlyUnlocked.any((a) => a.type == AchievementType.firstSolve), isTrue);
      expect(newlyUnlocked.any((a) => a.type == AchievementType.size9x9Master), isTrue);
      expect(newlyUnlocked.any((a) => a.type == AchievementType.speedDemon), isTrue);
    });

    test('does not return already unlocked achievements', () {
      const oldStats = GamificationStats(totalCompleted: 1, completedSizes: {3});
      const newStats = GamificationStats(totalCompleted: 2, completedSizes: {3});

      final newlyUnlocked = getNewlyUnlocked(oldStats, newStats);
      // firstSolve was already unlocked (both had 9x9)
      expect(newlyUnlocked.any((a) => a.type == AchievementType.firstSolve), isFalse);
    });
  });

  group('TrophyRoomStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadPuzzleRecords returns empty list when no records', () async {
      SharedPreferences.setMockInitialValues({});
      final records = await TrophyRoomStorage.loadPuzzleRecords();
      expect(records, isEmpty);
    });

    test('addPuzzleRecord and loadPuzzleRecords work correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'storage_test',
        n: 3,
        hints: [0, 1],
        hintValues: [5, 6],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      await TrophyRoomStorage.addPuzzleRecord(record);
      final records = await TrophyRoomStorage.loadPuzzleRecords();

      expect(records.length, equals(1));
      expect(records[0].id, equals('storage_test'));
    });

    test('deletePuzzleRecord removes record but preserves stats', () async {
      SharedPreferences.setMockInitialValues({});

      // First add a record and update stats
      final record = PuzzleRecord(
        id: 'delete_test',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 5,
      );
      await TrophyRoomStorage.addPuzzleRecord(record);

      // Update stats separately (simulating what AchievementTracker does)
      final stats = const GamificationStats().recordCompletion(
        contentId: record.contentId,
        gridSize: 3,
      );
      await TrophyRoomStorage.saveStats(stats);

      // Now delete the puzzle record
      await TrophyRoomStorage.deletePuzzleRecord('delete_test');

      // Verify record is gone
      final records = await TrophyRoomStorage.loadPuzzleRecords();
      expect(records, isEmpty);

      // But stats should still be there!
      final loadedStats = await TrophyRoomStorage.loadStats();
      expect(loadedStats.totalCompleted, equals(1));
      expect(loadedStats.completedSizes, contains(3));
    });

    test('addPuzzleRecord does not add duplicate puzzles', () async {
      SharedPreferences.setMockInitialValues({});

      final record1 = PuzzleRecord(
        id: 'first_solve',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      // Same puzzle content, different ID
      final record2 = PuzzleRecord(
        id: 'second_solve',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 8,
      );

      await TrophyRoomStorage.addPuzzleRecord(record1);
      await TrophyRoomStorage.addPuzzleRecord(record2);

      final records = await TrophyRoomStorage.loadPuzzleRecords();
      expect(records.length, equals(1));
      expect(records[0].id, equals('first_solve'));
    });

    test('loadAchievements derives from stats', () async {
      SharedPreferences.setMockInitialValues({});

      // Set up stats that would unlock some achievements
      final stats = GamificationStats(
        totalCompleted: 5,
        completedSizes: {2, 3},
        tutorialCompleted: true,
      );
      await TrophyRoomStorage.saveStats(stats);

      final achievements = await TrophyRoomStorage.loadAchievements();

      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.size4x4Master]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.size9x9Master]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.tutorialComplete]!.isUnlocked, isTrue);
    });

    test('loadStats returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = await TrophyRoomStorage.loadStats();

      expect(stats.totalCompleted, equals(0));
      expect(stats.completedSizes, isEmpty);
    });

    test('isAchievementUnlocked checks against derived achievements', () async {
      SharedPreferences.setMockInitialValues({});

      // Initially not unlocked
      var isUnlocked = await TrophyRoomStorage.isAchievementUnlocked(AchievementType.tutorialComplete);
      expect(isUnlocked, isFalse);

      // Mark tutorial completed
      await TrophyRoomStorage.markTutorialCompleted();

      isUnlocked = await TrophyRoomStorage.isAchievementUnlocked(AchievementType.tutorialComplete);
      expect(isUnlocked, isTrue);
    });

    test('markTutorialCompleted updates stats', () async {
      SharedPreferences.setMockInitialValues({});

      final achievement = await TrophyRoomStorage.markTutorialCompleted();
      expect(achievement, isNotNull);
      expect(achievement!.type, equals(AchievementType.tutorialComplete));

      final stats = await TrophyRoomStorage.loadStats();
      expect(stats.tutorialCompleted, isTrue);
    });

    test('markTutorialCompleted returns null if already completed', () async {
      SharedPreferences.setMockInitialValues({});

      await TrophyRoomStorage.markTutorialCompleted();
      final secondCall = await TrophyRoomStorage.markTutorialCompleted();

      expect(secondCall, isNull);
    });
  });

  group('AchievementTracker Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('unlocks firstSolve on first completion', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'first_solve',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.firstSolve), isTrue);
    });

    test('unlocks size achievements correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final record4x4 = PuzzleRecord(
        id: '4x4_test',
        n: 2,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record4x4,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.size4x4Master), isTrue);
    });

    test('unlocks speedDemon for fast completion', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'speed_test',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: const Duration(seconds: 90),
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.speedDemon), isTrue);
    });

    test('does not unlock speedDemon for slow completion', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'slow_test',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: const Duration(minutes: 5),
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.speedDemon), isFalse);
    });

    test('unlocks constraintMaster when using all 3 types', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'constraint_test',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 3,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.constraintMaster), isTrue);
    });

    test('4x4 constraint-only does NOT unlock constraint achievement (too easy)', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'constraint_only_4x4',
        n: 2,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 0,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 1,
        manualMoves: 0,
      );

      // 4x4 constraint-only should NOT unlock constraintOnly9x9
      expect(newAchievements.any((a) => a.type == AchievementType.constraintOnly9x9), isFalse);
    });

    test('unlocks constraintOnly9x9 for 9x9 with zero manual moves', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'constraint_only_9x9',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 0,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 1,
        manualMoves: 0,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.constraintOnly9x9), isTrue);
    });

    test('does not double-count same puzzle', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'duplicate_test',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final tracker = AchievementTracker();

      // Complete the puzzle first time
      await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 5,
      );

      var stats = await TrophyRoomStorage.loadStats();
      expect(stats.totalCompleted, equals(1));

      // Complete same puzzle again (same content ID)
      final duplicateRecord = PuzzleRecord(
        id: 'duplicate_test_2',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      await tracker.checkAchievements(
        completedPuzzle: duplicateRecord,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 5,
      );

      stats = await TrophyRoomStorage.loadStats();
      expect(stats.totalCompleted, equals(1)); // Still 1
    });

    test('counts different puzzles separately', () async {
      SharedPreferences.setMockInitialValues({});

      final record1 = PuzzleRecord(
        id: 'puzzle_1',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 3],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final record2 = PuzzleRecord(
        id: 'puzzle_2',
        n: 3,
        hints: [0, 5, 10],
        hintValues: [1, 2, 4], // Different value
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final tracker = AchievementTracker();

      await tracker.checkAchievements(
        completedPuzzle: record1,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 5,
      );

      await tracker.checkAchievements(
        completedPuzzle: record2,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 5,
      );

      final stats = await TrophyRoomStorage.loadStats();
      expect(stats.totalCompleted, equals(2));
    });

    test('unlocks difficulty tier achievements', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'hard_puzzle',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 50,
        difficultyForwards: 10000, // ~0.46 normalized = Hard tier
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 50,
      );

      // Should unlock hard1 (first hard puzzle)
      expect(newAchievements.any((a) => a.type == AchievementType.hard1), isTrue);
    });
  });

  group('Stats Persistence After Deletion Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('deleting puzzle does not affect achievement progress', () async {
      SharedPreferences.setMockInitialValues({});

      // Complete a puzzle
      final record = PuzzleRecord(
        id: 'test_puzzle',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 10,
      );

      await TrophyRoomStorage.addPuzzleRecord(record);

      final tracker = AchievementTracker();
      await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: const Duration(seconds: 60),
        constraintTypesUsed: 3,
        manualMoves: 10,
      );

      // Verify achievements
      var achievements = await TrophyRoomStorage.loadAchievements();
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.size9x9Master]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.speedDemon]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.constraintMaster]!.isUnlocked, isTrue);

      // Delete the puzzle record
      await TrophyRoomStorage.deletePuzzleRecord('test_puzzle');

      // Verify puzzle is gone
      final records = await TrophyRoomStorage.loadPuzzleRecords();
      expect(records, isEmpty);

      // Verify achievements are still there!
      achievements = await TrophyRoomStorage.loadAchievements();
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.size9x9Master]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.speedDemon]!.isUnlocked, isTrue);
      expect(achievements[AchievementType.constraintMaster]!.isUnlocked, isTrue);
    });

    test('deleting all puzzles preserves complete achievement history', () async {
      SharedPreferences.setMockInitialValues({});

      final tracker = AchievementTracker();

      // Complete multiple puzzles
      for (int i = 0; i < 5; i++) {
        final record = PuzzleRecord(
          id: 'puzzle_$i',
          n: 3,
          hints: [i],
          hintValues: [i + 1],
          completedAt: DateTime.now(),
          moveCount: 10,
        );

        await TrophyRoomStorage.addPuzzleRecord(record);
        await tracker.checkAchievements(
          completedPuzzle: record,
          timeSpent: null,
          constraintTypesUsed: 0,
          manualMoves: 10,
        );
      }

      // Verify count
      var stats = await TrophyRoomStorage.loadStats();
      expect(stats.totalCompleted, equals(5));

      // Delete all puzzle records
      final records = await TrophyRoomStorage.loadPuzzleRecords();
      for (final record in records) {
        await TrophyRoomStorage.deletePuzzleRecord(record.id);
      }

      // Verify puzzle records are gone
      final remaining = await TrophyRoomStorage.loadPuzzleRecords();
      expect(remaining, isEmpty);

      // Stats should still show 5 completions
      stats = await TrophyRoomStorage.loadStats();
      expect(stats.totalCompleted, equals(5));
    });
  });

  group('Achievement Model Tests', () {
    test('isUnlocked returns false when unlockedAt is null', () {
      final achievement = getDefaultAchievements()[AchievementType.firstSolve]!;
      expect(achievement.isUnlocked, isFalse);
    });

    test('progressPercent calculates correctly', () {
      final achievement = getDefaultAchievements()[AchievementType.tenPuzzles]!
          .copyWith(progress: 5);
      expect(achievement.progressPercent, equals(0.5));
    });

    test('progressPercent clamps to 1.0', () {
      final achievement = getDefaultAchievements()[AchievementType.tenPuzzles]!
          .copyWith(progress: 15);
      expect(achievement.progressPercent, equals(1.0));
    });
  });
}
