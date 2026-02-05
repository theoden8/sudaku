import 'package:shared_preferences/shared_preferences.dart';

/// Demo puzzle for screenshots - a carefully selected 9x9 puzzle
/// that shows good assistant deductions when constraints are applied.
/// Format: dots (.) for empty cells, digits 1-9 for filled cells.
const String demoPuzzle9x9 =
    '..53.....8......2..7..1.5..4....53...1..7...6..32...8..6.5....9..4....3......97..';

/// A simpler 4x4 demo puzzle
const String demoPuzzle4x4 = '1...' '..2.' '3..2' '...1';

/// Seeds demo data for screenshot tests.
///
/// [theme] - 'light' or 'dark'
/// [selectedGridSize] - Pre-select a grid size (2, 3, or 4) for the selection screen
Future<void> seedDemoData({
  String theme = 'light',
  int? selectedGridSize,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // Set theme mode (0 = system, 1 = light, 2 = dark)
  final themeModeIndex = theme == 'light' ? 1 : 2;
  await prefs.setInt('themeMode', themeModeIndex);

  // Set theme style (0 = modern, 1 = penAndPaper)
  await prefs.setInt('themeStyle', 0); // Modern style for screenshots

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

/// Clears demo mode flag.
Future<void> clearDemoData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('demoMode', false);
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
