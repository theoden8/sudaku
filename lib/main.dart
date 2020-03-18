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

class SudokuApp extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
      title: 'Sudoku',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        accentColor: Colors.orangeAccent[400],
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }
        ),
      ),
      home: MenuScreen(),
      routes: {
        SudokuScreen.routeName: (ctx) => SudokuScreen(),
        SudokuAssistScreen.routeName: (ctx) => SudokuAssistScreen(),
      },
    );
  }
}

