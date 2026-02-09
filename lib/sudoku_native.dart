import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// FFI type definitions
typedef SdGenerateNative = Int32 Function(
    Pointer<Uint8> outTable, Int32 n, Uint32 seed, Float difficulty, Int32 timeoutMs);
typedef SdGenerate = int Function(
    Pointer<Uint8> outTable, int n, int seed, double difficulty, int timeoutMs);

typedef SdSolveNative = Int32 Function(Pointer<Uint8> table, Int32 n);
typedef SdSolve = int Function(Pointer<Uint8> table, int n);

typedef SdDifficultyNative = Int32 Function(
    Pointer<Uint8> table,
    Int32 n,
    Int32 numSamples,
    Uint32 seed,
    Pointer<Int32> outMinFwd,
    Pointer<Int32> outMaxFwd,
    Pointer<Int32> outAvgFwd,
    Pointer<Int32> outMinBt,
    Pointer<Int32> outMaxBt,
    Pointer<Int32> outAvgBt);
typedef SdDifficulty = int Function(
    Pointer<Uint8> table,
    int n,
    int numSamples,
    int seed,
    Pointer<Int32> outMinFwd,
    Pointer<Int32> outMaxFwd,
    Pointer<Int32> outAvgFwd,
    Pointer<Int32> outMinBt,
    Pointer<Int32> outMaxBt,
    Pointer<Int32> outAvgBt);

/// Native sudoku library wrapper
class SudokuNative {
  static DynamicLibrary? _lib;
  static SdGenerate? _generate;
  static SdSolve? _solve;
  static SdDifficulty? _difficulty;

  /// Load the native library
  static void _ensureLoaded() {
    if (_lib != null) return;

    String libName;
    if (Platform.isAndroid || Platform.isLinux) {
      libName = 'libsudoku_native.so';
    } else if (Platform.isIOS || Platform.isMacOS) {
      libName = 'sudoku_native.framework/sudoku_native';
    } else {
      throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
    }

    _lib = DynamicLibrary.open(libName);

    _generate = _lib!.lookupFunction<SdGenerateNative, SdGenerate>('sd_generate');
    _solve = _lib!.lookupFunction<SdSolveNative, SdSolve>('sd_solve');
    _difficulty = _lib!.lookupFunction<SdDifficultyNative, SdDifficulty>('sd_difficulty');
  }

  /// Generate a new puzzle
  ///
  /// [n] - box size (2 for 4x4, 3 for 9x9, 4 for 16x16)
  /// [seed] - random seed (0 for time-based)
  /// [difficulty] - 0.0 = easy (many hints), 1.0 = hard (fully reduced)
  /// [timeoutMs] - timeout in milliseconds (0 = no limit)
  ///
  /// Returns the puzzle as a flat list of integers (0 = empty)
  static List<int> generate({
    required int n,
    int seed = 0,
    double difficulty = 1.0,
    int timeoutMs = 5000,
  }) {
    _ensureLoaded();

    final ne4 = n * n * n * n;
    final tablePtr = calloc<Uint8>(ne4);

    try {
      _generate!(tablePtr, n, seed, difficulty, timeoutMs);
      return tablePtr.asTypedList(ne4).toList();
    } finally {
      calloc.free(tablePtr);
    }
  }

  /// Solve a puzzle in-place
  ///
  /// Returns: 0 = INVALID, 1 = COMPLETE, 2 = MULTIPLE
  static int solve(List<int> table, int n) {
    _ensureLoaded();

    final ne4 = n * n * n * n;
    if (table.length != ne4) {
      throw ArgumentError('Table length must be $ne4 for n=$n');
    }

    final tablePtr = calloc<Uint8>(ne4);
    try {
      for (int i = 0; i < ne4; i++) {
        tablePtr[i] = table[i];
      }

      final result = _solve!(tablePtr, n);

      if (result == 1) {
        // COMPLETE - copy solution back
        for (int i = 0; i < ne4; i++) {
          table[i] = tablePtr[i];
        }
      }

      return result;
    } finally {
      calloc.free(tablePtr);
    }
  }

  /// Compute a hash seed from puzzle content for deterministic results
  static int _hashPuzzle(List<int> table) {
    // Simple hash combining all values
    int hash = 0x811c9dc5; // FNV-1a offset basis
    for (final val in table) {
      hash ^= val;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV-1a prime
    }
    return hash;
  }

  /// Estimate puzzle difficulty
  ///
  /// Returns a map with min/max/avg forwards and backtracks
  /// Uses a hash of the solved puzzle as seed for deterministic results
  static Map<String, int>? estimateDifficulty(List<int> table, int n, {int numSamples = 25}) {
    _ensureLoaded();

    final ne4 = n * n * n * n;
    if (table.length != ne4) {
      throw ArgumentError('Table length must be $ne4 for n=$n');
    }

    // First solve the puzzle to get the complete solution for hashing
    final solvedCopy = List<int>.from(table);
    final solveResult = solve(solvedCopy, n);
    if (solveResult != 1) {
      return null; // Invalid puzzle
    }

    // Hash the solved puzzle for deterministic seeding
    // Ensure seed is never 0 (native code uses time-based seed if 0)
    final seed = _hashPuzzle(solvedCopy) | 1;

    final tablePtr = calloc<Uint8>(ne4);
    final minFwdPtr = calloc<Int32>(1);
    final maxFwdPtr = calloc<Int32>(1);
    final avgFwdPtr = calloc<Int32>(1);
    final minBtPtr = calloc<Int32>(1);
    final maxBtPtr = calloc<Int32>(1);
    final avgBtPtr = calloc<Int32>(1);

    try {
      for (int i = 0; i < ne4; i++) {
        tablePtr[i] = table[i];
      }

      final result = _difficulty!(
        tablePtr, n, numSamples, seed,
        minFwdPtr, maxFwdPtr, avgFwdPtr,
        minBtPtr, maxBtPtr, avgBtPtr,
      );

      if (result == 0) {
        return null; // Invalid or multiple solutions
      }

      return {
        'minForwards': minFwdPtr.value,
        'maxForwards': maxFwdPtr.value,
        'avgForwards': avgFwdPtr.value,
        'minBacktracks': minBtPtr.value,
        'maxBacktracks': maxBtPtr.value,
        'avgBacktracks': avgBtPtr.value,
      };
    } finally {
      calloc.free(tablePtr);
      calloc.free(minFwdPtr);
      calloc.free(maxFwdPtr);
      calloc.free(avgFwdPtr);
      calloc.free(minBtPtr);
      calloc.free(maxBtPtr);
      calloc.free(avgBtPtr);
    }
  }

  /// Check if a puzzle is solvable using only basic techniques (naked/hidden singles).
  ///
  /// These are the techniques used by the assistant's "default constraints" feature.
  /// Returns true if the puzzle can be completely solved with these basic techniques,
  /// meaning the puzzle is considered "trivial" for the assistant.
  ///
  /// [table] - puzzle buffer (0 = empty cell)
  /// [n] - box dimension (2=4x4, 3=9x9, 4=16x16)
  static bool isSolvableWithBasicTechniques(List<int> table, int n) {
    final ne2 = n * n;
    final ne4 = ne2 * ne2;

    if (table.length != ne4) {
      throw ArgumentError('Table length must be $ne4 for n=$n');
    }

    // Work on a copy
    final buffer = List<int>.from(table);

    // Initialize domains: each empty cell can have values 1..ne2
    // domains[i] is a Set<int> of possible values for cell i
    final domains = List<Set<int>>.generate(ne4, (i) {
      if (buffer[i] != 0) {
        return <int>{}; // Filled cells have empty domain
      }
      return Set<int>.from(List.generate(ne2, (v) => v + 1));
    });

    // Helper to get row/col/box indices
    Iterable<int> iterateRow(int row) sync* {
      for (int c = 0; c < ne2; c++) yield row * ne2 + c;
    }

    Iterable<int> iterateCol(int col) sync* {
      for (int r = 0; r < ne2; r++) yield r * ne2 + col;
    }

    Iterable<int> iterateBox(int box) sync* {
      final boxRow = (box ~/ n) * n;
      final boxCol = (box % n) * n;
      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          yield (boxRow + r) * ne2 + (boxCol + c);
        }
      }
    }

    // Remove assigned values from domains in same row/col/box
    void propagateConstraints() {
      for (int i = 0; i < ne4; i++) {
        if (buffer[i] != 0) {
          final val = buffer[i];
          final row = i ~/ ne2;
          final col = i % ne2;
          final box = (row ~/ n) * n + (col ~/ n);

          for (final j in iterateRow(row)) domains[j].remove(val);
          for (final j in iterateCol(col)) domains[j].remove(val);
          for (final j in iterateBox(box)) domains[j].remove(val);
        }
      }
    }

    // Initial propagation
    propagateConstraints();

    // Iterate until no more progress
    bool progress = true;
    while (progress) {
      progress = false;

      // Naked single: cell with only one possible value
      for (int i = 0; i < ne4; i++) {
        if (buffer[i] == 0 && domains[i].length == 1) {
          buffer[i] = domains[i].first;
          domains[i].clear();
          propagateConstraints();
          progress = true;
        }
      }

      // Hidden single: value can only go in one cell within row/col/box
      for (int unit = 0; unit < ne2; unit++) {
        for (final line in [iterateRow(unit), iterateCol(unit), iterateBox(unit)]) {
          final cells = line.toList();
          for (int val = 1; val <= ne2; val++) {
            // Find cells where this value is possible
            final candidates = cells.where((i) => buffer[i] == 0 && domains[i].contains(val)).toList();
            if (candidates.length == 1) {
              final i = candidates.first;
              buffer[i] = val;
              domains[i].clear();
              propagateConstraints();
              progress = true;
            }
          }
        }
      }
    }

    // Check if puzzle is completely solved
    return buffer.every((v) => v != 0);
  }
}
