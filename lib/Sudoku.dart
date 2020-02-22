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
  ONE_OF, EQUAL, ALLDIFF,
}

class Constraint {
  List<int> condition;
  BitArray variables;
  BitArray domain;
  ConstraintType type;
  int start;
  bool active = true;
  int colorId = 0;

  Constraint(final List<int> condition, BitArray variables, BitArray domain, ConstraintType ct, int start) {
    this.condition = List<int>()..addAll(condition);
    this.variables = variables;
    this.domain = domain;
    this.type = ct;
    this.start = start;
  }

  bool isActive(Sudoku sd) {
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

  static const int
    SUCCESS = 1,
    INSUFFICIENT = 0,
    VIOLATED = -1;

  bool hasVariable(int variable) {
    return true;
  }

  int _applyOneof(Sudoku sd) {
    int count = 0;
    int remaining = -1;
    assert(domain.cardinality == 1);
    int value = domain.asIntIterable().first;
    for(int v in variables.asIntIterable()) {
      if(sd[v] == 0) {
        if(remaining != -1) {
          return Constraint.VIOLATED;
        }
        remaining = v;
      } else {
        domain.clearBit(sd[v]);
      }
    }
    if(count == 0) {
      return Constraint.INSUFFICIENT;
    }
    sd.setAssistantChange(remaining, value);
    return Constraint.SUCCESS;
  }

  int _applyEqual(Sudoku sd) {
    int val = 0;
    for(int v in variables.asIntIterable()) {
      if(sd[v] != 0) {
        if(val != 0) {
          return Constraint.VIOLATED;
        }
        val = sd[v];
      }
    }
    if(val == 0) {
      return Constraint.INSUFFICIENT;
    }
    for(int v in variables.asIntIterable()) {
      if(sd[v] == 0) {
        sd.setAssistantChange(v, val);
      }
    }
    return Constraint.SUCCESS;
  }

  int _applyAlldiff(Sudoku sd) {
    assert(variables.cardinality == domain.cardinality);
    BitArray newDomain = domain.clone();
    int index = -1;
    for(int v in variables.asIntIterable()) {
      if(sd[v] != 0) {
        if(!newDomain[sd[v]]) {
          return Constraint.VIOLATED;
        }
        newDomain.clearBit(sd[v]);
      } else {
        if(index != -1) {
          return Constraint.INSUFFICIENT;
        }
        index = v;
      }
    }
    int value = newDomain.asIntIterable().first;
    sd.setAssistantChange(index, value);
    return Constraint.SUCCESS;
  }

  int apply(Sudoku sd) {
    print('apply constraint ${this.type}');
    switch(this.type) {
      case ConstraintType.ONE_OF: return this._applyOneof(sd); break;
      case ConstraintType.EQUAL: return this._applyEqual(sd); break;
      case ConstraintType.ALLDIFF: return this._applyAlldiff(sd); break;
    }
    return Constraint.VIOLATED;
  }
}

class SudokuAssist {
  Sudoku sd;
  List<Constraint> constraints;

  SudokuAssist(Sudoku sd) {
    this.sd = sd;
    this.constraints = List<Constraint>();
  }

  void addConstraint(ConstraintType ct, BitArray variables, BitArray domain) {
    constraints.add(Constraint(List<int>()..addAll(sd.buf), variables.clone(), domain.clone(), ct, sd.changes.length));
  }

  void addOneOf(BitArray variables, int value) {
    this.addConstraint(ConstraintType.ONE_OF, variables, sd.getEmptyDomain()..setBit(value));
  }

  void addEqual(BitArray variables) {
    this.addConstraint(ConstraintType.EQUAL, variables, sd.getEmptyDomain());
  }

  void addAllDiff(BitArray variables, BitArray domain) {
    this.addConstraint(ConstraintType.ALLDIFF, variables, domain);
  }

  void apply() {
    for(var constr in this.constraints) {
      if(!constr.isActive(sd)) {
        continue;
      }
      constr.apply(this.sd);
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

  bool isEmpty() {
    return this.size() == 0;
  }

  int size() {
    return indices.length;
  }

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
    this.changes = List<SudokuChange>();
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
    var dom = BitArray(ne2 + 1);
    int i = index ~/ ne2, j = index % ne2;
    for(int t = 0; t < ne2 + 1; ++t) {
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
    return BitArray(ne2 + 1)..setAll();
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

  int index(int i, int j) {
    return i * ne2 + j;
  }

  // readonly
  int countUnknowns() {
    int c = 0;
    this.guard(() {
      for(int i = 0; i < ne4; ++i) {
        if(this.buf[i] == 0) {
          ++c;
        }
      }
    });
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
          int val = 0;
          this.guard(() {
            val = this.buf[pos[k]];
          });
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
    this.guard(() {
      this.buf[index] = val;
    });
  }

  void setAssistantChange(int index, int val) {
    this.guardChange(() {
      this.changes.last.registerChange(index, val);
    });
    this.guard(() {
      this.buf[index] = val;
    });
  }

  void undoChange() {
    this.guardChange(() {
      if(changes.length == 0) {
        return;
      }
      for(int i = 0; i < changes.last.size(); ++i) {
        int ind = changes.last.indices[changes.last.size() - i - 1];
        // int val = changes.last.values[changes.last.size() - i - 1];
        int precedingValue = 0;
        // same change stack
        for(SudokuChange c in changes.reversed) {
          for(int j = 0; j < ((c == changes.last) ? c.size() - i - 1 : c.size()); ++j) {
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
