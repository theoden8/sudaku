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

  // Clear any leftover demo data before all tests
  setUpAll(() async {
    await clearDemoData();
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

        // Seed demo data with theme, style AND pre-selected grid size
        print('Seeding demo data: theme=$theme, style=$style, gridSize=3...');
        await seedDemoData(theme: theme, style: style, selectedGridSize: 3);

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
        // Screenshot 1: Grid Selection Screen
        // =========================================
        print('--- Screenshot 1: Grid Selection ---');

        // Tap PLAY button to show size selection dialog
        final playText = find.text('PLAY');
        if (playText.evaluate().isNotEmpty) {
          await tester.tap(playText);
          // Wait longer for demo settings to load via async _loadDemoSettings()
          await tester.pump(const Duration(seconds: 2));
        }

        // Take screenshot of grid selection with 9×9 pre-selected
        await _takeScreenshot(
          binding,
          tester,
          '01-grid-selection$suffix',
        );

        // =========================================
        // Screenshot 2: Sudoku Screen with Puzzle
        // =========================================
        print('--- Screenshot 2: Sudoku Screen ---');

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

        // Take screenshot of sudoku screen
        await _takeScreenshot(
          binding,
          tester,
          '02-sudoku-puzzle$suffix',
        );

        // =========================================
        // Screenshot 3: Constraint List with Multiple Constraints
        // =========================================
        print('--- Screenshot 3: Constraint list ---');

        // Constraints are pre-loaded via setupDemoConstraints() when addDemoConstraints=true
        // Wait a bit longer for constraints to be fully rendered
        await tester.pump(const Duration(seconds: 1));

        // Take screenshot showing constraint list (no cell selection)
        await _takeScreenshot(
          binding,
          tester,
          '03-constraint-list$suffix',
        );

        // =========================================
        // Screenshot 4: Cell Selection with Constraint Options
        // =========================================
        print('--- Screenshot 4: Cell Selection ---');

        // Find mutable cells (TextButtons) and long-press to start multi-select
        final textButtons = find.byType(TextButton);
        print('TextButtons found: ${textButtons.evaluate().length}');

        if (textButtons.evaluate().length >= 57) {
          // =========================================
          // Select cells across DIFFERENT BOXES spanning the ENTIRE GRID
          // TextButton indices map to grid positions (only empty cells are TextButtons):
          //   TB 14 → grid 18 (2,0) box 3 - row 2
          //   TB 40 → grid 51 (5,6) box 5 - row 5
          //   TB 56 → grid 74 (8,2) box 6 - row 8
          // This demonstrates user-defined constraints spanning rows 2, 5, and 8
          // =========================================

          // Long press cell in row 2 (box 3) to start multi-select
          await tester.longPress(textButtons.at(14));
          await tester.pump(const Duration(milliseconds: 500));

          // Tap cell in row 5 (box 5)
          await tester.tap(textButtons.at(40));
          await tester.pump(const Duration(milliseconds: 300));

          // Tap cell in row 8 (box 6)
          await tester.tap(textButtons.at(56));
          await tester.pump(const Duration(milliseconds: 300));

          // Take screenshot showing cell selection with constraint options
          await _takeScreenshot(
            binding,
            tester,
            '04-selecting-constraint$suffix',
          );
        }

        print('========================================');
        print('Screenshot tour completed ($theme $style)');
        print('========================================');

        // Clean up demo mode
        await clearDemoData();
      });
    }
  });
}
