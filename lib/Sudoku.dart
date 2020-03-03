import 'dart:math';
import 'dart:async';

import 'package:bit_array/bit_array.dart';
import 'package:flutter/services.dart';


import 'main.dart';

import 'SudokuScreen.dart';


Future<List<int>> loadFrom1465(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(1465);
  // print('random number == $r');
  int ne4 = 81;
  return await a.loadStructuredData("assets/top1465",
    (String s) async =>  List<int>.generate(ne4, (i) {
      // if(i == 0) {
      //   print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
      // }
      int index = (ne4 + 1) * r + i;
      var c = s[index];
      assert(c != '\n');
      return (c == '.') ? 0 : int.parse(c);
    }),
  );
}

Future<List<int>> loadFrom44(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(44);
  // print('random number == $r');
  int ne4 = 256;
  return await a.loadStructuredData<List<int>>("assets/top44",
    (String s) async => List<int>.generate(ne4, (i) {
        // if(i == 0) {
        //   print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
        // }
        int index = (ne4 + 1) * r + i;
        var c = s[index];
        assert(c != '\n');
        switch(c) {
          case '.': return 0;
          case 'A': return 10;
          case 'B': return 11;
          case 'C': return 12;
          case 'D': return 13;
          case 'E': return 14;
          case 'F': return 15;
          case 'G': return 16;
          default: return int.parse(c);
        }
    }),
  );
}


class Buffer {
  List<int> buf;
  int get length => this.buf.length;
  bool _mutex = false;

  void guard(Function f) {
    while(this._mutex)
      ;
    this._mutex = true;
    f();
    this._mutex = false;
  }

  Buffer(int length) {
    this.buf = List<int>.generate(length, (i) => 0);
  }

  void setBuffer(List<int> newBuffer) {
    this.guard(() {
      this.buf = newBuffer;
    });
  }

  List<int> _getBuffer() {
    return this.buf;
  }

  List<int> getBuffer() {
    List<int> buffer = null;
    this.guard((){
      buffer = List<int>()..addAll(this._getBuffer());
    });
    return buffer;
  }

  int operator[](int index) {
    int val = null;
    this.guard(() {
      val = this.buf[index];
    });
    return val;
  }

  int operator[]=(int index, int val) {
    this.guard(() {
      this.buf[index] = val;
    });
    return val;
  }
}


enum ConstraintType {
  ONE_OF, EQUAL, ALLDIFF, GENERIC
}

abstract class Constraint {
  static const int
    NOT_RUN = -2,
    SUCCESS = 1,
    INSUFFICIENT = 0,
    VIOLATED = -1;

  Sudoku sd;
  Buffer condition;
  BitArray variables;
  ConstraintType type = ConstraintType.GENERIC;
  bool active = true;

  int get lastStatus => (this._statuses.length < 2) ? Constraint.NOT_RUN : this._statuses[this._statuses.length - 1];
  int get status => (this._statuses.isEmpty) ? Constraint.NOT_RUN : this._statuses.last;
  int ageLastRun = -1;
  List<int> _statuses;
  List<int> _successStreaks;
  List<Buffer> _successConditions;

  Constraint(Sudoku sd, BitArray variables) {
    this.sd = sd;
    this.updateCondition();
    this.variables = variables.clone();
    this._statuses = <int>[];
    this._successStreaks = <int>[];
    this._successConditions = <Buffer>[];
  }

  BitArray filteredDomain(BitArray dom, int variable) {
    return dom;
  }

  Iterable<int> getValues();

  bool checkInitialCondition() {
    for(int i = 0; i < sd.ne4; ++i) {
      if(this.condition[i] != 0 && this.condition[i] != sd[i]) {
        return false;
      }
    }
    return true;
  }

  bool isActive() {
    if(!this.active) {
      return false;
    }
    return this.checkInitialCondition();
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
    if(this._successConditions.isEmpty || this.status != Constraint.SUCCESS) {
      return false;
    }
    for(int i = 0; i < sd.ne4; ++i) {
      int val = this._successConditions.last[i];
      if(val != 0 && val != sd[i]) {
        return false;
      }
    }
    return true;
  }

  void retract() {
    if(!this._statuses.isEmpty) {
      this._statuses.removeLast();
      if(!this._successStreaks.isEmpty && this._successConditions.length == this._successStreaks.last) {
        this._successStreaks.removeLast();
        this._successConditions.removeLast();
      }
    }
  }

  void apply() {
    print('apply constraint ${this.type}');
    if(this.checkSuccessCondition()) {
      print('success by condition');
      return;
    }
    var currentCondition = sd.assist.currentCondition;
    int newStatus = this._apply();
    if(sd.age == this.ageLastRun) {
      this._statuses.last = newStatus;
      return;
    } else {
      this._statuses.add(newStatus);
    }
    if(this.lastStatus != Constraint.SUCCESS && this.status == Constraint.SUCCESS) {
      this._successStreaks.add(this._successConditions.length);
      this._successConditions.add(currentCondition);
    }
  }

  String toString() {
    return '${this.type}';
  }
}

class ConstraintOneOf extends Constraint {
  int value;

  ConstraintOneOf(Sudoku sd, BitArray variables, int value) : super(sd, variables) {
    this.value = value;
    this.type = ConstraintType.ONE_OF;
  }

  BitArray filteredDomain(BitArray dom, int variable) {
    if(this.variables[variable]) {
      return dom;
    }
    bool sameRow = true, sameCol = true, sameBox = true;
    int row = sd.getCoordinateRow(variable),
        col = sd.getCoordinateCol(variable),
        box = sd.getCoordinateBox(variable);
    for(int v in this.variables.asIntIterable()) {
      if(sameRow && sd.getCoordinateRow(v) != row) {
        sameRow = false;
      }
      if(sameCol && sd.getCoordinateCol(v) != col) {
        sameCol = false;
      }
      if(sameBox && sd.getCoordinateBox(v) != box) {
        sameBox = false;
      }
    }
    if(sameRow || sameCol || sameBox) {
      return dom..clearBit(value);
    }
    return super.filteredDomain(dom, variable);
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
          print('remainingUnique $v');
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
    return '${super.toString()} dom=${<int>[this.value]}';
  }
}

class ConstraintEqual extends Constraint {
  ConstraintEqual(Sudoku sd, BitArray variables) : super(sd, variables) {
    this.type = ConstraintType.EQUAL;
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
}

class ConstraintAllDiff extends Constraint {
  BitArray domain;
  int length;
  List<int> indexMap;

  List<BitArray> domainCache;
  List<int> assigned;

  ConstraintAllDiff(Sudoku sd, BitArray variables, BitArray domain) : super(sd, variables) {
    assert(variables.cardinality == domain.cardinality);
    this.type = ConstraintType.ALLDIFF;
    this.domain = domain.clone();
    this.length = this.domain.cardinality;
    this.indexMap = List<int>.generate(this.length, (i) => this.variables.asIntIterable().toList()[i]);
    this.clearDomainCache();
    this.resetAssigned();
    print('indexMap: $indexMap');
  }

  void resetAssigned() {
    this.assigned = List<int>.generate(this.length, (i) => sd[this.indexMap[i]]);
    print('assigned $assigned');
  }

  void clearDomainCache() {
    this.domainCache = List<BitArray>.generate(this.length, (i) => null);
  }

  BitArray filteredDomain(BitArray dom, int variable) {
    if(this.variables[variable]) {
      return (dom & this.domain)..clearBits(this.assigned);
    }
    bool sameRow = true, sameCol = true, sameBox = true;
    int row = sd.getCoordinateRow(variable),
        col = sd.getCoordinateCol(variable),
        box = sd.getCoordinateBox(variable);
    for(int v in this.variables.asIntIterable()) {
      if(sameRow && sd.getCoordinateRow(v) != row) {
        sameRow = false;
      }
      if(sameCol && sd.getCoordinateCol(v) != col) {
        sameCol = false;
      }
      if(sameBox && sd.getCoordinateBox(v) != box) {
        sameBox = false;
      }
    }
    if(sameRow || sameCol || sameBox) {
      return dom & this.domain;
    }
    return super.filteredDomain(dom, variable);
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
    return this.domainCache[ind];
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
    var values = List<int>();
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
    return '${super.toString()} dom=${this.domain.asIntIterable()}';
  }
}

class Eliminator {
  Sudoku sd;

  int get length => this.conditions.length;
  List<Buffer> conditions;
  List<BitArray> forbiddenValues;

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
    this.conditions = <Buffer>[];
    this.forbiddenValues = <BitArray>[];
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

  void eliminate(int variable, BitArray values) {
    this.removeObsoleteConditions();
    if(this.length == 0 || this.conditions.last != sd.assist.currentCondition) {
      this.conditions.add(sd.assist.currentCondition);
      this.guard(() {
        this.forbiddenValues.add(BitArray(sd.ne4 * (sd.ne2 + 1)));
      });
    }
    for(int val in values.asIntIterable()) {
      print('forbidden values size ${forbiddenValues.last.length} index [$variable]!=$val');
      this.guard(() {
        this.forbiddenValues.last.setBit((sd.ne2 + 1) * variable + val);
      });
    }
  }

  void reinstateValue(int variable, int value) {
    for(int i = 0; i < this.length; ++i) {
      print('reinstating [$variable] ?= $value');
      this.guard(() {
        this.forbiddenValues[i].clearBit((sd.ne2 + 1) * variable + value);
      });
    }
  }

  void reinstate(int variable, BitArray values) {
    for(var val in values.asIntIterable()) {
      this.reinstateValue(variable, val);
    }
  }

  bool checkCondition(int index) {
    bool ret = true;
    this.guard((){
      for(int i = 0; i < sd.ne4; ++i) {
        if(this.conditions[index][i] != 0 && this.conditions[index][i] != sd[i]) {
          ret = false;
          break;
        }
      }
    });
    return ret;
  }

  BitArray filteredDomain(BitArray dom, int variable) {
    var mask = sd.getEmptyDomain();
    for(int i = 0; i < this.length; ++i) {
      if(!this.checkCondition(i)) {
        continue;
      }
      for(int val = 1; val < sd.ne2; ++val) {
        if(!dom[val]) {
          continue;
        }
        bool forbidden;
        this.guard(() {
          forbidden = this.forbiddenValues[i][(sd.ne2 + 1) * variable + val];
        });
        if(forbidden) {
          mask.setBit(val);
        }
      }
    }
    return mask..invertAll();
  }
}


class SudokuAssist {
  Sudoku sd;
  Buffer currentCondition;
  List<Constraint> constraints;
  List<Constraint> newlySucceeded;
  Eliminator elim;
  bool autoComplete = false;

  SudokuAssist(Sudoku sd) {
    this.sd = sd;
    this.constraints = List<Constraint>();
    this.newlySucceeded = List<Constraint>();
    this.elim = Eliminator(sd);
    this.currentCondition = Buffer(sd.ne4);
  }

  BitArray filteredDomainConstrained(BitArray dom, int variable) {
    var mask = dom.clone();
    for(Constraint constr in this.constraints) {
      if(!constr.isActive() || (constr.status != Constraint.NOT_RUN && constr.status != Constraint.INSUFFICIENT)) {
        continue;
      }
      mask &= constr.filteredDomain(dom & mask, variable);
    }
    return mask;
  }

  BitArray filteredDomain(BitArray dom, int variable) {
    BitArray mask = this.elim.filteredDomain(dom, variable);
    mask = this.filteredDomainConstrained(mask, variable);
    return mask;
  }

  BitArray getDomain(int variable) {
    var dom = sd.getDomain(variable);
    return dom & this.filteredDomain(dom, variable);
  }

  BitArray getElimination(int variable) {
    var dom = sd.getDomain(variable);
    return dom ^ (dom & this.elim.filteredDomain(dom, variable));
  }

  BitArray getConstrained(int variable) {
    var dom = sd.getDomain(variable);
    return dom ^ (dom & this.filteredDomainConstrained(dom, variable));
  }

  void modifyEliminations(int variable, BitArray processedValues) {
    var edom = this.getElimination(variable);
    var diff = edom ^ processedValues;
    var toReinstate = edom & diff;
    var toEliminate = diff ^ toReinstate;
    this.elim.reinstate(variable, toReinstate);
    this.elim.eliminate(variable, toEliminate);
  }

  void addConstraint(Constraint ct) {
    constraints.add(ct);
  }

  bool checkConditionChange() {
    if(this.currentCondition == null) {
      return false;
    }
    for(int i = 0; i < sd.ne4; ++i) {
      if(sd[i] != this.currentCondition[i]) {
        return false;
      }
    }
    return true;
  }

  void updateCurrentCondition() {
    if(!this.checkConditionChange()) {
      this.currentCondition.setBuffer(sd.buf.getBuffer());
    }
  }

  void retract() {
    for(var constr in this.constraints) {
      constr.retract();
    }
  }

  void assistAutoComplete() {
    if(!this.autoComplete) {
      return;
    }
    for(int i = 0; i < sd.ne4; ++i) {
      if(sd.buf[i] == 0) {
        var dom = this.getDomain(i);
        if(dom.cardinality == 1) {
          sd.setAssistantChange(i, dom.asIntIterable().first);
        }
      }
    }
  }

  void apply() {
    newlySucceeded = List<Constraint>();
    this.assistAutoComplete();
    for(var constr in this.constraints) {
      if(!constr.isActive()) {
        continue;
      }
      constr.apply();
      if(constr.lastStatus != constr.status && constr.status == Constraint.SUCCESS) {
        this.newlySucceeded.add(constr);
      }
    }
    this.assistAutoComplete();
  }
}

class SudokuChange {
  List<int> indices;
  List<int> values;

  SudokuChange() {
    indices = List<int>();
    values = List<int>();
  }

  int get length => indices.length;
  bool get isEmpty => (this.length == 0);

  void registerChange(int index, int val) {
    indices.add(index);
    values.add(val);
  }
}

class SudokuChangeList {
  List<SudokuChange> changes;

  bool _mutex = false;
  dynamic guard(Function f) {
    while(this._mutex)
      ;
    this._mutex = true;
    var r = f();
    this._mutex = false;
    return r;
  }

  int get length => this.guard(() => this.changes.length);
  bool get isEmpty => this.guard(() => this.changes.isEmpty);
  SudokuChange get first => this.guard(() => this.changes.first);
  SudokuChange get last => this.guard(() => this.changes.last);

  SudokuChange operator[](int index) => this.guard(() => this.changes[index]);

  SudokuChangeList() {
    this.changes = <SudokuChange>[];
    this.add();
  }

  void add() {
    this.guard((){
      this.changes.add(SudokuChange());
    });
  }

  void registerChange(int index, int newval) {
    this.guard(() {
      this.changes.last.registerChange(index, newval);
    });
  }

  void removeLast() {
    if(this.isEmpty) {
      return;
    }
    guard(() {
      this.changes.removeLast();
    });
    if(this.isEmpty) {
      this.add();
    }
  }

  get reversed => this.guard(() => this.changes.reversed);
}

class Sudoku {
  BitArray hints;
  Buffer buf;
  SudokuChangeList changes;
  int n, ne2, ne4, ne6;

  SudokuAssist assist;

  bool _mutex = false;

  int get age => this.changes.length;

  void guard(Function() func) {
    while(this._mutex)
      ;
    this._mutex = true;
    func();
    this._mutex = false;
  }

  void _renameBuffer() {
    var renaming = List<int>.generate(ne2, (i) => i + 1);
    renaming.shuffle();
    renaming.insert(0, 0);
    // print('renaming $renaming');
    for(int i = 0; i < ne4; ++i) {
      this[i] = renaming[this.buf[i]];
    }
  }

  void _mangleCrossTranspose() {
    this.buf.setBuffer(this.buf._getBuffer().reversed.toList());
  }

  void _mangleTranspose() {
    this.buf.setBuffer(List<int>.generate(ne4, (index) {
      int i = index % ne2, j = index ~/ ne2;
      return this.buf[j * ne2 + i];
    }));
  }

  void _mangleBuffer() {
    this._renameBuffer();
    var rng = new Random();
    if(rng.nextInt(2) == 1) {
      this._mangleTranspose();
    }
    if(rng.nextInt(2) == 1) {
      this._mangleCrossTranspose();
    }
  }

  void _setupSudoku(AssetBundle a, SudokuScreenState ss) async {
    this.buf = Buffer(ne4);
    var r = new Random();
    if(n == 2) {
      this.guard(() {
        switch(r.nextInt(2)) {
          case 0:
            this.buf.setBuffer(<int>[
              1, 0, 0, 0,
              3, 2, 0, 0,
              0, 0, 2, 0,
              0, 0, 0, 1,
            ]);
          break;
          case 1:
            this.buf.setBuffer(<int>[
              1, 0, 0, 0,
              0, 2, 0, 0,
              3, 0, 2, 0,
              0, 0, 0, 1,
            ]);
          break;
        }
      });
    } else if(n == 3) {
      var newBuf = await loadFrom1465(a);
      this.buf.setBuffer(newBuf);
    } else if(n == 4) {
      var newBuf = await loadFrom44(a);
      this.buf.setBuffer(newBuf);
    } else {
      this.buf.setBuffer(List<int>.generate(this.ne4, (i) => r.nextInt(ne2 + 1)));
    }
    // print(this.toString());
    this._mangleBuffer();
    // print(this.toString());
    this.guard(() {
      this.hints = BitArray(ne4);
      for(int i = 0; i < ne4; ++i) {
        if(this.buf[i] != 0) {
          this.hints.setBit(i);
        }
      }
    });
    this.assist.updateCurrentCondition();
    assert(this.check());
    ss.runSetState();
  }

  Sudoku(int n, AssetBundle a, SudokuScreenState ss) {
    this.n = n;
    this.ne2 = n * n;
    this.ne4 = ne2 * ne2;
    this.ne6 = ne4 * ne2;
    this.changes = SudokuChangeList();
    this.assist = SudokuAssist(this);
    this._setupSudoku(a, ss);
  }

  bool isHint(int ind) {
    if(this.hints == null) {
      return false;
    }
    bool ret = false;
    this.guard(() {
      ret = this.hints[ind];
    });
    return ret;
  }

  bool checkIsComplete() {
    return !this.buf._getBuffer().contains(0);
  }

  BitArray getDomain(int index) {
    var dom = this.getEmptyDomain();
    if(this[index] != 0) {
      return dom..setBit(this[index]);
    }
    int i = index ~/ ne2, j = index % ne2;
    for(int t = 1; t < ne2 + 1; ++t) {
      dom.setBit(t);
    }
    for(int t = 0; t < ne2; ++t) {
      var conflicts = <int>[
        i * ne2 + t, // row
        ne2 * t + j, // col
        ((i ~/ n) * n + (t ~/ n)) * ne2 + (j ~/ n) * n + (t % n), // box
      ];
      for(int pos in conflicts) {
        int val = this[pos];
        if(index != pos && val != 0) {
          dom.clearBit(val);
        }
      }
    }
    // print('getDomain: ${dom.asIntIterable().toList()}');
    return dom;
  }

  BitArray getEmptyDomain() {
    return BitArray(ne2 + 1);
  }

  BitArray getFullDomain() {
    return BitArray(ne2 + 1)..setAll()..clearBit(0);
  }

  int operator[](int ind) {
    if(this.buf == null) {
      return 0;
    }
    return this.buf[ind];
  }

  int operator[]=(int ind, int val) {
    this.buf[ind] = val;
    this.assist.updateCurrentCondition();
    return val;
  }

  int index(int i, int j) {
    return i * ne2 + j;
  }

  int getCoordinateRow(int ind) {
    return ind ~/ ne2;
  }

  int getCoordinateCol(int ind) {
    return ind % ne2;
  }

  int getCoordinateBox(int ind) {
    return (this.getCoordinateRow(ind) ~/ n) + (this.getCoordinateCol(ind) ~/ n);
  }

  // readonly
  bool check() {
    var chk = List<int>(ne2 * 3);
    for(int i = 0; i < ne2; ++i) {
      for(int j = 0; j < ne2 * 3; ++j) {
        chk[j] = 0;
      }
      for(int j = 0; j < ne2; ++j) {
        var pos = <int>[(i*ne2)+j, (j*ne2)+i, ((i~/n)*n+(j~/n))*ne2+(i%n)*n+(j%n)];
        for(int k = 0; k < 3; ++k) {
          int val = this[pos[k]];
          if(val == 0) {
            continue;
          }
          int chkInd = k*ne2+val-1;
          if(chk[chkInd] != 0) {
            return false;
          }
          chk[chkInd] = 1;
        }
      }
    }
    return true;
  }

  void setManualChange(int index, int val) {
    this.changes.add();
    this.changes.registerChange(index, val);
    this[index] = val;
  }

  void setAssistantChange(int index, int val) {
    this.changes.last.registerChange(index, val);
    this[index] = val;
  }

  void undoChange() {
    if(this.changes.isEmpty) {
      return;
    }
    for(int i = 0; i < changes.last.length; ++i) {
      int ind = changes.last.indices[changes.last.length - i - 1];
      // int val = changes.last.values[changes.last.length - i - 1];
      int precedingValue = 0;
      // same change stack
      for(int c_ind in Iterable<int>.generate(this.changes.length, (c_ind) => this.changes.length - c_ind - 1)) {
        var c = this.changes[c_ind];
        for(int j = 0; j < ((c == changes.last) ? c.length - i - 1 : c.length); ++j) {
          int oldInd = c.indices[j];
          if(oldInd != ind) {
            continue;
          }
          precedingValue = c.values[j];
          break;
        }
        if(precedingValue != 0) {
          break;
        }
      }
    }
    this.changes.removeLast();
    this.assist.retract();
  }

  String toString() {
    String s = "$n\n";
    for(int i = 0; i < ne4; ++i) {
      s = "$s ${this[i]}";
      if((i != ne4 - 1) && (i % ne2 == ne2 - 1)) {
        s = "$s\n";
      }
    }
    return s;
  }

  String s_get(int val) {
    if(val == 0) {
      return '.';
    }
    if(val > 9) {
      return String.fromCharCode(('A'.codeUnitAt(0)) + val - 10);
    }
    return val.toString();
  }
}
