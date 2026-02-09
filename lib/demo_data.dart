import 'dart:convert';

import 'package:bit_array/bit_array.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Sudoku.dart';
import 'SudokuAssist.dart';
import 'TrophyRoom.dart';

/// Demo puzzle for screenshots - first puzzle from top1465 (fixed, not shuffled).
/// Format: dots (.) for empty cells, digits 1-9 for filled cells.
const String demoPuzzle9x9 =
    '4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........';

/// A simpler 4x4 demo puzzle
const String demoPuzzle4x4 = '1...' '..2.' '3..2' '...1';

/// Seeds demo data for screenshot tests.
///
/// [theme] - 'light' or 'dark'
/// [style] - 'modern' or 'paper'
/// [selectedGridSize] - Pre-select a grid size (2, 3, or 4) for the selection screen
Future<void> seedDemoData({
  String theme = 'light',
  String style = 'modern',
  int? selectedGridSize,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // Set theme mode (0 = system, 1 = light, 2 = dark)
  final themeModeIndex = theme == 'light' ? 1 : 2;
  await prefs.setInt('themeMode', themeModeIndex);

  // Set theme style (0 = modern, 1 = penAndPaper)
  final styleIndex = style == 'modern' ? 0 : 1;
  await prefs.setInt('themeStyle', styleIndex);

  // Set demo mode flag
  await prefs.setBool('demoMode', true);

  // Pre-select grid size if specified
  if (selectedGridSize != null) {
    await prefs.setInt('demoSelectedGridSize', selectedGridSize);
  } else {
    await prefs.remove('demoSelectedGridSize');
  }
}

/// Gets the pre-selected grid size for demo mode.
Future<int?> getDemoSelectedGridSize() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('demoSelectedGridSize');
}

/// Clears all demo mode settings.
Future<void> clearDemoData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('demoMode', false);
  await prefs.remove('demoSelectedGridSize');
}

/// Checks if demo mode is active.
Future<bool> isDemoMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('demoMode') ?? false;
}

/// Parses a demo puzzle string into a list of integers.
/// Returns a list where 0 represents empty cells.
List<int> parseDemoPuzzle(String puzzle) {
  return puzzle.split('').map((c) {
    if (c == '.') return 0;
    return int.parse(c);
  }).toList();
}

/// Sets up demo constraints for the screenshot tour.
///
/// For the demo puzzle '4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........'
/// Solution:
///   Row 0: 4 6 8 9 3 1 5 2 7
///   Row 1: 7 5 1 6 2 4 8 3 9
///   Row 2: 3 9 2 5 7 8 4 6 1
///   Row 3: 1 3 4 7 5 6 2 9 8
///   Row 4: 2 8 9 4 1 3 6 7 5
///   Row 5: 6 7 5 2 8 9 3 1 4
///   Row 6: 8 4 6 1 9 2 7 5 3
///   Row 7: 5 1 3 8 6 7 9 4 2
///   Row 8: 9 2 7 3 4 5 1 8 6
///
/// Constraints span the ENTIRE grid (rows 0-8, boxes 2-7):
///
/// 1. OneOf(1) on cells [27, 49, 74] - boxes 3, 4, 6 - cell 27 has 1
/// 2. Equal on cells [8, 74] - boxes 2, 6 - both = 7
/// 3. AllDiff on cells [29, 51, 67] - boxes 3, 5, 7 - values 4, 3, 6
void setupDemoConstraints(Sudoku sd) {
  final ne4 = sd.ne4;

  // Constraint 1: OneOf(1) spanning rows 3, 5, 8
  // Cell 27 (3,0) box 3 = 1, Cell 49 (5,4) box 4 = 8, Cell 74 (8,2) box 6 = 7
  // Exactly one cell (cell 27) has value 1
  final oneOfVars = BitArray(ne4);
  oneOfVars.setBit(27);  // (3,0) = 1
  oneOfVars.setBit(49);  // (5,4) = 8
  oneOfVars.setBit(74);  // (8,2) = 7
  sd.assist.addConstraint(ConstraintOneOf(sd, oneOfVars, 1));

  // Constraint 2: Equal spanning rows 0 and 8
  // Cell 8 (0,8) box 2 = 7, Cell 74 (8,2) box 6 = 7
  // Both have the same solution value 7
  final equalVars = BitArray(ne4);
  equalVars.setBit(8);   // (0,8) = 7
  equalVars.setBit(74);  // (8,2) = 7
  sd.assist.addConstraint(ConstraintEqual(sd, equalVars));

  // Constraint 3: AllDiff spanning rows 3, 5, 7
  // Cell 29 (3,2) box 3 = 4, Cell 51 (5,6) box 5 = 3, Cell 67 (7,4) box 7 = 6
  // All different values
  final allDiffVars = BitArray(ne4);
  allDiffVars.setBit(29);  // (3,2) = 4
  allDiffVars.setBit(51);  // (5,6) = 3
  allDiffVars.setBit(67);  // (7,4) = 6
  final allDiffDomain = BitArray(sd.ne2 + 1);
  allDiffDomain.setBit(4);
  allDiffDomain.setBit(3);
  allDiffDomain.setBit(6);
  sd.assist.addConstraint(ConstraintAllDiff(sd, allDiffVars, allDiffDomain));

  // NOTE: We intentionally do NOT call sd.assist.apply() here.
  // If we did, the solver would deduce values and satisfy constraints,
  // causing them to disappear from the constraint list before screenshots.
}

/// Seeds demo Trophy Room data for screenshot tests.
///
/// Creates achievements and puzzle records that showcase:
/// - Some achievements unlocked (tutorial, first solve, classic champion, easy1)
/// - Progress toward other achievements (3/10 puzzles, 3/5 easy)
/// - A few completed puzzles in the Puzzles tab
Future<void> seedDemoTrophyRoomData() async {
  final prefs = await SharedPreferences.getInstance();

  // Create demo stats with some achievements unlocked
  final demoStats = GamificationStats(
    totalCompleted: 3,  // 3 puzzles completed (shows 3/10 progress)
    completedSizes: {3},  // Only 9x9 completed
    solvedPuzzleIds: {'demo_puzzle_1', 'demo_puzzle_2', 'demo_puzzle_3'},
    fastestTimeSeconds: 180,  // 3 minutes
    maxDifficultyNormalized: 0.12,  // Easy range
    usedAllConstraintTypes: true,  // Constraint Master unlocked
    constraintOnlySizes: {},
    tutorialCompleted: true,  // Quick Learner unlocked
    easyCount: 3,  // 3 easy puzzles (Easy Start unlocked, 3/5 toward Easy Going)
    mediumCount: 0,
    hardCount: 0,
    expertCount: 0,
    extremeCount: 0,
    speedTiers: {},
    logicTiers: {},
  );

  // Save stats
  await prefs.setString('trophyRoom_stats', jsonEncode(demoStats.toJson()));

  // Create demo puzzle records
  // Using real puzzle patterns for realistic mini-grid previews
  final demoPuzzles = [
    PuzzleRecord(
      id: 'demo_1_${DateTime.now().millisecondsSinceEpoch}',
      n: 3,
      hints: [0, 4, 6, 10, 14, 18, 20, 24, 26, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80],
      hintValues: [4, 3, 5, 6, 8, 5, 9, 8, 6, 1, 2, 2, 1, 3, 6, 3, 1, 5, 9, 4, 9, 1, 6],
      completedAt: DateTime.now().subtract(const Duration(days: 1)),
      moveCount: 42,
      difficultyForwards: 350,  // Easy
    ),
    PuzzleRecord(
      id: 'demo_2_${DateTime.now().millisecondsSinceEpoch}',
      n: 3,
      hints: [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77],
      hintValues: [6, 1, 7, 2, 4, 3, 4, 4, 8, 7, 6, 9, 8, 7, 1, 1, 7, 5, 2, 8],
      completedAt: DateTime.now().subtract(const Duration(days: 3)),
      moveCount: 38,
      difficultyForwards: 420,  // Easy
    ),
    PuzzleRecord(
      id: 'demo_3_${DateTime.now().millisecondsSinceEpoch}',
      n: 3,
      hints: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62, 66, 70, 74, 78],
      hintValues: [8, 5, 6, 8, 1, 9, 7, 9, 4, 2, 1, 3, 3, 6, 9, 5, 9, 6, 7, 8],
      completedAt: DateTime.now().subtract(const Duration(days: 7)),
      moveCount: 45,
      difficultyForwards: 380,  // Easy
    ),
  ];

  // Save puzzle records
  await prefs.setString(
    'trophyRoom_puzzleRecords',
    jsonEncode(demoPuzzles.map((p) => p.toJson()).toList()),
  );
}

/// Clears all Trophy Room demo data.
Future<void> clearDemoTrophyRoomData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('trophyRoom_stats');
  await prefs.remove('trophyRoom_puzzleRecords');
}
