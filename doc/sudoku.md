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
