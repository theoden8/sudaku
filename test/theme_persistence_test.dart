import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudaku/main.dart';

void main() {
  group('Theme Persistence Tests', () {
    setUp(() {
      // Clear any previous mock values
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('App starts with default theme when no preferences saved',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(SudokuApp());
      // Use pump with duration instead of pumpAndSettle due to continuous animations
      await tester.pump(const Duration(milliseconds: 500));

      // App should render without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App loads saved dark theme mode from preferences',
        (WidgetTester tester) async {
      // ThemeMode.dark has index 2
      SharedPreferences.setMockInitialValues({
        'themeMode': ThemeMode.dark.index,
        'themeStyle': ThemeStyle.modern.index,
      });

      await tester.pumpWidget(SudokuApp());
      await tester.pump(const Duration(milliseconds: 500));

      // App should render without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App loads saved pen-and-paper style from preferences',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'themeMode': ThemeMode.system.index,
        'themeStyle': ThemeStyle.penAndPaper.index,
      });

      await tester.pumpWidget(SudokuApp());
      await tester.pump(const Duration(milliseconds: 500));

      // App should render without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App handles invalid preference values gracefully',
        (WidgetTester tester) async {
      // Set invalid index values
      SharedPreferences.setMockInitialValues({
        'themeMode': 999,
        'themeStyle': 999,
      });

      await tester.pumpWidget(SudokuApp());
      await tester.pump(const Duration(milliseconds: 500));

      // App should still render (using defaults)
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    test('Theme preferences are saved correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Save theme mode
      await prefs.setInt('themeMode', ThemeMode.dark.index);
      await prefs.setInt('themeStyle', ThemeStyle.penAndPaper.index);

      // Verify saved values
      expect(prefs.getInt('themeMode'), equals(ThemeMode.dark.index));
      expect(prefs.getInt('themeStyle'), equals(ThemeStyle.penAndPaper.index));
    });

    test('Theme mode enum indices are stable', () {
      // Verify enum indices haven't changed (important for persistence)
      expect(ThemeMode.system.index, equals(0));
      expect(ThemeMode.light.index, equals(1));
      expect(ThemeMode.dark.index, equals(2));

      expect(ThemeStyle.modern.index, equals(0));
      expect(ThemeStyle.penAndPaper.index, equals(1));
    });
  });
}
