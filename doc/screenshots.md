# Screenshot Tour

Automated screenshot generation for app store listings and documentation.

## Overview

The screenshot tour uses Flutter integration tests to capture consistent screenshots across all theme and style combinations. Screenshots are saved to the `screenshots/` directory.

## Running the Screenshot Tour

### Using Fastlane (Recommended)

```bash
# Install dependencies (first time only)
bundle install

# Generate and frame screenshots for Android
bundle exec fastlane android_screenshots_framed

# Generate and frame screenshots for iOS
bundle exec fastlane ios_screenshots_framed

# Generate screenshots for both platforms
bundle exec fastlane screenshots_framed_all

# Just add device frames to existing screenshots
bundle exec fastlane android_frame
bundle exec fastlane ios_frame
```

### Manual Run

```bash
# Run on a connected device or emulator
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart

# With custom output directory
SCREENSHOT_DIR=screenshots/android flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart
```

Screenshots are saved to `screenshots/` with naming format:
```
{number}-{screen}-{theme}-{style}.png
```

## Theme/Style Combinations

The tour runs 4 times, once for each combination:
- `light-modern` - Light theme with modern style
- `dark-modern` - Dark theme with modern style
- `light-paper` - Light theme with pen-and-paper style
- `dark-paper` - Dark theme with pen-and-paper style

## Screenshots Captured

### 1. Grid Selection (`01-grid-selection-*.png`)
The size selection screen with 9x9 pre-selected, showing the three grid size options (4x4, 9x9, 16x16).

### 2. Trophy Room (`02-trophy-room-*.png`)
The Trophy Room Achievements tab showcasing gamification features:
- Some achievements unlocked (Quick Learner, Constraint Master, First Steps, Classic Champion, Easy Start)
- Progress bars on achievements in progress (3/10 for Getting Hooked, 3/5 for Easy Going)
- Section headers grouping achievements by category (Learning, Completion, Size, Difficulty tiers)

### 3. Constraint List (`03-constraint-list-*.png`)
The constraint list with the AllDiff constraint selected, highlighting its cells on the grid. Shows all three demo constraints:
- OneOf (green)
- Equal (purple)
- AllDiff (orange) - selected

### 4. Cell Filled (`04-cell-filled-*.png`)
One of the AllDiff constraint cells (cell 29 at row 3, col 2) filled with its correct value (4), demonstrating constraint interaction.

## Demo Puzzle

Uses the first puzzle from the top1465 collection (fixed, not shuffled):
```
4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........
```

Solution:
```
Row 0: 4 6 8 9 3 1 5 2 7
Row 1: 7 5 1 6 2 4 8 3 9
Row 2: 3 9 2 5 7 8 4 6 1
Row 3: 1 3 4 7 5 6 2 9 8
Row 4: 2 8 9 4 1 3 6 7 5
Row 5: 6 7 5 2 8 9 3 1 4
Row 6: 8 4 6 1 9 2 7 5 3
Row 7: 5 1 3 8 6 7 9 4 2
Row 8: 9 2 7 3 4 5 1 8 6
```

## Demo Constraints

Three constraints are programmatically added to showcase the constraint assistant feature. They span the entire grid (rows 0-8, boxes 2-7) to demonstrate non-trivial user-defined constraints:

### 1. OneOf(1)
- Cells: [27, 49, 74] (rows 3, 5, 8)
- Boxes: 3, 4, 6
- Meaning: Exactly one of these cells contains the value 1
- Solution: Cell 27 has value 1

### 2. Equal
- Cells: [8, 74] (rows 0 and 8)
- Boxes: 2, 6
- Meaning: Both cells have the same value
- Solution: Both = 7

### 3. AllDiff
- Cells: [29, 51, 67] (rows 3, 5, 7)
- Boxes: 3, 5, 7
- Domain: {3, 4, 6}
- Meaning: All cells have different values from the domain
- Solution: Cell 29 = 4, Cell 51 = 3, Cell 67 = 6

## Implementation Details

### Demo Mode
Demo mode is activated via `SharedPreferences`:
- `demoMode: true` - Enables demo mode
- `themeMode` - Sets light (1) or dark (2) theme
- `themeStyle` - Sets modern (0) or paper (1) style
- `demoSelectedGridSize` - Pre-selects 9x9 grid (3)

### Demo Trophy Room Data
For the Trophy Room screenshot, demo gamification data is seeded to showcase achievements:
- **Stats**: 3 puzzles completed, 9x9 size unlocked, tutorial completed, all constraint types used, 3 easy puzzles
- **Achievements unlocked**: Quick Learner, Constraint Master, First Steps, Classic Champion, Easy Start
- **Achievements in progress**: Getting Hooked (3/10), Easy Going (3/5)
- **Puzzle records**: 3 demo 9x9 puzzles with varying completion dates and difficulty levels

### Key Files
- `lib/demo_data.dart` - Demo puzzle, constraint setup, and preference helpers
- `integration_test/screenshot_test.dart` - Screenshot tour test
- `test_driver/integration_test.dart` - Test driver that saves screenshots to disk

### Fastlane Files
- `Gemfile` / `Gemfile.lock` - Ruby dependencies for fastlane
- `fastlane/Fastfile` - Main fastlane configuration (routes to platform-specific files)
- `fastlane/Appfile` - App identifier configuration
- `android/fastlane/Fastfile` - Android-specific lanes (screenshots, build, deploy)
- `android/fastlane/Appfile` - Android app package name
- `ios/fastlane/Fastfile` - iOS-specific lanes (screenshots, build, deploy)
- `ios/fastlane/Appfile` - iOS app bundle identifier

### Screenshot Output Directories
- `screenshots/` - Default output for manual runs
- `screenshots/android/` - Raw Android screenshots (via fastlane)
- `screenshots/ios/` - Raw iOS screenshots (via fastlane)
- `fastlane/metadata/android/en-US/images/phoneScreenshots/` - Framed Android screenshots
- `fastlane/screenshots/en-US/` - Framed iOS screenshots

### Notes
- Constraints are added without calling `apply()` to prevent the solver from satisfying them before screenshots
- A 2-second delay after tapping ensures tap indicators disappear before capture
- The tutorial dialog is automatically dismissed if it appears
