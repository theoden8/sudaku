import 'package:bit_array/bit_array.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Sudoku.dart';
import 'SudokuAssist.dart';

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
///
/// These constraints span DIFFERENT boxes to show user-defined constraints
/// (not just the default row/col/box constraints):
///
/// 1. OneOf(6) on cells [1, 13, 24] - across boxes 0, 1, 2 - cell 1 has 6
/// 2. Equal on cells [8, 9] - boxes 2 and 0 - both have solution 7
/// 3. AllDiff on cells [2, 14, 25] - boxes 0, 1, 2 - solutions 8, 4, 6
void setupDemoConstraints(Sudoku sd) {
  final ne4 = sd.ne4;

  // Constraint 1: OneOf(6) across different boxes
  // Cell 1 (0,1) box 0 = 6, Cell 13 (1,4) box 1 = 2, Cell 24 (2,6) box 2 = 4
  // Exactly one cell (cell 1) has value 6
  final oneOfVars = BitArray(ne4);
  oneOfVars.setBit(1);   // (0,1) = 6
  oneOfVars.setBit(13);  // (1,4) = 2
  oneOfVars.setBit(24);  // (2,6) = 4
  sd.assist.addConstraint(ConstraintOneOf(sd, oneOfVars, 6));

  // Constraint 2: Equal on cells from different boxes
  // Cell 8 (0,8) box 2 = 7, Cell 9 (1,0) box 0 = 7
  // Both have the same solution value 7
  final equalVars = BitArray(ne4);
  equalVars.setBit(8);   // (0,8) = 7
  equalVars.setBit(9);   // (1,0) = 7
  sd.assist.addConstraint(ConstraintEqual(sd, equalVars));

  // Constraint 3: AllDiff across different boxes
  // Cell 2 (0,2) box 0 = 8, Cell 14 (1,5) box 1 = 4, Cell 25 (2,7) box 2 = 6
  // All different values
  final allDiffVars = BitArray(ne4);
  allDiffVars.setBit(2);   // (0,2) = 8
  allDiffVars.setBit(14);  // (1,5) = 4
  allDiffVars.setBit(25);  // (2,7) = 6
  final allDiffDomain = BitArray(sd.ne2 + 1);
  allDiffDomain.setBit(8);
  allDiffDomain.setBit(4);
  allDiffDomain.setBit(6);
  sd.assist.addConstraint(ConstraintAllDiff(sd, allDiffVars, allDiffDomain));

  // Apply the constraints
  sd.assist.apply();
}
