import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:bit_array/bit_array.dart';


import 'Sudoku.dart';


class NumpadScreenArguments {
  NumpadScreenArguments({this.domain, this.multiselectionMode, this.sd, this.variable});
  BitArray domain;
  int multiselectionMode;
  Sudoku sd;
  int variable = -1;
}

class NumpadScreen extends StatefulWidget {
  static const String routeName = '/numpad_data';

  NumpadScreen();

  State createState() => NumpadScreenState();
}

abstract class NumpadInteraction {
  NumpadScreenState numpad;

  NumpadInteraction(NumpadScreenState numpad) {
    this.numpad = numpad;
  }

  Color getColor(int val) {
    if(numpad.multiselection[val]) {
      return Colors.yellow[100];
    } else if(numpad.antiselection[val]) {
      return Colors.red[100];
    }
    return Colors.blue[100];
  }

  bool onPressEnabled(int val) {
    return numpad.dom[val];
  }
  void handleOnPress(BuildContext ctx, int val);

  bool onLongPressEnabled(int val) {
    return false;
  }

  void handleOnLongPress(BuildContext ctx, int val) {
  }

  List<Widget> makeToolbar(BuildContext ctx) {
    if(numpad.variable == null) {
      return <Widget>[];
    }
    return <Widget>[
      IconButton(
        icon: Icon(Icons.report),
        onPressed: () {
          // numpad.multiselectionMode = -1;
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
    // numpad.multiselectionMode = 0;
  }

  @override
  void handleOnPress(BuildContext ctx, int val) {
    Navigator.pop(ctx, val);
  }

  @override
  bool onLongPressEnabled(int val) {
    return numpad.dom[val] && numpad.variable != null;
  }

  @override
  void handleOnLongPress(BuildContext ctx, int val) {
    if(this.onLongPressEnabled(val)) {
      numpad.interact = EliminatorInteraction(this.numpad, -1);
      numpad.antiselection.invertBit(val);
      numpad.runSetState();
    }
  }

  @override
  List<Widget> makeToolbar(BuildContext ctx) {
    return <Widget>[
      IconButton(
        icon: Icon(Icons.report),
        onPressed: () {
          // this.multiselectionMode = -1;
          numpad.interact = EliminatorInteraction(numpad, -1);
          numpad.runSetState();
        },
      ),
    ];
  }
}

class MultiselectionInteraction extends NumpadInteraction {
  int limit = null;

  MultiselectionInteraction(NumpadScreenState ns, int q):
    super(ns)
  {
    // ns.multiselectionMode = this.limit = q;
    this.limit = q;
  }

  @override
  bool onPressEnabled(int val) {
    return super.onPressEnabled(val)
      && this.limit > numpad.multiselection.cardinality;
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
        onPressed: (numpad.multiselection.cardinality != this.limit) ? null : () {
          numpad.reset = true;
          Navigator.pop(ctx, numpad.multiselection);
        },
      ),
    ];
  }
}

class EliminatorInteraction extends NumpadInteraction {
  EliminatorInteraction(NumpadScreenState ns, int q):
    super(ns)
  {
  }

  @override
  void handleOnPress(BuildContext ctx, int val) {
    numpad.antiselection.invertBit(val);
    numpad.runSetState();
  }

  @override
  List<Widget> makeToolbar(BuildContext ctx) {
    return <Widget>[
      IconButton(
        icon: Icon(Icons.save),
        onPressed: () {
          numpad.reset = true;
          Navigator.pop(ctx, numpad.antiselection);
        },
      ),
    ];
  }
}

class NumpadScreenState extends State<NumpadScreen> {
  BitArray antiselection;
  BitArray multiselection;
  NumpadInteraction interact = null;
  BitArray dom;

  Sudoku sd;
  int variable;
  bool reset = true;

  void runSetState() {
    setState((){});
  }

  void _handleOnPress(BuildContext ctx, int val) {
    this.interact.handleOnPress(ctx, val);
  }

  void _handleOnLongPress(BuildContext ctx, int val) {
    return this.interact.handleOnLongPress(ctx, val);
  }

  void _resetSelections(int multiselectionMode) {
    if(!this.reset) {
      return;
    }
    this.multiselection = sd.getEmptyDomain();
    this.antiselection = sd.getEmptyDomain();
    if(this.variable != null) {
      this.antiselection = sd.assist.getElimination(variable);
    }
    if(multiselectionMode < 0) {
      this.interact = EliminatorInteraction(this, -1);
    } else if(multiselectionMode == 0) {
      this.interact = ValueInteraction(this);
    } else if(multiselectionMode > 0) {
      this.interact = MultiselectionInteraction(this, multiselectionMode);
    }
    this.reset = false;
  }

  List<Widget> _makeToolbar(BuildContext ctx) {
     return <Widget>[]..addAll(this.interact.makeToolbar(ctx));
  }

  Widget build(BuildContext ctx) {
    final NumpadScreenArguments args = ModalRoute.of(ctx).settings.arguments;
    this.dom = args.domain;
    this.variable = args.variable;
    this.sd = args.sd;
    final int n = sd.n;
    int multiselectionMode = args.multiselectionMode;
    this._resetSelections(multiselectionMode);

    bool isPortrait = MediaQuery.of(ctx).orientation == Orientation.portrait;
    final double w = (MediaQuery.of(ctx).size.width - 1.0) / n;
    final double h = (MediaQuery.of(ctx).size.height - 1.0) / n;
    final double size = (isPortrait ? w : h) - 8.0;
    final double sz = size;

    return Scaffold(
      appBar: AppBar(
        title: new Text('Selecting'),
        elevation: 0.0,
        actions: this._makeToolbar(ctx),
      ),
      body: CustomScrollView(
        primary: true,
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
                    elevation: this.multiselection[val + 1] ? 0 : 4.0,
                    color: this.interact.getColor(val + 1),
                    onPressed: !this.interact.onPressEnabled(val + 1)
                    ? null : () {
                      this._handleOnPress(ctx, val + 1);
                    },
                    onLongPress: !this.interact.onLongPressEnabled(val + 1)
                    ? null : () {
                      this._handleOnLongPress(ctx, val + 1);
                    },
                    disabledColor: Colors.grey,
                    padding: EdgeInsets.all(0.0),
                    child: Text(
                      (val + 1).toString(),
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
                    children: <Widget>[
                      (
                        this.interact is! MultiselectionInteraction ?
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
                        )
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
