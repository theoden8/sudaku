import 'dart:math';
import 'dart:async';

import 'package:bit_array/bit_array.dart';
import 'package:flutter/services.dart';

import 'SudokuBuffer.dart';
import 'SudokuDomain.dart';
import 'SudokuAssist.dart';


// load a dataset of hard n=3 sudokus
Future<List<int>> loadFrom1465(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(1465 + 87);
  // print('loading dataset $r');
  int ne4 = 81;
  String s = "";
  s += await a.loadString("assets/top1465");
  s += await a.loadString("assets/topn87");
  return List<int>.generate(ne4, (i) {
      // if(i == 0) {
      //   print(s.substring((ne4 + 1) * r, (ne4 + 1) * (r + 1)));
      // }
      int index = (ne4 + 1) * r + i;
      var c = s[index];
      if(c == '\n')print('$i');
      assert(c != '\n');
      return (c == '.') ? 0 : int.parse(c);
    }
  );
}


// load a dataset of hard n=4 sudokus
Future<List<int>> loadFrom44(AssetBundle a) async {
  var rng = new Random();
  int r = rng.nextInt(44);
  // print('random number == $r');
  int ne4 = 256;
  String s = await a.loadString("assets/top44");
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
  late int variable;
  late int value;
  late int prevValue;
  late bool assisted;

  SudokuChange({required int variable, required int value, required int prevValue, required bool assisted}) {
    this.variable = variable;
    this.value = value;
    this.prevValue = prevValue;
    this.assisted = assisted;
  }

  @override
  String toString() {
    return '[$variable]=($prevValue->$value):$assisted';
  }
}


class Sudoku {
  late BitArray hints;
  late SudokuBuffer buf;
  late List<SudokuChange> changes;
  late int n, ne2, ne4, ne6;
  late SudokuAssist assist;
  bool _mutex = false;

  int get age => this.changes.where((c) => !c.assisted).length;

  void guard(Function() func) {
    while(this._mutex)
      ;
    this._mutex = true;
    func();
    this._mutex = false;
  }

  void _renameSudokuValues() {
    var renaming = List<int>.generate(ne2, (i) => i + 1);
    renaming.shuffle();
    renaming.insert(0, 0);
    // print('renaming $renaming');
    for(int i = 0; i < ne4; ++i) {
      this[i] = renaming[this.buf[i]];
    }
  }

  void _transposeCrossGrid() {
    this.buf.setBuffer(this.buf.getBuffer().reversed.toList());
  }

  void _transposeGrid() {
    this.buf.setBuffer(List<int>.generate(ne4, (index) {
      int i = index % ne2, j = index ~/ ne2;
      return this.buf[j * ne2 + i];
    }));
  }

  List<Iterable<int>> _getBand(int band) {
    return List<int>.generate(n, (i) => i)
      .map((i) => this.iterateRow(band * n + i))
      .toList();
  }

  List<Iterable<int>> _getStack(int stack) {
    return List<int>.generate(n, (i) => i)
      .map((i) => this.iterateCol(stack * n + i))
      .toList();
  }

  List<Iterable<int>> Function(int) _getRandomSleeveFunc(dynamic rng) {
    if(rng.nextInt(2) == 0) {
      return this._getBand;
    } else {
      return this._getStack;
    }
  }

  void _swapLines(List<int> first, List<int> second) {
    for(int i = 0; i < ne2; ++i) {
      int tmp = this[first[i]];
      this[first[i]] = this[second[i]];
      this[second[i]] = tmp;
    }
  }

  void _swapSleeves(List<Iterable<int>> first, List<Iterable<int>> second) {
    for(int i = 0; i < n; ++i) {
      this._swapLines(first[i].toList(), second[i].toList());
    }
  }

  void _shuffleSleeve(dynamic rng, List<Iterable<int>> sleeve) {
    for(int i = n - 1; i >= 1; --i) {
      int j = rng.nextInt(i + 1);
      this._swapLines(sleeve[i].toList(), sleeve[j].toList());
    }
  }

  void _shuffleEachSleeve(dynamic rng, Function(int) sleeve_func) {
    var iter = List<int>.generate(n * 2, (i) => i)..shuffle(rng);
    for(int i = 0; i < n; ++i) {
      this._shuffleSleeve(rng, sleeve_func(i));
    }
  }

  void _shuffleSleeves(dynamic rng, Function(int) sleeve_func) {
    for(int i = n - 1; i >= 1; --i) {
      int j = rng.nextInt(i + 1);
      this._swapSleeves(sleeve_func(i), sleeve_func(j));
    }
  }

  void shuffleSudokuBuffer() {
    this._renameSudokuValues();
    var rng = new Random();
    for(int i = 0; i < n; ++i) {
      if(rng.nextInt(2) == 1) {
        this._transposeGrid();
      }
      if(rng.nextInt(2) == 1) {
        this._transposeCrossGrid();
      }
      this._shuffleEachSleeve(rng, this._getRandomSleeveFunc(rng));
      this._shuffleSleeves(rng, this._getRandomSleeveFunc(rng));
    }
  }

  BitArray getRandomBC(dynamic rng) {
    int r = rng.nextInt(3);
    var bc_ind = rng.nextInt(this.ne2);
    var bc = BitArray(this.ne4);
    if(r == 0) {
      bc.setBits(this.iterateRow(bc_ind));
    } else if(r == 1) {
      bc.setBits(this.iterateCol(bc_ind));
    } else if(r == 2) {
      bc.setBits(this.iterateBox(bc_ind));
    }
    return bc;
  }

  BitArray getUnsolvedRandomBC() {
    var rng = new Random();
    var bc = null;
    do {
      bc = this.getRandomBC(rng);
    } while(!this.checkIsComplete()
        && bc.asIntIterable()
             .every((ind) => (this[ind] != 0)));
    return bc;
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
    this.shuffleSudokuBuffer();
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
    // to prevent some pesky late initialization errors
    this.hints = BitArray(ne4);
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

  void operator[]=(int ind, int val) {
    this.buf[ind] = val;
    this.assist.updateCurrentCondition();
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
    var chk = List<int>.generate(ne2 * 3, (int i) => 0);
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
    this.changes.add(SudokuChange(
      variable: index,
      value: val,
      prevValue: this[index],
      assisted: false
    ));
    this[index] = val;
  }

  void setAssistantChange(int index, int val) {
    this.changes.add(SudokuChange(
      variable: index,
      value: val,
      prevValue: this[index],
      assisted: true
    ));
    this[index] = val;
  }

  bool isVariableManual(int index) {
    var varChanges = this.changes
        .where((c) => (c.variable == index));
    if(varChanges.isEmpty) {
      return true;
    }
    return !varChanges.last.assisted;
  }

  SudokuChange getLastChange() {
    SudokuChange? lastChange = null;
    this.guard(() {
      lastChange = this.changes.last;
    });
    return lastChange!;
  }

  void undoChange() {
    // print('undo change from $changes');
    while(true) {
      // diff stack is empty
      if(this.changes.isEmpty) {
        return;
      }
      // last change is manual
      if(!this.getLastChange().assisted) {
        break;
      }
      // undo assisted change
      this.undoLastChange();
    }
    this.undoLastChange();
  }

  void undoLastChange() {
    // diff stack is empty
    if(this.changes.isEmpty) {
      return;
    }
    var lastChange = this.getLastChange();
    int lastVariable = lastChange.variable;
    int precedingValue = lastChange.prevValue;
    assert(precedingValue == this._findPrecedingValue(lastVariable));
    // print('preceding value for $lastVariable is $precedingValue');
    this[lastVariable] = precedingValue;
    this.changes.removeLast();
  }

  int _findPrecedingValue(int variable) {
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

  String s_get_display(int val) {
    if(val == 0) {
      return '·';
    }
    return s_get(val);
  }
}
