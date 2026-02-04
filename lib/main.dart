import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:bit_array/bit_array.dart';
// import 'package:flutter_redux/flutter_redux.dart';
// import 'package:redux/redux.dart';


import 'SudokuNumpadScreen.dart';
import 'SudokuAssistScreen.dart';
import 'SudokuScreen.dart';
import 'MenuScreen.dart';


/// Custom painter for hand-drawn/sketched grid lines (Excalidraw-style)
/// Used for pen-and-paper theme to give a hand-drawn feel
class SketchedGridPainter extends CustomPainter {
  final int n;  // Grid dimension (e.g., 3 for 9x9)
  final Color lineColor;
  final double size;
  final List<List<double>> _wobbleCache;
  final double wobbleAmount;
  final double thinLineWidth;
  final double thickLineWidth;

  SketchedGridPainter({
    required this.n,
    required this.lineColor,
    required this.size,
    this.wobbleAmount = 3.0,
    this.thinLineWidth = 1.0,
    this.thickLineWidth = 2.5,
  }) : _wobbleCache = _generateWobbleCache(n, wobbleAmount);

  // Pre-generate wobble values so they're consistent across repaints
  static List<List<double>> _generateWobbleCache(int n, double wobbleAmount) {
    final random = Random(42);  // Fixed seed for consistency
    final ne2 = n * n;
    final totalLines = (ne2 + 1) * 2;  // Horizontal + vertical lines
    final segmentsPerLine = 12;  // Max segments per line

    return List.generate(totalLines, (lineIndex) {
      return List.generate(segmentsPerLine * 2, (i) {
        return (random.nextDouble() - 0.5) * wobbleAmount;
      });
    });
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final ne2 = n * n;  // Total cells per row/column
    final cellSize = size / ne2;

    // Thin lines for cell borders
    final thinPaint = Paint()
      ..color = lineColor.withOpacity(0.4)
      ..strokeWidth = thinLineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Thick lines for box borders
    final thickPaint = Paint()
      ..color = lineColor.withOpacity(0.9)
      ..strokeWidth = thickLineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    int lineIndex = 0;

    // Draw horizontal lines
    for (int i = 0; i <= ne2; i++) {
      final y = i * cellSize;
      final isBoxBorder = i % n == 0;
      final paint = isBoxBorder ? thickPaint : thinPaint;
      _drawSketchedLine(canvas, Offset(0, y), Offset(size, y), paint, lineIndex++);
    }

    // Draw vertical lines
    for (int j = 0; j <= ne2; j++) {
      final x = j * cellSize;
      final isBoxBorder = j % n == 0;
      final paint = isBoxBorder ? thickPaint : thinPaint;
      _drawSketchedLine(canvas, Offset(x, 0), Offset(x, size), paint, lineIndex++);
    }
  }

  void _drawSketchedLine(Canvas canvas, Offset start, Offset end, Paint paint, int lineIndex) {
    final path = Path();

    // Slightly offset start point for more hand-drawn feel
    final wobbles = _wobbleCache[lineIndex % _wobbleCache.length];
    final startWobble = wobbles[0] * 0.3;

    path.moveTo(
      start.dx + (start.dy == end.dy ? 0 : startWobble),
      start.dy + (start.dx == end.dx ? 0 : startWobble),
    );

    // Add wobble to make it look hand-drawn
    final distance = (end - start).distance;
    final segments = (distance / 25).ceil().clamp(4, 12);
    final dx = (end.dx - start.dx) / segments;
    final dy = (end.dy - start.dy) / segments;

    for (int i = 1; i <= segments; i++) {
      final targetX = start.dx + dx * i;
      final targetY = start.dy + dy * i;

      if (i == segments) {
        // End with slight wobble too
        final endWobble = wobbles[1] * 0.3;
        path.lineTo(
          end.dx + (start.dy == end.dy ? 0 : endWobble),
          end.dy + (start.dx == end.dx ? 0 : endWobble),
        );
      } else {
        // Use pre-computed wobble values
        final wobbleIdx = (i * 2) % wobbles.length;
        final wobbleX = wobbles[wobbleIdx];
        final wobbleY = wobbles[wobbleIdx + 1];

        // Apply wobble perpendicular to line direction
        if (start.dy == end.dy) {
          // Horizontal line - wobble vertically
          path.lineTo(targetX, targetY + wobbleY);
        } else {
          // Vertical line - wobble horizontally
          path.lineTo(targetX + wobbleX, targetY);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SketchedGridPainter oldDelegate) {
    return oldDelegate.n != n ||
           oldDelegate.lineColor != lineColor ||
           oldDelegate.size != size ||
           oldDelegate.wobbleAmount != wobbleAmount;
  }
}


/// Theme style options
enum ThemeStyle {
  modern,
  penAndPaper,
}

/// Consistent color palette for the app
/// Used across all screens to maintain visual language
class AppColors {
  // Primary gradient colors
  static const Color primaryPurple = Color(0xFF667eea);
  static const Color secondaryPurple = Color(0xFF764ba2);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color accent = Color(0xFF2196F3);
  static const Color accentLight = Color(0xFF64B5F6);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);

  // Constraint-specific colors
  static const Color constraintPurple = Color(0xFF9C27B0);
  static const Color constraintPurpleLight = Color(0xFFBA68C8);
  static const Color constraintOrange = Color(0xFFFF5722);
  static const Color constraintOrangeLight = Color(0xFFFF8A65);

  // Background colors
  static const Color darkBackground = Color(0xFF1a1a2e);
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkSurface = Color(0xFF2a2a4e);
  static const Color darkSurfaceLight = Color(0xFF3a3a5e);

  // Muted text colors
  static const Color darkMutedPrimary = Color(0xFF5a5a8e);
  static const Color darkMutedSecondary = Color(0xFF4a4a6e);
  static const Color lightMutedPrimary = Color(0xFF9999AA);
  static const Color lightMutedSecondary = Color(0xFFBBBBCC);

  // Disabled state colors
  static const Color darkDisabledBg = Color(0xFF2a2a4e);
  static const Color darkDisabledFg = Color(0xFF5a5a7e);
  static const Color lightDisabledBg = Color(0xFFE8E8E8);
  static const Color lightDisabledFg = Color(0xFFAAAAAA);

  // Dialog text colors
  static const Color darkDialogText = Color(0xFFAAAACC);
  static const Color darkCancelButton = Color(0xFF8888AA);
  static const Color lightCancelButton = Color(0xFF666688);

  // Special colors
  static const Color gold = Color(0xFFFFD700);

  // Cell colors for grid
  static const Color darkCellHintBg = Color(0xFF3a3a5e);  // Immutable hint cell background (dark)
  static const Color lightCellHintBg = Color(0xFFE0E0F0); // Immutable hint cell background (light)
  static const Color darkCellInferText = Color(0xFF7a7aaa);  // Assistant-inferred text (dark)
  static const Color lightCellInferText = Color(0xFF6666aa); // Assistant-inferred text (light)
  static const Color darkCellSelection = Color(0xFF4a4a7e);  // Selected cell background (dark) - more blue
  static const Color lightCellSelection = Color(0xFFD8D8E8); // Selected cell background (light) - subtle gray

  // Numpad colors - darker blue for available, lighter blue for selected
  static const Color numpadAvailableDark = Color(0xFF1976D2);   // Darker blue for available
  static const Color numpadSelectedLight = Color(0xFF90CAF9);   // Light blue for selection
  static const Color numpadSelectedDark = Color(0xFF64B5F6);    // Medium light blue for dark theme selection

  // Pen-and-paper theme colors - Light (blue fountain pen ink)
  static const Color paperBackground = Color(0xFFFAF8F5);       // Warm cream paper
  static const Color paperSurface = Color(0xFFF5F2ED);          // Slightly darker paper
  static const Color paperInk = Color(0xFF1A3A5C);              // Blue fountain pen ink
  static const Color paperInkLight = Color(0xFF3A5A7C);         // Lighter blue ink for hints
  static const Color paperPencil = Color(0xFF6A8AAA);           // Faded blue for inferred
  static const Color paperSelection = Color(0xFFE0E8F0);        // Light blue selection
  static const Color paperHint = Color(0xFFD8E4F0);             // Hint cells - clearly blue-tinted
  static const Color paperHintBorder = Color(0xFFB0C4D8);       // Visible blue border for hint cells
  static const Color paperGridLine = Color(0xFF8AAACE);         // Blue-ish grid lines

  // Pen-and-paper theme colors - Dark (cool charcoal, neutral grays)
  static const Color paperDarkBackground = Color(0xFF0A0A0E);   // Very dark cool charcoal
  static const Color paperDarkSurface = Color(0xFF141418);      // Slightly lighter cool charcoal
  static const Color paperDarkInk = Color(0xFFD4D4D8);          // Cool off-white ink
  static const Color paperDarkInkLight = Color(0xFFA0A0A8);     // Lighter ink
  static const Color paperDarkPencil = Color(0xFF686870);       // Cool gray pencil for inferred
  static const Color paperDarkSelection = Color(0xFF202028);    // Cool selection
  static const Color paperDarkHint = Color(0xFF1A1A30);         // Hint cells - clearly blue-tinted background
  static const Color paperDarkHintBorder = Color(0xFF383858);  // Prominent blue border for hint cells
  static const Color paperDarkGridLine = Color(0xFF34343C);     // Grid lines
}

void main() => runApp(SudokuApp());

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class SudokuTheme {
  Function(ThemeMode themeMode) onThemeModeChange;
  Function(ThemeStyle themeStyle) onThemeStyleChange;
  ThemeStyle currentStyle;

  Color? blue, veryBlue, green, yellow, veryYellow, orange, red, veryRed, purple, cyan;

  Color? foreground;
  Color? cellForeground;
  Color? cellInferColor;
  Color? cellHintColor;
  Color? cellBackground;
  Color? cellSelectionColor;
  Color? buttonForeground = Colors.black;
  Color? buttonBackground;
  Color? buttonSelectedBackground;
  Color? constraintOneOf;
  Color? constraintEqual;
  Color? constraintAllDiff;

  // Numpad colors
  Color? numpadAvailable;
  Color? numpadAvailableActive;
  Color? numpadForbidden;
  Color? numpadForbiddenActive;
  Color? numpadUnconstrained;
  Color? numpadDisabledBg;
  Color? numpadDisabledFg;
  Color? numpadTextOnLight;
  Color? numpadTextOnColored;
  Color? numpadSelected;

  // Hint cell border (for sketched style)
  Color? cellHintBorder;

  // UI colors (replacing isDark checks)
  Color dialogTitleColor;
  Color dialogTextColor;
  Color mutedPrimary;
  Color mutedSecondary;
  Color cancelButtonColor;
  Color disabledBg;
  Color disabledFg;
  Color shadowColor;
  Color iconColor;
  Color logoColorPrimary;
  Color logoColorSecondary;
  Color subtitleColor;

  // Style properties
  bool isSketchedStyle;

  SudokuTheme({
    required this.blue,
    required this.veryBlue,
    required this.green,
    required this.yellow,
    required this.veryYellow,
    required this.orange,
    required this.red,
    required this.veryRed,
    required this.purple,
    required this.cyan,
    required this.foreground,
    required this.cellForeground,
    required this.cellInferColor,
    required this.cellHintColor,
    required this.cellBackground,
    required this.cellSelectionColor,
    required this.numpadAvailable,
    required this.numpadAvailableActive,
    required this.numpadForbidden,
    required this.numpadForbiddenActive,
    required this.numpadUnconstrained,
    required this.numpadDisabledBg,
    required this.numpadDisabledFg,
    required this.numpadTextOnLight,
    required this.numpadTextOnColored,
    required this.numpadSelected,
    required this.dialogTitleColor,
    required this.dialogTextColor,
    required this.mutedPrimary,
    required this.mutedSecondary,
    required this.cancelButtonColor,
    required this.disabledBg,
    required this.disabledFg,
    required this.shadowColor,
    required this.iconColor,
    required this.logoColorPrimary,
    required this.logoColorSecondary,
    required this.subtitleColor,
    required this.onThemeModeChange,
    required this.onThemeStyleChange,
    required this.currentStyle,
    this.cellHintBorder,
    this.isSketchedStyle = false,
  })
  {
    this.buttonForeground = Colors.black;
    this.buttonBackground = this.blue;
    this.buttonSelectedBackground = this.green;
    this.constraintOneOf = this.green?.withOpacity(0.4);
    this.constraintEqual = this.purple?.withOpacity(0.4);
    this.constraintAllDiff = this.blue?.withOpacity(0.4);
  }
}

class _SudokuAppState extends State<SudokuApp> {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeStyle _themeStyle = ThemeStyle.modern;

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  void _setThemeStyle(ThemeStyle themeStyle) {
    setState(() {
      _themeStyle = themeStyle;
    });
  }

  // Modern Light Theme
  SudokuTheme getLightModernTheme() => SudokuTheme(
    blue: Colors.blue[100],
    veryBlue: Colors.blue[200],
    green: Colors.green[100],
    yellow: Colors.yellow[100],
    veryYellow: Colors.yellow[200],
    orange: Colors.orange[100],
    red: Colors.red[100],
    veryRed: Colors.red[200],
    purple: Colors.purple[100],
    cyan: Colors.cyan[100],
    foreground: Colors.black,
    cellForeground: Colors.black,
    cellInferColor: AppColors.lightCellInferText,
    cellHintColor: AppColors.lightCellHintBg,
    cellBackground: null,
    cellSelectionColor: AppColors.lightCellSelection,
    numpadAvailable: AppColors.numpadAvailableDark,
    numpadAvailableActive: AppColors.accent,
    numpadForbidden: AppColors.errorLight,
    numpadForbiddenActive: AppColors.error,
    numpadUnconstrained: AppColors.warning,
    numpadDisabledBg: AppColors.lightDisabledBg,
    numpadDisabledFg: AppColors.lightDisabledFg,
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: AppColors.numpadSelectedLight,
    dialogTitleColor: Colors.black87,
    dialogTextColor: Colors.black54,
    mutedPrimary: AppColors.lightMutedPrimary,
    mutedSecondary: AppColors.lightMutedSecondary,
    cancelButtonColor: AppColors.lightCancelButton,
    disabledBg: AppColors.lightDisabledBg,
    disabledFg: AppColors.lightDisabledFg,
    shadowColor: Colors.grey,
    iconColor: Colors.black54,
    logoColorPrimary: Colors.blue.shade600,
    logoColorSecondary: Colors.blue.shade400,
    subtitleColor: Colors.black38,
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
  );

  // Pen-and-Paper Light Theme - blue fountain pen ink on cream paper
  SudokuTheme getLightPenAndPaperTheme() => SudokuTheme(
    blue: const Color(0xFFD0D8E8),      // Muted blue-gray
    veryBlue: const Color(0xFFC0C8D8),
    green: const Color(0xFFD8E8D8),     // Muted sage
    yellow: const Color(0xFFE8E0C8),    // Muted cream
    veryYellow: const Color(0xFFE0D8C0),
    orange: const Color(0xFFE8D8C8),    // Muted peach
    red: const Color(0xFFE8D0D0),       // Muted rose
    veryRed: const Color(0xFFD8C0C0),
    purple: const Color(0xFFD8D0E8),    // Muted lavender
    cyan: const Color(0xFFD0E0E8),      // Muted teal
    foreground: AppColors.paperInk,
    cellForeground: AppColors.paperInk,
    cellInferColor: AppColors.paperPencil,
    cellHintColor: AppColors.paperHint,
    cellBackground: AppColors.paperBackground,
    cellSelectionColor: AppColors.paperSelection,
    numpadAvailable: AppColors.paperInk,          // Blue ink
    numpadAvailableActive: const Color(0xFF0A2A4C),
    numpadForbidden: const Color(0xFFB8A8A8),     // Muted rose
    numpadForbiddenActive: const Color(0xFF988888),
    numpadUnconstrained: const Color(0xFF8A9AAA), // Muted blue-gray
    numpadDisabledBg: AppColors.paperSurface,
    numpadDisabledFg: const Color(0xFFBBBBCC),
    numpadTextOnLight: AppColors.paperInk,
    numpadTextOnColored: Colors.white,
    numpadSelected: const Color(0xFFD0E0F0),      // Light blue highlight
    dialogTitleColor: AppColors.paperInk,
    dialogTextColor: AppColors.paperPencil,
    mutedPrimary: AppColors.paperPencil,
    mutedSecondary: const Color(0xFF8A9AAA),
    cancelButtonColor: AppColors.paperPencil,
    disabledBg: AppColors.paperSurface,
    disabledFg: const Color(0xFFBBBBCC),
    shadowColor: const Color(0xFF8A9AAA),
    iconColor: AppColors.paperPencil,
    logoColorPrimary: AppColors.paperInk,
    logoColorSecondary: AppColors.paperInk,
    subtitleColor: AppColors.paperPencil.withOpacity(0.6),
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
    cellHintBorder: AppColors.paperHintBorder,  // Visible blue border for hint cells
    isSketchedStyle: true,
  );

  // Modern Dark Theme
  SudokuTheme getDarkModernTheme() => SudokuTheme(
    blue: const Color(0xFF449FCC),
    veryBlue: Colors.blue[200],
    green: const Color(0xFF44AA66),
    yellow: const Color(0xFFBBAA44),
    veryYellow: const Color(0xFFBBAA66),
    orange: const Color(0xFFEEAA55),
    red: const Color(0xFFCC6666),
    veryRed: const Color(0xFFAA4444),
    purple: const Color(0xFF9944AA),
    cyan: const Color(0xFF449999),
    foreground: Colors.grey[200],
    cellForeground: Colors.grey[300],
    cellInferColor: AppColors.darkCellInferText,
    cellHintColor: AppColors.darkCellHintBg,
    cellBackground: null,
    cellSelectionColor: AppColors.darkCellSelection,
    numpadAvailable: AppColors.numpadAvailableDark,
    numpadAvailableActive: AppColors.accent,
    numpadForbidden: AppColors.errorLight,
    numpadForbiddenActive: AppColors.error,
    numpadUnconstrained: AppColors.warningLight,
    numpadDisabledBg: AppColors.darkDisabledBg,
    numpadDisabledFg: AppColors.darkDisabledFg,
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: AppColors.numpadSelectedDark,
    dialogTitleColor: Colors.white,
    dialogTextColor: AppColors.darkDialogText,
    mutedPrimary: AppColors.darkMutedPrimary,
    mutedSecondary: AppColors.darkMutedSecondary,
    cancelButtonColor: AppColors.darkCancelButton,
    disabledBg: AppColors.darkDisabledBg,
    disabledFg: AppColors.darkDisabledFg,
    shadowColor: Colors.black,
    iconColor: Colors.white70,
    logoColorPrimary: Colors.blue.shade300,
    logoColorSecondary: Colors.blue.shade200,
    subtitleColor: Colors.white38,
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
  );

  // Pen-and-Paper Dark Theme - cool charcoal with neutral off-white ink
  SudokuTheme getDarkPenAndPaperTheme() => SudokuTheme(
    blue: const Color(0xFF282830),      // Cool slate
    veryBlue: const Color(0xFF383840),
    green: const Color(0xFF283028),     // Slight green tint
    yellow: const Color(0xFF303028),    // Neutral dark
    veryYellow: const Color(0xFF404038),
    orange: const Color(0xFF383030),    // Neutral with slight warmth
    red: const Color(0xFF302828),       // Neutral dark
    veryRed: const Color(0xFF403038),
    purple: const Color(0xFF2C2838),    // Cool purple tint
    cyan: const Color(0xFF283038),      // Cool teal
    foreground: AppColors.paperDarkInk,
    cellForeground: AppColors.paperDarkInk,
    cellInferColor: AppColors.paperDarkPencil,
    cellHintColor: AppColors.paperDarkHint,
    cellBackground: AppColors.paperDarkBackground,
    cellSelectionColor: AppColors.paperDarkSelection,
    numpadAvailable: AppColors.paperDarkInk,      // Cool off-white
    numpadAvailableActive: const Color(0xFFE8E8F0),
    numpadForbidden: const Color(0xFF484048),     // Muted cool red
    numpadForbiddenActive: const Color(0xFF403038),
    numpadUnconstrained: const Color(0xFF505058), // Neutral gray
    numpadDisabledBg: AppColors.paperDarkSurface,
    numpadDisabledFg: const Color(0xFF383840),
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: AppColors.paperDarkBackground,
    numpadSelected: const Color(0xFF24242C),      // Cool subtle highlight
    dialogTitleColor: AppColors.paperDarkInk,
    dialogTextColor: AppColors.paperDarkPencil,
    mutedPrimary: AppColors.paperDarkPencil,
    mutedSecondary: const Color(0xFF505058),
    cancelButtonColor: AppColors.paperDarkPencil,
    disabledBg: AppColors.paperDarkSurface,
    disabledFg: const Color(0xFF383840),
    shadowColor: Colors.black,
    iconColor: AppColors.paperDarkPencil,
    logoColorPrimary: AppColors.paperDarkInk,
    logoColorSecondary: AppColors.paperDarkInk,
    subtitleColor: AppColors.paperDarkPencil.withOpacity(0.6),
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
    cellHintBorder: AppColors.paperDarkHintBorder,  // Blue-ish border for hint cells
    isSketchedStyle: true,
  );

  SudokuTheme getSudokuTheme(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isPenAndPaper = _themeStyle == ThemeStyle.penAndPaper;

    if (isLight) {
      return isPenAndPaper ? getLightPenAndPaperTheme() : getLightModernTheme();
    } else {
      return isPenAndPaper ? getDarkPenAndPaperTheme() : getDarkModernTheme();
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final isPenAndPaper = _themeStyle == ThemeStyle.penAndPaper;

    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: isPenAndPaper ? AppColors.paperInk : AppColors.primaryPurple,
        colorScheme: ColorScheme.light().copyWith(
          primary: isPenAndPaper ? AppColors.paperInk : AppColors.primaryPurple,
          secondary: isPenAndPaper ? AppColors.paperInkLight : AppColors.secondaryPurple,
          surface: isPenAndPaper ? AppColors.paperSurface : AppColors.lightBackground,
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: isPenAndPaper ? AppColors.paperBackground : AppColors.lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: isPenAndPaper ? AppColors.paperDarkInk : AppColors.primaryPurple,
        colorScheme: ColorScheme.dark().copyWith(
          primary: isPenAndPaper ? AppColors.paperDarkInk : AppColors.primaryPurple,
          secondary: isPenAndPaper ? AppColors.paperDarkInkLight : AppColors.secondaryPurple,
          surface: isPenAndPaper ? AppColors.paperDarkSurface : AppColors.darkSurface,
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: isPenAndPaper ? AppColors.paperDarkBackground : AppColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: _themeMode,
      home: MenuScreen(sudokuThemeFunc: getSudokuTheme),
      routes: {
        SudokuScreen.routeName: (ctx) => SudokuScreen(sudokuThemeFunc: getSudokuTheme),
        SudokuAssistScreen.routeName: (ctx) => SudokuAssistScreen(),
      },
    );
  }
}

