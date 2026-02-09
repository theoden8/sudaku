import 'package:bit_array/bit_array.dart';
import 'package:flutter/foundation.dart';

import 'SudokuBuffer.dart';
import 'SudokuDomain.dart';
import 'Sudoku.dart';

enum ConstraintType {
  ONE_OF, EQUAL, ALLDIFF, GENERIC
}

// generic constraint
// some constraints are run occasionally
// specifically, when they are unsuccessful and their conditions match
abstract class Constraint extends DomainFilterer {
  static const int
    NOT_RUN = -2,
    SUCCESS = 1,
    INSUFFICIENT = 0,
    VIOLATED = -1;

  late Sudoku sd;
  late SudokuBuffer condition;
  late BitArray variables;
  ConstraintType type = ConstraintType.GENERIC;
  bool active = true;

  int get status => (this._statuses.isEmpty) ? Constraint.NOT_RUN : this._statuses.last;
  int get lastStatus => (this._statuses.length < 2) ? Constraint.NOT_RUN : this._statuses[this._statuses.length - 1];
  int get age => (this._agesRun.isEmpty) ? -1 : _agesRun.last;
  // stacks that get appended to each time run
  late List<int> _statuses;
  late List<int> _agesRun;
  // stacks that get appended to on each success
  late List<int> _successStreaks;
  late List<SudokuBuffer> _successConditions;

  Constraint(Sudoku sd, BitArray variables) {
    this.sd = sd;
    this.updateCondition();
    this.variables = variables.clone();
    this._statuses = <int>[];
    this._agesRun = <int>[];
    this._successStreaks = <int>[];
    this._successConditions = <SudokuBuffer>[];
  }

  int getCommonRow() {
    int row = -1;
    for(int variable in this.variables.asIntIterable()) {
      int vrow = sd.getRow(variable);
      if(row == -1) {
        row = vrow;
      } else if(row != vrow) {
        return -1;
      }
    }
    return row;
  }

  int getCommonCol() {
    int col = -1;
    for(int variable in this.variables.asIntIterable()) {
      int vcol = sd.getCol(variable);
      if(col == -1) {
        col = vcol;
      } else if(col != vcol) {
        return -1;
      }
    }
    return col;
  }

  int getCommonBox() {
    int box = -1;
    for(int variable in this.variables.asIntIterable()) {
      int vbox = sd.getBox(variable);
      if(box == -1) {
        box = vbox;
      } else if(box != vbox) {
        return -1;
      }
    }
    return box;
  }

  void filterTotalDomain(SudokuDomain sdom) {
  }

  Iterable<int> getValues();

  bool checkInitialCondition() {
    return this.condition.match(sd.buf);
  }

  bool isActive() {
    return this.active && this.checkInitialCondition();
  }

  void updateCondition() {
    this.condition = sd.assist.currentCondition;
  }

  void activate() {
    this.active = true;
  }

  void deactivate() {
    this.active = false;
  }

  int _apply();

  bool checkSuccessCondition() {
    assert(this.status != Constraint.SUCCESS || this._successConditions.last.match(sd.buf));
    return !this._successConditions.isEmpty
      && this.status == Constraint.SUCCESS
      && this._successConditions.last.match(sd.buf);
  }

  void retract() {
    if(!this._statuses.isEmpty && sd.age == this.age) {
      this._statuses.removeLast();
      if(!this._successStreaks.isEmpty && this._successConditions.length == this._successStreaks.last) {
        this._successStreaks.removeLast();
        this._successConditions.removeLast();
      }
    }
  }

  // generic wrap for _apply
  // updates stack variables
  void apply() {
    // print('apply constraint ${this.type}');
    if(this.checkSuccessCondition()) {
      // print('success by condition');
      return;
    }
    var currentCondition = sd.assist.currentCondition;
    this._statuses.add(this._apply());
    this._agesRun.add(sd.age);
    if(this.lastStatus != Constraint.SUCCESS && this.status == Constraint.SUCCESS) {
      this._successStreaks.add(this._successConditions.length);
      this._successConditions.add(currentCondition);
    }
  }

  String toString() {
    return '${this.type}';
  }

  String s_display();
}

class ConstraintOneOf extends Constraint {
  late int value;

  ConstraintOneOf(Sudoku sd, BitArray variables, int value) : super(sd, variables) {
    this.value = value;
    this.type = ConstraintType.ONE_OF;
  }

  @override
  void filterTotalDomain(SudokuDomain sdom) {
    var affected = BitArray(sd.ne4);
    int commonRow = super.getCommonRow(),
        commonCol = super.getCommonCol(),
        commonBox = super.getCommonBox();
    if(commonRow != -1) {
      affected.setBits(sd.iterateRow(commonRow));
    }
    if(commonCol != -1) {
      affected.setBits(sd.iterateCol(commonCol));
    }
    if(commonBox != -1) {
      affected.setBits(sd.iterateBox(commonBox));
    }
    affected.asIntIterable()
      .where((v) => !this.variables[v])
      .forEach((v) {
        sdom[v].clearBit(this.value);
      });
  }

  @override
  Iterable<int> getValues() {
    return <int>[this.value];
  }

  @override
  int _apply() {
    // there is variable that inevitably is assigned to value
    int remainingUnique = -1;
    for(int v in this.variables.asIntIterable()) {
      var dom = sd.assist.getDomain(v);
      if(dom.cardinality == 1 && dom[this.value]) {
        if(remainingUnique == -1) {
          if (kDebugMode) print('remainingUnique $v');
          remainingUnique = v;
        } else {
          return Constraint.VIOLATED;
        }
      }
    }
    if(remainingUnique != -1) {
      sd.setAssistantChange(remainingUnique, value);
      return Constraint.SUCCESS;
    }
    // there is only one variable that can hold the value
    int remaining = -1;
    for(int v in this.variables.asIntIterable()) {
      if(sd.assist.getDomain(v)[this.value]) {
        if(remaining == -1) {
          remaining = v;
        } else {
          return Constraint.INSUFFICIENT;
        }
      }
    }
    if(remaining == -1) {
      return Constraint.VIOLATED;
    }
    sd.setAssistantChange(remaining, value);
    return Constraint.SUCCESS;
  }

  @override
  String toString() {
    return 'One-of: ${this.value}';
  }

  @override
  String s_display() {
    return "oneOf";
  }
}

class ConstraintEqual extends Constraint {
  ConstraintEqual(Sudoku sd, BitArray variables) : super(sd, variables) {
    this.type = ConstraintType.EQUAL;
  }

  @override
  void filterTotalDomain(SudokuDomain sdom) {
    var common = sd.getCommonDomain(this.variables.asIntIterable());
    this.variables.asIntIterable()
      .forEach((v) {
        sdom[v].assign(common);
      });
  }

  @override
  Iterable<int> getValues() {
    var dom = sd.getFullDomain();
    for(int v in this.variables.asIntIterable()) {
      dom = dom & sd.assist.getDomain(v);
    }
    return dom.asIntIterable();
  }

  @override
  int _apply() {
    var dom = sd.getFullDomain();
    for(int v in this.variables.asIntIterable()) {
      dom = dom & sd.assist.getDomain(v);
    }
    dom.clearBit(0);
    if(dom.isEmpty) {
      return Constraint.VIOLATED;
    } else if(dom.cardinality > 1) {
      return Constraint.INSUFFICIENT;
    }
    // one unique value for all of them
    int val = dom.asIntIterable().first;
    for(int v in variables.asIntIterable()) {
      if(sd[v] == 0) {
        sd.setAssistantChange(v, val);
      }
    }
    return Constraint.SUCCESS;
  }

  @override
  String s_display() {
    return "equal";
  }
}

class ConstraintAllDiff extends Constraint {
  late BitArray domain;
  late int length;
  late List<int> indexMap;

  late List<BitArray?> domainCache;
  late List<int> assigned;

  ConstraintAllDiff(Sudoku sd, BitArray variables, BitArray domain) : super(sd, variables) {
    assert(variables.cardinality == domain.cardinality);
    this.type = ConstraintType.ALLDIFF;
    this.domain = domain.clone();
    this.length = this.domain.cardinality;
    this.indexMap = List<int>.generate(this.length, (i) => this.variables.asIntIterable().toList()[i]);
    this.clearDomainCache();
    this.resetAssigned();
    // print('indexMap: $indexMap');
  }

  void resetAssigned() {
    this.assigned = List<int>.generate(this.length, (i) => sd[this.indexMap[i]]);
    // print('assigned $assigned');
  }

  void clearDomainCache() {
    this.domainCache = List<BitArray?>.generate(this.length, (i) => null);
  }

  @override
  void filterTotalDomain(SudokuDomain sdom) {
    var affected = BitArray(sd.ne4);
    int commonRow = super.getCommonRow(),
        commonCol = super.getCommonCol(),
        commonBox = super.getCommonBox();
    if(commonRow != -1) {
      affected.setBits(sd.iterateRow(commonRow));
    }
    if(commonCol != -1) {
      affected.setBits(sd.iterateCol(commonCol));
    }
    if(commonBox != -1) {
      affected.setBits(sd.iterateBox(commonBox));
    }
    affected.asIntIterable()
      .where((v) => !this.variables[v])
      .forEach((v) {
        sdom[v].clearBits(this.domain.asIntIterable());
      });
    this.variables.asIntIterable()
      .forEach((v) {
        sdom[v].assign(sdom[v].asBitArray() & this.domain);
      });
  }

  BitArray getDomain(int variable) {
    int ind = this.indexMap.indexOf(variable);
    if(this.domainCache[ind] == null) {
      var dom = null;
      if(this.assigned[ind] != 0) {
        dom = sd.getEmptyDomain()..setBit(this.assigned[ind]);
      } else {
        dom = sd.assist.getDomain(variable) & this.domain;
        dom.clearBits(this.assigned);
      }
      assert(dom != null);
      this.domainCache[ind] = dom;
    }
    return this.domainCache[ind]!;
  }

  // check if a given variable can be assigned a given value
  bool isValue(int variable, int value) {
    int antiCount = 0;
    for(int v in this.variables.asIntIterable()) {
      var dom = this.getDomain(v);
      if(v == variable) {
        // the only value possible in this cell
        if(dom.cardinality == 1 && dom[value]) {
          // print('is value [$variable] = $value, because the only left');
          return true;
        } else if(!dom[value]) {
          return false;
        }
      } else {
        // this value is available in another cell
        if(dom[value]) {
          return false;
        }
        // or it is not
        ++antiCount;
        // print('[$v] denies $value');
      }
    }
    // all other cells can't have this value
    if(antiCount == this.length - 1) {
      // print('is value [$variable] = $value, because everyone else denies');
    }
    return antiCount == this.length - 1;
  }

  int getVariableAssignment(int variable) {
    var values = <int>[];
    for(int val in this.domain.asIntIterable()) {
      if(this.isValue(variable, val)) {
        values.add(val);
      }
    }
    if(values.length == 0) {
      // print('inconclusive [$variable]');
      return 0;
    } else if(values.length == 1) {
      // print('can assign [$variable] = $values');
      return values.first;
    } else {
      // print('variable [$variable] violation values $values');
      return -1;
    }
  }

  int _applyCached() {
    // at least one assignment per pass
    for(int i = 0; i < this.length; ++i) {
      // pass over the variables
      for(int variable in this.variables.asIntIterable()) {
        if(this.getDomain(variable).isEmpty) {
          // deadend
          return Constraint.VIOLATED;
        }
        int ind = this.indexMap.indexOf(variable);
        if(this.assigned[ind] != 0) {
          continue;
        }
        int val = this.getVariableAssignment(variable);
        if(val > 0) {
          this.assigned[ind] = val;
          this.clearDomainCache();
        } else if(val == -1) {
          // two values fit this exact cell, leads to overlap
          return Constraint.VIOLATED;
        }
      }
      // if all is assigned everything is good
      int zeros = 0;
      for(int x in this.assigned) {
        if(x == 0) {
          ++zeros;
        }
      }
      // finalize
      if(zeros == 0) {
        for(int i = 0; i < this.length; ++i) {
          sd.setAssistantChange(this.indexMap[i], this.assigned[i]);
        }
        return Constraint.SUCCESS;
      }
    }
    return Constraint.INSUFFICIENT;
  }

  @override
  Iterable<int> getValues() {
    return this.domain.asIntIterable();
  }

  @override
  int _apply() {
    this.resetAssigned();
    int code = this._applyCached();
    this.clearDomainCache();
    return code;
  }

  @override
  String toString() {
    return 'All different: ${this.domain.asIntIterable()}';
  }

  @override
  String s_display() {
    return "allDiff";
  }
}

class Eliminator extends DomainFilterer {
  late Sudoku sd;
  late List<SudokuBuffer> conditions;
  late List<SudokuDomain> forbiddenValues;

  int get length => this.conditions.length;

  bool mutex = false;
  void guard(Function f) {
    while(mutex)
      ;
    mutex = true;
    f();
    mutex = false;
  }

  Eliminator(Sudoku sd) {
    this.sd = sd;
    this.conditions = <SudokuBuffer>[];
    this.forbiddenValues = <SudokuDomain>[];
  }

  EliminatorSubdomain operator[](int variable) {
    return EliminatorSubdomain(this, variable);
  }

  void removeObsoleteConditions() {
    int i = 0;
    while(i < this.length) {
      this.guard(() {
        if(this.forbiddenValues[i].isEmpty) {
          this.conditions.removeAt(i);
          this.forbiddenValues.removeAt(i);
        } else {
          ++i;
        }
      });
    }
  }

  bool checkCondition(int index) {
    return this.conditions[index].match(sd.buf);
  }

  Iterable<int> iterateActiveConditions() sync* {
    for(int i = 0; i < this.length; ++i) {
      if(this.checkCondition(i)) {
        yield i;
      }
    }
  }

  void _eliminate(int variable, Iterable<int> values) {
    this.removeObsoleteConditions();
    if(this.length == 0 || this.conditions.last != sd.assist.currentCondition) {
      // Clone the condition to prevent it being modified by updateCurrentCondition()
      this.conditions.add(sd.assist.currentCondition.clone());
      this.guard(() {
        this.forbiddenValues.add(SudokuDomain(sd));
      });
    }
    this.forbiddenValues.last[variable].setBits(values);
  }

  BitArray getCommonElimination(Iterable<int> indices) {
    var edom = this.getTotalElimination();
    if(indices.isEmpty) {
      return sd.getEmptyDomain();
    }
    return indices
      .map((i) => edom[i].asBitArray())
      .fold(sd.getFullDomain(), (BitArray a, BitArray b) => (a & b));
  }

  BitArray getRepresentativeElimination(Iterable<int> indices) {
    var edom = this.getTotalElimination();
    return indices
      .map((i) => edom[i].asBitArray())
      .fold(sd.getEmptyDomain(), (BitArray a, BitArray b) => (a | b));
  }

  SudokuDomain getTotalElimination() {
    var edom = SudokuDomain(sd);
    this.iterateActiveConditions()
      .map((i) => this.forbiddenValues[i])
      .forEach((fdom) {
        edom |= fdom;
      });
    return edom;
  }

  void filterTotalDomain(SudokuDomain sdom) {
    // Clear eliminated values from the domain
    // Note: We can't use &= because it creates a new object instead of modifying in place
    var eliminated = this.getTotalElimination();
    for (int i = 0; i < sdom.dom.length; ++i) {
      if (eliminated.dom[i]) {
        sdom.dom.clearBit(i);
      }
    }
  }
}

class EliminatorSubdomain {
  late Sudoku sd;
  late Eliminator elim;
  late int variable;

  int get length => elim.length;

  EliminatorSubdomain(Eliminator elim, int variable) {
    this.sd = elim.sd;
    this.elim = elim;
    this.variable = variable;
  }

  bool operator[](int value) {
    bool res = false;
    this.elim.iterateActiveConditions()
      .forEach((i) {
        if(this.elim.forbiddenValues[i][this.variable][value]) {
          res = true;
        }
      });
    return res;
  }

  void operator[]=(int value, bool bit) {
    if(this[value] != bit) {
      this.invertBit(value);
    }
  }

  void reinstate(Iterable<int> values) {
    this.elim.forbiddenValues.forEach((edom) {
      edom[this.variable].clearBits(values);
    });
  }

  void eliminate(Iterable<int> values) {
    this.elim._eliminate(this.variable, values);
  }

  BitArray asBitArray() {
    if(this.elim.iterateActiveConditions().isEmpty) {
      return sd.getEmptyDomain();
    }
    return this.elim.iterateActiveConditions()
      .map<BitArray>((i) => this.elim.forbiddenValues[i][this.variable].asBitArray())
      .fold(sd.getFullDomain(), (BitArray a, BitArray b) => (a & b));
  }

  void invertBit(int value) {
    if(this[value]) {
      this.eliminate(<int>[value]);
    } else {
      this.reinstate(<int>[value]);
    }
  }

  void invertBits(Iterable<int> values) {
    var ones = sd.getEmptyDomain()..setBits(values.where((val) => this[val]));
    this.reinstate(values.where((val) => ones[val]));
    this.eliminate(values.where((val) => !ones[val]));
  }
}

class Constrainer extends DomainFilterer {
  late Sudoku sd;
  late List<Constraint> constraints;

  Constrainer(Sudoku sd, List<Constraint> constraints) {
    this.sd = sd;
    this.constraints = constraints;
  }

  ConstrainerSubdomain operator[](int variable) {
    return ConstrainerSubdomain(this, variable);
  }

  void filterTotalDomain(SudokuDomain sdom) {
    if(!sd.assist.hintConstrained) {
      return;
    }
    this.filterWithDefaultConstraints(sdom);
    this.constraints.where((constr) =>
      constr.isActive() && (
        constr.status == Constraint.NOT_RUN
        || constr.status == Constraint.INSUFFICIENT
      )
    ).forEach((constr) {
      sdom.filter(constr);
    });
  }

  void filterWithDefaultConstraints(SudokuDomain sdom) {
    if(!sd.assist.shouldUseDefaultConstraints) {
      return;
    }
  }

  void assistDefaultConstraints() {
    if(!sd.assist.shouldUseDefaultConstraints) {
      return;
    }
    bool restart = true;
    while(restart) {
      var sdom = sd.assist.getTotalDomain();
      restart = false;
      for(int i = 0; i < sd.ne2; ++i) {
        for(var line in <Iterable<int>>[sd.iterateRow(i), sd.iterateCol(i), sd.iterateBox(i)]) {
          var free = line.where((v) => (sd[v] == 0));
          // print('line $line');
          // print('values ${line.map((v) => sd[v])}');
          // print('free $free');
          for(int v in free) {
            if(sdom[v].cardinality == 1) {
              int val = sdom[v].asIntIterable().first;
              // print('unique [$v] = $val');
              sd.setAssistantChange(v, val);
              restart = true;
              break;
            } else {
              for(int val in sdom[v].asBitArray().asIntIterable()) {
                var others = free.where((w) => (v != w));
                if(others
                  .map((w) => !sdom[w][val])
                  .fold(true, (bool a, bool b) => (a && b)))
                {
                  sd.setAssistantChange(v, val);
                  // print('exclusive [$v] = $val');
                  restart = true;
                  break;
                }
              }
            }
            if(restart)break;
          }
          if(restart)break;
        }
        if(restart)break;
      }
    }
  }

  BitArray getCommonConstrained(Iterable<int> indices) {
    var cdom = this.getTotalConstrained();
    if(indices.isEmpty) {
      return sd.getEmptyDomain();
    }
    return indices
      .map((i) => cdom[i].asBitArray())
      .fold(sd.getFullDomain(), (BitArray a, BitArray b) => (a & b));
  }

  BitArray getRepresentativeConstrained(Iterable<int> indices) {
    var cdom = this.getTotalConstrained();
    return indices
      .map((i) => cdom[i].asBitArray())
      .fold(sd.getEmptyDomain(), (BitArray a, BitArray b) => (a | b));
  }

  SudokuDomain getTotalConstrained() {
    return sd.getTotalDomain()..filter(this);
  }
}

class ConstrainerSubdomain {
  late Sudoku sd;
  late Constrainer constr;
  late int variable;

  ConstrainerSubdomain(Constrainer constr, int variable) {
    this.sd = sd;
    this.constr = constr;
    this.variable = variable;
  }
}

class SudokuAssist extends DomainFilterer {
  // state variables
  late Sudoku sd;
  late SudokuBuffer currentCondition;
  late List<Constraint> constraints;
  late List<Constraint> newlySucceeded;
  late Eliminator elim;
  late Constrainer constr;
  // configuration variables
  bool autoComplete = false;
  bool useDefaultConstraints = false;
  bool hintAvailable = true;
  bool hintConstrained = true;
  bool hintContradictions = true;
  bool showDifficulty = true;
  bool showLiveDifficulty = false;
  bool showDifficultyNumbers = false;
  // configuration readers
  bool get shouldUseDefaultConstraints => autoComplete && useDefaultConstraints;

  /// Check if a puzzle is trivially solvable using only the assistant's
  /// default constraints (naked singles and hidden singles).
  ///
  /// This creates a temporary Sudoku instance, enables auto-complete with
  /// default constraints, and checks if the puzzle gets fully solved.
  ///
  /// Returns true if the puzzle can be completely solved by the assistant
  /// with only basic techniques, meaning it's too easy for larger grids.
  static bool isTriviallyAutoSolvable(List<int> puzzle, int n) {
    final ne4 = n * n * n * n;
    if (puzzle.length != ne4) {
      throw ArgumentError('Puzzle length must be $ne4 for n=$n');
    }

    // Create a temporary Sudoku instance with the puzzle
    final testSudoku = Sudoku.demo(n, List<int>.from(puzzle), () {});

    // Enable auto-complete with default constraints
    testSudoku.assist.autoComplete = true;
    testSudoku.assist.useDefaultConstraints = true;

    // Run the assistant repeatedly until no more progress
    int prevEmpty = ne4;
    while (true) {
      testSudoku.assist.apply();

      // Count empty cells
      int emptyCount = 0;
      for (int i = 0; i < ne4; i++) {
        if (testSudoku.buf[i] == 0) emptyCount++;
      }

      // No progress made - stop
      if (emptyCount >= prevEmpty) break;
      prevEmpty = emptyCount;

      // Puzzle is solved
      if (emptyCount == 0) break;
    }

    // Return true if puzzle is fully solved (trivially solvable)
    return testSudoku.buf.getBuffer().every((v) => v != 0);
  }

  SudokuAssist(Sudoku sd) {
    this.sd = sd;
    this.constraints = <Constraint>[];
    this.newlySucceeded = <Constraint>[];
    this.elim = Eliminator(sd);
    this.constr = Constrainer(sd, this.constraints);
    this.currentCondition = SudokuBuffer(sd.ne4);
  }

  void filterTotalDomain(SudokuDomain sdom) {
    sdom.filter(this.elim);
    sdom.filter(this.constr);
  }

  BitArray getDomain(int variable) {
    return this.getTotalDomain()[variable].asBitArray();
  }

  SudokuDomain getTotalDomain() {
    return sd.getTotalDomain()..filter(this);
  }

  BitArray getCommonDomain(Iterable<int> indices) {
    return indices
      .map((i) => this.getDomain(i))
      .fold(sd.getFullDomain(), (BitArray a, BitArray b) => (a & b));
  }

  BitArray getRepresentativeDomain(Iterable<int> indices) {
    return indices
      .map((i) => this.getDomain(i))
      .fold(sd.getFullDomain(), (BitArray a, BitArray b) => (a | b));
  }

  SudokuDomain getTotalElimination() {
    return this.elim.getTotalElimination();
  }

  BitArray getCommonElimination(Iterable<int> indices) {
    return this.elim.getCommonElimination(indices);
  }

  BitArray getRepresentativeElimination(Iterable<int> indices) {
    return this.elim.getRepresentativeElimination(indices);
  }

  SudokuDomain getTotalConstrained() {
    return this.constr.getTotalConstrained();
  }

  BitArray getCommonConstrained(Iterable<int> indices) {
    return this.constr.getCommonConstrained(indices);
  }

  BitArray getRepresentativeConstrained(Iterable<int> indices) {
    return this.constr.getRepresentativeConstrained(indices);
  }

  void modifyEliminations(int variable, BitArray processedValues) {
    this.elim[variable].invertBits(processedValues.asIntIterable());
  }

  void addConstraint(Constraint ct) {
    constraints.add(ct);
  }

  bool checkConditionChange() {
    return this.currentCondition != null && this.currentCondition == sd.buf;
  }

  void updateCurrentCondition() {
    if(!this.checkConditionChange()) {
      this.currentCondition.setBuffer(sd.buf.getBuffer());
    }
  }

  void retract() {
    // simply retract all constraints
    for(Constraint constr in this.constraints) {
      constr.retract();
    }
  }

  void assistAutoComplete() {
    if(!this.autoComplete) {
      return;
    }
    var sdom = this.getTotalDomain();
    for(int i = 0; i < sd.ne4; ++i) {
      if(sd.buf[i] == 0) {
        if(sdom[i].cardinality == 1) {
          sd.setAssistantChange(i, sdom[i].asIntIterable().first);
        }
      }
    }
    if(this.useDefaultConstraints) {
      this.constr.assistDefaultConstraints();
    }
  }

  void reapply() {
    for(int i = 0; i < sd.ne4; ++i) {
      if(!sd.isVariableManual(i)) {
        sd.setAssistantChange(i, 0);
      }
    }
    var successfulConstraints = Set.of(
      this.constraints
        .where((constr) => constr.status == Constraint.SUCCESS));
    this.apply();
    this.newlySucceeded = this.newlySucceeded
        .where((constr) => successfulConstraints.contains(constr))
        .toList();
  }

  void apply() {
    // these will need to be removed from the interface
    this.newlySucceeded = <Constraint>[];
    this.assistAutoComplete();
    bool restart = true;
    while(restart) {
      restart = false;
      for(Constraint constr in this.constraints) {
        if(!constr.isActive()) {
          continue;
        }
        constr.apply();
        if(constr.lastStatus != constr.status && constr.status == Constraint.SUCCESS) {
          this.newlySucceeded.add(constr);
          // restart = true;
        }
        if(restart)break;
      }
    }
    this.assistAutoComplete();
  }
}
