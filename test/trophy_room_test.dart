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

    test('deletePuzzleRecord removes record', () async {
      SharedPreferences.setMockInitialValues({});

      final record1 = PuzzleRecord(
        id: 'delete_test_1',
        n: 3,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 5,
      );
      final record2 = PuzzleRecord(
        id: 'delete_test_2',
        n: 3,
        hints: [1],
        hintValues: [2],
        completedAt: DateTime.now(),
        moveCount: 6,
      );

      await TrophyRoomStorage.addPuzzleRecord(record1);
      await TrophyRoomStorage.addPuzzleRecord(record2);

      var records = await TrophyRoomStorage.loadPuzzleRecords();
      expect(records.length, equals(2));

      await TrophyRoomStorage.deletePuzzleRecord('delete_test_1');
      records = await TrophyRoomStorage.loadPuzzleRecords();

      expect(records.length, equals(1));
      expect(records[0].id, equals('delete_test_2'));
    });

    test('loadAchievements returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final achievements = await TrophyRoomStorage.loadAchievements();

      expect(achievements.length, equals(AchievementType.values.length));
      expect(achievements[AchievementType.firstSolve]!.isUnlocked, isFalse);
    });

    test('loadStats returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = await TrophyRoomStorage.loadStats();

      expect(stats['totalCompleted'], equals(0));
      expect(stats['completedSizes'], isEmpty);
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

    test('unlocks size4x4Master for n=2 completion', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'size_test',
        n: 2,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
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
        timeSpent: const Duration(seconds: 90), // Under 2 minutes
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
        timeSpent: const Duration(minutes: 5), // Over 2 minutes
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.speedDemon), isFalse);
    });

    test('unlocks constraintMaster when using all 3 constraint types', () async {
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

    test('tracks progress for count-based achievements', () async {
      SharedPreferences.setMockInitialValues({});

      final tracker = AchievementTracker();

      // Complete first puzzle
      await tracker.checkAchievements(
        completedPuzzle: PuzzleRecord(
          id: 'progress_1',
          n: 3,
          hints: [0],
          hintValues: [1],
          completedAt: DateTime.now(),
          moveCount: 5,
        ),
        timeSpent: null,
        constraintTypesUsed: 0,
        manualMoves: 10,
      );

      final achievements = await TrophyRoomStorage.loadAchievements();
      expect(achievements[AchievementType.tenPuzzles]!.progress, equals(1));
    });

    test('unlocks constraintOnly4x4 for 4x4 with zero manual moves', () async {
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

      expect(newAchievements.any((a) => a.type == AchievementType.constraintOnly4x4), isTrue);
    });

    test('does not unlock constraintOnly4x4 for 4x4 with manual moves', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'manual_4x4',
        n: 2,
        hints: [0],
        hintValues: [1],
        completedAt: DateTime.now(),
        moveCount: 5,
      );

      final tracker = AchievementTracker();
      final newAchievements = await tracker.checkAchievements(
        completedPuzzle: record,
        timeSpent: null,
        constraintTypesUsed: 1,
        manualMoves: 5,
      );

      expect(newAchievements.any((a) => a.type == AchievementType.constraintOnly4x4), isFalse);
    });

    test('does not unlock constraintOnly4x4 for 9x9 with zero manual moves', () async {
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

      expect(newAchievements.any((a) => a.type == AchievementType.constraintOnly4x4), isFalse);
    });

    test('unlocks constraintOnly9x9 for 9x9 with zero manual moves', () async {
      SharedPreferences.setMockInitialValues({});

      final record = PuzzleRecord(
        id: 'constraint_only_9x9_success',
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

    test('does not double-count same puzzle for achievements', () async {
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
      expect(stats['totalCompleted'], equals(1));

      // Complete the same puzzle again (same hints/values)
      final duplicateRecord = PuzzleRecord(
        id: 'duplicate_test_2', // Different ID but same content
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
      // Should still be 1 because it's the same puzzle
      expect(stats['totalCompleted'], equals(1));
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
      expect(stats['totalCompleted'], equals(2));
    });
  });

  group('PuzzleRecord Content ID Tests', () {
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
          .copyWith(progress: 15); // Over target
      expect(achievement.progressPercent, equals(1.0));
    });
  });
}
