import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bit_array/bit_array.dart';

import 'package:flutter/services.dart';

import 'main.dart';
import 'SudokuScreen.dart';


class MenuScreen extends StatefulWidget {
  Function(BuildContext) sudokuThemeFunc;

  MenuScreen({required this.sudokuThemeFunc});

  State createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  Widget _makeSudokuSizeButton(ctx, setState, int n) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    bool isSelected = this._selectedSize == n;
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: isSelected ? 0.0 : 4.0,
          primary: isSelected ? theme.buttonSelectedBackground : theme.buttonBackground,
          padding: EdgeInsets.all(0.0),
        ),
        onPressed: () {
          if(this._selectedSize == n) {
            this._selectedSize = -1;
          } else {
            this._selectedSize = n;
          }
          setState((){});
        },
        child: Center(
          child: Text(
            "$n",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 56.0,
              color: theme.buttonForeground,
            ),
          ),
        ),
      ),
    );
  }

  int _selectedSize = -1;
  Future<void> _showPlayDialog(BuildContext ctx) async {
    this._selectedSize = -1;
    await showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Select sudoku size',
      transitionDuration: Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (ctx, setState) => Scaffold(
            appBar: AppBar(
              title: Text(
                'Selecting size',
              ),
              elevation: 4.0,
              actions: [
                IconButton(
                  icon: Icon(Theme.of(context).brightness == Brightness.light ? Icons.wb_sunny : Icons.nights_stay),
                  onPressed: () async {
                    final theme = this.widget.sudokuThemeFunc(ctx);
                    setState(() {
                      if (Theme.of(context).brightness == Brightness.light) {
                        theme.onChange(ThemeMode.dark);
                      } else {
                        theme.onChange(ThemeMode.light);
                      }
                    });
                  },
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Spacer(flex: 1),
                Expanded(
                  flex: 3,
                  child: this._makeSudokuSizeButton(ctx, setState, 2),
                ),
                Expanded(
                  flex: 3,
                  child: this._makeSudokuSizeButton(ctx, setState, 3),
                ),
                Expanded(
                  flex: 3,
                  child: this._makeSudokuSizeButton(ctx, setState, 4),
                ),
                Spacer(flex: 2),
              ],
            ),
            floatingActionButton: (this._selectedSize == -1) ? null : Container(
              width: 100,
              height: 100,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.pushNamed(
                    this.context,
                    SudokuScreen.routeName,
                    arguments: SudokuScreenArguments(
                      n: this._selectedSize,
                    ),
                  );
                },
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 80.0,
                ),
                backgroundColor: Colors.blue,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget build(BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    return Scaffold(
      appBar: AppBar(
        title: new Text(
          'Sudaku',
        ),
        elevation: 0.0,
        actions: [
            IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.light ? Icons.wb_sunny : Icons.nights_stay),
            onPressed: () async {
              final theme = this.widget.sudokuThemeFunc(ctx);
              setState(() {
                if (Theme.of(context).brightness == Brightness.light) {
                  theme.onChange(ThemeMode.dark);
                } else {
                  theme.onChange(ThemeMode.light);
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Expanded(
          //   flex: 3,
          //   child: Container(
          //     margin: const EdgeInsets.all(16.0),
          //     child: Center(
          //       child: Text(
          //         'Sudaku',
          //         textAlign: TextAlign.center,
          //         style: TextStyle(
          //           fontWeight: FontWeight.bold,
          //           fontSize: 30.0,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          // Expanded(
          //   flex: 10,
          //   child: Image.asset(
          //     'assets/icon.png',
          //     bundle: DefaultAssetBundle.of(ctx),
          //   ),
          // ),
          Spacer(flex: 1),
          Expanded(
            flex: 10,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4.0,
                color: theme.buttonBackground,
                child: ListTile(
                  title: Center(
                    child: Column(
                      children: <Widget>[
                        Spacer(flex: 1),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: <Widget>[
                              Spacer(),
                              Icon(
                                Icons.play_circle_filled,
                                color: theme.buttonForeground,
                                size: 80,
                              ),
                              Text(
                                "Play",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 80,
                                  color: theme.buttonForeground,
                                ),
                              ),
                              Spacer(),
                            ],
                          ),
                        ),
                        Spacer(flex: 1),
                      ]
                    ),
                  ),
                  onTap: () {
                    this._showPlayDialog(ctx);
                  },
                ),
              ),
            ),
          ),
          Spacer(flex: 1),
        ],
      ),
    );
  }
}
