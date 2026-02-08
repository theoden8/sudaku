# Gamification

The Trophy Room provides achievements and puzzle tracking to reward player progress.

## Accessing Trophy Room

Tap the trophy icon in the top-right corner of the main menu.

## Features

### Puzzle Difficulty

Puzzle difficulty is estimated using the native solver library. See [solver.md](solver.md) for technical details.

#### Difficulty Levels
| Level | Description |
|-------|-------------|
| Easy | Straightforward puzzles, quick to solve |
| Medium | Moderate challenge |
| Hard | Requires more advanced techniques |
| Expert | Challenging puzzles |
| Extreme | Top-tier difficulty |

#### Difficulty Display
- **App Bar**: Shows difficulty badge next to "SUDOKU" title (can be toggled in Assistant settings)
- **Victory Dialog**: Shows difficulty when you complete a puzzle
- **Trophy Room**: Shows difficulty on each puzzle card in the Puzzles tab

#### Live Difficulty
When enabled in Assistant settings, difficulty updates as you solve the puzzle, showing how hard the remaining puzzle is. This feature is disabled by default as it may affect performance on older devices.

### Completed Puzzles

The Puzzles tab displays all unique puzzles you've completed. Each puzzle shows:
- Mini grid preview with hint positions
- Completion date
- Move count
- Difficulty level (if available)

Actions:
- **Share**: Export puzzle as dot notation (copy to clipboard)
- **Launch**: Replay the puzzle from scratch
- **Delete**: Remove from collection

Duplicate detection prevents the same puzzle from appearing multiple times.

### Achievements

The Achievements tab tracks your progress across various milestones.

#### Completion Achievements
| Achievement | Description |
|-------------|-------------|
| First Steps | Complete your first puzzle |
| Getting Hooked | Complete 10 puzzles |
| Dedicated | Complete 25 puzzles |
| Sudoku Master | Complete 50 puzzles |

#### Size Achievements
| Achievement | Description |
|-------------|-------------|
| Mini Master | Complete a 4x4 puzzle |
| Classic Champion | Complete a 9x9 puzzle |
| Challenge Conqueror | Complete a 16x16 puzzle |
| Size Doesn't Matter | Complete all three sizes |

#### Skill Achievements
| Achievement | Description |
|-------------|-------------|
| Speed Demon | Complete a puzzle in under 2 minutes |
| Constraint Master | Use all 3 constraint types in one puzzle |
| Logic Grandmaster | Complete a 9x9 using only constraints |

Note: "First Steps" requires completing a 9x9 or larger puzzle (4x4 is too easy to count).

#### Difficulty Achievements
| Achievement | Description |
|-------------|-------------|
| Hard Solver | Complete a Hard difficulty puzzle |
| Expert Solver | Complete an Expert difficulty puzzle |
| Extreme Solver | Complete an Extreme difficulty puzzle |

#### Learning Achievements
| Achievement | Description |
|-------------|-------------|
| Quick Learner | Complete the constraint tutorial |

Note: Once the tutorial is completed, the tutorial offer dialog will no longer appear.

### Puzzle Import

Import puzzles using dot notation:
1. Tap the import button (top-right of Puzzles tab)
2. Select grid size (4x4, 9x9, or 16x16)
3. Paste dot notation string
4. Tap Import

#### Dot Notation Format
- `.` represents an empty cell
- `1-9` represent values 1-9
- `A-G` represent values 10-16 (for 16x16 grids)
- Whitespace is ignored

Example 9x9: `..3.2.6..9..3.5..1..18.64....81.29..7.......8..67.82....26.95..8..2.3..9..5.1.3..`

## Data Storage

Trophy Room data is stored locally using SharedPreferences:
- `trophyRoom_puzzleRecords`: Completed puzzles list
- `trophyRoom_achievements`: Achievement unlock states
- `trophyRoom_stats`: Completion counts and solved puzzle IDs

To clear all gamification data on Linux:
```bash
rm -rf ~/.local/share/sudaku/
```

## Duplicate Detection

The system uses content-based IDs to prevent:
- Same puzzle appearing multiple times in Puzzles list
- Same puzzle counting multiple times toward achievements

A puzzle's identity is determined by its hints (positions and values), not by when it was solved.
