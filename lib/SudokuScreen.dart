import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:bit_array/bit_array.dart';


import 'main.dart';
import 'Sudoku.dart';
import 'SudokuAssist.dart';
import 'SudokuNumpadScreen.dart';
import 'SudokuAssistScreen.dart';


class SudokuScreen extends StatefulWidget {
  static const String routeName = '/sudoku_arguments';

  Function(BuildContext) sudokuThemeFunc;

  SudokuScreen({required this.sudokuThemeFunc});

  State createState() => SudokuScreenState();
}

class SudokuScreenArguments {
  final int n;

  SudokuScreenArguments({required this.n});
}

abstract class ConstraintInteraction {
  late SudokuScreenState self;
  late Sudoku sd;

  ConstraintInteraction(SudokuScreenState ss) {
    this.self = ss;
    this.sd = ss.sd!;
  }

  void finishOnSelection() {
    self.interact = null;
    self.endMultiSelect();
    self.runSetState();
    if(self._showTutorial && self._tutorialStage == 2) {
      self._tutorialStage = 3;
    }
  }

  Future<void> onSelection();
}

class OneofInteraction extends ConstraintInteraction {
  OneofInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    BitArray dom = self.sd!.getEmptyDomain();
    for(int v in self._multiSelect!.asIntIterable()) {
      dom = dom | self.sd!.getDomain(v);
    }
    var val = await self._showSelectionNumpad(NumpadInteractionType.SELECT_VALUE, 1);
    if(val == null) {
      return;
    }
    sd.assist.addConstraint(ConstraintOneOf(sd, self._multiSelect!, val));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EqualInteraction extends ConstraintInteraction {
  EqualInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    sd.assist.addConstraint(ConstraintEqual(sd, this.self._multiSelect!));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class AlldiffInteraction extends ConstraintInteraction {
  AlldiffInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.MULTISELECTION, self._multiSelect!.cardinality);
    if(selection == null || selection.cardinality != self._multiSelect!.cardinality) {
      return;
    }
    sd.assist.addConstraint(ConstraintAllDiff(sd, self._multiSelect!, selection));
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EliminatorInteraction extends ConstraintInteraction {
  EliminatorInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.ANTISELECTION, -1);
    if(selection == null) {
      return;
    }
    EliminatorInteractionReturnType changes = selection;
    for(int v in self._multiSelect!.asIntIterable()) {
      var diff = (sd.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd.assist.elim[v].invertBits(diff.asIntIterable());
    }
    self.runAssistant();
    this.finishOnSelection();
  }
}

class SudokuScreenState extends State<SudokuScreen> {
  Sudoku? sd = null;
  ConstraintInteraction? interact = null;

  BitArray? _multiSelect = null;
  int _selectedCell = -1;

  double screenWidth = 0,
         screenHeight = 0;

  void runSetState() {
    setState((){});
  }

  void _handleVictory() {
  }

  Future<void> _showVictoryDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 32),
              const SizedBox(width: 12),
              Text(
                'Victory!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Congratulations on solving the puzzle!',
            style: TextStyle(
              color: isDark ? AppColors.darkDialogText : Colors.black54,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Awesome!'),
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
    if(sd!.checkIsComplete() && sd!.check()) {
      this._showVictoryDialog();
    }
  }

  Future<void> _handleOnPressCell(int index) async {
    if(this._multiSelect!.isEmpty) {
      this._selectedCell = index;
      this._selectCellValue(index);
    } else {
      this._multiSelect!.invertBit(index);
    }
    this.runSetState();
  }

  Future<void> _handleLongPressCell(int index) async {
    if(this._multiSelect!.isEmpty) {
      this.startMultiSelect();
      this._multiSelect!.setBit(index);
      this.runSetState();
    }
  }

  BitArray getSelection() {
    if(this._multiSelect!.isEmpty) {
      var res = BitArray(sd!.ne4);
      if(this._selectedCell != -1) {
        res.setBit(this._selectedCell);
      }
      return res;
    }
    return this._multiSelect!.clone();
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
          sd: this.sd!,
          nitype: nitype,
          count: count,
          variables: this.getSelection(),
          sudokuThemeFunc: this.widget.sudokuThemeFunc,
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
    sd!.setManualChange(variable, val);
    // for(int v in variables) {
    //   if(v == variables.first) {
    //     sd.setManualChange(v, val);
    //   } else {
    //     sd.setAssistantChange(v, val);
    //   }
    // }
    this.runAssistant(reapply: (val == 0));
  }

  void _processCellElimination(Iterable<int> variables, EliminatorInteractionReturnType changes) {
    for(int v in variables) {
      var diff = (sd!.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd!.assist.elim[v].invertBits(diff.asIntIterable());
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

  Future<void> _showResetDialog(BuildContext ctx) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              Text(
                'Reset Puzzle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'This will clear all your progress. This action cannot be undone.',
            style: TextStyle(
              color: isDark ? AppColors.darkDialogText : Colors.black54,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkCancelButton : AppColors.lightCancelButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Reset'),
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

  Border getBorder(int i, int j, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);

    bool left = (j % sd!.n == 0);
    bool right = (j % sd!.n == sd!.n - 1);
    bool top = (i % sd!.n == 0);
    bool bottom = (i % sd!.n == sd!.n - 1);
    bool leftEdge = (j == 0), rightEdge = (j == sd!.ne2 - 1);
    bool topEdge = (i == 0), bottomEdge = (i == sd!.ne2 - 1);

    var side = BorderSide(
      width: 0.5,
      color: theme.foreground,
    );
    var edgeSide = BorderSide(
      width: 2.0,
      color: theme.foreground,
    );
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

  Widget _makeSudokuCellImmutable(int index, double sz, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    int sdval = sd![index];
    return Card(
      margin: const EdgeInsets.all(0.0),
      elevation: 1.0,
      color: theme.cellHintColor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(sz * 0.05),
          child: Text(
            sd!.s_get(sdval),
            style: TextStyle(
              fontSize: sz * 0.85,
              height: 1.0,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void startMultiSelect() {
    this._selectedCell = -1;
    this._multiSelect ??= BitArray(sd!.ne4);
    this._multiSelect!.clearAll();
  }

  void endMultiSelect() {
    this._multiSelect!.clearAll();
  }

  Color? getCellColor(int index, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    if(sd!.assist.hintContradictions && sd!.assist.getDomain(index).isEmpty) {
      return theme.red;
    } else if(this._multiSelect!.isEmpty) {
      if(this._selectedCell == index) {
        return theme.cellBackground;
      } else if(this._selectedConstraint != null && this._selectedConstraint.variables[index]) {
        switch(this._selectedConstraint.type) {
          case ConstraintType.ONE_OF: return theme.constraintOneOf;
          case ConstraintType.EQUAL: return theme.constraintEqual;
          case ConstraintType.ALLDIFF: return theme.constraintAllDiff!;
        }
      }
    } else {
      if(this._multiSelect![index]) {
        return theme.cellSelectionColor;
      }
    }
    if(this._tutorialCells != null && this._tutorialCells![index]) {
      return theme.orange;
    }
    return null;
  }

  Color? getCellTextColor(int index, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    if(sd!.isVariableManual(index)) {
      return theme.cellForeground;
    }
    return theme.cellInferColor;
  }

  Widget _makeSudokuCellMutable(int index, double sz, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    int sdval = sd![index];
    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        )),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if(states.contains(WidgetState.pressed)) {
              return theme.cellSelectionColor;
            }
            return this.getCellColor(index, ctx);
          }
        ),
      ),
      onPressed: () {
        this._handleOnPressCell(index);
      },
      onLongPress: () {
        this._handleLongPressCell(index);
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(sz * 0.05),
          child: Text(
            sd!.s_get_display(sdval),
            style: TextStyle(
              fontSize: sz * 0.85,
              height: 1.0,
              color: this.getCellTextColor(index, ctx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _makeSudokuCell(int index, double sz, BuildContext ctx) {
    if(sd!.isHint(index)) {
      return this._makeSudokuCellImmutable(index, sz, ctx);
    }
    return this._makeSudokuCellMutable(index, sz, ctx);
  }

  Widget _makeSudokuGridContent(BuildContext ctx, double size) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    double sz = (size - 1.0) / sd!.ne2;
    return CustomScrollView(
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverGrid.count(
          crossAxisCount: sd!.ne2,
          children: List<Widget>.generate(sd!.ne4, (index) {
            int i = index ~/ sd!.ne2, j = index % sd!.ne2;
            return Container(
              margin: const EdgeInsets.all(0.0),
              decoration: BoxDecoration(
                border: getBorder(i, j, ctx),
              ),
              child: this._makeSudokuCell(index, sz, ctx),
            );
          }),
        )
      ],
    );
  }

  var _scaffoldBodyContext = null;
  void _showAssistantResult() async {
    for(Constraint constr in sd!.assist.newlySucceeded) {
      ScaffoldMessenger.of(this._scaffoldBodyContext).showSnackBar(
        SnackBar(
          elevation: 4.0,
          content: Text(
            constr.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
            ),
          ),
        ),
      );
    }
  }

  bool _showTutorial = false;
  int _tutorialStage = 0;
  bool _tutorialDialogShown = false;

  BitArray? _tutorialCells = null;
  void _selectTutorialCells() {
    this._tutorialCells = BitArray(sd!.ne4)
      ..setBits(
          sd!.getUnsolvedRandomBC()
        .asIntIterable()
        .where((ind) => !sd!.isHint(ind)));
    if(this._tutorialCells == null) {
      this._tutorialCells = BitArray(sd!.ne4);
    }
    if (kDebugMode) print('tutorialcells ${this._tutorialCells!.asIntIterable()}');
  }

  Future<void> _showTutorialMessage({required String title, required String message, required Function() nextFunc}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                  ),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? AppColors.darkDialogText : Colors.black54,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Got it'),
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

  Future<void> _showTutorialOfferDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                  ),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Would you like a quick tutorial on how to use the constraint assistant?',
            style: TextStyle(
              color: isDark ? AppColors.darkDialogText : Colors.black54,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkCancelButton : AppColors.lightCancelButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Skip'),
              onPressed: () {
                this._showTutorial = false;
                this.runSetState();
                Navigator.of(ctx).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Start Tutorial'),
              onPressed: () {
                Navigator.of(ctx).pop();
                this._selectTutorialCells();
                this._showTutorial = true;
                this._tutorialStage = 1;
                this.runSetState();
                this._showTutorialMessage(
                  title: 'Multi-selection',
                  message: 'Long-press to enter multi-selection mode. To proceed, select the highlighted cells.',
                  nextFunc: (){}
                );
              }
            ),
          ],
        );
      },
    );
  }

  Widget _makeTutorialButtonStage12(BuildContext ctx) {
    final iconSize = min(80.0, min(screenWidth, screenHeight) * 0.15);
    var tutorialCellsUnset = BitArray(sd!.ne4)
      ..setBits(
        this._tutorialCells!
          .asIntIterable()
          .where((ind) => (sd![ind] == 0))
      );
    bool passCondition = (
      this._multiSelect!.cardinality == tutorialCellsUnset.cardinality
      && this._multiSelect!.asIntIterable().every(
        (msel) => tutorialCellsUnset[msel]
      )
    );
    this._tutorialStage = !passCondition ? 1 : 2;

    final gradientColors = passCondition
        ? [AppColors.success, AppColors.successLight] // Green when ready
        : [AppColors.warning, AppColors.warningLight]; // Orange when selecting

    return GestureDetector(
      onTap: !passCondition ? null : () {
        Scaffold.of(ctx).openDrawer();
        this.runSetState();
        this._showTutorialMessage(
            title: 'One of',
            message: 'One of the cells contains a specific value.',
            nextFunc: () {
              this._showTutorialMessage(
                title: 'All different',
                message: 'Match the selected cells with the same number of values.',
                nextFunc: () {
                  this._showTutorialMessage(
                    title: 'Instructions',
                    message: 'Tap "All different".',
                    nextFunc: () {
                    }
                  );
                }
              );
            }
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(passCondition ? 0.4 : 0.2),
              blurRadius: passCondition ? 15 : 8,
              offset: Offset(0, passCondition ? 6 : 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            passCondition ? Icons.check_circle_outline_rounded : Icons.touch_app_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _makeTutorialButtonStage3(BuildContext ctx) {
    final iconSize = min(80.0, min(screenWidth, screenHeight) * 0.15);
    return GestureDetector(
      onTap: () {
        this._showTutorialMessage(
            title: "New constraint",
            message: 'Assistant is used to simplify mechanical deductions. It will now account for the new rule.',
            nextFunc: () {
              this._showTutorialMessage(
                title: 'Assistant',
                message: 'Once you get used to using constraints, you should enable default rules through the settings.',
                nextFunc: () {
                }
              );
            }
        );
        this._showTutorial = false;
        this._tutorialStage = 0;
        this._tutorialCells = null;
        this.runSetState();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.success, AppColors.successLight],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _makeTutorialButton(BuildContext ctx) {
    final marginSize = min(32.0, min(screenWidth, screenHeight) * 0.05);
    final buttonSize = min(120.0, min(screenWidth, screenHeight) * 0.25);
    return Container(
      margin: EdgeInsets.all(marginSize),
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: (){
          switch(this._tutorialStage) {
            case 1:
            case 2:
              return this._makeTutorialButtonStage12(ctx);
            case 3:
              return this._makeTutorialButtonStage3(ctx);
            default:
              return const SizedBox.shrink();
          }
        }(),
      ),
    );
  }

  // Color mapping for constraint types
  static const Map<ConstraintType, List<Color>> _constraintColors = {
    ConstraintType.ONE_OF: [AppColors.success, AppColors.successLight],
    ConstraintType.EQUAL: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
    ConstraintType.ALLDIFF: [AppColors.accent, AppColors.accentLight],
  };

  var _selectedConstraint = null;
  Widget _makeConstraintList(BuildContext ctx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var constraints = sd!.assist.constraints.where((Constraint c) {
      return c.status != Constraint.SUCCESS;
    }).toList();

    // Theme-aware muted colors
    final mutedPrimary = isDark ? AppColors.darkMutedPrimary : AppColors.lightMutedPrimary;
    final mutedSecondary = isDark ? AppColors.darkMutedSecondary : AppColors.lightMutedSecondary;

    if (constraints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_add_rounded,
              size: 48,
              color: mutedSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No constraints yet',
              style: TextStyle(
                color: mutedPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select cells to add constraints',
              style: TextStyle(
                color: mutedSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    var listTiles = List<Widget>.generate(constraints.length, (i) {
      final constraint = constraints[i];
      final colors = _constraintColors[constraint.type] ?? [Colors.grey, Colors.grey[400]!];
      final isViolated = constraint.status == Constraint.VIOLATED;
      final isSelected = this._selectedConstraint == constraint;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: GestureDetector(
          onTap: !constraint.isActive() ? null : () {
            this._multiSelect!.clearAll();
            this._selectedConstraint = constraint;
            this.runSetState();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isViolated
                  ? const LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: constraint.isActive()
                          ? colors
                          : [colors[0].withOpacity(0.4), colors[1].withOpacity(0.4)],
                    ),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isViolated ? Colors.red : colors[0]).withOpacity(isSelected ? 0.4 : 0.2),
                  blurRadius: isSelected ? 10 : 4,
                  offset: Offset(0, isSelected ? 4 : 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Checkbox
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: constraint.isActive(),
                      onChanged: (bool? b) {
                        if(b!) {
                          constraint.activate();
                        } else {
                          constraint.deactivate();
                          if(this._selectedConstraint == constraint) {
                            this._selectedConstraint = null;
                          }
                        }
                        this.runAssistant();
                      },
                      fillColor: WidgetStateProperty.all(Colors.white.withOpacity(0.3)),
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  // Constraint info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          constraint.s_display(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Values: ${constraint.getValues()}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    onPressed: () {
                      if(this._selectedConstraint == constraint) {
                        this._selectedConstraint = null;
                      }
                      sd!.assist.constraints.remove(constraint);
                      this.runAssistant();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    if(this._selectedConstraint != null) {
      listTiles.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkSurfaceLight : const Color(0xFFDDDDEE),
              foregroundColor: isDark ? AppColors.darkDialogText : AppColors.lightCancelButton,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Deselect constraint'),
            onPressed: () {
              this._selectedConstraint = null;
              this.runSetState();
            }
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: listTiles,
    );
  }

  Widget _makeDrawerItem({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final bool isEnabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Disabled colors that match the theme
    final disabledBg = isDark ? AppColors.darkDisabledBg : AppColors.lightDisabledBg;
    final disabledFg = isDark ? AppColors.darkDisabledFg : AppColors.lightDisabledFg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHighlighted
                        ? gradientColors
                        : [gradientColors[0].withOpacity(0.7), gradientColors[1].withOpacity(0.7)],
                  )
                : null,
            color: isEnabled ? null : disabledBg,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(isHighlighted ? 0.4 : 0.2),
                      blurRadius: isHighlighted ? 12 : 6,
                      offset: Offset(0, isHighlighted ? 4 : 2),
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isEnabled ? Colors.white : disabledFg,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isEnabled ? Colors.white : disabledFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Drawer _makeDrawer(BuildContext ctx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTutorialHighlight = this._showTutorial && this._tutorialStage == 2;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                      ),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Constraints',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Constraint options
            _makeDrawerItem(
              icon: Icons.looks_one_rounded,
              title: 'One of',
              gradientColors: const [AppColors.success, AppColors.successLight],
              onTap: (this._multiSelect!.cardinality < 2) ? null : () async {
                this.interact = OneofInteraction(this);
                await this.interact!.onSelection();
                Navigator.pop(ctx);
                this.runSetState();
              },
            ),
            _makeDrawerItem(
              icon: Icons.link_rounded,
              title: 'Equivalence',
              gradientColors: const [AppColors.constraintPurple, AppColors.constraintPurpleLight],
              onTap: (this._multiSelect!.cardinality < 2) ? null : () async {
                this.interact = EqualInteraction(this);
                await this.interact!.onSelection();
                Navigator.pop(ctx);
                this.runSetState();
              },
            ),
            _makeDrawerItem(
              icon: Icons.difference_rounded,
              title: 'All different',
              gradientColors: const [AppColors.accent, AppColors.accentLight],
              onTap: (this._multiSelect!.cardinality < 2) ? null : () async {
                this.interact = AlldiffInteraction(this);
                await this.interact!.onSelection();
                Navigator.pop(ctx);
                this.runSetState();
              },
              isHighlighted: isTutorialHighlight,
            ),
            _makeDrawerItem(
              icon: Icons.block_rounded,
              title: 'Eliminate',
              gradientColors: const [AppColors.constraintOrange, AppColors.constraintOrangeLight],
              onTap: (this._multiSelect!.cardinality < 1) ? null : () async {
                this.interact = EliminatorInteraction(this);
                await this.interact!.onSelection();
                Navigator.pop(ctx);
                this.runSetState();
              },
            ),
            const Spacer(),
            // Hint text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Long-press cells to select multiple',
                style: TextStyle(
                  color: isDark ? AppColors.darkMutedPrimary : AppColors.lightMutedPrimary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void backtrackAssistant() {
    this.sd!.assist.retract();
  }

  void runAssistant({bool reapply=false}) {
    if(reapply) {
      this.sd!.assist.reapply();
    } else {
      this.sd!.assist.apply();
    }
    this._showAssistantResult();
    this._checkVictoryConditions();
    this.runSetState();
  }

  void _showAssistantOptions(BuildContext ctx) async {
    await Navigator.pushNamed(
      this.context,
      SudokuAssistScreen.routeName,
      arguments: SudokuAssistScreenArguments(
        sd: this.sd!,
      ),
    );
    this.runAssistant();
  }

  List<Widget> _makeToolBar(BuildContext ctx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    if(this._showTutorial && this._tutorialStage >= 1) {
      return <Widget>[];
    }
    const int
      TOOLBAR_ASSIST = 0,
      TOOLBAR_TUTOR = 1,
      TOOLBAR_RESET = 2;
    return <Widget>[
      IconButton(
        icon: Icon(Icons.undo_rounded, color: iconColor),
        onPressed: () {
          setState(() {
            if(this._multiSelect!.cardinality > 0) {
              this.endMultiSelect();
              return;
            }
            if(!this.sd!.changes.isEmpty) {
              this._selectedCell = sd!.getLastChange().assisted ? -1 : sd!.getLastChange().variable;
            }
            this.backtrackAssistant();
            this.sd!.undoChange();
            this.runAssistant();
          });
        },
      ),
      IconButton(
        icon: Icon(Icons.edit_rounded, color: iconColor),
        onPressed: () {
          if(this._multiSelect!.cardinality > 0) {
            this._selectCellValues(this._multiSelect!.asIntIterable());
          } else if(this._selectedCell != -1) {
            this._selectCellValue(this._selectedCell);
          }
        },
      ),
      PopupMenuButton<String>(
        icon: Icon(Icons.palette, color: iconColor),
        onSelected: (value) {
          final theme = this.widget.sudokuThemeFunc(ctx);
          setState(() {
            switch (value) {
              case 'light':
                theme.onThemeModeChange(ThemeMode.light);
                break;
              case 'dark':
                theme.onThemeModeChange(ThemeMode.dark);
                break;
              case 'system':
                theme.onThemeModeChange(ThemeMode.system);
                break;
              case 'modern':
                theme.onThemeStyleChange(ThemeStyle.modern);
                break;
              case 'penAndPaper':
                theme.onThemeStyleChange(ThemeStyle.penAndPaper);
                break;
            }
          });
        },
        itemBuilder: (context) {
          final theme = this.widget.sudokuThemeFunc(ctx);
          return [
            PopupMenuItem(
              enabled: false,
              child: Text(
                'BRIGHTNESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkMutedPrimary : AppColors.lightMutedPrimary,
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'light',
              child: Row(
                children: [
                  Icon(Icons.wb_sunny, size: 20),
                  SizedBox(width: 12),
                  Text('Light'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'dark',
              child: Row(
                children: [
                  Icon(Icons.nights_stay, size: 20),
                  SizedBox(width: 12),
                  Text('Dark'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'system',
              child: Row(
                children: [
                  Icon(Icons.settings_brightness, size: 20),
                  SizedBox(width: 12),
                  Text('System'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(
                'STYLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkMutedPrimary : AppColors.lightMutedPrimary,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'modern',
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: theme.currentStyle == ThemeStyle.modern
                        ? AppColors.primaryPurple
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Modern',
                    style: TextStyle(
                      fontWeight: theme.currentStyle == ThemeStyle.modern
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: theme.currentStyle == ThemeStyle.modern
                          ? AppColors.primaryPurple
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'penAndPaper',
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 20,
                    color: theme.currentStyle == ThemeStyle.penAndPaper
                        ? AppColors.primaryPurple
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pen & Paper',
                    style: TextStyle(
                      fontWeight: theme.currentStyle == ThemeStyle.penAndPaper
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: theme.currentStyle == ThemeStyle.penAndPaper
                          ? AppColors.primaryPurple
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
      PopupMenuButton<int>(
        icon: Icon(Icons.more_vert_rounded, color: iconColor),
        onSelected: (int opt) {
          switch(opt) {
            case TOOLBAR_RESET:
              this._showResetDialog(ctx);
            break;
            case TOOLBAR_TUTOR:
              this._showTutorialOfferDialog();
            break;
            case TOOLBAR_ASSIST:
              this._showAssistantOptions(ctx);
            break;
          }
        },
        itemBuilder: (BuildContext ctx) => <PopupMenuEntry<int>>[
          const PopupMenuItem(
            value: TOOLBAR_ASSIST,
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20),
                SizedBox(width: 12),
                Text('Assistant'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TOOLBAR_TUTOR,
            child: Row(
              children: [
                Icon(Icons.school_rounded, size: 20),
                SizedBox(width: 12),
                Text('Tutor'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TOOLBAR_RESET,
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, size: 20),
                SizedBox(width: 12),
                Text('Reset'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildResponsiveLayout(BuildContext ctx, BoxConstraints constraints) {
    final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;

    // Calculate optimal grid size based on orientation
    double gridSize;

    // Minimum width needed for the constraint list to be readable
    const double minConstraintListWidth = 200.0;

    if (isPortrait) {
      // In portrait, constraint list is below so grid can use full width
      gridSize = min(availableWidth, availableHeight * 0.7);
    } else {
      // In landscape, grid limited by height and must leave space for constraint list
      gridSize = min(availableHeight, availableWidth - minConstraintListWidth);
    }

    // Ensure grid doesn't exceed available space
    gridSize = min(gridSize, min(availableWidth, availableHeight));

    // Ensure minimum grid size for playability
    final minGridSize = 200.0;
    gridSize = max(gridSize, minGridSize);

    this.screenWidth = availableWidth;
    this.screenHeight = availableHeight;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget gridWidget = Container(
      width: gridSize,
      height: gridSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: this._makeSudokuGridContent(ctx, gridSize),
        ),
      ),
    );

    Widget secondaryContent = (this._showTutorial && this._tutorialStage >= 1)
        ? this._makeTutorialButton(ctx)
        : this._makeConstraintList(ctx);

    // Wrap secondary content with max-width constraint for readability
    Widget secondaryWidget = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
        ),
        child: secondaryContent,
      ),
    );

    if (isPortrait) {
      // Check if content might overflow on very small screens
      final bool needsScroll = (gridSize + 100) > availableHeight;

      if (needsScroll) {
        // Use scrollable layout for very small screens
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(child: gridWidget),
              SizedBox(
                height: max(150, availableHeight * 0.3),
                child: secondaryWidget,
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(child: gridWidget),
          Expanded(child: secondaryWidget),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(child: gridWidget),
          Expanded(child: secondaryWidget),
        ],
      );
    }
  }

  Widget build(BuildContext ctx) {
    var args = ModalRoute.of(ctx)!.settings.arguments! as SudokuScreenArguments;
    final int n = args.n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if(sd == null || sd!.n != n) {
      sd = Sudoku(n, DefaultAssetBundle.of(ctx), () {
        this.runSetState();
      });
      this._multiSelect = BitArray(sd!.ne4);
      this._tutorialDialogShown = false;
    }

    // Show tutorial offer dialog once after sudoku is initialized
    if (!_tutorialDialogShown) {
      _tutorialDialogShown = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _showTutorialOfferDialog();
      });
    }

    var appBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'SUDOKU',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 24,
          letterSpacing: 3,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: this._makeToolBar(ctx),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: appBar,
        drawer: this._makeDrawer(ctx),
        body: Builder(
          builder: (ctx) {
            this._scaffoldBodyContext = ctx;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildResponsiveLayout(context, constraints);
                  },
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
