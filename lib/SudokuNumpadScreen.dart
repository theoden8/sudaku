import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:bit_array/bit_array.dart';

import 'Sudoku.dart';
import 'SudokuAssist.dart';


class NumpadScreen extends StatefulWidget {
  NumpadInteractionType nitype;
  int count;
  Sudoku sd;
  BitArray variables;

  NumpadScreen({required this.nitype, required this.count, required this.sd, required this.variables});

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

  Color getColor(int val) {
    if(numpad.multiselection[val]) {
      return Colors.yellow[100]!;
    } else if((numpad.forbidden ^ numpad.antiselection)[val]) {
      if(numpad.antiselectionChanges[val]) {
        return Colors.red[200]!;
      }
      return Colors.red[100]!;
    } else if(!numpad.constrained[val]) {
      return Colors.orange[100]!;
    }
    if(numpad.antiselectionChanges[val]) {
      return Colors.blue[200]!;
    }
    return Colors.blue[100]!;
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

  List<Widget> makeToolbar(BuildContext ctx) {
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
  ValueInteraction(NumpadScreenState ns) :
    super(ns)
  {
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
  List<Widget> makeToolbar(BuildContext ctx) {
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
  List<Widget> makeToolbar(BuildContext ctx) {
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
  List<Widget> makeToolbar(BuildContext ctx) {
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

  List<Widget> _makeToolbar(BuildContext ctx) {
     return <Widget>[]..addAll(this.interact!.makeToolbar(ctx));
  }

  Widget build(BuildContext ctx) {
    this.variables = widget.variables;
    this.sd = widget.sd;
    final int n = sd.n;
    this._resetSelections(widget.nitype, widget.count);

    final double w = (MediaQuery.of(ctx).size.width - 1.0) / n;
    final double h = (MediaQuery.of(ctx).size.height - 1.0) / n;
    final double size = min(w, h) - 8.0;
    final double sz = size;

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
        title: new Text('Selecting' + proportionText),
        elevation: 0.0,
        actions: this._makeToolbar(ctx),
      ),
      body: CustomScrollView(
        primary: true,
        scrollDirection: (w < h) ? Axis.vertical : Axis.horizontal,
        slivers: <Widget>[
          SliverGrid.count(
            // crossAxisSpacing: h,
            crossAxisCount: n,
            // mainAxisCount: n,
            children: List<Widget>.generate(n * n, (val) =>
              SizedBox(
                width: sz,
                height: sz,
                child: Container(
                  margin: EdgeInsets.all(sz * 0.1),
                  child: RaisedButton(
                    elevation: (this.multiselection[val + 1] || this.antiselectionChanges[val + 1]) ? 0 : 4.0,
                    color: this.interact!.getColor(val + 1),
                    onPressed: !this.interact!.onPressEnabled(val + 1)
                    ? null : () {
                      this._handleOnPress(ctx, val + 1);
                    },
                    onLongPress: !this.interact!.onLongPressEnabled(val + 1)
                    ? null : () {
                      this._handleOnLongPress(ctx, val + 1);
                    },
                    disabledColor: Colors.grey,
                    padding: EdgeInsets.all(0.0),
                    child: Text(
                      sd.s_get(val + 1),
                      style: TextStyle(
                        fontSize: sz * 0.4,
                      ),
                    ),
                  ),
                ),
              )
            ).toList(),
          ),
          SliverGrid.count(
            crossAxisCount: 1,
            children: <Widget>[
              Flex(
                direction: Axis.vertical,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: (w < h) ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.all((w < h) ? 0 : sz * 0.1),
                        child: this.interact is! MultiselectionInteraction ?
                        RaisedButton(
                          padding: EdgeInsets.all(16.0),
                          elevation: 16.0,
                          child: Text('Clear'),
                          onPressed: () {
                            this._handleOnPress(ctx, 0);
                          },
                        )
                        : RaisedButton(
                          padding: EdgeInsets.all(16.0),
                          elevation: 16.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.cancel),
                              Text('Cancel'),
                            ],
                          ),
                          onPressed: () {
                            this.reset = true;
                            Navigator.pop(ctx, multiselection);
                          },
                        ),
                      ),
                    ],
                  ),
                ]
              ),
            ],
          ),
        ],
      ),
    );
  }
}
