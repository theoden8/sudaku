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
        // Screenshot 3: Cell Selection with Constraint Options
        // =========================================
        print('--- Screenshot 3: Cell Selection ---');

        // Find mutable cells (TextButtons) and long-press to start multi-select
        final textButtons = find.byType(TextButton);
        print('TextButtons found: ${textButtons.evaluate().length}');

        if (textButtons.evaluate().length >= 8) {
          // =========================================
          // For the demo puzzle '4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........'
          // The first empty cells (TextButtons) have these solution values:
          //   at(0)=6, at(1)=8, at(2)=9, at(3)=1, at(4)=5, at(5)=2, at(6)=7, at(7)=7
          // =========================================

          // Long press first cell to start multi-select
          await tester.longPress(textButtons.first);
          await tester.pump(const Duration(milliseconds: 500));

          // Tap two more cells to select them (cells 0,1,2 have solutions 6,8,9)
          await tester.tap(textButtons.at(1));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(textButtons.at(2));
          await tester.pump(const Duration(milliseconds: 300));

          // Take screenshot showing cell selection with constraint options
          await _takeScreenshot(
            binding,
            tester,
            '03-selecting-constraint$suffix',
          );

          // =========================================
          // Screenshot 4: Apply OneOf Constraint
          // =========================================
          print('--- Screenshot 4: OneOf Constraint ---');

          // Apply "One of" constraint - valid because cell 0 contains 6
          final oneOfButton = find.text('One of');
          print('One of button found: ${oneOfButton.evaluate().isNotEmpty}');

          if (oneOfButton.evaluate().isNotEmpty) {
            await tester.tap(oneOfButton);
            await tester.pump(const Duration(seconds: 1));

            // Take screenshot showing numpad for OneOf value selection
            await _takeScreenshot(
              binding,
              tester,
              '04-oneof-constraint$suffix',
            );

            // Find numpad buttons by looking for ElevatedButton children with text
            // The numpad uses ElevatedButtons, grid cells use TextButtons
            final numpadButtons = find.ancestor(
              of: find.text('6'),
              matching: find.byType(ElevatedButton),
            );
            if (numpadButtons.evaluate().isNotEmpty) {
              await tester.tap(numpadButtons.first);
              await tester.pump(const Duration(seconds: 1));
            } else {
              // Fallback: just go back to dismiss numpad
              final navigator = find.byType(Navigator);
              if (navigator.evaluate().isNotEmpty) {
                // Simulate back button by tapping outside or finding back button
                final backButton = find.byIcon(Icons.arrow_back);
                if (backButton.evaluate().isNotEmpty) {
                  await tester.tap(backButton.first);
                  await tester.pump(const Duration(seconds: 1));
                }
              }
            }
          }

          // Wait for any navigation/animation to complete
          await tester.pump(const Duration(seconds: 1));

          // Re-find textButtons after potential navigation
          final gridButtons = find.byType(TextButton);
          print('TextButtons after OneOf: ${gridButtons.evaluate().length}');

          // =========================================
          // Screenshot 5: Apply Equivalent Constraint
          // =========================================
          print('--- Screenshot 5: Equivalent Constraint ---');

          if (gridButtons.evaluate().length >= 8) {
            // Select cells at(6) and at(7) - both have solution value 7, so Equivalent is valid
            await tester.longPress(gridButtons.at(6), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            await tester.tap(gridButtons.at(7), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));

            // Apply "Equivalent" constraint - valid because both cells = 7
            final equivButton = find.text('Equivalent');
            print('Equivalent button found: ${equivButton.evaluate().isNotEmpty}');

            if (equivButton.evaluate().isNotEmpty) {
              await tester.tap(equivButton);
              await tester.pump(const Duration(seconds: 1));

              // Take screenshot showing the constraint applied
              await _takeScreenshot(
                binding,
                tester,
                '05-equivalent-constraint$suffix',
              );
            }
          }
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
