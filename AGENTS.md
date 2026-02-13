# AGENTS.md

Instructions for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

Sudaku is a constraint-based Sudoku **assistant** (not solver). Users control solving strategy while the app handles constraint propagation. Supports 4x4, 9x9, and 16x16 puzzles.

## Build Commands

This project uses **FVM (Flutter Version Manager)**. Always prefix flutter commands with `fvm`:

```bash
# Setup
fvm flutter pub get --enforce-lockfile

# Run all tests
fvm flutter test

# Run single test file
fvm flutter test test/sudoku_test.dart

# Run single test by name
fvm flutter test --name "test name pattern"

# Lint/analyze
fvm flutter analyze

# Run app
fvm flutter run

# Build
fvm flutter build apk --release --flavor fdroid    # Android
fvm flutter build linux --release                   # Linux
fvm flutter build macos --release                   # macOS
fvm flutter build ios --release --no-codesign      # iOS

# FFI integration tests (Linux only, requires xvfb)
xvfb-run fvm flutter test integration_test/ffi_test.dart -d linux
```

## Project Structure

```
lib/                    # Main source files
  Sudoku.dart           # Core puzzle state, change history, undo/redo
  SudokuDomain.dart     # Domain representation (BitArray per cell)
  SudokuAssist.dart     # Constraint system: OneOf, Equal, AllDiff
  SudokuBuffer.dart     # Puzzle state snapshots for conditions
  sudoku_native.dart    # FFI wrapper for native solver

test/                   # Unit tests (sudoku_test.dart, sudoku_assist_test.dart, etc.)
integration_test/       # FFI/native code tests
native/                 # C implementation of Algorithm X (difficulty calc only)
```

## Code Style Guidelines

### Import Ordering

Order imports in these groups, separated by blank lines:
1. `dart:` core libraries (dart:math, dart:async)
2. `package:flutter/` Flutter SDK
3. `package:` third-party packages (bit_array, shared_preferences)
4. Local imports (relative paths)

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:bit_array/bit_array.dart';

import 'SudokuBuffer.dart';
```

### Naming Conventions

| Type | Convention | Examples |
|------|------------|----------|
| Classes | PascalCase | `SudokuChange`, `ConstraintOneOf` |
| Files | PascalCase matching class | `SudokuAssist.dart` |
| Methods/variables | camelCase | `getTotalDomain`, `currentCondition` |
| Private members | underscore prefix | `_mutex`, `_statuses` |
| Constants | SCREAMING_SNAKE_CASE | `NOT_RUN`, `SUCCESS` |
| Enum values | SCREAMING_SNAKE_CASE | `ConstraintType.ONE_OF` |

### Type Annotations

- Explicit types on class fields: `late BitArray hints;`
- Explicit function return types: `BitArray getDomain(int variable)`
- Explicit generic types: `List<SudokuChange>`, `Map<int, List<int>>`
- `var` allowed for local variables when type is obvious

### Formatting

- Use `late` for late-initialized non-nullable fields
- Named parameters with `required`: `required int variable`
- Explicit `this.` for member access (consistent with codebase)
- Sync generators (`sync*`) for custom iterators

### Error Handling

- `assert()` for internal invariants and dev checks
- Try-catch with fallbacks for FFI/external operations
- Null safety with `??` and `?` operators
- Guard clauses with early returns
- Debug output: `if (kDebugMode) print('message')`

## Constraint System

Three constraint types filter cell domains:
- **AllDiff**: Selected cells must have different values
- **OneOf**: Selected cells contain exactly one occurrence of specified values
- **Equal**: Selected cells must have the same value

Status constants: `NOT_RUN` (-2), `SUCCESS` (1), `INSUFFICIENT` (0), `VIOLATED` (-1)

## Testing Patterns

```dart
group('Feature Name', () {
  late Sudoku sd;

  setUp(() {
    sd = Sudoku.demo(3, puzzle, () {});
  });

  test('descriptive test name explaining expected behavior', () {
    sd.assist.autoComplete = true;
    sd.assist.apply();
    expect(sd.buf[9], equals(7),
        reason: 'Explanation of why this should be true');
  });
});
```

### Assertion Style
- Use `expect()` with matchers: `equals()`, `isTrue`, `isFalse`, `isEmpty`
- Include `reason:` for complex assertions
- Use `SharedPreferences.setMockInitialValues({})` for persistence tests

## Key Concepts

- **Domains**: Each cell tracks possible values via BitArray. Constraints narrow domains.
- **Manual vs Assisted changes**: Manual = user input, Assisted = constraint inferences
- **Constraint conditions**: Constraints can be conditional on specific board states
- **Rollback**: Full undo/redo support including constraint effects

## Linting

Uses `package:flutter_lints/flutter.yaml`. Run `fvm flutter analyze` before committing.

## CI/CD

GitHub Actions on push/PR to master: validates metadata, runs tests, builds for Android/Linux/iOS/macOS, runs FFI integration tests.
