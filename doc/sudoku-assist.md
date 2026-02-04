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

## Test Coverage

The Sudoku Assist layer is tested in `test/sudoku_assist_test.dart` with the following scenarios:

### ConstraintType Enum
- All four types exist: ONE_OF, EQUAL, ALLDIFF, GENERIC

### Constraint Status Constants
- NOT_RUN = -2
- SUCCESS = 1
- INSUFFICIENT = 0
- VIOLATED = -1
- All status values are distinct

### Common Row Detection
- Cells in same row return that row index
  - Cells [0, 1, 2] → row 0
  - Cells [72, 73, 74] → row 8
- Cells in different rows return -1
- Single cell returns its row
- Empty list returns -1

### Common Column Detection
- Cells in same column return that column index
  - Cells [0, 9, 18] → column 0
  - Cells [8, 17, 26] → column 8
- Cells in different columns return -1
- Single cell returns its column

### Common Box Detection
- Cells in same box return that box index
  - Cells [0, 1, 10] → box 0
  - Cells [30, 31, 39, 40] → box 4
  - Cells [60, 70, 80] → box 8
- Cells in different boxes return -1
- Single cell returns its box

### Domain BitArray Operations
- Create empty domain (cardinality 0)
- Create full domain with values 1-9 (cardinality 9, bit 0 false)
- Remove value from domain via clearBit
- Single value domain (cardinality 1)
- Domain intersection removes non-common values
- Domain union combines values from both

### AllDiff Constraint Logic
- Assigned values reduce other cells' domains
  - If cell has value 5, other cells exclude 5
- Valid assignment: all values different
- Invalid assignment: duplicate values detected

### OneOf Constraint Logic
- Identifies unique cell for a value
  - Domains: cell 0 = {1,2}, cell 1 = {2,3}, cell 2 = {3}
  - Value 1 can only go in cell 0
  - Value 2 has multiple options → returns -1
- No valid cell returns -1

### Equal Constraint Logic
- Common domain is intersection of all domains
  - {1,2,3,4,5} ∩ {3,4,5,6,7} ∩ {4,5,6,7,8} = {4,5}
- No common values indicates violation (empty result)
- Single common value succeeds

### Domain Filtering
- Filtering removes eliminated values
  - Full domain {1-9} minus {1,2,3} = {4,5,6,7,8,9}
- Cascading constraints narrow domain
  - Row removes {1,2,3}, column removes {4,5}, box removes {6}
  - Final domain: {7,8,9}

### Condition Matching
- Buffer matches pattern with wildcards (0 = wildcard)
  - Pattern [1,0,0,0,5,0,0,0,9] matches [1,2,3,4,5,6,7,8,9]
  - Pattern [1,...] does not match [2,...]
- Exact state matches itself

### Constraint Activation
- Constraint active by default
- Deactivated constraint is not active
- Reactivated constraint is active

### Domain Cardinality Tracking
- Empty domain: cardinality 0
- Full domain (1-9): cardinality 9
- Single value: cardinality 1
- Partial domain: correct count after removals

### Value Assignment Inference
- Single value domain can be assigned (cardinality == 1)
- Multiple values cannot be auto-assigned
- Empty domain indicates constraint violation

### Row/Column/Box Iteration Indices
- Row indices are consecutive (stride 1)
- Column indices have stride ne2 (9 for 9×9)
- Box indices form correct 3×3 patterns

### Constraint Status History
- Empty status history returns NOT_RUN
- Status history tracks multiple applications
- lastStatus returns second-to-last status

### Constraint Retract/Rollback
- Retract removes last status when age matches
- Retract does nothing when age mismatch
- Retract on empty status list does nothing
- Success streaks track successful condition applications
- Retract removes success streak when appropriate
- Retract only removes status at matching age

### Eliminator Rollback
- Reinstate clears eliminated values from forbidden list
- Obsolete conditions are removed when empty

### Multi-Step Constraint Rollback
- Multiple constraints retract in sequence
- Domain filtering rollback restores original domain
- Success streak history tracks and retracts correctly
- AllDiff rollback restores eliminated values
- Constraint cascade rollback
- Full solving step undo with domain restoration

### Constraint Enable/Disable with Rollback
- Disabled constraint does not affect domain during rollback
- Enable constraint after rollback applies new eliminations
- Toggle constraint active state during multi-step rollback

### Add/Remove Constraint with Rollback
- Added constraint can be removed during rollback
- Removed constraint is restored during rollback
- Constraint modifications tracked through rollback
- Default constraints behavior with rollback
- User constraint added then disabled before rollback

### Complex Rollback Scenarios
- Rollback with mixed default and user constraints
- Multiple constraint enable/disable cycles with rollback

### Multi-Step Redo
- Redo domain eliminations in sequence
- Redo constraint status history
- Redo constraint enable/disable with domain state
- Redo with interleaved undo operations
- Redo clears when new constraint applied
- Redo success streaks correctly

### Constraint Cancellation Rollback
- Adding and canceling bogus constraint restores original state
  - Bogus EQUAL constraint causes assisted changes
  - Removing constraint clears all its assisted changes
  - Manual values preserved through cancellation
- Canceling one constraint preserves effects of other constraints
  - Multiple active constraints with different effects
  - Removing one constraint clears only its effects
  - Other constraint effects remain intact
- Constraint status resets when constraint is removed and re-added
  - New constraint starts with NOT_RUN status
  - Empty status history on re-add
- Domain filtering is recalculated after constraint cancellation
  - Canceled constraint's domain filters are undone
  - Other constraints' filters still applied
- Chained inferences are cleared when root constraint is canceled
  - Constraint A infers value, Constraint B depends on it
  - Canceling A clears both A's and B's inferences
- Eliminations from canceled constraint are reinstated
  - Values eliminated by canceled constraint restored to domain
  - Eliminations from other constraints preserved
