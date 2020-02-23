import 'dart:math';
import 'dart:async';

import 'package:bit_array/bit_array.dart';
import 'package:flutter/services.dart';


import 'main.dart';
import 'SudokuScreen.dart';


Future<List<int>> loadFrom1465(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(1465);
  print('random number == $r');
  int ne4 = 81;
  return await a.loadStructuredData("assets/top1465",
    (String s) async =>  List<int>.generate(ne4, (i) {
      if(i == 0) {
        print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
      }
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
  print('random number == $r');
  int ne4 = 256;
  return await a.loadStructuredData<List<int>>("assets/top44",
    (String s) async => List<int>.generate(ne4, (i) {
        if(i == 0) {
          print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
        }
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
  int status = Constraint.NOT_RUN;
  List<int> condition;
  List<int> successCondition = null;
  BitArray variables;
  ConstraintType type = ConstraintType.GENERIC;
  int start;
  bool active = true;
  int colorId = 0;

  Constraint(Sudoku sd, BitArray variables) {
    this.sd = sd;
    sd.guard(() {
      this.condition = List<int>()..addAll(sd.buf);
    });
    this.variables = variables.clone();
    this.start = -1;
  }

  Iterable<int> getValues();

  bool isActive() {
    if(!this.active) {
      return false;
    }
    for(int i = 0; i < sd.ne4; ++i) {
      if(this.condition[i] != 0 && this.condition[i] != sd.buf[i]) {
        return false;
      }
    }
    return true;
  }

  void activate() {
    this.active = true;
  }

  void deactivate() {
    this.active = false;
  }

  int _apply();

  bool checkSuccessCondition() {
    if(this.successCondition == null) {
      return false;
    }
    for(int i = 0; i < sd.ne4; ++i) {
      int val = this.successCondition[i];
      if(val != 0 && val != sd[i]) {
        return false;
      }
    }
    return true;
  }

  bool checkStart() {
    return start != -1 && start < sd.changes.length - 1;
  }

  bool checkMemoizedPass() {
    return this.checkStart() && this.checkSuccessCondition();
  }

  void apply() {
    print('apply constraint ${this.type}');
    if(this.checkMemoizedPass()) {
      print('success by condition');
      return;
    } else {
      this.successCondition = null;
    }
    var currentCondition = List<int>()..addAll(sd.buf);
    // re-calculated:
    // this.status = Constraint.NOT_RUN;
    this.status = this._apply();
    if(status == Constraint.SUCCESS) {
      sd.guard(() {
        this.successCondition = currentCondition;
      });
      if(!sd.assist.dryRunMode) {
        this.start = sd.changes.length;
      }
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

  BitArray getDomain(int variable) {
    var dom = sd.getDomain(variable);
    return dom;
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
      var dom = sd.getDomain(v);
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
      if(sd.getDomain(v)[this.value]) {
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
      dom = dom & sd.getDomain(v);
    }
    return dom.asIntIterable();
  }

  @override
  int _apply() {
    var dom = sd.getFullDomain();
    for(int v in this.variables.asIntIterable()) {
      dom = dom & sd.getDomain(v);
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

  BitArray getDomain(int variable) {
    int ind = this.indexMap.indexOf(variable);
    if(this.domainCache[ind] == null) {
      var dom = null;
      if(this.assigned[ind] != 0) {
        dom = sd.getEmptyDomain()..setBit(this.assigned[ind]);
      } else {
        dom = sd.getDomain(variable) & this.domain;
        for(var val in this.assigned) {
          dom.clearBit(val);
        }
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

class SudokuAssist {
  Sudoku sd;
  List<Constraint> constraints;
  List<Constraint> newlySucceeded;

  SudokuAssist(Sudoku sd) {
    this.sd = sd;
    this.constraints = List<Constraint>();
    this.newlySucceeded = List<Constraint>();
  }

  void addConstraint(Constraint ct) {
    constraints.add(ct);
  }

  bool dryRunMode = false;
  void dryRun() {
    print('dry running constraints');
    this.dryRunMode = true;
    this.apply();
    this.dryRunMode = false;
  }

  void apply() {
    newlySucceeded = List<Constraint>();
    for(var constr in this.constraints) {
      if(!constr.isActive()) {
        continue;
      }
      int beforeStatus = constr.status;
      constr.apply();
      int afterStatus = constr.status;
      if(beforeStatus != afterStatus && !this.dryRunMode && afterStatus == Constraint.SUCCESS) {
        this.newlySucceeded.add(constr);
      }
    }
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

class Sudoku {
  BitArray hints;
  List<int> buf;
  List<SudokuChange> changes;
  int n, ne2, ne4, ne6;

  SudokuAssist assist;

  bool _mutex = false;
  bool _changeMutex = false;

  void wait() {
    while(this._mutex)
      ;
  }

  void guard(Function() func) {
    this.wait();
    this._mutex = true;
    func();
    this._mutex = false;
  }

  void waitChange() {
    while(this._changeMutex)
      ;
  }

  void guardChange(Function() func) {
    this.waitChange();
    this._changeMutex = true;
    func();
    this._changeMutex = false;
  }

  void _renameBuffer() {
    var renaming = List<int>.generate(ne2, (i) => i + 1);
    renaming.shuffle();
    renaming.insert(0, 0);
    // print('renaming $renaming');
    this.guard(() {
      for(int i = 0; i < ne4; ++i) {
        this.buf[i] = renaming[this.buf[i]];
      }
    });
  }

  void _mangleCrossTranspose() {
    this.guard(() {
      this.buf = this.buf.reversed.toList();
    });
  }

  void _mangleTranspose() {
    this.guard(() {
      this.buf = List<int>.generate(ne4, (index) {
        int i = index % ne2, j = index ~/ ne2;
        return this.buf[j * ne2 + i];
      });
    });
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
    if(this._mutex) {
      return;
    }

    var r = new Random();
    if(n == 2) {
      this.guard(() {
        switch(r.nextInt(2)) {
          case 0:
            this.buf = <int>[
              1, 0, 0, 0,
              3, 2, 0, 0,
              0, 0, 2, 0,
              0, 0, 0, 1,
            ];
          break;
          case 1:
            this.buf = <int>[
              1, 0, 0, 0,
              0, 2, 0, 0,
              3, 0, 2, 0,
              0, 0, 0, 1,
            ];
          break;
        }
      });
    } else if(n == 3) {
      var newBuf = await loadFrom1465(a);
      this.guard(() {
        this.buf = newBuf;
      });
    } else if(n == 4) {
      var newBuf = await loadFrom44(a);
      this.guard(() {
        this.buf = newBuf;
      });
    } else {
      this.guard(() {
        this.buf = List<int>.generate(this.ne4, (i) => r.nextInt(ne2 + 1));
      });
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
    assert(this.check());
    ss.runSetState();
  }

  Sudoku(int n, AssetBundle a, SudokuScreenState ss) {
    this.n = n;
    this.ne2 = n * n;
    this.ne4 = ne2 * ne2;
    this.ne6 = ne4 * ne2;
    this.changes = List<SudokuChange>()..add(SudokuChange());
    this.assist = SudokuAssist(this);
    this._setupSudoku(a, ss);
  }

  bool isHint(int ind) {
    if(this.buf == null) {
      return false;
    }
    this.wait();
    return this.hints[ind];
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
    int val = 0;
    this.guard(() {
      val = this.buf[ind];
    });
    return val;
  }

  int operator[]=(int ind, int val) {
    this.guard(() {
      this.buf[ind] = val;
    });
    return val;
  }

  int index(int i, int j) {
    return i * ne2 + j;
  }

  // readonly
  int countUnknowns() {
    int c = 0;
    for(int i = 0; i < ne4; ++i) {
      if(this[i] == 0) {
        ++c;
      }
    }
    return c;
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
    this.guardChange(() {
      this.changes.add(SudokuChange());
      this.changes.last.registerChange(index, val);
    });
    this[index] = val;
  }

  void setAssistantChange(int index, int val) {
    if(this.assist.dryRunMode) {
      return;
    }
    this.guardChange(() {
      this.changes.last.registerChange(index, val);
    });
    this[index] = val;
  }

  void undoChange() {
    this.guardChange(() {
      if(changes.isEmpty) {
        return;
      }
      for(int i = 0; i < changes.last.length; ++i) {
        int ind = changes.last.indices[changes.last.length - i - 1];
        // int val = changes.last.values[changes.last.length - i - 1];
        int precedingValue = 0;
        // same change stack
        for(SudokuChange c in changes.reversed) {
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
        this.guard(() {
          this.buf[ind] = precedingValue;
        });
      }
      changes.removeLast();
      if(changes.isEmpty) {
        changes.add(SudokuChange());
      }
    });
  }

  String toString() {
    String s = "$n\n";
    for(int i = 0; i < ne4; ++i) {
      s = "$s ${this.buf[i]}";
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
