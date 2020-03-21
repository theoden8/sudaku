import 'dart:math';
import 'dart:async';

import 'package:bit_array/bit_array.dart';
import 'package:flutter/services.dart';

import 'SudokuBuffer.dart';
import 'SudokuDomain.dart';
import 'SudokuAssist.dart';

Future<String> load1465(AssetBundle a) async {
  return await a.loadString("assets/top1465");
}

Future<List<int>> loadFrom1465(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(1465);
  // print('random number == $r');
  int ne4 = 81;
  String s = await load1465(a);
  return List<int>.generate(ne4, (i) {
      // if(i == 0) {
      //   print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
      // }
      int index = (ne4 + 1) * r + i;
      var c = s[index];
      assert(c != '\n');
      return (c == '.') ? 0 : int.parse(c);
    }
  );
}

Future<String> load44(AssetBundle a) async {
  return await a.loadString("assets/top44");
}

Future<List<int>> loadFrom44(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(44);
  // print('random number == $r');
  int ne4 = 256;
  String s = await load44(a);
  return List<int>.generate(ne4, (i) {
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
    }
  );
}

class SudokuChange {
  int variable;
  int value;
  bool assisted;

  SudokuChange(int variable, int value, bool assisted) {
    this.variable = variable;
    this.value = value;
    this.assisted = assisted;
  }

  @override
  String toString() {
    return '[$variable]=$value:$assisted';
  }
}

class Sudoku {
  BitArray hints;
  SudokuBuffer buf;
  List<SudokuChange> changes;
  int n, ne2, ne4, ne6;

  SudokuAssist assist;

  bool _mutex = false;

  int get age => this.changes.where((c) => !c.assisted).length;

  void guard(Function() func) {
    while(this._mutex)
      ;
    this._mutex = true;
    func();
    this._mutex = false;
  }

  void _renameSudokuBuffer() {
    var renaming = List<int>.generate(ne2, (i) => i + 1);
    renaming.shuffle();
    renaming.insert(0, 0);
    // print('renaming $renaming');
    for(int i = 0; i < ne4; ++i) {
      this[i] = renaming[this.buf[i]];
    }
  }

  void _mangleCrossTranspose() {
    this.buf.setBuffer(this.buf.getBuffer().reversed.toList());
  }

  void _mangleTranspose() {
    this.buf.setBuffer(List<int>.generate(ne4, (index) {
      int i = index % ne2, j = index ~/ ne2;
      return this.buf[j * ne2 + i];
    }));
  }

  void _mangleSudokuBuffer() {
    this._renameSudokuBuffer();
    var rng = new Random();
    if(rng.nextInt(2) == 1) {
      this._mangleTranspose();
    }
    if(rng.nextInt(2) == 1) {
      this._mangleCrossTranspose();
    }
  }

  void _setupSudoku(AssetBundle a, Function() callback_f) async {
    this.buf = SudokuBuffer(ne4);
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
    this._mangleSudokuBuffer();
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
    callback_f();
  }

  Sudoku(int n, AssetBundle a, callback_f) {
    this.n = n;
    this.ne2 = n * n;
    this.ne4 = ne2 * ne2;
    this.ne6 = ne4 * ne2;
    this.changes = <SudokuChange>[];
    this.assist = SudokuAssist(this);
    this._setupSudoku(a, callback_f);
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
    return !this.buf.getBuffer().contains(0);
  }

  Iterable<int> iterateRow(int row) sync* {
    for(int i = 0; i < ne2; ++i) {
      yield row * ne2 + i;
    }
  }

  Iterable<int> iterateCol(int col) sync* {
    for(int i = 0; i < ne2; ++i) {
      yield i * ne2 + col;
    }
  }

  Iterable<int> iterateBox(int box) sync* {
    for(int i = 0; i < n; ++i) {
      for(int j = 0; j < n; ++j) {
        yield (((box ~/ n) * n + i) * ne2) + ((box % n) * n + j);
      }
    }
  }

  BitArray getDomain(int index) {
    return this.getTotalDomain()[index].asBitArray();
  }

  BitArray getCommonDomain(Iterable<int> indices) {
    return indices
      .map((i) => this.getDomain(i))
      .fold(this.getFullDomain(), (BitArray a, BitArray b) => (a & b));
  }

  BitArray getRepresentativeDomain(Iterable<int> indices) {
    return indices
      .map((i) => this.getDomain(i))
      .fold(this.getEmptyDomain(), (BitArray a, BitArray b) => (a | b));
  }

  SudokuDomain getTotalDomain() {
    var sdom = SudokuDomain(this);
    for(int i = 0; i < ne4; ++i) {
      int val = this[i];
      if(val > 0) {
        sdom[i].setBit(val);
      } else {
        sdom[i].assign(this.getFullDomain());
      }
    }
    List<int>.generate(ne4, (i) => i)
      .where((i) => this[i] > 0)
      .forEach((i) {
        int val = this[i];
        <int>[]
          ..addAll(this.iterateRow(this.getRow(i)))
          ..addAll(this.iterateCol(this.getCol(i)))
          ..addAll(this.iterateBox(this.getBox(i)))
          ..where((int j) => (this[j] != val))
          .forEach((int j) {
            sdom[j].clearBit(val);
          });
      });
    return sdom;
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

  int getRow(int ind) {
    return ind ~/ ne2;
  }

  int getCol(int ind) {
    return ind % ne2;
  }

  int getBox(int ind) {
    return (this.getRow(ind) ~/ n) * n + (this.getCol(ind) ~/ n);
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
    this.changes.add(SudokuChange(index, val, false));
    this[index] = val;
  }

  void setAssistantChange(int index, int val) {
    this.changes.add(SudokuChange(index, val, true));
    this[index] = val;
  }

  SudokuChange getLastChange() {
    SudokuChange lastChange = null;
    this.guard(() {
      lastChange = this.changes.last;
    });
    return lastChange;
  }

  void undoChange() {
    // print('undo change from $changes');
    while(true) {
      if(this.changes.isEmpty) {
        return;
      }
      if(!this.getLastChange().assisted) {
        break;
      }
      this.undoLastChange();
    }
    this.undoLastChange();
  }

  void undoLastChange() {
    if(this.changes.isEmpty) {
      return;
    }
    var lastChange = this.getLastChange();
    int lastVariable = lastChange.variable;
    int precedingValue = this.findPrecedingValue(lastVariable);
    // print('preceding value for $lastVariable is $precedingValue');
    this[lastVariable] = precedingValue;
    this.changes.removeLast();
  }

  int findPrecedingValue(int variable) {
    int val = 0;
    this.guard(() {
      var hist = this.changes
        .reversed
        .where((c) => (c.variable == variable));
      // print('hist $hist');
      if(hist.length < 2) {
        val = 0;
        return;
      }
      // reagann and brezhnev running a cross
      // brezhnev took the honored second place
      // and reagann came second last
      val = hist.take(2).last.value;
    });
    return val;
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
