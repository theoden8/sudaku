# User Interface

## Screens

### Menu Screen
Entry point to the application with options:
- Start new puzzle (9×9 or 16×16)
- Resume previous session
- Settings and preferences
- Theme selection (light/dark mode)

### Sudoku Screen
Main puzzle-solving interface displaying:
- The Sudoku grid with hints and filled cells
- Selected cell highlighting
- Domain information for cells
- Active constraints visualization
- Status indicators

### Sudoku Assist Screen
Constraint management interface for:
- Creating new constraints
- Viewing active constraints
- Setting constraint conditions
- Enabling/disabling constraints
- Viewing constraint status and history

### Numpad Screen
Input interface for entering values into cells

## Visual Elements

### Cell Display
- **Hints**: Pre-filled values (shown distinctly from user entries)
- **Filled cells**: User-entered values
- **Inferred values**: Values suggested by constraints (shown in special color)
- **Empty cells**: Blank cells awaiting input
- **Cell hints**: Small numbers showing remaining domain values

### Color Coding

Different constraint types and states are color-coded:

**Light Theme**:
- Blue: General highlights and navigation
- Green: OneOf constraints and success states
- Purple: Equal constraints
- Cyan: AllDiff constraints
- Yellow: Warnings and pending actions
- Red: Violations and errors

**Dark Theme**: Adapted colors optimized for dark backgrounds

### Cell Selection
- Single tap: Select a cell
- Multiple selection: Select multiple cells for constraint creation
- Selected cells are highlighted
- Common row/column/box relationships shown

## Interaction Patterns

### Basic Input
1. Tap a cell to select it
2. Enter a value using the numpad
3. Value fills the cell and domains update
4. Constraints propagate automatically

### Creating Constraints
1. Select multiple cells (tap each cell)
2. Open the Assist screen
3. Choose constraint type (AllDiff, OneOf, Equal)
4. Set conditions (optional)
5. Activate constraint
6. Return to main screen to see effects

### Managing Constraints
- View list of all constraints in Assist screen
- Each constraint shows:
  - Type and affected cells
  - Current status (active/inactive, success/violated)
  - Age (how long ago it was applied)
  - History of applications
- Toggle constraints on/off
- Delete constraints no longer needed

### Domain Visualization
- Tap a cell to see its current domain
- Small hint numbers show remaining possibilities
- Color intensity may indicate domain size
- Inferred values (domain of size 1) shown prominently

### Undo/Redo
- Change history tracked
- Can undo both manual and assisted changes
- History shows what changed and why (manual vs assisted)

## Themes

### Light Theme
Clean, high-contrast interface with:
- White/light backgrounds
- Black text
- Pastel colors for constraints
- Clear cell boundaries

### Dark Theme
Eye-friendly dark interface with:
- Dark gray backgrounds
- Light gray text
- Muted but distinct colors for constraints
- Reduced eye strain for extended solving sessions

### Theme Switching
- Automatic: Follows system theme preference
- Manual: User can override system setting
- Smooth transitions between themes
- Colors remain semantically consistent

## Accessibility

- High contrast modes
- Clear visual hierarchy
- Large touch targets for cell selection
- Color-blind friendly palette options
- Responsive layout for different screen sizes

## Performance

- Efficient rendering of large 16×16 grids
- Smooth constraint propagation without lag
- Responsive touch interactions
- Minimal battery usage
