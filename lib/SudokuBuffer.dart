class SudokuBuffer {
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

  SudokuBuffer(int length) {
    this.buf = List<int>.generate(length, (i) => 0);
  }

  void setBuffer(List<int> newSudokuBuffer) {
    this.guard(() {
      this.buf = newSudokuBuffer;
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

  bool operator==(SudokuBuffer other) {
    return !Iterable<bool>.generate(this.length, (i) => (
      this[i] == other[i])
    ).contains(false);
  }

  bool match(SudokuBuffer other) {
    assert(this.length == other.length);
    return !Iterable<bool>.generate(this.length, (i) => (
      this[i] == 0 || this[i] == other[i]
    )).contains(false);
  }

  SudokuBuffer clone() {
    return SudokuBuffer(this.length)..setBuffer(this.getBuffer());
  }
}

