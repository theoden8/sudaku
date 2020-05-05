import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bit_array/bit_array.dart';


import 'main.dart';
import 'Sudoku.dart';
import 'SudokuAssist.dart';
import 'SudokuNumpadScreen.dart';
import 'SudokuAssistScreen.dart';


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

  void finishOnSelection() {
    self.interact = null;
    self.endMultiSelect();
    self.runSetState();
    if(self._showTutorial && self._tutorialStage == 2) {
      self._tutorialStage = 3;
    }
  }

  void onSelection();
}

class OneofInteraction extends ConstraintInteraction {
  OneofInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onSelection() async {
    BitArray dom = self.sd.getEmptyDomain();
    for(int v in self._multiSelect.asIntIterable()) {
      dom = dom | self.sd.getDomain(v);
    }
    var val = await self._showSelectionNumpad(NumpadInteractionType.SELECT_VALUE, 1);
    if(val == null) {
      return;
    }
    sd.assist.addConstraint(ConstraintOneOf(sd, self._multiSelect, val));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EqualInteraction extends ConstraintInteraction {
  EqualInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onSelection() async {
    sd.assist.addConstraint(ConstraintEqual(sd, this.self._multiSelect));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class AlldiffInteraction extends ConstraintInteraction {
  AlldiffInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.MULTISELECTION, self._multiSelect.cardinality);
    if(selection == null || selection.cardinality != self._multiSelect.cardinality) {
      return;
    }
    sd.assist.addConstraint(ConstraintAllDiff(sd, self._multiSelect, selection));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EliminatorInteraction extends ConstraintInteraction {
  EliminatorInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  void onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.ANTISELECTION, -1);
    if(selection == null) {
      return;
    }
    EliminatorInteractionReturnType changes = selection;
    for(int v in self._multiSelect.asIntIterable()) {
      var diff = (sd.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd.assist.elim[v].invertBits(diff.asIntIterable());
    }
    self.runAssistant();
    this.finishOnSelection();
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

  void _checkVictoryConditions() async {
    if(sd.checkIsComplete() && sd.check()) {
      this._showVictoryDialog();
    }
  }

  Future<void> _handleOnPressCell(int index) {
    if(this._multiSelect.isEmpty) {
      this._selectedCell = index;
      this._selectCellValue(index);
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

  BitArray getSelection() {
    if(this._multiSelect.isEmpty) {
      var res = BitArray(sd.ne4);
      if(this._selectedCell != -1) {
        res.setBit(this._selectedCell);
      }
      return res;
    }
    return this._multiSelect.clone();
  }

  Future _showSelectionNumpad(NumpadInteractionType nitype, int count) async {
    var sel = this.getSelection();
    if(sel.isEmpty) {
      return null;
    }
    final val = await showGeneralDialog(
      context: this.context,
      barrierDismissible: true,
      barrierLabel: "Selecting value",
      transitionDuration: Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) {
        return NumpadScreen(
          sd: this.sd,
          nitype: nitype,
          count: count,
          variables: this.getSelection(),
        );
      },
    );
    return val;
  }

  Future<void> _selectCellValues(Iterable<int> variables) async {
    final ret = await this._showSelectionNumpad(NumpadInteractionType.ANTISELECTION, -1);
    this._processCellSelection(variables, ret);
  }

  Future<void> _selectCellValue(int variable) async {
    final ret = await this._showSelectionNumpad(NumpadInteractionType.SELECT_VALUE, 1);
    this._processCellSelection(variable, ret);
  }

  void _processCellValueSelection(int variable, int val) {
    sd.setManualChange(variable, val);
    // for(int v in variables) {
    //   if(v == variables.first) {
    //     sd.setManualChange(v, val);
    //   } else {
    //     sd.setAssistantChange(v, val);
    //   }
    // }
    this.runAssistant();
  }

  void _processCellElimination(Iterable<int> variables, EliminatorInteractionReturnType changes) {
    for(int v in variables) {
      var diff = (sd.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd.assist.elim[v].invertBits(diff.asIntIterable());
    }
  }

  void _processCellSelection(dynamic variable_s, dynamic ret) {
    if(ret != null) {
      if(ret is int) {
        this._processCellValueSelection(variable_s, ret);
      } else if(ret is EliminatorInteractionReturnType) {
        if(variable_s is int) {
          this._processCellElimination(<int>[variable_s], ret);
        } else {
          this._processCellElimination(variable_s, ret);
        }
      } else {
      }
      this.runSetState();
    }
    this.endMultiSelect();
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
    if(this._tutorialCells != null && this._tutorialCells[index]) {
      return Colors.orange[100];
    }
    return Colors.white;
  }

  Color getCellTextColor(int index) {
    if(sd.isVariableManual(index)) {
      return Colors.black;
    }
    return Colors.grey[500];
  }

  Widget _makeSudokuCellMutable(int index, double sz) {
    int i = index ~/ sd.ne2, j = index % sd.ne2;
    int sdval = sd[index];
    return FlatButton(
      padding: const EdgeInsets.all(0.0),
      color: this.getCellColor(index),
      textColor: this.getCellTextColor(index),
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
  void _showAssistantResult() async {
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

  bool _showTutorial = true;
  int _tutorialStage = 0;

  BitArray _tutorialCells = null;
  void _selectTutorialCells() {
    this._tutorialCells = BitArray(sd.ne4)
      ..setBits(
          sd.getUnsolvedRandomBC()
        .asIntIterable()
        .where((ind) => !sd.isHint(ind)));
    if(this._tutorialCells == null) {
      this._tutorialCells = BitArray(sd.ne4);
    }
    print('tutorialcells ${this._tutorialCells.asIntIterable()}');
  }

  Future<void> _showTutorialMessage(String title, String message, Function() nextFunc) async {
    return showDialog<void>(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(ctx).pop();
                nextFunc();
              }
            ),
          ],
        );
      },
    );
  }

  Widget _makeTutorialButtonStage0(BuildContext ctx) {
    return RaisedButton(
      elevation: 4.0,
      color: Colors.blue[100],
      onPressed: () {
        this._selectTutorialCells();
        this._tutorialStage = 1;
        this.runSetState();
        this._showTutorialMessage(
          'Multi-selection',
          'Long-press to enter multi-selection mode. To proceed, select the highlighted cells.',
          (){}
        );
      },
      onLongPress: () {
        this._showTutorial = false;
        this.runSetState();
      },
      child: Center(
        child: Icon(
          Icons.help,
          size: 80,
        ),
      ),
    );
  }

  Widget _makeTutorialButtonStage12(BuildContext ctx) {
    var tutorialCellsUnset = BitArray(sd.ne4)
      ..setBits(
        this._tutorialCells
          .asIntIterable()
          .where((ind) => (sd[ind] == 0))
      );
    bool passCondition = (
      this._multiSelect.cardinality == tutorialCellsUnset.cardinality
      && this._multiSelect.asIntIterable().every(
        (msel) => tutorialCellsUnset[msel]
      )
    );
    this._tutorialStage = !passCondition ? 1 : 2;
    return RaisedButton(
      elevation: passCondition ? 4.0 : 0.0,
      color: Colors.blue[100],
      onPressed: !passCondition ? null : () {
        Scaffold.of(ctx).openDrawer();
        this.runSetState();
        this._showTutorialMessage(
            'One of',
            'One of the cells contains a specific value.',
            () {
              this._showTutorialMessage(
                'All different',
                'Match the selected cells with the same number of values.',
                () {
                  this._showTutorialMessage(
                    'Instructions',
                    'Tap "All different".',
                    () {
                    }
                  );
                }
              );
            }
        );
      },
      child: Center(
        child: Icon(
          passCondition ? Icons.select_all : Icons.touch_app,
          size: 80,
        ),
      ),
    );
  }

  Widget _makeTutorialButtonStage3(BuildContext ctx) {
    return RaisedButton(
      elevation: 4.0,
      color: Colors.blue[100],
      onPressed: () {
        this._showTutorialMessage(
            "New constraint",
            'Assistant is used to simplify mechanical deductions. It will now account for the new rule.',
            () {
              this._showTutorialMessage(
                'Assistant',
                'Once you get used to using constraints, you should enable default rules through the settings.',
                () {
                }
              );
            }
        );
        this._showTutorial = false;
        this._tutorialStage = 0;
        this._tutorialCells = null;
        this.runSetState();
      },
      child: Center(
        child: Icon(
          Icons.done,
          size: 80,
        ),
      ),
    );
  }

  Widget _makeTutorialButton(BuildContext ctx) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(32.0),
        child: (stage){
          switch(stage) {
            case 0:
              return this._makeTutorialButtonStage0(ctx);
            break;
            case 1:
            case 2:
              return this._makeTutorialButtonStage12(ctx);
            break;
            case 3:
              return this._makeTutorialButtonStage3(ctx);
            break;
          }
        }(this._tutorialStage),
      ),
    );
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
              this.runAssistant();
            }
          ),
          trailing: IconButton(
            icon: Icon(Icons.cancel),
            onPressed: () {
              if(this._selectedConstraint == constraints[i]) {
                this._selectedConstraint = null;
              }
              sd.assist.constraints.remove(constraints[i]);
              this.runAssistant();
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
        Card(
          child: ListTile(
            leading: Icon(Icons.link_off),
            title: Text('One of'),
            onTap: (this._multiSelect.cardinality < 2) ? null : () async {
              this.interact = OneofInteraction(this);
              await this.interact.onSelection();
              Navigator.pop(ctx);
              this.runSetState();
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.link),
            title: Text('Equivalence'),
            onTap: (this._multiSelect.cardinality < 2) ? null : () async {
              this.interact = EqualInteraction(this);
              await this.interact.onSelection();
              Navigator.pop(ctx);
              this.runSetState();
            },
          ),
        ),
        Card(
          color: (
            this._showTutorial
            && this._tutorialStage == 2
          ) ? Colors.blue[100] : Colors.white,
          child: ListTile(
            leading: Icon(Icons.sort),
            title: Text('All different'),
            onTap: (this._multiSelect.cardinality < 2) ? null : () async {
              this.interact = AlldiffInteraction(this);
              await this.interact.onSelection();
              Navigator.pop(ctx);
              this.runSetState();
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.report),
            title: Text('Eliminate'),
            onTap: (this._multiSelect.cardinality < 1) ? null : () async {
              this.interact = EliminatorInteraction(this);
              await this.interact.onSelection();
              Navigator.pop(ctx);
              this.runSetState();
            },
          ),
        ),
      ],
    ),
  );

  void runAssistant() {
    sd.assist.apply();
    this._showAssistantResult();
    this._checkVictoryConditions();
    this.runSetState();
  }

  void _showAssistantOptions(BuildContext ctx) async {
    await Navigator.pushNamed(
      this.context,
      SudokuAssistScreen.routeName,
      arguments: SudokuAssistScreenArguments(
        sd: this.sd,
      ),
    );
    this.runAssistant();
  }

  List<Widget> _makeToolbar(BuildContext ctx) {
    if(this._showTutorial && this._tutorialStage >= 1) {
      return <Widget>[];
    }
    const int
      TOOLBAR_ASSIST = 0,
      TOOLBAR_TUTOR = 1,
      TOOLBAR_RESET = 2;
    return <Widget>[
      IconButton(
        icon: Icon(Icons.undo),
        onPressed: () {
          setState(() {
            if(this._multiSelect.cardinality > 0) {
              this.endMultiSelect();
              return;
            }
            if(!sd.changes.isEmpty) {
              this._selectedCell = sd.getLastChange().assisted ? -1 : sd.getLastChange().variable;
            }
            sd.undoChange();
            this.runAssistant();
          });
        },
      ),
      IconButton(
        icon: Icon(Icons.create),
        onPressed: () {
          if(this._multiSelect.cardinality > 0) {
            this._selectCellValues(this._multiSelect.asIntIterable());
          } else if(this._selectedCell != -1) {
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
            case TOOLBAR_TUTOR:
              this._showTutorial = true;
              this.runSetState();
            break;
            case TOOLBAR_ASSIST:
              this._showAssistantOptions(ctx);
            break;
          }
        },
        itemBuilder: (BuildContext ctx) => <PopupMenuEntry<int>>[
          PopupMenuItem(
            value: TOOLBAR_ASSIST,
            child: Text('Assistant'),
          ),
          PopupMenuItem(
            value: TOOLBAR_TUTOR,
            child: Text('Tutor')
          ),
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
      sd = Sudoku(n, DefaultAssetBundle.of(ctx), () {
        this.runSetState();
      });
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
                  this._showTutorial ?
                    this._makeTutorialButton(ctx)
                    : this._makeConstraintList(ctx),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}
