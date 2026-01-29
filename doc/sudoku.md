# Sudoku

## Overview

Sudaku supports classic Sudoku puzzles in two variants:
- **9×9 puzzles** (3×3 boxes) - Standard Sudoku
- **16×16 puzzles** (4×4 boxes) - Extended Sudoku

## Rules

The fundamental rule of Sudoku is simple:
- Each row must contain all numbers (1-9 for 9×9, 1-16 for 16×16)
- Each column must contain all numbers
- Each box must contain all numbers

## Puzzle Structure

### Grid Organization
- **Cells**: Individual squares in the grid (81 for 9×9, 256 for 16×16)
- **Rows**: Horizontal lines of cells
- **Columns**: Vertical lines of cells
- **Boxes**: Square regions (3×3 or 4×4) that partition the grid

### Cell States
- **Hints**: Cells provided with the puzzle (shown as given clues)
- **Filled**: Cells where the user has entered a value
- **Empty**: Cells that still need to be solved

## Puzzle Database

Sudaku includes curated datasets of challenging puzzles:
- **top1465**: 1465 hard 9×9 puzzles
- **topn87**: 87 hardest 9×9 puzzles
- **top44**: 44 hard 16×16 puzzles

New puzzles are loaded randomly from these datasets when starting a game.

## Domain Representation

Internally, each cell has a "domain" - the set of possible values it can take:
- Initially, empty cells have all numbers in their domain
- As constraints are applied, domains shrink
- When a domain has only one value, the cell can be filled
- If a domain becomes empty, a contradiction has occurred

## Test Coverage

The Sudoku layer is tested in `test/sudoku_test.dart` with the following scenarios:

### Grid Structure
- SudokuBuffer initializes with correct size for 9×9 (81 cells)
- SudokuBuffer initializes with correct size for 16×16 (256 cells)
- All cells initialize to 0 (empty)

### Coordinate Conversion
- Index to row conversion (e.g., index 17 → row 1)
- Index to column conversion (e.g., index 17 → column 8)
- Index to box conversion (e.g., index 40 → box 4)
- Row and column to index conversion (e.g., row 1, col 0 → index 9)

### Row Iteration
- Iterate row generates correct consecutive indices
- Row 0: [0, 1, 2, 3, 4, 5, 6, 7, 8]
- Row 8: [72, 73, 74, 75, 76, 77, 78, 79, 80]
- All rows together cover all 81 cells exactly once

### Column Iteration
- Iterate column generates correct indices with stride 9
- Column 0: [0, 9, 18, 27, 36, 45, 54, 63, 72]
- Column 8: [8, 17, 26, 35, 44, 53, 62, 71, 80]
- All columns together cover all 81 cells exactly once

### Box Iteration
- Iterate box generates correct 3×3 grid indices
- Box 0: [0, 1, 2, 9, 10, 11, 18, 19, 20]
- Box 4: [30, 31, 32, 39, 40, 41, 48, 49, 50]
- Box 8: [60, 61, 62, 69, 70, 71, 78, 79, 80]
- All boxes together cover all 81 cells exactly once

### Domain Operations (BitArray)
- Empty domain has no bits set
- Full domain has values 1-9 (bit 0 excluded)
- Domain intersection: {1,2,3,4,5} ∩ {3,4,5,6,7} = {3,4,5}
- Domain union: {1,2,3} ∪ {3,4,5} = {1,2,3,4,5}

### SudokuBuffer Operations
- Buffer initializes with correct size
- Values can be set and retrieved via indexing
- Buffer can be set from a list
- Pattern matching with wildcards (0 = wildcard)

### Change Tracking
- SudokuChange records variable index, value, and previous value
- Manual and assisted changes are distinguished by flag

### Puzzle Validation
- Duplicate detection in rows (values 1-9 valid, duplicate 5 invalid)
- Empty cells (0) do not violate constraints

### Undo/Rollback
- undoLastChange restores previous value
- undoChange skips assisted changes until manual change
- Multiple undo operations work correctly
- Undo on empty changes list does nothing
- findPrecedingValue returns correct value from history
- Undo preserves changes for other variables

### Multi-Step Rollback
- Full undo sequence restores initial state
- Interleaved manual and assisted changes undo correctly
- Undo and redo simulation with change replay
- Overwrite same cell multiple times then undo
- Partial undo leaves valid intermediate state
- Undo with assisted inference chain
