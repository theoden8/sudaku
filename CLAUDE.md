# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sudaku is a constraint-based Sudoku **assistant**, not a solver. Users remain in full control of solving strategy while the app automates mechanical bookkeeping through constraint propagation. The app supports 4×4, 9×9, and 16×16 puzzles.

## Build Commands

This project uses FVM (Flutter Version Manager). Always prefix flutter commands with `fvm`:

```bash
# Setup
fvm flutter pub get --enforce-lockfile

# Run tests
fvm flutter test                          # All tests
fvm flutter test test/sudoku_test.dart    # Single test file

# Lint
fvm flutter analyze

# Run app
fvm flutter run

# Build
fvm flutter build apk --release --flavor fdroid    # Android
fvm flutter build linux --release                   # Linux
fvm flutter build macos --release                   # macOS

# FFI integration tests (Linux)
xvfb-run fvm flutter test integration_test/ffi_test.dart -d linux
```

## Documentation

**Read `doc/` first** for detailed architecture and feature documentation:
- `sudoku.md` - Core puzzle state and grid operations
- `sudoku-assist.md` - Constraint system (AllDiff, OneOf, Equal), domain filtering, rollback
- `interface.md` - UI screens, themes, responsive layout, tutorial flow
- `persistence.md` - Auto-save and SharedPreferences storage
- `gamification.md` - Trophy room, achievements, puzzle import
- `solver.md` - Native FFI library for puzzle generation and difficulty estimation

## Code Structure

Core logic in `lib/`:
- **Sudoku.dart** - Puzzle state, change history, undo/redo
- **SudokuAssist.dart** - Constraint system with propagation
- **SudokuDomain.dart** - Domain representation using BitArray
- **sudoku_native.dart** - FFI wrapper for native C solver

Native C code in `native/` - Algorithm X (dancing links) for generation/difficulty.

## Maintaining Documentation

When making changes to the codebase, update the relevant `doc/` files and this file to keep documentation in sync with the code.
