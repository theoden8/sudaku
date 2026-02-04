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

  // Numpad selection colors (distinct from available)
  static const Color numpadSelectedLight = Color(0xFF66BB6A);  // Bright green for selection
  static const Color numpadSelectedDark = Color(0xFF4CAF50);   // Medium green for dark theme
}

void main() => runApp(SudokuApp());

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class SudokuTheme {
  Function(ThemeMode themeMode) onChange;

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
    required this.onChange,
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

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  SudokuTheme getLightTheme() => SudokuTheme(
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
    // Numpad colors for light theme
    numpadAvailable: AppColors.accentLight,
    numpadAvailableActive: AppColors.accent,
    numpadForbidden: AppColors.errorLight,
    numpadForbiddenActive: AppColors.error,
    numpadUnconstrained: AppColors.warning,
    numpadDisabledBg: AppColors.lightDisabledBg,
    numpadDisabledFg: AppColors.lightDisabledFg,
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: AppColors.numpadSelectedLight,
    onChange: _setThemeMode,
  );

  SudokuTheme getDarkTheme() => SudokuTheme(
    blue: Color(0xFF449FCC),
    veryBlue: Colors.blue[200],
    green: Color(0xFF44AA66),
    yellow: Color(0xFFBBAA44),
    veryYellow: Color(0xFFBBAA66),
    orange: Color(0xFFEEAA55),
    red: Color(0xFFCC6666),
    veryRed: Color(0xFFAA4444),
    purple: Color(0xFF9944AA),
    cyan: Color(0xFF449999),
    foreground: Colors.grey[200],
    cellForeground: Colors.grey[300],
    cellInferColor: AppColors.darkCellInferText,
    cellHintColor: AppColors.darkCellHintBg,
    cellBackground: null,
    cellSelectionColor: AppColors.darkCellSelection,
    // Numpad colors for dark theme
    numpadAvailable: AppColors.accentLight,
    numpadAvailableActive: AppColors.accent,
    numpadForbidden: AppColors.errorLight,
    numpadForbiddenActive: AppColors.error,
    numpadUnconstrained: AppColors.warningLight,
    numpadDisabledBg: AppColors.darkDisabledBg,
    numpadDisabledFg: AppColors.darkDisabledFg,
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: AppColors.numpadSelectedDark,
    onChange: _setThemeMode,
  );

  SudokuTheme getSudokuTheme(BuildContext context) {
    if(Theme.of(context).brightness == Brightness.light) {
      return getLightTheme();
    } else {
      return getDarkTheme();
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: AppColors.primaryPurple,
        colorScheme: ColorScheme.light().copyWith(
          primary: AppColors.primaryPurple,
          secondary: AppColors.secondaryPurple,
          surface: AppColors.lightBackground,
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: AppColors.primaryPurple,
        colorScheme: ColorScheme.dark().copyWith(
          primary: AppColors.primaryPurple,
          secondary: AppColors.secondaryPurple,
          surface: AppColors.darkSurface,
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
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

