# Puzzle State Persistence

The app automatically saves the current puzzle state so users can continue where they left off.

## How it works

1. **Auto-save on changes**: The puzzle state is saved automatically whenever:
   - A cell value changes
   - A constraint is added, removed, or toggled
   - Any assistant-related change occurs

2. **Save on exit**: When the user taps "Exit" from the puzzle screen, the state is explicitly saved before navigating back to the menu.

3. **Resume on launch**: When returning to the menu screen, if a saved puzzle exists, a "CONTINUE" button appears above the "NEW" button.

## Data stored

The following data is persisted using SharedPreferences:

- `n`: Grid size (2, 3, or 4)
- `buffer`: Current cell values (list of integers)
- `hints`: Indices of the original hint cells (immutable cells)

## Implementation details

- **Storage**: Uses `SharedPreferences` with JSON encoding
- **Key**: `savedPuzzle`
- **Debouncing**: Auto-save is debounced to avoid excessive writes (500ms minimum between saves)
- **Cleanup**: Saved state is cleared when the user starts a continued puzzle

## Files involved

- `lib/SudokuScreen.dart`: Save/load/clear methods, auto-save logic
- `lib/MenuScreen.dart`: Load saved state, display Continue button
- `lib/Sudoku.dart`: `Sudoku.fromSaved()` constructor for restoring state
