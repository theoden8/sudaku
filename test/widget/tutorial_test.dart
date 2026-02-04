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
        sudokuThemeFunc: getTestTheme,
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
    cellSelectionColor: Colors.grey[200],
    numpadAvailable: Colors.blue[200],
    numpadAvailableActive: Colors.blue[400],
    numpadForbidden: Colors.red[200],
    numpadForbiddenActive: Colors.red[400],
    numpadUnconstrained: Colors.orange[300],
    numpadDisabledBg: Colors.grey[300],
    numpadDisabledFg: Colors.grey[500],
    numpadTextOnLight: Colors.black87,
    numpadTextOnColored: Colors.white,
    numpadSelected: Colors.green[400],
    dialogTitleColor: Colors.black87,
    dialogTextColor: Colors.black54,
    mutedPrimary: Colors.grey.shade600,
    mutedSecondary: Colors.grey.shade500,
    cancelButtonColor: Colors.grey.shade600,
    disabledBg: Colors.grey.shade300,
    disabledFg: Colors.grey.shade500,
    shadowColor: Colors.grey,
    iconColor: Colors.black54,
    logoColorPrimary: Colors.blue.shade600,
    logoColorSecondary: Colors.blue.shade400,
    subtitleColor: Colors.black38,
    onThemeModeChange: (_) {},
    onThemeStyleChange: (_) {},
    currentStyle: ThemeStyle.modern,
  );
}

void main() {
  group('Menu Screen Widget Tests', () {
    testWidgets('Menu screen displays app title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      // Use pump with duration instead of pumpAndSettle due to continuous animation
      await tester.pump(const Duration(milliseconds: 100));

      // Find the app title
      expect(find.text('SUDAKU'), findsOneWidget);
    });

    testWidgets('Menu screen displays PLAY button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Find the PLAY button text
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('Menu screen displays "Tap to begin" hint', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tap to begin'), findsOneWidget);
    });

    testWidgets('Menu screen PLAY button opens size selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the PLAY area
      await tester.tap(find.text('PLAY'));
      // Wait for dialog animation
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the size selection dialog
      expect(find.text('Choose Your Grid'), findsOneWidget);
    });

    testWidgets('Size selection shows grid preview cards', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap PLAY to show size selection
      await tester.tap(find.text('PLAY'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show size labels for each grid option
      expect(find.text('4×4'), findsOneWidget);   // 2x2 grid = 4x4 cells
      expect(find.text('9×9'), findsOneWidget);   // 3x3 grid = 9x9 cells
      expect(find.text('16×16'), findsOneWidget); // 4x4 grid = 16x16 cells
    });

    testWidgets('Size selection shows difficulty labels', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap PLAY to show size selection
      await tester.tap(find.text('PLAY'));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show difficulty labels
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Challenge'), findsOneWidget);
    });

    testWidgets('Selecting size shows START button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap PLAY to show size selection
      await tester.tap(find.text('PLAY'));
      await tester.pump(const Duration(milliseconds: 500));

      // Select Classic (9×9)
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 300));

      // START button should be visible
      expect(find.text('START'), findsOneWidget);
    });

    testWidgets('Theme toggle button exists on menu', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Should find the palette icon for theme settings popup
      final paletteIcon = find.byIcon(Icons.palette);

      expect(paletteIcon, findsOneWidget);
    });
  });

  // Note: Tutorial flow tests require running the full app with assets loaded.
  // These tests are moved to integration tests (integration_test/interaction_flow_test.dart)
  // which can properly load assets and test the full tutorial flow.

  group('Responsive Layout Tests', () {
    testWidgets('Menu screen adapts to portrait orientation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PLAY'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Menu screen adapts to landscape orientation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PLAY'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Size selection adapts to small screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('PLAY'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('4×4'), findsOneWidget);
      expect(find.text('9×9'), findsOneWidget);
      expect(find.text('16×16'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Size selection adapts to tablet size', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        child: MenuScreen(sudokuThemeFunc: getTestTheme),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('PLAY'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('4×4'), findsOneWidget);
      expect(find.text('9×9'), findsOneWidget);
      expect(find.text('16×16'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
