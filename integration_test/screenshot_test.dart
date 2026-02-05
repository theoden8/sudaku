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

  group('Screenshot Tour', () {
    for (final theme in ['light', 'dark']) {
      testWidgets('Screenshot tour ($theme theme)',
          (WidgetTester tester) async {
        print('========================================');
        print('Starting screenshot tour ($theme theme)');
        print('========================================');

        // Seed demo data with theme
        print('Seeding demo data with $theme theme...');
        await seedDemoData(theme: theme);

        // Launch the app
        print('Launching app...');
        await tester.pumpWidget(SudokuApp());
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Set orientation
        await _setDeviceOrientation(tester);

        // Convert Flutter surface to image for screenshots
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();

        final themeSuffix = theme == 'light' ? '-light' : '-dark';

        // =========================================
        // Screenshot 1: Grid Selection Screen
        // =========================================
        print('--- Screenshot 1: Grid Selection ---');

        // Tap PLAY button to show size selection dialog
        // The button contains "PLAY" text
        final playFinder = find.textContaining('PLAY');
        if (playFinder.evaluate().isNotEmpty) {
          await tester.tap(playFinder.first);
        }
        await tester.pumpAndSettle();

        // Select 9x9 grid - look for the "9×9" label or "Classic" text
        final classicCard = find.text('9×9');
        if (classicCard.evaluate().isNotEmpty) {
          await tester.tap(classicCard);
          await tester.pumpAndSettle();
        } else {
          // Try finding Classic label
          final classicLabel = find.text('Classic');
          if (classicLabel.evaluate().isNotEmpty) {
            await tester.tap(classicLabel);
            await tester.pumpAndSettle();
          }
        }

        // Take screenshot of grid selection with 9×9 selected
        await _takeScreenshot(
          binding,
          tester,
          '01-grid-selection$themeSuffix',
        );

        // =========================================
        // Screenshot 2: Sudoku Screen with Puzzle
        // =========================================
        print('--- Screenshot 2: Sudoku Screen ---');

        // Start the game - look for START button
        final startFinder = find.textContaining('START');
        if (startFinder.evaluate().isNotEmpty) {
          await tester.tap(startFinder.first);
        } else {
          // Fallback: look for play_arrow icon
          final playArrow = find.byIcon(Icons.play_arrow_rounded);
          if (playArrow.evaluate().isNotEmpty) {
            await tester.tap(playArrow.first);
          } else {
            await tester.tap(find.byIcon(Icons.play_arrow).first);
          }
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Dismiss tutorial dialog if it appears
        final skipButton = find.text('Skip');
        if (skipButton.evaluate().isNotEmpty) {
          await tester.tap(skipButton);
          await tester.pumpAndSettle();
        }

        // Take screenshot of sudoku screen
        await _takeScreenshot(
          binding,
          tester,
          '02-sudoku-puzzle$themeSuffix',
        );

        // =========================================
        // Screenshot 3: Selecting Cells for Constraint
        // =========================================
        print('--- Screenshot 3: Cell Selection ---');

        // Find mutable cells (TextButtons) and long-press to start multi-select
        final textButtons = find.byType(TextButton);
        if (textButtons.evaluate().length >= 3) {
          // Long press first cell to start multi-select
          await tester.longPress(textButtons.first);
          await tester.pumpAndSettle();

          // Tap two more cells to select them
          await tester.tap(textButtons.at(1));
          await tester.pumpAndSettle();
          await tester.tap(textButtons.at(2));
          await tester.pumpAndSettle();

          // Take screenshot showing cell selection with constraint options
          await _takeScreenshot(
            binding,
            tester,
            '03-selecting-constraint$themeSuffix',
          );

          // =========================================
          // Screenshot 4: Constraint Applied (showing deductions)
          // =========================================
          print('--- Screenshot 4: Constraint Applied ---');

          // Apply "All different" constraint
          final allDiffButton = find.text('All different');
          if (allDiffButton.evaluate().isNotEmpty) {
            await tester.tap(allDiffButton);
            await tester.pumpAndSettle();

            // The numpad should appear for value selection
            // Select values matching the cell count (e.g., 1, 2, 3)
            for (int i = 1; i <= 3; i++) {
              final valueButton = find.text('$i');
              if (valueButton.evaluate().isNotEmpty) {
                await tester.tap(valueButton.first);
                await tester.pumpAndSettle();
              }
            }

            // Confirm selection if there's a confirm button
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();
            }

            // Close any dialogs that might have appeared
            final gotItButton = find.text('Got it');
            while (gotItButton.evaluate().isNotEmpty) {
              await tester.tap(gotItButton.first);
              await tester.pumpAndSettle();
            }

            // Take screenshot showing constraint in list
            await _takeScreenshot(
              binding,
              tester,
              '04-constraint-applied$themeSuffix',
            );
          }
        }

        print('========================================');
        print('Screenshot tour completed ($theme theme)');
        print('========================================');

        // Clean up demo mode
        await clearDemoData();
      });
    }
  });
}
