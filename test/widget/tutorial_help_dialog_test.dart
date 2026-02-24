import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudaku/TutorialHelpPages.dart';
import 'package:sudaku/main.dart';

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    home: child,
    theme: ThemeData.light(),
  );
}

void main() {
  // Make hit test warnings fatal to catch layout issues
  WidgetController.hitTestWarningShouldBeFatal = true;

  group('TutorialHelpDialog Widget Tests', () {
    final testPages = [
      const TutorialHelpPage(
        icon: Icons.lightbulb_rounded,
        gradientColors: [AppColors.primaryPurple, AppColors.secondaryPurple],
        title: 'Test Page 1',
        body: 'This is the body of test page 1.',
      ),
      const TutorialHelpPage(
        icon: Icons.auto_awesome_rounded,
        gradientColors: [AppColors.accent, AppColors.accentLight],
        title: 'Test Page 2',
        body: 'This is the body of test page 2.',
      ),
      const TutorialHelpPage(
        icon: Icons.touch_app_rounded,
        gradientColors: [AppColors.success, AppColors.successLight],
        title: 'Test Page 3',
        body: 'This is the body of test page 3.',
      ),
    ];

    testWidgets('displays first page title and body', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Page 1'), findsOneWidget);
      expect(find.text('This is the body of test page 1.'), findsOneWidget);
    });

    testWidgets('shows Next button on non-last page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Next'), findsOneWidget);
      // No Back button on first page
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('Next button navigates to next page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show page 2
      expect(find.text('Test Page 2'), findsOneWidget);
      // Back button should now be visible
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Back button navigates to previous page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Go to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Test Page 2'), findsOneWidget);

      // Go back to page 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Test Page 1'), findsOneWidget);
    });

    testWidgets('last page shows dismiss button with correct label', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            dismissLabel: 'Finish',
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to last page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show Finish button instead of Next
      expect(find.text('Next'), findsNothing);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('dismiss button calls onDismiss', (WidgetTester tester) async {
      bool dismissed = false;
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: [testPages[0]], // Single page
            onDismiss: () => dismissed = true,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Single page shows dismiss button directly
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('Skip Tutorial button is shown when onSkip provided', (WidgetTester tester) async {
      bool skipped = false;
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
            onSkip: () => skipped = true,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Skip Tutorial'), findsOneWidget);

      await tester.tap(find.text('Skip Tutorial'));
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
    });

    testWidgets('Skip Tutorial button is not shown when onSkip is null', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Skip Tutorial'), findsNothing);
    });

    testWidgets('dot indicators match page count', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: testPages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 3 dot indicators for 3 pages
      final dots = find.byWidgetPredicate((widget) =>
        widget is Container &&
        (widget.decoration is BoxDecoration) &&
        (widget.decoration as BoxDecoration).shape == BoxShape.circle
      );
      expect(dots, findsNWidgets(3));
    });

    testWidgets('no dot indicators for single page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: [testPages[0]],
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final dots = find.byWidgetPredicate((widget) =>
        widget is Container &&
        (widget.decoration is BoxDecoration) &&
        (widget.decoration as BoxDecoration).shape == BoxShape.circle
      );
      expect(dots, findsNothing);
    });

    testWidgets('renders page icon with gradient', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: [testPages[0]],
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Should find the lightbulb icon
      expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
    });
  });

  group('TutorialHelpContent Full Reference Tests', () {
    testWidgets('fullReference pages render correctly', (WidgetTester tester) async {
      final pages = TutorialHelpContent.fullReference;
      await tester.pumpWidget(createTestApp(
        child: Scaffold(
          body: TutorialHelpDialog(
            pages: pages,
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // First page should be visible
      expect(find.text('What is a Constraint?'), findsOneWidget);
    });
  });
}
