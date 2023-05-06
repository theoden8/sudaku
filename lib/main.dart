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
  Color? buttonForeground = Colors.black;
  Color? buttonBackground;
  Color? buttonSelectedBackground;
  Color? constraintOneOf;
  Color? constraintEqual;
  Color? constraintAllDiff;

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
    required this.onChange,
  })
  {
    this.buttonForeground = Colors.black;
    this.buttonBackground = this.blue;
    this.buttonSelectedBackground = this.green;
    this.constraintOneOf = this.green;
    this.constraintEqual = this.purple;
    this.constraintAllDiff = this.cyan;
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
    cellInferColor: Colors.grey[500],
    cellHintColor: Colors.grey[300],
    cellBackground: null,
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
    cellInferColor: Colors.grey[500],
    cellHintColor: Colors.grey[400],
    cellBackground: null,
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
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.light().copyWith(
          secondary: Colors.orangeAccent[400],
          background: Colors.blue[100],
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: Color(0xFFFFFFFF),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.dark().copyWith(
          secondary: Colors.orangeAccent[400],
          background: Color(0xFF449FCC),
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
        scaffoldBackgroundColor: Color(0xFF333333),
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

