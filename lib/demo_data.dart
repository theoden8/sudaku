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
/// Solution row 0: 4 6 8 9 3 1 5 2 7
/// Solution row 1: 7 5 1 6 2 4 8 3 9
///
/// This adds 3 valid constraints:
/// 1. AllDiff on cells [1,2,3] (solutions 6,8,9 - all different)
/// 2. OneOf(1) on cells [5,6,7] (cell 5 has solution 1)
/// 3. Equal on cells [8,9] (both have solution 7)
void setupDemoConstraints(Sudoku sd) {
  final ne4 = sd.ne4;

  // Constraint 1: AllDiff on row 0, columns 1-3 (indices 1, 2, 3)
  // These cells have solutions 6, 8, 9 - all different
  final allDiffVars = BitArray(ne4);
  allDiffVars.setBit(1);
  allDiffVars.setBit(2);
  allDiffVars.setBit(3);
  final allDiffDomain = BitArray(sd.ne2 + 1);
  allDiffDomain.setBit(6);
  allDiffDomain.setBit(8);
  allDiffDomain.setBit(9);
  sd.assist.addConstraint(ConstraintAllDiff(sd, allDiffVars, allDiffDomain));

  // Constraint 2: OneOf(1) on row 0, columns 5-7 (indices 5, 6, 7)
  // Cell 5 has solution 1
  final oneOfVars = BitArray(ne4);
  oneOfVars.setBit(5);
  oneOfVars.setBit(6);
  oneOfVars.setBit(7);
  sd.assist.addConstraint(ConstraintOneOf(sd, oneOfVars, 1));

  // Constraint 3: Equal on cells 8 and 9 (row 0 col 8, row 1 col 0)
  // Both have solution 7
  final equalVars = BitArray(ne4);
  equalVars.setBit(8);
  equalVars.setBit(9);
  sd.assist.addConstraint(ConstraintEqual(sd, equalVars));

  // Run the assistant to process the constraints
  sd.assist.run();
}
