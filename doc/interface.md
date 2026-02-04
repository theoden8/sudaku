# User Interface

## Screens

### Menu Screen
Entry point to the application featuring a playful, game-like design:

**Main Screen**:
- Animated 3×3 grid logo with subtle pulse effect
- Gradient PLAY button (purple-blue) with play icon
- "Tap to begin" hint text
- Decorative background grids (rotated, semi-transparent)
- Theme toggle button in app bar

**Size Selection Dialog**:
- Three colorful gradient cards for grid sizes:
  - **4×4 (Easy)**: Green gradient - beginner friendly
  - **9×9 (Classic)**: Blue gradient - standard sudoku
  - **16×16 (Challenge)**: Purple gradient - advanced
- Each card shows:
  - Mini grid preview (white lines on gradient)
  - Size label (e.g., "9×9")
  - Difficulty label
  - Check mark when selected
- Animated selection effects (scale, border, shadow)
- START button appears when a size is selected

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

## Animations

### Menu Screen Animations
- **Pulse effect**: Logo and PLAY button gently pulse using `AnimationController` with `CurvedAnimation`
- **Card selection**: `AnimatedContainer` for smooth scale, border, and shadow transitions (200ms)
- **START button**: `AnimatedOpacity` and `AnimatedSlide` for fade-in and slide-up when visible

### Transitions
- **Navigation**: Standard Material page transitions
- **Dialog**: `showDialog` with default Material animation
- **Theme change**: Smooth color transitions via Flutter's theme animation

## Responsive Layout System

The interface adapts to all screen sizes and orientations using Flutter's `LayoutBuilder` and responsive techniques.

### Layout Strategies

**Portrait Mode**:
- Content stacked vertically
- Grid/cards take most of height
- Controls below main content
- Scrollable if content exceeds screen

**Landscape Mode**:
- Content arranged horizontally
- Grid/cards on left, controls on right
- `FittedBox` scales content to fit width
- Centered with automatic scaling

### Overflow Prevention

Multiple techniques ensure no content overflows:

1. **FittedBox with scaleDown**: Cards and buttons scale down proportionally when space is limited
2. **ConstrainedBox**: Maximum dimensions prevent elements from growing too large
3. **Responsive sizing**: Dimensions calculated as percentages of available space with min/max bounds
4. **ListView fallback**: Portrait mode switches to scrollable list when cards don't fit

### Screen-Specific Adaptations

**Menu Screen**:
- Logo and button sizes scale with `shortestSide`
- Maximum sizes prevent oversized elements on tablets
- Decoration grids scale and stay partially off-screen

**Size Selection**:
- Card size: `max(120, min(availableHeight * 0.7, availableWidth / 3.5))`
- Portrait: Vertical column or scrollable ListView
- Landscape: Horizontal row wrapped in `FittedBox`
- START button: Responsive height and width with scaling content

**Sudoku Screen**:
- Grid size: `min(availableWidth, availableHeight * 0.7)` in portrait
- Secondary content fills remaining space via `Expanded`
- Grid centered in both orientations

**Numpad Screen**:
- Grid size adapts to leave room for action button
- Portrait: Grid above, button below
- Landscape: Grid left, button right

**Assistant Screen**:
- `ConstrainedBox` limits width to 600px for readability
- Centered on wide screens, full width on narrow screens

## Accessibility

- High contrast modes
- Clear visual hierarchy
- Large touch targets for cell selection
- Color-blind friendly palette options
- Responsive layout for different screen sizes
- Minimum touch target sizes maintained even on small screens

## Performance

- Efficient rendering of large 16×16 grids
- Smooth constraint propagation without lag
- Responsive touch interactions
- Minimal battery usage

## Test Coverage

The interface layer has widget tests in `test/widget/tutorial_test.dart` and integration tests in `integration_test/interaction_flow_test.dart`.

### Widget Tests (implemented)
- Menu screen displays Play button
- Menu screen Play button is tappable and shows size selection
- Size selection shows 2, 3, 4 options
- Selecting size shows play FAB
- Theme toggle button exists on menu

### Responsive Layout Tests (implemented)
- Menu screen adapts to portrait orientation
- Menu screen adapts to landscape orientation
- Size selection adapts to small screen
- Size selection adapts to tablet size

### Integration Tests (implemented)
- Full flow: Menu -> Size Selection -> Sudoku Screen
- Skip tutorial and view constraint list
- Cell selection and numpad interaction
- Undo button functionality
- Theme toggle works on Sudoku screen
- Drawer opens with constraint options
- Menu button in toolbar shows options
- Assistant settings screen accessible
- App works in portrait and landscape orientations

### Tutorial Flow
The tutorial is a multi-stage guided workflow:
- **Stage 0**: Help button visible, tap to start tutorial, long-press to skip
- **Stage 1**: Multi-selection mode - user selects highlighted cells
- **Stage 2**: Open drawer and select "All different" constraint
- **Stage 3**: Tutorial completion with explanation

Tutorial tests require the full app with assets loaded and are covered in integration tests.
