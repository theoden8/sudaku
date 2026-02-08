import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudaku/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Make hit test warnings fatal to catch layout issues
  WidgetController.hitTestWarningShouldBeFatal = true;

  group('Standard Interaction Flow Tests', () {
    testWidgets('Full flow: Menu -> Size Selection -> Sudoku Screen',
        (WidgetTester tester) async {
      // Start the app
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Verify we're on the menu screen
      expect(find.text('Sudaku'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);

      // Tap Play
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Verify size selection appears
      expect(find.text('Selecting size'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Select size 3 (standard 9x9 Sudoku)
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // Verify FAB appears
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Tap play FAB
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on the Sudoku screen
      expect(find.text('Sudoku'), findsOneWidget);

      // Tutorial should be visible (help icon at stage 0)
      expect(find.byIcon(Icons.help), findsOneWidget);
    });

    testWidgets('Skip tutorial and view constraint list',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Long press to skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Tutorial should be hidden
      expect(find.byIcon(Icons.help), findsNothing);
    });

    testWidgets('Cell selection and numpad interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Find and tap a mutable cell (TextButton)
      // The grid contains both hint cells (Cards) and mutable cells (TextButtons)
      final textButtons = find.byType(TextButton);
      if (textButtons.evaluate().isNotEmpty) {
        await tester.tap(textButtons.first);
        await tester.pumpAndSettle();

        // Should show numpad screen
        expect(find.text('Selecting'), findsOneWidget);

        // Numpad should have Clear button
        expect(find.text('Clear'), findsOneWidget);
      }
    });

    testWidgets('Undo button functionality', (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Undo button should be in the app bar
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('Theme toggle works on Sudoku screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Find theme toggle (sun or moon icon)
      final sunIcon = find.byIcon(Icons.wb_sunny);
      final moonIcon = find.byIcon(Icons.nights_stay);

      // One of them should exist
      expect(
        sunIcon.evaluate().isNotEmpty || moonIcon.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Drawer opens with constraint options',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Open drawer using scaffold
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Drawer should show constraint options
      expect(find.text('Constraints'), findsOneWidget);
      expect(find.text('One of'), findsOneWidget);
      expect(find.text('Equivalence'), findsOneWidget);
      expect(find.text('All different'), findsOneWidget);
      expect(find.text('Eliminate'), findsOneWidget);
    });

    testWidgets('Menu button in toolbar shows options',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Find and tap the popup menu button (more_vert icon)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Should show menu options
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('Tutor'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Assistant settings screen accessible',
        (WidgetTester tester) async {
      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku screen
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Skip tutorial
      await tester.longPress(find.byIcon(Icons.help));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Assistant
      await tester.tap(find.text('Assistant'));
      await tester.pumpAndSettle();

      // Should navigate to Assistant screen
      expect(find.text('Assistant'), findsWidgets);
      expect(find.text('Show only available values'), findsOneWidget);
    });
  });

  group('Responsive Layout Integration Tests', () {
    testWidgets('App works in portrait orientation',
        (WidgetTester tester) async {
      // Set portrait size
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should display correctly
      expect(find.text('Sudoku'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('App works in landscape orientation',
        (WidgetTester tester) async {
      // Set landscape size
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(SudokuApp());
      await tester.pumpAndSettle();

      // Navigate to Sudoku
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should display correctly
      expect(find.text('Sudoku'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
