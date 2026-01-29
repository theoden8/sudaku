# Sudoku Assist System

## Philosophy

Sudaku is **not a solver**. It doesn't solve puzzles for you or use brute-force search. Instead, it provides a constraint-based assistance system that:
- Executes logical deductions based on rules you specify
- Eliminates values that are mechanically implied by your decisions
- Lets you maintain full control over the solving strategy
- Makes you responsible for your own logic and mistakes

## Constraint System

The assist system works through user-defined constraints that filter cell domains. When you specify constraints, the system propagates their logical consequences automatically.

### Constraint Types

#### AllDiff (All Different)
- Ensures selected cells must contain different values
- Most fundamental constraint in Sudoku
- Applied implicitly to all rows, columns, and boxes
- Can be explicitly added for custom cell groups

**Example**: If you select three cells and apply AllDiff, and two already contain 3 and 7, the third cell's domain will exclude 3 and 7.

#### OneOf (One-Of)
- Specifies that selected cells contain exactly one occurrence of certain values
- Useful for advanced solving techniques

**Example**: If you know cells A, B, C must contain exactly one 5 between them, a OneOf constraint expresses this relationship.

#### Equal
- Forces selected cells to have the same value
- Useful for symmetry-based solving

**Example**: If puzzle symmetry suggests two cells must be equal, this constraint links their domains.

### Constraint Lifecycle

1. **Creation**: User selects cells and chooses constraint type
2. **Condition**: Constraint activates when its preconditions match the current board state
3. **Propagation**: When active, constraint filters domains of involved cells
4. **Status Tracking**:
   - `NOT_RUN`: Constraint hasn't been checked yet
   - `SUCCESS`: Constraint successfully filtered domains
   - `INSUFFICIENT`: Not enough information to apply constraint
   - `VIOLATED`: Constraint contradicts current state (indicates an error)

### Domain Filtering

The core of the assist system is domain filtering:

1. **Initial State**: Empty cells start with full domains (all possible values)
2. **Constraint Application**: Each active constraint removes impossible values
3. **Propagation**: Changes cascade to related cells
4. **Inference**: When a domain reduces to a single value, that value is inferred
5. **User Confirmation**: Inferred values are shown but not automatically filled

### Buffer System

The app maintains a "buffer" representing the current state:
- Tracks which cells are filled and with what values
- Records which values remain possible for each cell
- Conditions can be set to activate constraints only in specific states
- Enables sophisticated solving strategies

## Assisted vs Manual Changes

The system distinguishes between:
- **Manual changes**: Values you explicitly enter
- **Assisted changes**: Values inferred by the constraint system

This distinction helps track:
- The actual "age" of the puzzle (number of manual decisions)
- Which parts of the solution are mechanically derived
- Where your reasoning led vs where the system helped

## Workflow

A typical solving session:

1. Load a puzzle (hints are pre-filled)
2. Make an initial manual move (setting a cell value)
3. Define constraints for cell groups you want to track
4. System propagates constraints and shows inferences
5. Review and accept/reject inferred values
6. Make another manual move
7. Repeat until solved
