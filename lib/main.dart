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

  // Pen-and-paper theme colors - Light
  static const Color paperBackground = Color(0xFFFAF8F5);       // Warm cream paper
  static const Color paperSurface = Color(0xFFF5F2ED);          // Slightly darker paper
  static const Color paperInk = Color(0xFF2C2C2C);              // Dark ink
  static const Color paperInkLight = Color(0xFF5C5C5C);         // Lighter ink for hints
  static const Color paperPencil = Color(0xFF888888);           // Pencil gray for inferred
  static const Color paperSelection = Color(0xFFE8E4DC);        // Subtle selection
  static const Color paperHint = Color(0xFFEDE9E0);             // Hint cell background
  static const Color paperGridLine = Color(0xFFCCC8C0);         // Grid lines

  // Pen-and-paper theme colors - Dark
  static const Color paperDarkBackground = Color(0xFF1E1C1A);   // Dark warm paper
  static const Color paperDarkSurface = Color(0xFF2A2826);      // Slightly lighter dark paper
  static const Color paperDarkInk = Color(0xFFE8E4DC);          // Light ink on dark
  static const Color paperDarkInkLight = Color(0xFFB8B4AC);     // Lighter ink
  static const Color paperDarkPencil = Color(0xFF888880);       // Pencil for inferred
  static const Color paperDarkSelection = Color(0xFF3A3836);    // Subtle selection
  static const Color paperDarkHint = Color(0xFF323028);         // Hint cell background
  static const Color paperDarkGridLine = Color(0xFF4A4840);     // Grid lines
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
    required this.onThemeModeChange,
    required this.onThemeStyleChange,
    required this.currentStyle,
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
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
  );

  // Pen-and-Paper Light Theme - warm, minimalist, classic feel
  SudokuTheme getLightPenAndPaperTheme() => SudokuTheme(
    blue: const Color(0xFFD0D8E8),      // Muted blue-gray
    veryBlue: const Color(0xFFC0C8D8),
    green: const Color(0xFFD8E0D0),     // Muted sage
    yellow: const Color(0xFFE8E0C8),    // Muted cream
    veryYellow: const Color(0xFFE0D8C0),
    orange: const Color(0xFFE8D8C8),    // Muted peach
    red: const Color(0xFFE0D0D0),       // Muted rose
    veryRed: const Color(0xFFD8C0C0),
    purple: const Color(0xFFD8D0E0),    // Muted lavender
    cyan: const Color(0xFFD0E0E0),      // Muted teal
    foreground: AppColors.paperInk,
    cellForeground: AppColors.paperInk,
    cellInferColor: AppColors.paperPencil,
    cellHintColor: AppColors.paperHint,
    cellBackground: AppColors.paperBackground,
    cellSelectionColor: AppColors.paperSelection,
    numpadAvailable: const Color(0xFF5C5C5C),     // Ink gray
    numpadAvailableActive: const Color(0xFF3C3C3C),
    numpadForbidden: const Color(0xFFB8A8A8),     // Muted rose
    numpadForbiddenActive: const Color(0xFF988888),
    numpadUnconstrained: const Color(0xFFB8B098), // Muted tan
    numpadDisabledBg: AppColors.paperSurface,
    numpadDisabledFg: const Color(0xFFBBBBAA),
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: const Color(0xFFD8D0C0),      // Warm highlight
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
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
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
  );

  // Pen-and-Paper Dark Theme - warm, minimalist, classic feel on dark background
  SudokuTheme getDarkPenAndPaperTheme() => SudokuTheme(
    blue: const Color(0xFF4A5868),      // Muted slate blue
    veryBlue: const Color(0xFF5A6878),
    green: const Color(0xFF4A5848),     // Muted forest
    yellow: const Color(0xFF585848),    // Muted olive
    veryYellow: const Color(0xFF686858),
    orange: const Color(0xFF685848),    // Muted brown
    red: const Color(0xFF584848),       // Muted burgundy
    veryRed: const Color(0xFF684858),
    purple: const Color(0xFF504858),    // Muted plum
    cyan: const Color(0xFF485858),      // Muted teal
    foreground: AppColors.paperDarkInk,
    cellForeground: AppColors.paperDarkInk,
    cellInferColor: AppColors.paperDarkPencil,
    cellHintColor: AppColors.paperDarkHint,
    cellBackground: AppColors.paperDarkBackground,
    cellSelectionColor: AppColors.paperDarkSelection,
    numpadAvailable: const Color(0xFFB8B4AC),     // Light ink
    numpadAvailableActive: const Color(0xFFE8E4DC),
    numpadForbidden: const Color(0xFF786868),     // Muted rose
    numpadForbiddenActive: const Color(0xFF685858),
    numpadUnconstrained: const Color(0xFF787060), // Muted tan
    numpadDisabledBg: AppColors.paperDarkSurface,
    numpadDisabledFg: const Color(0xFF585850),
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: const Color(0xFF1E1C1A),
    numpadSelected: const Color(0xFF4A4840),      // Warm highlight
    onThemeModeChange: _setThemeMode,
    onThemeStyleChange: _setThemeStyle,
    currentStyle: _themeStyle,
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

