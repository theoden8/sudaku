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

/// Debug helper to print what text widgets are visible
void _debugPrintTextWidgets(WidgetTester tester) {
  final textWidgets = find.byType(Text);
  print('--- Visible Text widgets (${textWidgets.evaluate().length}): ---');
  for (final element in textWidgets.evaluate().take(20)) {
    final widget = element.widget as Text;
    if (widget.data != null) {
      print('  "${widget.data}"');
    }
  }
  print('--- End Text widgets ---');
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

        // Use pump with duration instead of pumpAndSettle since menu has continuous animations
        await tester.pump(const Duration(seconds: 3));

        // Set orientation
        await _setDeviceOrientation(tester);

        // Convert Flutter surface to image for screenshots
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(seconds: 1));

        final themeSuffix = theme == 'light' ? '-light' : '-dark';

        // Debug: show what widgets are visible
        _debugPrintTextWidgets(tester);

        // =========================================
        // Screenshot 1: Grid Selection Screen
        // =========================================
        print('--- Screenshot 1: Grid Selection ---');

        // Find and tap PLAY button - it's a Text widget inside a GestureDetector
        final playText = find.text('PLAY');
        print('PLAY button found: ${playText.evaluate().isNotEmpty}');

        if (playText.evaluate().isNotEmpty) {
          await tester.tap(playText);
          await tester.pump(const Duration(seconds: 1));
        } else {
          // Try finding by icon if text doesn't work
          final playIcon = find.byIcon(Icons.play_arrow_rounded);
          if (playIcon.evaluate().isNotEmpty) {
            await tester.tap(playIcon.first);
            await tester.pump(const Duration(seconds: 1));
          }
        }

        // Debug after tapping
        _debugPrintTextWidgets(tester);

        // Select 9x9 grid - look for the "9×9" label
        final classicCard = find.text('9×9');
        print('9×9 card found: ${classicCard.evaluate().isNotEmpty}');

        if (classicCard.evaluate().isNotEmpty) {
          await tester.tap(classicCard);
          await tester.pump(const Duration(milliseconds: 500));
        } else {
          // Try finding Classic label
          final classicLabel = find.text('Classic');
          if (classicLabel.evaluate().isNotEmpty) {
            await tester.tap(classicLabel);
            await tester.pump(const Duration(milliseconds: 500));
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

        // Start the game - look for START button or play icon
        final startText = find.text('START');
        print('START button found: ${startText.evaluate().isNotEmpty}');

        if (startText.evaluate().isNotEmpty) {
          await tester.tap(startText);
        } else {
          // Fallback: look for play_arrow icon
          final playArrow = find.byIcon(Icons.play_arrow_rounded);
          if (playArrow.evaluate().isNotEmpty) {
            await tester.tap(playArrow.first);
          } else {
            final playArrow2 = find.byIcon(Icons.play_arrow);
            if (playArrow2.evaluate().isNotEmpty) {
              await tester.tap(playArrow2.first);
            }
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
          '02-sudoku-puzzle$themeSuffix',
        );

        // =========================================
        // Screenshot 3: Selecting Cells for Constraint
        // =========================================
        print('--- Screenshot 3: Cell Selection ---');

        // Find mutable cells (TextButtons) and long-press to start multi-select
        final textButtons = find.byType(TextButton);
        print('TextButtons found: ${textButtons.evaluate().length}');

        if (textButtons.evaluate().length >= 3) {
          // Long press first cell to start multi-select
          await tester.longPress(textButtons.first);
          await tester.pump(const Duration(milliseconds: 500));

          // Tap two more cells to select them
          await tester.tap(textButtons.at(1));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(textButtons.at(2));
          await tester.pump(const Duration(milliseconds: 300));

          // Take screenshot showing cell selection with constraint options
          await _takeScreenshot(
            binding,
            tester,
            '03-selecting-constraint$themeSuffix',
          );

          // =========================================
          // Screenshot 4: Value Selection (Numpad)
          // =========================================
          print('--- Screenshot 4: Value Selection ---');

          // Apply "All different" constraint to show numpad
          final allDiffButton = find.text('All different');
          print('All different button found: ${allDiffButton.evaluate().isNotEmpty}');

          if (allDiffButton.evaluate().isNotEmpty) {
            await tester.tap(allDiffButton);
            await tester.pump(const Duration(seconds: 1));

            // Take screenshot of numpad/value selection screen
            await _takeScreenshot(
              binding,
              tester,
              '04-value-selection$themeSuffix',
            );

            // Go back to main screen by tapping back or outside
            final backButton = find.byIcon(Icons.arrow_back);
            if (backButton.evaluate().isNotEmpty) {
              await tester.tap(backButton);
              await tester.pump(const Duration(milliseconds: 500));
            } else {
              // Try pressing back key
              await tester.pageBack();
              await tester.pump(const Duration(milliseconds: 500));
            }
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
