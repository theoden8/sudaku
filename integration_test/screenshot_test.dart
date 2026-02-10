import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudaku/main.dart';
import 'package:sudaku/demo_data.dart';

/// Check if device is tablet based on screen size
bool _isTablet(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final shortestSide = size.shortestSide;
  return shortestSide > 600;
}

/// Set device orientation based on device type
/// Tablet: landscape, Phone: portrait
Future<void> _setDeviceOrientation(WidgetTester tester) async {
  if (Platform.isIOS || Platform.isAndroid) {
    if (_isTablet(tester)) {
      print('Tablet detected - setting landscape orientation');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      print('Phone detected - setting portrait orientation');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    await tester.pump();
  }
}

// Timeout constants
const Duration _screenshotTimeout = Duration(seconds: 10);

/// Helper to take a screenshot with current theme.
Future<void> _takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  print('Capturing screenshot: $name');
  await tester.pump();

  await binding.takeScreenshot(name).timeout(
    _screenshotTimeout,
    onTimeout: () {
      print('Warning: Screenshot $name timed out');
      return <int>[];
    },
  );
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Make hit test warnings fatal to catch layout issues
  WidgetController.hitTestWarningShouldBeFatal = true;

  // Clear any leftover demo data before all tests
  setUpAll(() async {
    await clearDemoData();
    await clearDemoTrophyRoomData();
  });

  // Clean up after all tests to help process exit
  tearDownAll(() async {
    await clearDemoData();
    await clearDemoTrophyRoomData();
    // Reset frame policy to stop continuous rendering
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmark;
    // Give time for cleanup to complete
    await Future.delayed(const Duration(milliseconds: 500));
  });

  group('Screenshot Tour', () {
    // All theme/style combinations
    final combinations = [
      {'theme': 'light', 'style': 'modern'},
      {'theme': 'dark', 'style': 'modern'},
      {'theme': 'light', 'style': 'paper'},
      {'theme': 'dark', 'style': 'paper'},
    ];

    for (final combo in combinations) {
      final theme = combo['theme']!;
      final style = combo['style']!;
      final suffix = '-$theme-$style';

      testWidgets('Screenshot tour ($theme $style)',
          (WidgetTester tester) async {
        print('========================================');
        print('Starting screenshot tour ($theme $style)');
        print('========================================');

        // Clear any previous demo data first
        await clearDemoData();
        await clearDemoTrophyRoomData();

        // Seed demo data with theme, style AND pre-selected grid size
        print('Seeding demo data: theme=$theme, style=$style, gridSize=3...');
        await seedDemoData(theme: theme, style: style, selectedGridSize: 3);

        // Seed Trophy Room demo data for achievements screenshot
        print('Seeding Trophy Room demo data...');
        await seedDemoTrophyRoomData();

        // Launch the app
        print('Launching app...');
        await tester.pumpWidget(SudokuApp());

        // Use pump with duration instead of pumpAndSettle since menu has continuous animations
        await tester.pump(const Duration(seconds: 3));

        // Set orientation
        await _setDeviceOrientation(tester);

        // Convert Flutter surface to image for screenshots
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(seconds: 1));

        // =========================================
        // Screenshot 2: Trophy Room - Achievements (do this first from menu)
        // =========================================
        print('--- Screenshot 2: Trophy Room ---');

        // Navigate to Trophy Room from menu
        final trophyIcon = find.byIcon(Icons.emoji_events_rounded);
        if (trophyIcon.evaluate().isNotEmpty) {
          print('Found trophy icon, navigating to Trophy Room...');
          await tester.tap(trophyIcon.first);
          await tester.pump(const Duration(seconds: 2));
        } else {
          print('Warning: Trophy icon not found');
        }

        // Switch to Achievements tab
        final achievementsTab = find.text('Achievements');
        if (achievementsTab.evaluate().isNotEmpty) {
          print('Switching to Achievements tab...');
          await tester.tap(achievementsTab.first);
          await tester.pump(const Duration(seconds: 1));
        }

        // Take Trophy Room screenshot
        await _takeScreenshot(
          binding,
          tester,
          '02-trophy-room$suffix',
        );

        // Navigate back to menu
        final backButton = find.byIcon(Icons.arrow_back_rounded);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pump(const Duration(seconds: 1));
        }

        // =========================================
        // Screenshot 1: Grid Selection Screen
        // =========================================
        print('--- Screenshot 1: Grid Selection ---');

        // Tap PLAY button to show size selection dialog
        final playText = find.text('PLAY');
        if (playText.evaluate().isNotEmpty) {
          await tester.tap(playText);
          // Wait longer for demo settings to load via async _loadDemoSettings()
          // and for difficulty selector animation to complete
          await tester.pump(const Duration(seconds: 2));
          // Additional pump to ensure START button and difficulty selector are visible
          await tester.pump(const Duration(seconds: 1));
        }

        // Verify grid selection dialog is visible before taking screenshot
        final startButton = find.text('START');
        if (startButton.evaluate().isEmpty) {
          print('Warning: START button not found, waiting longer...');
          await tester.pump(const Duration(seconds: 2));
        }

        // Take screenshot of grid selection with 9×9 pre-selected
        await _takeScreenshot(
          binding,
          tester,
          '01-grid-selection$suffix',
        );

        // =========================================
        // Screenshot 3: Start game and show constraints
        // =========================================
        print('--- Starting game ---');

        // Start the game - START button should be visible since 9x9 is pre-selected
        final startText = find.text('START');
        if (startText.evaluate().isNotEmpty) {
          await tester.tap(startText);
        } else {
          // Fallback: look for play_arrow icon
          final playArrow = find.byIcon(Icons.play_arrow_rounded);
          if (playArrow.evaluate().isNotEmpty) {
            await tester.tap(playArrow.first);
          }
        }
        await tester.pump(const Duration(seconds: 2));

        // Dismiss tutorial dialog if it appears
        final skipButton = find.text('Skip');
        if (skipButton.evaluate().isNotEmpty) {
          print('Dismissing tutorial dialog...');
          await tester.tap(skipButton);
          await tester.pump(const Duration(milliseconds: 500));
        }

        // =========================================
        // Screenshot 3: Constraint List with AllDiff Highlighted
        // =========================================
        print('--- Screenshot 3: Constraint list with AllDiff highlighted ---');

        // Clear any SnackBars that may have appeared from initial assistant run
        final scaffoldFinder = find.byType(Scaffold);
        if (scaffoldFinder.evaluate().isNotEmpty) {
          final scaffoldContext = tester.element(scaffoldFinder.first);
          ScaffoldMessenger.of(scaffoldContext).clearSnackBars();
          await tester.pump(const Duration(milliseconds: 300));
        }

        // Constraints are pre-loaded via setupDemoConstraints() when addDemoConstraints=true
        // Wait a bit longer for constraints to be fully rendered
        await tester.pump(const Duration(seconds: 1));

        // Find and tap the AllDiff constraint to highlight its cells
        final allDiffText = find.text('allDiff');
        if (allDiffText.evaluate().isNotEmpty) {
          print('Found AllDiff constraint, tapping to highlight cells...');
          await tester.tap(allDiffText);
          // Wait longer for tap indicator to disappear before screenshot
          await tester.pump(const Duration(seconds: 2));
        } else {
          print('Warning: AllDiff constraint not found');
        }

        // Take screenshot showing constraint list with AllDiff cells highlighted
        await _takeScreenshot(
          binding,
          tester,
          '03-constraint-list$suffix',
        );

        // =========================================
        // Screenshot 4: Fill in a cell from AllDiff constraint
        // =========================================
        print('--- Screenshot 4: Filling AllDiff cell ---');

        // Find mutable cells (TextButtons)
        final textButtons = find.byType(TextButton);
        print('TextButtons found: ${textButtons.evaluate().length}');

        if (textButtons.evaluate().length >= 25) {
          // Cell 29 (row 3, col 2) is TextButton index 24
          // Its solution value is 4
          // TB index mapping for cell 29:
          //   TB 0-6: row 0 (7 cells), TB 7-13: row 1 (7 cells), TB 14-22: row 2 (9 cells)
          //   TB 23-28: row 3 -> TB 24 = cell 29

          // Tap cell 29 to select it
          print('Tapping cell 29 (TB index 24)...');
          await tester.tap(textButtons.at(24));
          await tester.pump(const Duration(milliseconds: 500));

          // Find and tap the digit 4 button
          final digit4 = find.text('4');
          if (digit4.evaluate().length > 1) {
            // There may be multiple '4' texts - tap the one in the number pad
            // The number pad buttons are usually the last ones found
            print('Found digit 4, tapping to enter value...');
            await tester.tap(digit4.last);
            // Wait for tap indicator to disappear (SnackBar stays visible)
            await tester.pump(const Duration(seconds: 2));
          }

          // Take screenshot showing the filled cell with SnackBar
          await _takeScreenshot(
            binding,
            tester,
            '04-cell-filled$suffix',
          );
        }

        print('========================================');
        print('Screenshot tour completed ($theme $style)');
        print('========================================');

        // Clean up demo mode
        await clearDemoData();
        await clearDemoTrophyRoomData();
      });
    }
  });
}
