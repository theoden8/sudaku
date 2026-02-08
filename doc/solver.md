# Native Solver Library

Sudaku includes a native C library (`sudoku_native`) that provides puzzle generation, solving, and difficulty estimation. The library uses FFI (Foreign Function Interface) to communicate between Dart/Flutter and the native code.

## Features

### Puzzle Generation

Generate puzzles with configurable parameters:

```dart
SudokuNative.generate(
  n: 3,              // Grid dimension (2=4x4, 3=9x9, 4=16x16)
  seed: 12345,       // Random seed for reproducibility
  difficulty: 0.7,   // 0.0=easy (more hints), 1.0=hard (fewer hints)
  timeoutMs: 5000,   // Timeout in milliseconds
);
```

The difficulty parameter controls hint count:
- `0.0`: Maximum hints (easy puzzles)
- `1.0`: Minimum hints (hard puzzles)
- Same seed + difficulty always produces identical puzzles

### Puzzle Solving

Solve a puzzle in-place:

```dart
final result = SudokuNative.solve(puzzle, n);
// Returns: 0=INCOMPLETE, 1=COMPLETE, -1=CONTRADICTION
```

### Difficulty Estimation

Estimate puzzle difficulty using statistical sampling:

```dart
final stats = SudokuNative.estimateDifficulty(
  puzzleBuffer,      // Current puzzle state
  n,                 // Grid dimension
  numSamples: 25,    // Number of solving attempts
);
// Returns: {'minForwards', 'maxForwards', 'avgForwards'}
```

The solver counts "forwards" - the number of forward steps required to solve. More forwards = harder puzzle.

## Difficulty Normalization

Raw forwards counts are converted to a 0.0-1.0 scale using logarithmic normalization:

| Normalized Range | Label | Typical Forwards |
|-----------------|-------|------------------|
| 0.00 - 0.15 | Easy | ~300-500 |
| 0.15 - 0.35 | Medium | ~500-2,000 |
| 0.35 - 0.55 | Hard | ~2,000-10,000 |
| 0.55 - 0.75 | Expert | ~10,000-100,000 |
| 0.75 - 1.00 | Extreme | ~100,000-600,000 |

Reference values:
- Minimum: ~324 (trivial 9x9, log2 ≈ 8.3)
- Maximum: ~600,000 (hardest top44 16x16, log2 ≈ 19.2)

Formula:
```
normalized = (log2(forwards) - 8.3) / (19.2 - 8.3)
```

## Platform Support

The native library is available on:
- Linux (x64)
- Android (arm64-v8a, armeabi-v7a, x86_64)
- macOS (arm64, x86_64)
- iOS (arm64)

On platforms without native support, difficulty estimation returns `null` and puzzles are loaded from asset files instead.

## Integration Points

### App Bar Difficulty Badge

When enabled in Assistant settings, the difficulty badge appears next to the title:
- Shows difficulty label (Easy/Medium/Hard/Expert/Extreme)
- Or exact forwards count if "Show exact numbers" is enabled
- Updates live if "Live difficulty" is enabled

### Victory Dialog

Shows the puzzle's difficulty when completed.

### Trophy Room

Each puzzle card displays its difficulty level. Difficulty is computed on first load for puzzles that predate the feature.

### Menu Screen

9x9 and 16x16 grid sizes show a difficulty selector with 5 levels, which maps to the native generator's difficulty parameter.

## Testing

FFI integration tests run on Linux CI:
```bash
xvfb-run fvm flutter test integration_test/ffi_test.dart -d linux
```

Tests verify:
- Puzzle generation for all sizes
- Solving correctness
- Difficulty estimation determinism
- Seed reproducibility
