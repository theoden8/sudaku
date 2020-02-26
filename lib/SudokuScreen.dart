import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bit_array/bit_array.dart';


import 'main.dart';
import 'Sudoku.dart';
import 'NumpadScreen.dart';


class SudokuScreen extends StatefulWidget {
  static const String routeName = '/sudoku_arguments';

  SudokuScreen();

  State createState() => SudokuScreenState();
}

class SudokuScreenArguments {
  SudokuScreenArguments({this.n});
  final int n;
}

abstract class ConstraintInteraction {
  SudokuScreenState self;
  Sudoku sd;

  ConstraintInteraction(SudokuScreenState ss) {
    this.self = ss;
    this.sd = ss.sd;
  }

  void finish_up() {
    self.interact = null;
    self.endMultiSelect();
    self.runSetState();
  }

  void onConstraintSelection();
}

class OneofInteraction extends ConstraintInteraction {
  OneofInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onConstraintSelection() async {
    BitArray dom = self.sd.getEmptyDomain();
    for(int v in self._multiSelect.asIntIterable()) {
      dom = dom | self.sd.getDomain(v);
    }
    var val = await self._selectValue(dom, null);
    if(val == null) {
      return;
    }
    sd.assist.addConstraint(ConstraintOneOf(sd, self._multiSelect, val));
    sd.assist.apply();
    self.showAssistantResult();
    this.finish_up();
  }
}

class EqualInteraction extends ConstraintInteraction {
  EqualInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onConstraintSelection() async {
    sd.assist.addConstraint(ConstraintEqual(sd, this.self._multiSelect));
    sd.assist.apply();
    self.showAssistantResult();
    this.finish_up();
  }
}

class AlldiffInteraction extends ConstraintInteraction {
  AlldiffInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onConstraintSelection() async {
    BitArray dom = sd.getEmptyDomain();
    for(int v in self._multiSelect.asIntIterable()) {
      dom = dom | sd.getDomain(v);
    }
    var selection = await self._selectValues(dom, self._multiSelect.cardinality);
    if(selection == null || selection.cardinality != self._multiSelect.cardinality) {
      return;
    }
    sd.assist.addConstraint(ConstraintAllDiff(sd, self._multiSelect, selection));
    sd.assist.apply();
    self.showAssistantResult();
    this.finish_up();
  }
}

class SudokuScreenState extends State<SudokuScreen> {
  Sudoku sd = null;
  ConstraintInteraction interact = null;

  BitArray _multiSelect = null;
  int _selectedCell = -1;

  void runSetState() {
    setState((){});
  }

  void _handleVictory() {
  }

  Future<void> _showVictoryDialog() async {
    return showDialog<void>(
      context: this.context,
      // barrierDismissable: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Victory'),
          content: Text('Congratulations'),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                this._handleVictory();
                Navigator.of(ctx).pop();
              }
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleOnPressCell(int index) {
    if(this._multiSelect.isEmpty) {
      this._selectedCell = index;
    } else {
      this._multiSelect.invertBit(index);
    }
    this.runSetState();
  }

  Future<void> _handleLongPressCell(int index) async {
    if(this._multiSelect.isEmpty) {
      this.startMultiSelect();
      this._multiSelect.setBit(index);
      this.runSetState();
    }
  }

  Future _selectValues(BitArray domain, int q) async {
    final selection = await Navigator.pushNamed(
      this.context,
      NumpadScreen.routeName,
      arguments: NumpadScreenArguments(
        sd: this.sd,
        domain: domain,
        multiselectionMode: q,
      ),
    );
    return selection;
  }

  Future _selectValue(BitArray domain, int variable) async {
    final val = await Navigator.pushNamed(
      this.context,
      NumpadScreen.routeName,
      arguments: NumpadScreenArguments(
        sd: this.sd,
        domain: domain,
        multiselectionMode: 0,
        variable: variable,
      ),
    );
    return val;
  }

  Future<void> _selectCellValue(int index) async {
    final ret = await this._selectValue(sd.getDomain(index), index);
    if(ret != null) {
      if(ret is int) {
        int val = ret;
        sd.setManualChange(index, val);
        if(val != 0) {
          sd.assist.apply();
          this.showAssistantResult();
        }
      } else if(ret is BitArray) {
        BitArray e = ret;
        sd.assist.modifyEliminations(index, e);
      }
      this.runSetState();
    }
    if(sd.checkIsComplete() && sd.check()) {
      this._showVictoryDialog();
    }
  }

  Future<void> _showResetDialog() async {
    return showDialog<void>(
      context: this.context,
      // barrierDismissable: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Reset'),
          content: Text('This action is irreversible'),
          actions: <Widget>[
            FlatButton(
              child: Text('Hold on'),
              onPressed: () {
                Navigator.of(ctx).pop();
              }
            ),
            FlatButton(
              child: Text('Reset'),
              onPressed: () {
                this._handleResetPress();
                Navigator.of(ctx).pop();
              }
            ),
          ],
        );
      },
    );
  }

  void _handleResetPress() {
    setState(() {
      this.sd = null;
    });
  }

  Border getBorder(int i, int j) {
    bool left = (j % sd.n == 0);
    bool right = (j % sd.n == sd.n - 1);
    bool top = (i % sd.n == 0);
    bool bottom = (i % sd.n == sd.n - 1);
    bool leftEdge = (j == 0), rightEdge = (j == sd.ne2 - 1);
    bool topEdge = (i == 0), bottomEdge = (i == sd.ne2 - 1);

    var side = BorderSide(width: 0.5);
    var edgeSide = BorderSide(width: 2.0);
    var leftSide = leftEdge ? edgeSide : side;
    var rightSide = rightEdge ? edgeSide : side;
    var topSide = topEdge ? edgeSide : side;
    var bottomSide = bottomEdge ? edgeSide : side;

    // corners
    if(left && top) {
      return Border(
        left: leftSide,
        top: topSide,
      );
    } else if(left && bottom) {
      return Border(
        left: leftSide,
        bottom: bottomSide,
      );
    } else if(right && top) {
      return Border(
        right: rightSide,
        top: topSide,
      );
    } else if(right && bottom) {
      return Border(
        right: rightSide,
        bottom: bottomSide,
      );
    }
    // sides
    else if(left) {
      return Border(left: leftSide);
    } else if(right) {
      return Border(right: rightSide);
    } else if(top) {
      return Border(top: topSide);
    } else if(bottom) {
      return Border(bottom: bottomSide);
    }
    return Border();
  }

  Widget _makeSudokuCellImmutable(int index, double sz) {
    int sdval = sd[index];
    return Card(
      margin: const EdgeInsets.all(0.0),
      elevation: 1.0,
      color: Colors.grey[300],
      child: Container(
        margin: EdgeInsets.all(0.0),
        child: Text(
          sd.s_get(sdval),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sz * 0.9,
          ),
        ),
      ),
    );
  }

  void startMultiSelect() {
    this._selectedCell = -1;
    this._multiSelect ??= BitArray(sd.ne4);
    this._multiSelect.clearAll();
  }

  void endMultiSelect() {
    this._multiSelect.clearAll();
  }

  Color getCellColor(int index) {
    if(this._multiSelect.isEmpty) {
      if(this._selectedCell == index) {
        return Colors.blue[100];
      } else if(this._selectedConstraint != null && this._selectedConstraint.variables[index]) {
        switch(this._selectedConstraint.type) {
          case ConstraintType.ONE_OF: return Colors.green[100];
          case ConstraintType.EQUAL: return Colors.purple[100];
          case ConstraintType.ALLDIFF: return Colors.cyan[100];
        }
      }
    } else {
      if(this._multiSelect[index]) {
        return Colors.yellow[200];
      }
    }
    return Colors.white;
  }

  Widget _makeSudokuCellMutable(int index, double sz) {
    int i = index ~/ sd.ne2, j = index % sd.ne2;
    int sdval = sd[index];
    return FlatButton(
      padding: const EdgeInsets.all(0.0),
      color: this.getCellColor(index),
      onPressed: () {
        this._handleOnPressCell(index);
      },
      onLongPress: () {
        // this._handleLongPressCell(index, sz*(j+0.5), sz*(i+0.5));
        this._handleLongPressCell(index);
      },
      splashColor: Colors.blueAccent,
      child: Text(
        sd.s_get(sdval),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: sz * 0.9),
      ),
    );
  }

  Widget _makeSudokuCell(int index, double sz) {
    if(sd.isHint(index)) {
      return this._makeSudokuCellImmutable(index, sz);
    }
    return this._makeSudokuCellMutable(index, sz);
  }

  Widget _makeSudokuGrid(BuildContext ctx) {
    bool isPortrait = MediaQuery.of(ctx).orientation == Orientation.portrait;
    double w = MediaQuery.of(ctx).size.width;
    double h = MediaQuery.of(ctx).size.height;
    // double size = (isPortrait ? w : h) - 8.0;
    double size = w;
    double sz = (size - 1.0) / sd.ne2;
    return SizedBox(
      child: Container(
        margin: const EdgeInsets.all(0.0),
        width: size,
        height: size,
        child: CustomScrollView(
          primary: true,
          slivers: <Widget>[
            SliverGrid.count(
              crossAxisCount: sd.ne2,
              children: List<Widget>.generate(sd.ne4, (index) {
                int i = index ~/ sd.ne2, j = index % sd.ne2;
                return SizedBox(
                  child: Container(
                    margin: const EdgeInsets.all(0.0),
                    decoration: BoxDecoration(
                      border: getBorder(i, j),
                    ),
                    width: sz,
                    height: sz,
                    child: this._makeSudokuCell(index, sz),
                  ),
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  var _scaffoldBodyContext = null;
  void showAssistantResult() async {
    for(Constraint constr in sd.assist.newlySucceeded) {
      Scaffold.of(this._scaffoldBodyContext).showSnackBar(
        SnackBar(
          elevation: 4.0,
          content: Text(
            constr.toString(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  var _selectedConstraint = null;
  Widget _makeConstraintList(BuildContext ctx) {
    var constraints = sd.assist.constraints.where((Constraint c) {
      return c.status != Constraint.SUCCESS;
    }).toList();
    var listTiles = List<Widget>.generate(constraints.length, (i) {
      return  Card(
        elevation: 1.0,
        color: (Constraint c) {
          if(c.status == Constraint.SUCCESS) {
            return Colors.green[100];
          } else if(c.status == Constraint.VIOLATED) {
            return Colors.red[100];
          }
          return Colors.white;
        }(constraints[i]),
        child: ListTile(
          leading: Checkbox(
            value: constraints[i].isActive(),
            onChanged: (bool b) {
              if(b) {
                constraints[i].activate();
                // if(!constraints[i].checkInitialCondition()) {
                //   constraints[i].updateCondition();
                // }
              } else {
                constraints[i].deactivate();
                if(this._selectedConstraint == constraints[i]) {
                  this._selectedConstraint = null;
                }
              }
              sd.assist.apply();
              this.runSetState();
              this.showAssistantResult();
            }
          ),
          trailing: IconButton(
            icon: Icon(Icons.cancel),
            onPressed: () {
              if(this._selectedConstraint == constraints[i]) {
                this._selectedConstraint = null;
              }
              sd.assist.constraints.remove(constraints[i]);
              this.runSetState();
            },
          ),
          title: Text(
            '${constraints[i].type} dom=${constraints[i].getValues()}',
          ),
          onTap: !constraints[i].isActive() ? null : () {
            this._multiSelect.clearAll();
            this._selectedConstraint = constraints[i];
            this.runSetState();
          }
        ),
      );
    });
    if(this._selectedConstraint != null) {
      listTiles.add(OutlineButton(
        child: Text('Deselect'),
        onPressed: () {
          this._selectedConstraint = null;
          this.runSetState();
        }
      ));
    }
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        children: listTiles,
      ),
    );
  }

  Drawer _makeDrawer(BuildContext ctx) => Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DrawerHeader(
          child: Row(
            children: <Widget>[
              Icon(Icons.select_all),
              Text(
                'Constraints',
                style: TextStyle(
                  fontSize: 20.0,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: Icon(Icons.link_off),
          title: Text('oneof'),
          onTap: (this._multiSelect.cardinality < 2) ? null : () async {
            this.interact = OneofInteraction(this);
            await this.interact.onConstraintSelection();
            Navigator.pop(ctx);
            this.runSetState();
          }
        ),
        ListTile(
          leading: Icon(Icons.link),
          title: Text('equal'),
          onTap: (this._multiSelect.cardinality < 2) ? null : () async {
            this.interact = EqualInteraction(this);
            await this.interact.onConstraintSelection();
            Navigator.pop(ctx);
            this.runSetState();
          }
        ),
        ListTile(
          leading: Icon(Icons.sort),
          title: Text('allDiff'),
          onTap: (this._multiSelect.cardinality < 2) ? null : () async {
            this.interact = AlldiffInteraction(this);
            await this.interact.onConstraintSelection();
            Navigator.pop(ctx);
            this.runSetState();
          }
        ),
      ],
    ),
  );

  List<Widget> _makeToolbar(BuildContext ctx) {
    const int TOOLBAR_RESET = 0;
    return <Widget>[
      IconButton(
        icon: Icon(Icons.undo),
        onPressed: () {
          setState(() {
            if(this._multiSelect.cardinality > 0) {
              this.endMultiSelect();
              return;
            }
            if(sd.changes.length > 0) {
              if(!sd.changes.last.isEmpty) {
                this._selectedCell = sd.changes.last.indices.first;
              }
            }
            sd.undoChange();
          });
        },
      ),
      IconButton(
        icon: Icon(Icons.create),
        onPressed: () {
          if(this._selectedCell != -1) {
            this._selectCellValue(this._selectedCell);
          }
        },
      ),
      PopupMenuButton<int>(
        onSelected: (int opt) {
          switch(opt) {
            case TOOLBAR_RESET:
              this._showResetDialog();
            break;
          }
        },
        itemBuilder: (BuildContext ctx) => <PopupMenuEntry<int>>[
          PopupMenuItem(
            value: TOOLBAR_RESET,
            child: Text('Reset'),
          ),
        ],
      ),
    ];
  }

  Widget build(BuildContext ctx) {
    final SudokuScreenArguments args = ModalRoute.of(ctx).settings.arguments;
    final int n = args.n;

    if(sd == null || sd.n != n) {
      // print('making new sudoku');
      sd = Sudoku(n, DefaultAssetBundle.of(ctx), this);
      this._multiSelect = BitArray(sd.ne4);
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: new Text('Sudoku'),
          elevation: 4.0,
          actions: this._makeToolbar(ctx),
        ),
        drawer: this._makeDrawer(ctx),
        body: Builder(
          builder: (ctx) {
            this._scaffoldBodyContext = ctx;
            return Container(
              margin: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  this._makeSudokuGrid(ctx),
                  this._makeConstraintList(ctx),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}
