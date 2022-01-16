import 'package:bit_array/bit_array.dart';

import 'Sudoku.dart';

abstract class DomainInterfaceReadOnly {
  bool get isEmpty;
  int get length;
  int get cardinality;
}

abstract class DomainInterface extends DomainInterfaceReadOnly {
  void setBit(int index);
  void setBits(Iterable<int> indices);
  void clearBit(int index);
  void clearBits(Iterable<int> indices);
  void invertBit(int index);
  void invertBits(Iterable<int> indices);
  BitArray asBitArray();
  Iterable<int> asIntIterable();
}

abstract class DomainFilterer {
  void filterTotalDomain(SudokuDomain sdom);
}

class SudokuDomain extends DomainInterface {
  late Sudoku sd;
  late BitArray dom;
  bool _mutex = false;

  @override
  bool get isEmpty => this.dom.isEmpty;

  @override
  int get length => this.dom.length;

  @override
  int get cardinality => this.dom.cardinality;

  void guard(Function f) {
    while(this._mutex)
      ;
    this._mutex = true;
    f();
    this._mutex = false;
  }

  SudokuDomain(Sudoku sd) {
    this.sd = sd;
    this.reset();
  }

  static SudokuDomain fromBitArray(Sudoku sd, BitArray dom) {
    var sdom = SudokuDomain(sd);
    sdom.guard(() {
      sdom.dom = dom;
    });
    return sdom;
  }

  void reset() {
    this.dom = BitArray(sd.ne6 + sd.ne4);
  }

  void filter(DomainFilterer df) {
    df.filterTotalDomain(this);
  }

  SudokuSubdomain operator[](int v) {
    return SudokuSubdomain(sd, this, v);
  }

  void operator[]=(int v, BitArray dom) {
    this[v].assign(dom);
  }

  int index(int variable, int value) {
    return variable * (sd.ne2 + 1) + value;
  }

  bool getBit(int index) {
    bool? bit = null;
    this.guard(() {
      bit = this.dom[index];
    });
    return bit!;
  }

  @override
  void setBit(int index) {
    this.guard(() {
      this.dom.setBit(index);
    });
  }

  @override
  void setBits(Iterable<int> indices) {
    this.guard(() {
      this.dom.setBits(indices);
    });
  }

  @override
  void clearBit(int index) {
    this.guard(() {
      this.dom.clearBit(index);
    });
  }

  @override
  void clearBits(Iterable<int> indices) {
    this.guard(() {
      this.dom.clearBits(indices);
    });
  }

  @override
  void invertBit(int index) {
    this.guard(() {
      this.dom.invertBit(index);
    });
  }

  @override
  void invertBits(Iterable<int> indices) {
    this.guard(() {
      this.dom.invertBits(indices);
    });
  }

  @override
  BitArray asBitArray() {
    return this.dom.clone();
  }

  @override
  Iterable<int> asIntIterable() {
    return this.dom.asIntIterable();
  }

  SudokuDomain operator&(SudokuDomain other) {
    SudokuDomain? sdom = null;
    this.guard((){other.guard((){
      sdom = SudokuDomain.fromBitArray(sd, this.dom & other.dom);
    });});
    return sdom!;
  }

  SudokuDomain operator|(SudokuDomain other) {
    SudokuDomain? sdom = null;
    this.guard((){other.guard((){
      sdom = SudokuDomain.fromBitArray(sd, this.dom | other.dom);
    });});
    return sdom!;
  }

  SudokuDomain operator^(SudokuDomain other) {
    SudokuDomain? sdom = null;
    this.guard((){other.guard((){
      sdom = SudokuDomain.fromBitArray(sd, this.dom ^ other.dom);
    });});
    return sdom!;
  }

  SudokuDomain operator~() {
    return this.clone()..invert();
  }

  void invert() {
    this.guard(() {
      this.dom.invertAll();
    });
  }

  SudokuDomain clone() {
    return SudokuDomain(sd) | this;
  }
}

class SudokuSubdomain extends DomainInterface {
  late Sudoku sd;
  late SudokuDomain sdom;
  late int variable;

  @override
  bool get isEmpty => (this.cardinality == 0);

  @override
  int get length => sd.ne2 + 1;

  @override
  int get cardinality => this.asIntIterable().length;

  SudokuSubdomain(Sudoku sd, SudokuDomain sdom, int variable) {
    this.sd = sd;
    this.sdom = sdom;
    this.variable = variable;
  }

  BitArray asBitArray() {
    return BitArray(this.length)..setBits(Iterable<int>.generate(this.length, (i) => i).where((i) => this[i]));
  }

  bool operator[](int value) {
    return this.sdom.getBit(sdom.index(this.variable, value));
  }

  void operator[]=(int value, bool bit) {
    if(bit) {
      this.setBit(value);
    } else {
      this.clearBit(value);
    }
  }

  void assign(BitArray dom) {
    for(int i = 0; i < this.length; ++i) {
      this[i] = dom[i];
    }
  }

  // SudokuSubdomain operator=(BitArray dom) {
  //   this.assign(dom);
  //   return this;
  // }

  @override
  void setBit(int value) {
    this.sdom.setBit(this.sdom.index(this.variable, value));
  }

  @override
  void setBits(Iterable<int> values) {
    this.sdom.setBits(values.map((val) => this.sdom.index(this.variable, val)));
  }

  @override
  void clearBit(int value) {
    this.sdom.clearBit(this.sdom.index(this.variable, value));
  }

  @override
  void clearBits(Iterable<int> values) {
    this.sdom.clearBits(values.map((val) => this.sdom.index(this.variable, val)));
  }

  @override
  void invertBit(int value) {
    this.sdom.invertBit(this.sdom.index(this.variable, value));
  }

  @override
  void invertBits(Iterable<int> values) {
    this.sdom.invertBits(values.map((val) => this.sdom.index(this.variable, val)));
  }

  @override
  Iterable<int> asIntIterable() {
    return Iterable<int>.generate(this.length, (i) => i).where((i) => this[i]);
  }
}
