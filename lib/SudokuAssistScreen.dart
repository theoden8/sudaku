import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bit_array/bit_array.dart';


import 'main.dart';
import 'Sudoku.dart';
import 'SudokuAssist.dart';


class SudokuAssistScreen extends StatefulWidget {
  static const String routeName = "/sudoku_assist";

  SudokuAssistScreen();

  State createState() => SudokuAssistScreenState();
}

class SudokuAssistScreenArguments {
  SudokuAssistScreenArguments({this.sd});

  Sudoku sd;
}

class SudokuAssistScreenState extends State<SudokuAssistScreen> {
  Sudoku sd;

  void runSetState() {
    setState((){});
  }

  List<Widget> _makeToolbar(BuildContext ctx) {
    return <Widget>[
    ];
  }

  List<Widget> _makeOptionList(BuildContext ctx) {
    var listTiles = <Widget>[];
    listTiles.addAll(<Widget>[
      ListTile(
        leading: Checkbox(
          value: sd.assist.hintAvailable,
          onChanged: (bool b) {
            sd.assist.hintAvailable = b;
            this.runSetState();
          },
        ),
        title: Text(
          'Show only available values',
          textAlign: TextAlign.left,
        ),
        onTap: () {
          sd.assist.hintAvailable = !sd.assist.hintAvailable;
          this.runSetState();
        },
      ),
      ListTile(
        leading: Checkbox(
          value: sd.assist.hintConstrained,
          onChanged: (bool b) {
            sd.assist.hintAvailable = b;
            this.runSetState();
          },
        ),
        title: Text(
          'Allow constraints to eliminate values',
          textAlign: TextAlign.left,
        ),
        onTap: () {
          sd.assist.hintConstrained = !sd.assist.hintConstrained;
          this.runSetState();
        },
      ),
      ListTile(
        leading: Checkbox(
          value: sd.assist.autoComplete,
          onChanged: (bool b) {
            sd.assist.autoComplete = b;
            this.runSetState();
          },
        ),
        title: Text(
          'Fill in a value when only one left',
          textAlign: TextAlign.left,
        ),
        onTap: () {
          sd.assist.autoComplete = !sd.assist.autoComplete;
          this.runSetState();
        },
      )
    ]);
    if(sd.assist.autoComplete) {
      listTiles.add(
        Padding(
          padding: const EdgeInsets.only(left: 32.0),
          child: ListTile(
            leading: Checkbox(
              value: sd.assist.useDefaultConstraints,
              onChanged: (bool b) {
                sd.assist.useDefaultConstraints = b;
                this.runSetState();
              },
            ),
            title: Text(
              'Use default constraints (alldiff for rows, columns, boxes)',
              textAlign: TextAlign.left,
            ),
            onTap: () {
              sd.assist.useDefaultConstraints = !sd.assist.useDefaultConstraints;
              this.runSetState();
            },
          ),
        )
      );
    }
    return listTiles;
  }

  Widget build(BuildContext ctx) {
    SudokuAssistScreenArguments args = ModalRoute.of(ctx).settings.arguments;
    this.sd = args.sd;

    return Scaffold(
      appBar: AppBar(
        title: Text('Assistant'),
        elevation: 0.0,
        actions: this._makeToolbar(ctx),
      ),
      body:ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        children: this._makeOptionList(ctx),
      ),
    );
  }
}
