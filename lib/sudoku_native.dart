import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'SudokuAssist.dart';

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
  /// [trivialAllowed] - if false and puzzle is solvable with basic techniques, returns null
  ///
  /// Returns the puzzle as a flat list of integers (0 = empty), or null if
  /// trivialAllowed is false and the puzzle is trivially solvable.
  static List<int>? generate({
    required int n,
    int seed = 0,
    double difficulty = 1.0,
    int timeoutMs = 5000,
    bool trivialAllowed = true,
  }) {
    _ensureLoaded();

    final ne4 = n * n * n * n;
    final tablePtr = calloc<Uint8>(ne4);

    try {
      _generate!(tablePtr, n, seed, difficulty, timeoutMs);
      final puzzle = tablePtr.asTypedList(ne4).toList();

      // Check if puzzle is trivially solvable when not allowed
      if (!trivialAllowed && SudokuAssist.isTriviallyAutoSolvable(puzzle, n)) {
        return null;
      }

      return puzzle;
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

}
