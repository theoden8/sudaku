import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

// ============================================================================
// Puzzle Record - represents a completed puzzle
// ============================================================================

class PuzzleRecord {
  final String id;
  final int n;
  final List<int> hints;
  final List<int> hintValues;
  final DateTime completedAt;
  final int moveCount;
  final String? nickname;

  PuzzleRecord({
    required this.id,
    required this.n,
    required this.hints,
    required this.hintValues,
    required this.completedAt,
    required this.moveCount,
    this.nickname,
  });

  int get ne2 => n * n;
  int get ne4 => ne2 * ne2;

  /// Convert to dot notation format (e.g., '.4.3.......6..8..')
  String toDotNotation() {
    final buffer = List.filled(ne4, 0);
    for (int i = 0; i < hints.length; i++) {
      buffer[hints[i]] = hintValues[i];
    }
    return buffer.map((v) {
      if (v == 0) return '.';
      if (v > 9) return String.fromCharCode('A'.codeUnitAt(0) + v - 10);
      return v.toString();
    }).join();
  }

  /// Parse from dot notation format
  static PuzzleRecord? fromDotNotation(String notation, int n) {
    final cleanNotation = notation.replaceAll(RegExp(r'\s'), '');
    final ne2 = n * n;
    final ne4 = ne2 * ne2;

    if (cleanNotation.length != ne4) return null;

    final hints = <int>[];
    final hintValues = <int>[];

    for (int i = 0; i < ne4; i++) {
      final c = cleanNotation[i];
      if (c != '.') {
        hints.add(i);
        if (c.codeUnitAt(0) >= 'A'.codeUnitAt(0) && c.codeUnitAt(0) <= 'G'.codeUnitAt(0)) {
          hintValues.add(c.codeUnitAt(0) - 'A'.codeUnitAt(0) + 10);
        } else {
          final parsed = int.tryParse(c);
          if (parsed == null || parsed < 1 || parsed > ne2) return null;
          hintValues.add(parsed);
        }
      }
    }

    return PuzzleRecord(
      id: _generateUniqueId(),
      n: n,
      hints: hints,
      hintValues: hintValues,
      completedAt: DateTime.now(),
      moveCount: 0,
      nickname: 'Imported Puzzle',
    );
  }

  static String _generateUniqueId() {
    final random = Random();
    return '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': n,
    'hints': hints,
    'hintValues': hintValues,
    'completedAt': completedAt.toIso8601String(),
    'moveCount': moveCount,
    'nickname': nickname,
  };

  static PuzzleRecord fromJson(Map<String, dynamic> json) => PuzzleRecord(
    id: json['id'] as String,
    n: json['n'] as int,
    hints: (json['hints'] as List).cast<int>(),
    hintValues: (json['hintValues'] as List).cast<int>(),
    completedAt: DateTime.parse(json['completedAt'] as String),
    moveCount: json['moveCount'] as int,
    nickname: json['nickname'] as String?,
  );

  /// Build buffer for launching puzzle (all hints filled, rest empty)
  List<int> buildLaunchBuffer() {
    final buffer = List.filled(ne4, 0);
    for (int i = 0; i < hints.length; i++) {
      buffer[hints[i]] = hintValues[i];
    }
    return buffer;
  }
}

// ============================================================================
// Achievement System
// ============================================================================

enum AchievementType {
  firstSolve,
  tenPuzzles,
  twentyFivePuzzles,
  fiftyPuzzles,
  size4x4Master,
  size9x9Master,
  size16x16Master,
  allSizesMaster,
  speedDemon,
  constraintMaster,
  constraintOnly4x4,
}

class Achievement {
  final AchievementType type;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final DateTime? unlockedAt;
  final int? progress;
  final int? target;

  Achievement({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.unlockedAt,
    this.progress,
    this.target,
  });

  bool get isUnlocked => unlockedAt != null;

  double get progressPercent =>
      (progress != null && target != null && target! > 0)
          ? (progress! / target!).clamp(0.0, 1.0)
          : 0.0;

  Achievement copyWith({
    DateTime? unlockedAt,
    int? progress,
  }) => Achievement(
    type: type,
    title: title,
    description: description,
    icon: icon,
    gradientColors: gradientColors,
    unlockedAt: unlockedAt ?? this.unlockedAt,
    progress: progress ?? this.progress,
    target: target,
  );

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'progress': progress,
  };

  static Achievement fromJson(Map<String, dynamic> json, Achievement template) {
    return template.copyWith(
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      progress: json['progress'] as int?,
    );
  }
}

/// Default achievement definitions
Map<AchievementType, Achievement> getDefaultAchievements() {
  return {
    AchievementType.firstSolve: Achievement(
      type: AchievementType.firstSolve,
      title: 'First Steps',
      description: 'Complete your first puzzle',
      icon: Icons.star_rounded,
      gradientColors: [AppColors.gold, const Color(0xFFFFB347)],
    ),
    AchievementType.tenPuzzles: Achievement(
      type: AchievementType.tenPuzzles,
      title: 'Getting Hooked',
      description: 'Complete 10 puzzles',
      icon: Icons.looks_one_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      target: 10,
      progress: 0,
    ),
    AchievementType.twentyFivePuzzles: Achievement(
      type: AchievementType.twentyFivePuzzles,
      title: 'Dedicated',
      description: 'Complete 25 puzzles',
      icon: Icons.trending_up_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
      target: 25,
      progress: 0,
    ),
    AchievementType.fiftyPuzzles: Achievement(
      type: AchievementType.fiftyPuzzles,
      title: 'Sudoku Master',
      description: 'Complete 50 puzzles',
      icon: Icons.workspace_premium_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
      target: 50,
      progress: 0,
    ),
    AchievementType.size4x4Master: Achievement(
      type: AchievementType.size4x4Master,
      title: 'Mini Master',
      description: 'Complete a 4x4 puzzle',
      icon: Icons.grid_3x3_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
    ),
    AchievementType.size9x9Master: Achievement(
      type: AchievementType.size9x9Master,
      title: 'Classic Champion',
      description: 'Complete a 9x9 puzzle',
      icon: Icons.grid_view_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
    ),
    AchievementType.size16x16Master: Achievement(
      type: AchievementType.size16x16Master,
      title: 'Challenge Conqueror',
      description: 'Complete a 16x16 puzzle',
      icon: Icons.apps_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
    ),
    AchievementType.allSizesMaster: Achievement(
      type: AchievementType.allSizesMaster,
      title: 'Size Doesn\'t Matter',
      description: 'Complete puzzles of all sizes',
      icon: Icons.emoji_events_rounded,
      gradientColors: [AppColors.gold, AppColors.warning],
    ),
    AchievementType.speedDemon: Achievement(
      type: AchievementType.speedDemon,
      title: 'Speed Demon',
      description: 'Complete a puzzle in under 2 minutes',
      icon: Icons.speed_rounded,
      gradientColors: [AppColors.error, AppColors.errorLight],
    ),
    AchievementType.constraintMaster: Achievement(
      type: AchievementType.constraintMaster,
      title: 'Constraint Master',
      description: 'Use all 3 constraint types in one puzzle',
      icon: Icons.rule_rounded,
      gradientColors: [AppColors.primaryPurple, AppColors.secondaryPurple],
    ),
    AchievementType.constraintOnly4x4: Achievement(
      type: AchievementType.constraintOnly4x4,
      title: 'Pure Logic',
      description: 'Complete a 4x4 puzzle using only constraints',
      icon: Icons.auto_fix_high_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.gold],
    ),
  };
}

// ============================================================================
// Storage
// ============================================================================

class TrophyRoomStorage {
  static const String _puzzleRecordsKey = 'trophyRoom_puzzleRecords';
  static const String _achievementsKey = 'trophyRoom_achievements';
  static const String _statsKey = 'trophyRoom_stats';

  // Puzzle Records
  static Future<List<PuzzleRecord>> loadPuzzleRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_puzzleRecordsKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => PuzzleRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> savePuzzleRecords(List<PuzzleRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(_puzzleRecordsKey, json);
  }

  static Future<void> addPuzzleRecord(PuzzleRecord record) async {
    final records = await loadPuzzleRecords();
    records.insert(0, record); // Most recent first
    await savePuzzleRecords(records);
  }

  static Future<void> deletePuzzleRecord(String id) async {
    final records = await loadPuzzleRecords();
    records.removeWhere((r) => r.id == id);
    await savePuzzleRecords(records);
  }

  // Achievements
  static Future<Map<AchievementType, Achievement>> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_achievementsKey);
    final defaults = getDefaultAchievements();

    if (json == null) return defaults;

    try {
      final savedMap = jsonDecode(json) as Map<String, dynamic>;
      final result = <AchievementType, Achievement>{};

      for (final type in AchievementType.values) {
        final template = defaults[type]!;
        final key = type.index.toString();
        if (savedMap.containsKey(key)) {
          result[type] = Achievement.fromJson(
            savedMap[key] as Map<String, dynamic>,
            template,
          );
        } else {
          result[type] = template;
        }
      }
      return result;
    } catch (e) {
      return defaults;
    }
  }

  static Future<void> saveAchievements(Map<AchievementType, Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final entry in achievements.entries) {
      map[entry.key.index.toString()] = entry.value.toJson();
    }
    await prefs.setString(_achievementsKey, jsonEncode(map));
  }

  // Stats
  static Future<Map<String, dynamic>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_statsKey);
    if (json == null) {
      return {
        'totalCompleted': 0,
        'completedSizes': <int>[],
      };
    }
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return {
        'totalCompleted': 0,
        'completedSizes': <int>[],
      };
    }
  }

  static Future<void> saveStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats));
  }
}

// ============================================================================
// Achievement Tracker
// ============================================================================

class AchievementTracker {
  /// Check and unlock achievements after puzzle completion.
  /// Returns list of newly unlocked achievements.
  Future<List<Achievement>> checkAchievements({
    required PuzzleRecord completedPuzzle,
    required Duration? timeSpent,
    required int constraintTypesUsed,
    required int manualMoves,
  }) async {
    final newlyUnlocked = <Achievement>[];
    final achievements = await TrophyRoomStorage.loadAchievements();
    final stats = await TrophyRoomStorage.loadStats();

    // Update stats
    final totalCompleted = ((stats['totalCompleted'] ?? 0) as int) + 1;
    final completedSizes = Set<int>.from(
      ((stats['completedSizes'] ?? []) as List).cast<int>(),
    )..add(completedPuzzle.n);

    // Helper to unlock achievement
    void unlock(AchievementType type) {
      if (!achievements[type]!.isUnlocked) {
        achievements[type] = achievements[type]!.copyWith(
          unlockedAt: DateTime.now(),
        );
        newlyUnlocked.add(achievements[type]!);
      }
    }

    // Helper to update progress
    void updateProgress(AchievementType type, int progress) {
      final current = achievements[type]!;
      achievements[type] = current.copyWith(progress: progress);
      if (current.target != null && progress >= current.target! && !current.isUnlocked) {
        unlock(type);
      }
    }

    // Check first solve
    if (totalCompleted == 1) {
      unlock(AchievementType.firstSolve);
    }

    // Check count-based achievements
    updateProgress(AchievementType.tenPuzzles, totalCompleted);
    updateProgress(AchievementType.twentyFivePuzzles, totalCompleted);
    updateProgress(AchievementType.fiftyPuzzles, totalCompleted);

    // Check size-based achievements
    if (completedPuzzle.n == 2) {
      unlock(AchievementType.size4x4Master);
    } else if (completedPuzzle.n == 3) {
      unlock(AchievementType.size9x9Master);
    } else if (completedPuzzle.n == 4) {
      unlock(AchievementType.size16x16Master);
    }

    // Check all sizes
    if (completedSizes.containsAll([2, 3, 4])) {
      unlock(AchievementType.allSizesMaster);
    }

    // Check speed demon (under 2 minutes)
    if (timeSpent != null && timeSpent.inSeconds < 120) {
      unlock(AchievementType.speedDemon);
    }

    // Check constraint master (all 3 types used)
    if (constraintTypesUsed >= 3) {
      unlock(AchievementType.constraintMaster);
    }

    // Check constraint-only 4x4 (solved without manual cell entries)
    if (completedPuzzle.n == 2 && manualMoves == 0) {
      unlock(AchievementType.constraintOnly4x4);
    }

    // Save updates
    await TrophyRoomStorage.saveAchievements(achievements);
    await TrophyRoomStorage.saveStats({
      'totalCompleted': totalCompleted,
      'completedSizes': completedSizes.toList(),
    });

    return newlyUnlocked;
  }
}
