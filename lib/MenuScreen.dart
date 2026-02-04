import 'dart:math';

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
  Widget _makeSudokuSizeButton(ctx, setState, int n, double buttonSize) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    bool isSelected = this._selectedSize == n;
    // Scale font size based on button size
    final double fontSize = buttonSize * 0.4;

    return Padding(
      padding: EdgeInsets.all(buttonSize * 0.1),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: isSelected ? 0.0 : 4.0,
          backgroundColor: isSelected ? theme.buttonSelectedBackground : theme.buttonBackground,
          padding: const EdgeInsets.all(0.0),
          minimumSize: Size(buttonSize, buttonSize * 0.8),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "$n",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                color: theme.buttonForeground,
              ),
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
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (ctx, setState) => Scaffold(
            appBar: AppBar(
              title: const Text('Selecting size'),
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
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
                  final double availableWidth = constraints.maxWidth;
                  final double availableHeight = constraints.maxHeight;

                  // Calculate button size based on screen size
                  double buttonSize;
                  if (isPortrait) {
                    buttonSize = min(availableWidth * 0.8, availableHeight * 0.2);
                  } else {
                    buttonSize = min(availableHeight * 0.25, availableWidth * 0.25);
                  }

                  final buttons = [
                    _makeSudokuSizeButton(ctx, setState, 2, buttonSize),
                    _makeSudokuSizeButton(ctx, setState, 3, buttonSize),
                    _makeSudokuSizeButton(ctx, setState, 4, buttonSize),
                  ];

                  if (isPortrait) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: buttons.map((b) => Expanded(child: b)).toList(),
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: buttons.map((b) => Expanded(child: b)).toList(),
                    );
                  }
                },
              ),
            ),
            floatingActionButton: (this._selectedSize == -1) ? null : LayoutBuilder(
              builder: (context, constraints) {
                // Scale FAB size based on screen
                final double fabSize = min(80.0, MediaQuery.of(context).size.shortestSide * 0.15);
                return SizedBox(
                  width: fabSize + 20,
                  height: fabSize + 20,
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
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: fabSize,
                    ),
                  ),
                );
              },
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
        title: const Text('Sudaku'),
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;

            // Calculate responsive sizes
            final double iconSize = min(availableWidth * 0.15, availableHeight * 0.15);
            final double fontSize = min(availableWidth * 0.15, availableHeight * 0.12);
            final double cardHeight = min(availableHeight * 0.4, availableWidth * 0.5);

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: cardHeight,
                  ),
                  child: Card(
                    elevation: 4.0,
                    color: theme.buttonBackground,
                    child: InkWell(
                      onTap: () {
                        this._showPlayDialog(ctx);
                      },
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.play_circle_filled,
                                  color: theme.buttonForeground,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Play",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: theme.buttonForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
