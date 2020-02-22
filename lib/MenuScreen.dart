import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bit_array/bit_array.dart';


import 'main.dart';
import 'SudokuScreen.dart';


class MenuScreen extends StatefulWidget {
  State createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  void _handleOnPress(int n) {
    Navigator.pushNamed(
      this.context,
      SudokuScreen.routeName,
      arguments: SudokuScreenArguments(
        n: n,
      ),
    );
  }

  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: new Text('Sudoku'),
        elevation: 0.0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.all(8.0),
            child: Text(
              'Sudoku',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RaisedButton(
              elevation: 4,
              onPressed: () {
                this._handleOnPress(2);
              },
              disabledColor: Colors.grey,
              padding: EdgeInsets.all(0.0),
              child: Text(
                "N = 2",
                style: TextStyle(
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RaisedButton(
              elevation: 4,
              onPressed: () {
                this._handleOnPress(3);
              },
              disabledColor: Colors.grey,
              padding: EdgeInsets.all(0.0),
              child: Text(
                "N = 3",
                style: TextStyle(
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RaisedButton(
              elevation: 4,
              onPressed: () {
                this._handleOnPress(4);
              },
              disabledColor: Colors.grey,
              padding: EdgeInsets.all(0.0),
              child: Text(
                "N = 4",
                style: TextStyle(
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
