import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:bit_array/bit_array.dart';

import 'Sudoku.dart';
import 'SudokuAssist.dart';
import 'main.dart'; // For SudokuTheme


class NumpadScreen extends StatefulWidget {
  NumpadInteractionType nitype;
  int count;
  Sudoku sd;
  BitArray variables;
  Function(BuildContext) sudokuThemeFunc;

  NumpadScreen({
    required this.nitype,
    required this.count,
    required this.sd,
    required this.variables,
    required this.sudokuThemeFunc
  });

  State createState() => NumpadScreenState();
}

enum NumpadInteractionType {
  SELECT_VALUE,
  MULTISELECTION,
  ANTISELECTION,
}

abstract class NumpadInteraction {
  late NumpadScreenState numpad;
  late NumpadInteractionType type;

  NumpadInteraction(NumpadScreenState numpad) {
    this.numpad = numpad;
  }

  Color? getColor(int val, BuildContext ctx) {
    final theme = numpad.widget.sudokuThemeFunc(ctx);

    if(numpad.multiselection[val]) {
      // Selected values - use theme's selection color
      return theme.cellSelectionColor;
    } else if((numpad.forbidden ^ numpad.antiselection)[val]) {
      // Forbidden/eliminated values
      if(numpad.antiselectionChanges[val]) {
        return theme.numpadForbiddenActive;
      }
      return theme.numpadForbidden;
    } else if(!numpad.constrained[val]) {
      // Unconstrained values
      return theme.numpadUnconstrained;
    }
    // Available values
    if(numpad.antiselectionChanges[val]) {
      return theme.numpadAvailableActive;
    }
    return theme.numpadAvailable;
  }

  bool onPressEnabled(int val) {
    return numpad.available[val];
  }
  void handleOnPress(BuildContext ctx, int val);

  bool onLongPressEnabled(int val) {
    return false;
  }

  void handleOnLongPress(BuildContext ctx, int val) {
  }

  List<Widget> makeToolBar(BuildContext ctx) {
    if(numpad.variables.cardinality > 1) {
      return <Widget>[];
    }
    return <Widget>[
      IconButton(
        icon: Icon(Icons.report),
        onPressed: () {
          numpad.interact = EliminatorInteraction(numpad, -1);
          numpad.runSetState();
        },
      ),
    ];
  }
}

class ValueInteraction extends NumpadInteraction {
  ValueInteraction(NumpadScreenState numpad): super(numpad) {
    this.type = NumpadInteractionType.SELECT_VALUE;
  }

  @override
  void handleOnPress(BuildContext ctx, int val) {
    Navigator.pop(ctx, val);
  }

  @override
  bool onLongPressEnabled(int val) {
    return numpad.available[val];
  }

  @override
  void handleOnLongPress(BuildContext ctx, int val) {
    if(this.onLongPressEnabled(val)) {
      numpad.interact = EliminatorInteraction(this.numpad, -1);
      numpad.interact!.handleOnPress(ctx, val);
      numpad.runSetState();
    }
  }

  @override
  List<Widget> makeToolBar(BuildContext ctx) {
    return <Widget>[
      IconButton(
        icon: Icon(Icons.report),
        onPressed: () {
          numpad.interact = EliminatorInteraction(numpad, -1);
          numpad.runSetState();
        },
      ),
    ];
  }
}

class MultiselectionInteraction extends NumpadInteraction {
  late int count;

  MultiselectionInteraction(NumpadScreenState ns, int count):
    super(ns)
  {
    this.type = NumpadInteractionType.MULTISELECTION;
    this.count = count;
  }

  @override
  bool onPressEnabled(int val) {
    return super.onPressEnabled(val) && (
      numpad.multiselection[val]
      || this.count > numpad.multiselection.cardinality);
  }

  @override
  void handleOnPress(BuildContext ctx, int val) {
    if(!this.onPressEnabled(val) || numpad.antiselection[val]) {
      return;
    }
    numpad.multiselection.invertBit(val);
    numpad.runSetState();
  }

  @override
  List<Widget> makeToolBar(BuildContext ctx) {
    return [
      IconButton(
        icon: Icon(Icons.save),
        onPressed: (numpad.multiselection.cardinality != this.count) ? null : () {
          numpad.reset = true;
          Navigator.pop(ctx, numpad.multiselection);
        },
      ),
    ];
  }
}

class EliminatorInteractionReturnType {
  BitArray
    antiselectionChanges,
    forbidden;

  EliminatorInteractionReturnType({required this.forbidden, required this.antiselectionChanges});
}

class EliminatorInteraction extends NumpadInteraction {
  EliminatorInteraction(NumpadScreenState ns, int q):
    super(ns)
  {
    this.type = NumpadInteractionType.ANTISELECTION;
  }

  @override
  void handleOnPress(BuildContext ctx, int val) {
    numpad.antiselection.invertBit(val);
    numpad.antiselectionChanges.setBit(val);
    numpad.runSetState();
  }

  @override
  List<Widget> makeToolBar(BuildContext ctx) {
    return <Widget>[
      IconButton(
        icon: Icon(Icons.save),
        onPressed: () {
          numpad.reset = true;
          Navigator.pop(ctx, EliminatorInteractionReturnType(
            forbidden: numpad.forbidden ^ numpad.antiselection,
            antiselectionChanges: numpad.antiselectionChanges
          ));
        },
      ),
    ];
  }
}

class NumpadScreenState extends State<NumpadScreen> {
  late BitArray
    antiselectionChanges,
    antiselection,
    multiselection;
  late BitArray
    available,
    forbidden,
    constrained;
  NumpadInteraction? interact = null;

  late Sudoku sd;
  late BitArray variables;
  bool reset = true;

  void runSetState() {
    setState((){});
  }

  void _handleOnPress(BuildContext ctx, int val) {
    this.interact!.handleOnPress(ctx, val);
  }

  void _handleOnLongPress(BuildContext ctx, int val) {
    return this.interact!.handleOnLongPress(ctx, val);
  }

  void _resetSelections(NumpadInteractionType nitype, int count) {
    if(!this.reset) {
      return;
    }
    this.multiselection = sd.getEmptyDomain();
    this.antiselection = sd.getEmptyDomain();
    this.antiselectionChanges = sd.getEmptyDomain();
    switch(nitype) {
      case NumpadInteractionType.ANTISELECTION:
        this.interact = EliminatorInteraction(this, count);
      break;
      case NumpadInteractionType.SELECT_VALUE:
        this.interact = ValueInteraction(this);
      break;
      case NumpadInteractionType.MULTISELECTION:
        this.interact = MultiselectionInteraction(this, count);
      break;
    }
    if(nitype == NumpadInteractionType.SELECT_VALUE) {
      if(this.sd.assist.hintAvailable) {
        this.available = sd.getCommonDomain(this.variables.asIntIterable());
      } else {
        this.available = sd.getFullDomain();
      }
      this.forbidden = sd.assist.getCommonElimination(variables.asIntIterable());
      if(sd.assist.hintConstrained) {
        this.constrained = sd.assist.getCommonConstrained(variables.asIntIterable());
      } else {
        this.constrained = sd.getFullDomain();
      }
    } else {
      if(this.sd.assist.hintAvailable) {
        this.available = sd.getRepresentativeDomain(this.variables.asIntIterable());
      } else {
        this.available = sd.getFullDomain();
      }
      this.forbidden = sd.assist.getRepresentativeElimination(variables.asIntIterable());
      if(sd.assist.hintConstrained) {
        this.constrained = sd.assist.getRepresentativeConstrained(variables.asIntIterable());
      } else {
        this.constrained = sd.getFullDomain();
      }
    }
    this.reset = false;
  }

  List<Widget> _makeToolBar(BuildContext ctx) {
     return <Widget>[]..addAll(this.interact!.makeToolBar(ctx));
  }

  Widget _buildNumpadGrid(BuildContext ctx, double cellSize, int n) {
    final theme = this.widget.sudokuThemeFunc(ctx);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n,
        childAspectRatio: 1.0,
      ),
      itemCount: n * n,
      itemBuilder: (context, val) {
        return Container(
          margin: EdgeInsets.all(cellSize * 0.05),
          child: ElevatedButton(
            style: ButtonStyle(
              padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                (Set<WidgetState> states) => EdgeInsets.all(0.0)
              ),
              shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              )),
              elevation: WidgetStateProperty.resolveWith<double>(
                (Set<WidgetState> states) {
                  if(this.multiselection[val + 1] || this.antiselectionChanges[val + 1]) {
                    return 0;
                  }
                  return 4.0;
                }
              ),
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  if(states.contains(WidgetState.disabled)) {
                    return theme.numpadDisabledBg;
                  }
                  return this.interact!.getColor(val + 1, context);
                }
              ),
            ),
            onPressed: !this.interact!.onPressEnabled(val + 1)
            ? null : () {
              this._handleOnPress(ctx, val + 1);
            },
            onLongPress: !this.interact!.onLongPressEnabled(val + 1)
            ? null : () {
              this._handleOnLongPress(ctx, val + 1);
            },
            child: Builder(
              builder: (btnContext) {
                // Use dark text for light selection background, white for colored buttons
                final isSelected = this.multiselection[val + 1];
                final textColor = isSelected
                    ? theme.numpadTextOnLight
                    : theme.numpadTextOnColored;
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.all(cellSize * 0.1),
                    child: Text(
                      sd.s_get(val + 1),
                      style: TextStyle(
                        fontSize: cellSize * 0.4,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildActionButton(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: this.interact is! MultiselectionInteraction
        ? ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16.0),
              elevation: 4.0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.clear),
                SizedBox(width: 8),
                Text('Clear'),
              ],
            ),
            onPressed: () {
              this._handleOnPress(ctx, 0);
            },
          )
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16.0),
              elevation: 4.0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.cancel),
                SizedBox(width: 8),
                Text('Cancel'),
              ],
            ),
            onPressed: () {
              this.reset = true;
              Navigator.pop(ctx, multiselection);
            },
          ),
    );
  }

  Widget build(BuildContext ctx) {
    this.variables = widget.variables;
    this.sd = widget.sd;
    final int n = sd.n;
    this._resetSelections(widget.nitype, widget.count);

    String proportionText = '';
    if(widget.nitype == NumpadInteractionType.MULTISELECTION) {
      int no_msel = 0;
      if(this.multiselection != null) {
        no_msel = this.multiselection.cardinality;
      }
      proportionText = ' (${no_msel}/${widget.count})';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Selecting$proportionText'),
        elevation: 0.0,
        actions: this._makeToolBar(ctx),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;

            // Calculate grid size to fit the screen with button below
            double gridSize;
            if (isPortrait) {
              // In portrait, grid should take most of the width, leave space for button
              gridSize = min(availableWidth * 0.95, availableHeight * 0.75);
            } else {
              // In landscape, grid is limited by height (leave space for button below)
              gridSize = min(availableHeight * 0.75, availableWidth * 0.85);
            }

            final double cellSize = gridSize / n;

            // Both orientations use Column layout with button below grid
            // Grid is centered horizontally
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: gridSize,
                      height: gridSize,
                      child: _buildNumpadGrid(ctx, cellSize, n),
                    ),
                  ),
                ),
                _buildActionButton(ctx),
              ],
            );
          },
        ),
      ),
    );
  }
}
