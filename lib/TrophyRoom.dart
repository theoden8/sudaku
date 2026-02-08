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
  final int? difficultyForwards;  // Average forwards count from difficulty estimation

  PuzzleRecord({
    required this.id,
    required this.n,
    required this.hints,
    required this.hintValues,
    required this.completedAt,
    required this.moveCount,
    this.nickname,
    this.difficultyForwards,
  });

  /// Get difficulty as a normalized value 0.0-1.0 using log scale
  /// Based on reference values: min ~324 (trivial 9x9), max ~600k (top44 16x16)
  double? get difficultyNormalized {
    if (difficultyForwards == null) return null;
    // Log scale: log2(324) ≈ 8.3, log2(600000) ≈ 19.2
    // Range of ~11 log units
    const minLog = 8.3;
    const maxLog = 19.2;
    final logVal = _log2(difficultyForwards!.toDouble());
    return ((logVal - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  static double _log2(double x) => x > 0 ? (log(x) / ln2) : 0;

  /// Get difficulty label for display
  String get difficultyLabel {
    final norm = difficultyNormalized;
    if (norm == null) return 'Unknown';
    if (norm < 0.15) return 'Easy';
    if (norm < 0.35) return 'Medium';
    if (norm < 0.55) return 'Hard';
    if (norm < 0.75) return 'Expert';
    return 'Extreme';
  }

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

  /// Generate a content-based ID from hints (for duplicate detection)
  String get contentId {
    final sortedHints = List<int>.from(hints);
    sortedHints.sort();
    final pairs = <String>[];
    for (int i = 0; i < hints.length; i++) {
      final idx = sortedHints.indexOf(hints[i]);
      pairs.add('${hints[i]}:${hintValues[i]}');
    }
    pairs.sort();
    return '${n}_${pairs.join(',')}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': n,
    'hints': hints,
    'hintValues': hintValues,
    'completedAt': completedAt.toIso8601String(),
    'moveCount': moveCount,
    'nickname': nickname,
    'difficultyForwards': difficultyForwards,
  };

  static PuzzleRecord fromJson(Map<String, dynamic> json) => PuzzleRecord(
    id: json['id'] as String,
    n: json['n'] as int,
    hints: (json['hints'] as List).cast<int>(),
    hintValues: (json['hintValues'] as List).cast<int>(),
    completedAt: DateTime.parse(json['completedAt'] as String),
    moveCount: json['moveCount'] as int,
    nickname: json['nickname'] as String?,
    difficultyForwards: json['difficultyForwards'] as int?,
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
  constraintOnly9x9,  // Note: 4x4 constraint-only removed (too easy)
  tutorialComplete,
  // Difficulty-based achievements (per tier with count milestones)
  // Easy tier
  easy1, easy5, easy10,
  // Medium tier
  medium1, medium5, medium10,
  // Hard tier
  hard1, hard5, hard10,
  // Expert tier
  expert1, expert5,
  // Extreme tier
  extreme1, extreme3,
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
    'type': type.name, // Use name for migration safety
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
      title: 'Versatile Solver',
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
    AchievementType.constraintOnly9x9: Achievement(
      type: AchievementType.constraintOnly9x9,
      title: 'Logic Grandmaster',
      description: 'Complete a 9x9 puzzle using only constraints',
      icon: Icons.psychology_rounded,
      gradientColors: [AppColors.gold, AppColors.primaryPurple],
    ),
    AchievementType.tutorialComplete: Achievement(
      type: AchievementType.tutorialComplete,
      title: 'Quick Learner',
      description: 'Complete the constraint tutorial',
      icon: Icons.school_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
    ),
    // Difficulty-based achievements (tiered with count milestones)
    // Easy tier
    AchievementType.easy1: Achievement(
      type: AchievementType.easy1,
      title: 'Easy Start',
      description: 'Complete 1 Easy puzzle',
      icon: Icons.sentiment_satisfied_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
    ),
    AchievementType.easy5: Achievement(
      type: AchievementType.easy5,
      title: 'Easy Going',
      description: 'Complete 5 Easy puzzles',
      icon: Icons.sentiment_satisfied_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      target: 5,
      progress: 0,
    ),
    AchievementType.easy10: Achievement(
      type: AchievementType.easy10,
      title: 'Easy Expert',
      description: 'Complete 10 Easy puzzles',
      icon: Icons.sentiment_satisfied_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      target: 10,
      progress: 0,
    ),
    // Medium tier
    AchievementType.medium1: Achievement(
      type: AchievementType.medium1,
      title: 'Medium Start',
      description: 'Complete 1 Medium puzzle',
      icon: Icons.trending_flat_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
    ),
    AchievementType.medium5: Achievement(
      type: AchievementType.medium5,
      title: 'Medium Minded',
      description: 'Complete 5 Medium puzzles',
      icon: Icons.trending_flat_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
      target: 5,
      progress: 0,
    ),
    AchievementType.medium10: Achievement(
      type: AchievementType.medium10,
      title: 'Medium Master',
      description: 'Complete 10 Medium puzzles',
      icon: Icons.trending_flat_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
      target: 10,
      progress: 0,
    ),
    // Hard tier
    AchievementType.hard1: Achievement(
      type: AchievementType.hard1,
      title: 'Hard Start',
      description: 'Complete 1 Hard puzzle',
      icon: Icons.psychology_alt_rounded,
      gradientColors: [AppColors.warning, AppColors.gold],
    ),
    AchievementType.hard5: Achievement(
      type: AchievementType.hard5,
      title: 'Hard Worker',
      description: 'Complete 5 Hard puzzles',
      icon: Icons.psychology_alt_rounded,
      gradientColors: [AppColors.warning, AppColors.gold],
      target: 5,
      progress: 0,
    ),
    AchievementType.hard10: Achievement(
      type: AchievementType.hard10,
      title: 'Hard Core',
      description: 'Complete 10 Hard puzzles',
      icon: Icons.psychology_alt_rounded,
      gradientColors: [AppColors.warning, AppColors.gold],
      target: 10,
      progress: 0,
    ),
    // Expert tier
    AchievementType.expert1: Achievement(
      type: AchievementType.expert1,
      title: 'Expert Start',
      description: 'Complete 1 Expert puzzle',
      icon: Icons.lightbulb_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
    ),
    AchievementType.expert5: Achievement(
      type: AchievementType.expert5,
      title: 'Expert Mind',
      description: 'Complete 5 Expert puzzles',
      icon: Icons.lightbulb_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
      target: 5,
      progress: 0,
    ),
    // Extreme tier
    AchievementType.extreme1: Achievement(
      type: AchievementType.extreme1,
      title: 'Extreme Start',
      description: 'Complete 1 Extreme puzzle',
      icon: Icons.local_fire_department_rounded,
      gradientColors: [AppColors.error, AppColors.gold],
    ),
    AchievementType.extreme3: Achievement(
      type: AchievementType.extreme3,
      title: 'Extreme Legend',
      description: 'Complete 3 Extreme puzzles',
      icon: Icons.local_fire_department_rounded,
      gradientColors: [AppColors.error, AppColors.gold],
      target: 3,
      progress: 0,
    ),
  };
}

// ============================================================================
// Gamification Stats - Single source of truth for achievements
// ============================================================================

/// Difficulty tiers for achievement tracking
enum _DifficultyTier { easy, medium, hard, expert, extreme }

/// Immutable stats that only grow (monotonic). Achievements are derived from this.
class GamificationStats {
  final int totalCompleted;
  final Set<int> completedSizes;        // {2, 3, 4} for 4x4, 9x9, 16x16
  final Set<String> solvedPuzzleIds;    // Content IDs for duplicate detection

  // High-water marks (monotonic - only increase)
  final int? fastestTimeSeconds;        // Best completion time ever
  final double? maxDifficultyNormalized; // Highest difficulty beaten

  // Boolean flags (once true, stays true)
  final bool usedAllConstraintTypes;    // Ever used all 3 in one puzzle
  final Set<int> constraintOnlySizes;   // Sizes beaten with 0 manual moves
  final bool tutorialCompleted;
  // Difficulty tier counts
  final int easyCount;
  final int mediumCount;
  final int hardCount;
  final int expertCount;
  final int extremeCount;

  const GamificationStats({
    this.totalCompleted = 0,
    this.completedSizes = const {},
    this.solvedPuzzleIds = const {},
    this.fastestTimeSeconds,
    this.maxDifficultyNormalized,
    this.usedAllConstraintTypes = false,
    this.constraintOnlySizes = const {},
    this.tutorialCompleted = false,
    this.easyCount = 0,
    this.mediumCount = 0,
    this.hardCount = 0,
    this.expertCount = 0,
    this.extremeCount = 0,
  });

  /// Create updated stats after completing a puzzle
  GamificationStats recordCompletion({
    required String contentId,
    required int gridSize,
    int? timeSeconds,
    double? difficultyNormalized,
    bool usedAllConstraints = false,
    bool wasConstraintOnly = false,
  }) {
    final isNewPuzzle = !solvedPuzzleIds.contains(contentId);

    // Determine difficulty tier and increment count
    final tier = _getDifficultyTier(difficultyNormalized);
    final newEasyCount = (isNewPuzzle && tier == _DifficultyTier.easy) ? easyCount + 1 : easyCount;
    final newMediumCount = (isNewPuzzle && tier == _DifficultyTier.medium) ? mediumCount + 1 : mediumCount;
    final newHardCount = (isNewPuzzle && tier == _DifficultyTier.hard) ? hardCount + 1 : hardCount;
    final newExpertCount = (isNewPuzzle && tier == _DifficultyTier.expert) ? expertCount + 1 : expertCount;
    final newExtremeCount = (isNewPuzzle && tier == _DifficultyTier.extreme) ? extremeCount + 1 : extremeCount;

    return GamificationStats(
      totalCompleted: isNewPuzzle ? totalCompleted + 1 : totalCompleted,
      completedSizes: {...completedSizes, gridSize},
      solvedPuzzleIds: {...solvedPuzzleIds, contentId},
      fastestTimeSeconds: _minNullable(fastestTimeSeconds, timeSeconds),
      maxDifficultyNormalized: _maxNullable(maxDifficultyNormalized, difficultyNormalized),
      usedAllConstraintTypes: usedAllConstraintTypes || usedAllConstraints,
      constraintOnlySizes: wasConstraintOnly
          ? {...constraintOnlySizes, gridSize}
          : constraintOnlySizes,
      tutorialCompleted: tutorialCompleted,
      easyCount: newEasyCount,
      mediumCount: newMediumCount,
      hardCount: newHardCount,
      expertCount: newExpertCount,
      extremeCount: newExtremeCount,
    );
  }

  static _DifficultyTier _getDifficultyTier(double? normalized) {
    if (normalized == null) return _DifficultyTier.easy; // Default to easy if unknown
    // Match thresholds from difficultyLabel
    if (normalized < 0.15) return _DifficultyTier.easy;
    if (normalized < 0.35) return _DifficultyTier.medium;
    if (normalized < 0.55) return _DifficultyTier.hard;
    if (normalized < 0.75) return _DifficultyTier.expert;
    return _DifficultyTier.extreme;
  }

  /// Mark tutorial as completed
  GamificationStats withTutorialCompleted() => GamificationStats(
    totalCompleted: totalCompleted,
    completedSizes: completedSizes,
    solvedPuzzleIds: solvedPuzzleIds,
    fastestTimeSeconds: fastestTimeSeconds,
    maxDifficultyNormalized: maxDifficultyNormalized,
    usedAllConstraintTypes: usedAllConstraintTypes,
    constraintOnlySizes: constraintOnlySizes,
    tutorialCompleted: true,
    easyCount: easyCount,
    mediumCount: mediumCount,
    hardCount: hardCount,
    expertCount: expertCount,
    extremeCount: extremeCount,
  );

  static int? _minNullable(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static double? _maxNullable(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }

  Map<String, dynamic> toJson() => {
    'totalCompleted': totalCompleted,
    'completedSizes': completedSizes.toList(),
    'solvedPuzzleIds': solvedPuzzleIds.toList(),
    'fastestTimeSeconds': fastestTimeSeconds,
    'maxDifficultyNormalized': maxDifficultyNormalized,
    'usedAllConstraintTypes': usedAllConstraintTypes,
    'constraintOnlySizes': constraintOnlySizes.toList(),
    'tutorialCompleted': tutorialCompleted,
    'easyCount': easyCount,
    'mediumCount': mediumCount,
    'hardCount': hardCount,
    'expertCount': expertCount,
    'extremeCount': extremeCount,
  };

  static GamificationStats fromJson(Map<String, dynamic> json) {
    return GamificationStats(
      totalCompleted: (json['totalCompleted'] ?? 0) as int,
      completedSizes: Set<int>.from(
        ((json['completedSizes'] ?? []) as List).cast<int>(),
      ),
      solvedPuzzleIds: Set<String>.from(
        ((json['solvedPuzzleIds'] ?? []) as List).cast<String>(),
      ),
      fastestTimeSeconds: json['fastestTimeSeconds'] as int?,
      maxDifficultyNormalized: (json['maxDifficultyNormalized'] as num?)?.toDouble(),
      usedAllConstraintTypes: (json['usedAllConstraintTypes'] ?? false) as bool,
      constraintOnlySizes: Set<int>.from(
        ((json['constraintOnlySizes'] ?? []) as List).cast<int>(),
      ),
      tutorialCompleted: (json['tutorialCompleted'] ?? false) as bool,
      easyCount: (json['easyCount'] ?? 0) as int,
      mediumCount: (json['mediumCount'] ?? 0) as int,
      hardCount: (json['hardCount'] ?? 0) as int,
      expertCount: (json['expertCount'] ?? 0) as int,
      extremeCount: (json['extremeCount'] ?? 0) as int,
    );
  }
}

/// Derive achievements from stats - pure function, no side effects
Map<AchievementType, Achievement> deriveAchievements(GamificationStats stats) {
  final templates = getDefaultAchievements();
  final result = <AchievementType, Achievement>{};

  // Helper to mark achievement as unlocked
  Achievement unlocked(AchievementType type) => templates[type]!.copyWith(
    unlockedAt: DateTime.fromMillisecondsSinceEpoch(0), // Placeholder time
  );

  // Helper to set progress on count-based achievements
  Achievement withProgress(AchievementType type, int progress) {
    final template = templates[type]!;
    final isUnlocked = template.target != null && progress >= template.target!;
    return template.copyWith(
      progress: progress,
      unlockedAt: isUnlocked ? DateTime.fromMillisecondsSinceEpoch(0) : null,
    );
  }

  // Count-based achievements (4x4 doesn't count - too easy)
  final hasCompleted9x9OrLarger = stats.completedSizes.contains(3) || stats.completedSizes.contains(4);
  result[AchievementType.firstSolve] = hasCompleted9x9OrLarger
      ? unlocked(AchievementType.firstSolve)
      : templates[AchievementType.firstSolve]!;

  result[AchievementType.tenPuzzles] = withProgress(
    AchievementType.tenPuzzles, stats.totalCompleted);
  result[AchievementType.twentyFivePuzzles] = withProgress(
    AchievementType.twentyFivePuzzles, stats.totalCompleted);
  result[AchievementType.fiftyPuzzles] = withProgress(
    AchievementType.fiftyPuzzles, stats.totalCompleted);

  // Size-based achievements
  result[AchievementType.size4x4Master] = stats.completedSizes.contains(2)
      ? unlocked(AchievementType.size4x4Master)
      : templates[AchievementType.size4x4Master]!;
  result[AchievementType.size9x9Master] = stats.completedSizes.contains(3)
      ? unlocked(AchievementType.size9x9Master)
      : templates[AchievementType.size9x9Master]!;
  result[AchievementType.size16x16Master] = stats.completedSizes.contains(4)
      ? unlocked(AchievementType.size16x16Master)
      : templates[AchievementType.size16x16Master]!;
  result[AchievementType.allSizesMaster] = stats.completedSizes.containsAll([2, 3, 4])
      ? unlocked(AchievementType.allSizesMaster)
      : templates[AchievementType.allSizesMaster]!;

  // Speed achievement
  result[AchievementType.speedDemon] = (stats.fastestTimeSeconds != null && stats.fastestTimeSeconds! < 120)
      ? unlocked(AchievementType.speedDemon)
      : templates[AchievementType.speedDemon]!;

  // Constraint achievements
  result[AchievementType.constraintMaster] = stats.usedAllConstraintTypes
      ? unlocked(AchievementType.constraintMaster)
      : templates[AchievementType.constraintMaster]!;
  // Note: constraintOnly4x4 removed (too easy)
  result[AchievementType.constraintOnly9x9] = stats.constraintOnlySizes.contains(3)
      ? unlocked(AchievementType.constraintOnly9x9)
      : templates[AchievementType.constraintOnly9x9]!;

  // Tutorial achievement
  result[AchievementType.tutorialComplete] = stats.tutorialCompleted
      ? unlocked(AchievementType.tutorialComplete)
      : templates[AchievementType.tutorialComplete]!;

  // Difficulty tier achievements
  // Easy tier
  result[AchievementType.easy1] = stats.easyCount >= 1
      ? unlocked(AchievementType.easy1)
      : templates[AchievementType.easy1]!;
  result[AchievementType.easy5] = withProgress(AchievementType.easy5, stats.easyCount);
  result[AchievementType.easy10] = withProgress(AchievementType.easy10, stats.easyCount);

  // Medium tier
  result[AchievementType.medium1] = stats.mediumCount >= 1
      ? unlocked(AchievementType.medium1)
      : templates[AchievementType.medium1]!;
  result[AchievementType.medium5] = withProgress(AchievementType.medium5, stats.mediumCount);
  result[AchievementType.medium10] = withProgress(AchievementType.medium10, stats.mediumCount);

  // Hard tier
  result[AchievementType.hard1] = stats.hardCount >= 1
      ? unlocked(AchievementType.hard1)
      : templates[AchievementType.hard1]!;
  result[AchievementType.hard5] = withProgress(AchievementType.hard5, stats.hardCount);
  result[AchievementType.hard10] = withProgress(AchievementType.hard10, stats.hardCount);

  // Expert tier
  result[AchievementType.expert1] = stats.expertCount >= 1
      ? unlocked(AchievementType.expert1)
      : templates[AchievementType.expert1]!;
  result[AchievementType.expert5] = withProgress(AchievementType.expert5, stats.expertCount);

  // Extreme tier
  result[AchievementType.extreme1] = stats.extremeCount >= 1
      ? unlocked(AchievementType.extreme1)
      : templates[AchievementType.extreme1]!;
  result[AchievementType.extreme3] = withProgress(AchievementType.extreme3, stats.extremeCount);

  return result;
}

/// Get list of newly unlocked achievements by comparing old and new stats
List<Achievement> getNewlyUnlocked(GamificationStats oldStats, GamificationStats newStats) {
  final oldAchievements = deriveAchievements(oldStats);
  final newAchievements = deriveAchievements(newStats);

  final newlyUnlocked = <Achievement>[];
  for (final type in AchievementType.values) {
    final wasUnlocked = oldAchievements[type]?.isUnlocked ?? false;
    final isNowUnlocked = newAchievements[type]?.isUnlocked ?? false;
    if (!wasUnlocked && isNowUnlocked) {
      newlyUnlocked.add(newAchievements[type]!);
    }
  }
  return newlyUnlocked;
}

// ============================================================================
// Storage
// ============================================================================

class TrophyRoomStorage {
  static const String _puzzleRecordsKey = 'trophyRoom_puzzleRecords';
  static const String _statsKey = 'trophyRoom_stats';

  // Puzzle Records (visible history - can be deleted)
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
    // Check for duplicate by contentId - don't add if already exists
    final existingIndex = records.indexWhere((r) => r.contentId == record.contentId);
    if (existingIndex != -1) {
      // Puzzle already exists, don't add duplicate
      return;
    }
    records.insert(0, record); // Most recent first
    await savePuzzleRecords(records);
  }

  static Future<void> deletePuzzleRecord(String id) async {
    final records = await loadPuzzleRecords();
    records.removeWhere((r) => r.id == id);
    await savePuzzleRecords(records);
    // Note: Stats are NOT modified when deleting a puzzle record
    // This preserves achievement progress
  }

  // Stats (permanent, monotonic)
  static Future<GamificationStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_statsKey);
    if (json == null) return const GamificationStats();

    try {
      return GamificationStats.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return const GamificationStats();
    }
  }

  static Future<void> saveStats(GamificationStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  // Convenience: Load achievements derived from stats
  static Future<Map<AchievementType, Achievement>> loadAchievements() async {
    final stats = await loadStats();
    return deriveAchievements(stats);
  }

  /// Check if a specific achievement is unlocked
  static Future<bool> isAchievementUnlocked(AchievementType type) async {
    final stats = await loadStats();
    final achievements = deriveAchievements(stats);
    return achievements[type]?.isUnlocked ?? false;
  }

  /// Mark tutorial as completed
  static Future<Achievement?> markTutorialCompleted() async {
    final oldStats = await loadStats();
    if (oldStats.tutorialCompleted) return null; // Already completed

    final newStats = oldStats.withTutorialCompleted();
    await saveStats(newStats);

    final achievements = deriveAchievements(newStats);
    return achievements[AchievementType.tutorialComplete];
  }
}

// ============================================================================
// Achievement Tracker
// ============================================================================

class AchievementTracker {
  /// Check and update stats after puzzle completion.
  /// Returns list of newly unlocked achievements.
  Future<List<Achievement>> checkAchievements({
    required PuzzleRecord completedPuzzle,
    required Duration? timeSpent,
    required int constraintTypesUsed,
    required int manualMoves,
  }) async {
    // Load current stats
    final oldStats = await TrophyRoomStorage.loadStats();

    // Update stats with this completion
    final newStats = oldStats.recordCompletion(
      contentId: completedPuzzle.contentId,
      gridSize: completedPuzzle.n,
      timeSeconds: timeSpent?.inSeconds,
      difficultyNormalized: completedPuzzle.difficultyNormalized,
      usedAllConstraints: constraintTypesUsed >= 3,
      wasConstraintOnly: manualMoves == 0,
    );

    // Save updated stats
    await TrophyRoomStorage.saveStats(newStats);

    // Return newly unlocked achievements
    return getNewlyUnlocked(oldStats, newStats);
  }
}
