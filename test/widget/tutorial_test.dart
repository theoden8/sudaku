import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudaku/main.dart';
import 'package:sudaku/MenuScreen.dart';
import 'package:sudaku/SudokuScreen.dart';

// Test helper to create a testable app with necessary theme
Widget createTestApp({required Widget child}) {
  return MaterialApp(
    home: child,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: ThemeMode.light,
    routes: {
      SudokuScreen.routeName: (ctx) => SudokuScreen(
        sudokuThemeFunc: (ctx) => SudokuTheme(
          blue: Colors.blue[100],
          veryBlue: Colors.blue[200],
          green: Colors.green[100],
          yellow: Colors.yellow[100],
          veryYellow: Colors.yellow[200],
          orange: Colors.orange[100],
          red: Colors.red[100],
          veryRed: Colors.red[200],
          purple: Colors.purple[100],
          cyan: Colors.cyan[100],
          foreground: Colors.black,
          cellForeground: Colors.black,
          cellInferColor: Colors.grey[500],
          cellHintColor: Colors.grey[300],
          cellBackground: null,
          onChange: (_) {},
        ),
      ),
    },
  );
}

SudokuTheme getTestTheme(BuildContext ctx) {
  return SudokuTheme(
    blue: Colors.blue[100],
    veryBlue: Colors.blue[200],
    green: Colors.green[100],
    yellow: Colors.yellow[100],
    veryYellow: Colors.yellow[200],
    orange: Colors.orange[100],
    red: Colors.red[100],
    veryRed: Colors.red[200],
    purple: Colors.purple[100],
    cyan: Colors.cyan[100],
    foreground: Colors.black,
    cellForeground: Colors.black,
    cellInferColor: Colors.grey[500],
    cellHintColor: Colors.grey[300],
    cellBackground: null,
    onChange: (_) {},
  );
}

void main() {
  group('Tutorial Widget Tests', () {
    testWidgets('Menu screen displays Play button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));

      // Find the Play button
      expect(find.text('Play'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('Menu screen Play button is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));

      // Tap the Play area (Card with InkWell)
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Should show the size selection dialog
      expect(find.text('Selecting size'), findsOneWidget);
    });

    testWidgets('Size selection shows 2, 3, 4 options', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));

      // Tap Play to show size selection
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Should show size options
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Selecting size shows play FAB', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));

      // Tap Play to show size selection
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Initially no FAB
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // Select size 3 (standard Sudoku)
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // FAB should appear
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Theme toggle button exists on menu', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));

      // Should find theme toggle icon (sun for light mode)
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });
  });

  // Note: Tutorial flow tests require running the full app with assets loaded.
  // These tests are moved to integration tests (integration_test/interaction_flow_test.dart)
  // which can properly load assets and test the full tutorial flow.
  //
  // The tutorial flow includes:
  // - Stage 0: Help button visible, tap to start tutorial, long-press to skip
  // - Stage 1: Multi-selection mode - select highlighted cells
  // - Stage 2: Open drawer and select "All different" constraint
  // - Stage 3: Tutorial completion
  //
  // Widget tests here focus on testable components without asset dependencies.

  group('Responsive Layout Tests', () {
    testWidgets('Menu screen adapts to portrait orientation', (WidgetTester tester) async {
      // Set a portrait size
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pumpAndSettle();

      // Play button should be visible
      expect(find.text('Play'), findsOneWidget);

      // Reset size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Menu screen adapts to landscape orientation', (WidgetTester tester) async {
      // Set a landscape size
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pumpAndSettle();

      // Play button should still be visible
      expect(find.text('Play'), findsOneWidget);

      // Reset size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Size selection adapts to small screen', (WidgetTester tester) async {
      // Set a small phone size
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Size options should still be visible
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Size selection adapts to tablet size', (WidgetTester tester) async {
      // Set a tablet size
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Size options should still be visible
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
