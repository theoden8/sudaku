import 'package:flutter/material.dart';

import 'main.dart';
import 'Sudoku.dart';


class SudokuAssistScreen extends StatefulWidget {
  static const String routeName = "/sudoku_assist";

  SudokuAssistScreen();

  State createState() => SudokuAssistScreenState();
}

class SudokuAssistScreenArguments {
  Sudoku sd;
  Function(BuildContext) sudokuThemeFunc;

  SudokuAssistScreenArguments({required this.sd, required this.sudokuThemeFunc});
}

class SudokuAssistScreenState extends State<SudokuAssistScreen> {
  late Sudoku sd;
  late Function(BuildContext) sudokuThemeFunc;

  void runSetState() {
    setState((){});
  }

  Widget _buildSettingItem({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    List<Color>? gradientColors,
    bool isIndented = false,
  }) {
    final theme = sudokuThemeFunc(ctx);
    final colors = gradientColors ?? [AppColors.primaryPurple, AppColors.secondaryPurple];

    return Padding(
      padding: EdgeInsets.only(
        left: isIndented ? 24.0 : 0.0,
        bottom: 12.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon container with gradient
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: value
                            ? colors
                            : [
                                theme.disabledBg,
                                theme.disabledBg,
                              ],
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: value
                          ? Colors.white
                          : theme.disabledFg,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.dialogTitleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.dialogTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Switch
                  Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeColor: colors[0],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext ctx, String title) {
    final theme = sudokuThemeFunc(ctx);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.mutedPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  List<Widget> _makeOptionList(BuildContext ctx) {
    var widgets = <Widget>[];

    // Hints section
    widgets.add(_buildSectionHeader(ctx, 'HINTS'));

    widgets.add(_buildSettingItem(
      ctx: ctx,
      icon: Icons.visibility_rounded,
      title: 'Show available values',
      subtitle: 'Only show values that can be placed in a cell',
      value: sd.assist.hintAvailable,
      onChanged: (bool b) {
        sd.assist.hintAvailable = b;
        runSetState();
      },
      gradientColors: [AppColors.accent, AppColors.accentLight],
    ));

    widgets.add(_buildSettingItem(
      ctx: ctx,
      icon: Icons.filter_alt_rounded,
      title: 'Constraint elimination',
      subtitle: 'Allow constraints to eliminate impossible values',
      value: sd.assist.hintConstrained,
      onChanged: (bool b) {
        sd.assist.hintConstrained = b;
        runSetState();
      },
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
    ));

    widgets.add(_buildSettingItem(
      ctx: ctx,
      icon: Icons.warning_amber_rounded,
      title: 'Show contradictions',
      subtitle: 'Highlight cells that violate constraints',
      value: sd.assist.hintContradictions,
      onChanged: (bool b) {
        sd.assist.hintContradictions = b;
        runSetState();
      },
      gradientColors: [AppColors.warning, AppColors.warningLight],
    ));

    // Auto-completion section
    widgets.add(_buildSectionHeader(ctx, 'AUTO-COMPLETION'));

    widgets.add(_buildSettingItem(
      ctx: ctx,
      icon: Icons.auto_fix_high_rounded,
      title: 'Auto-complete cells',
      subtitle: 'Fill in a value when only one possibility remains',
      value: sd.assist.autoComplete,
      onChanged: (bool b) {
        sd.assist.autoComplete = b;
        runSetState();
      },
      gradientColors: [AppColors.success, AppColors.successLight],
    ));

    // Show nested option only when autoComplete is enabled
    if (sd.assist.autoComplete) {
      widgets.add(_buildSettingItem(
        ctx: ctx,
        icon: Icons.grid_view_rounded,
        title: 'Use default constraints',
        subtitle: 'Apply all-different for rows, columns, and boxes',
        value: sd.assist.useDefaultConstraints,
        onChanged: (bool b) {
          sd.assist.useDefaultConstraints = b;
          runSetState();
        },
        gradientColors: [AppColors.primaryPurple, AppColors.secondaryPurple],
        isIndented: true,
      ));
    }

    return widgets;
  }

  Widget build(BuildContext ctx) {
    var args = ModalRoute.of(ctx)!.settings.arguments! as SudokuAssistScreenArguments;
    this.sd = args.sd;
    this.sudokuThemeFunc = args.sudokuThemeFunc;
    final theme = sudokuThemeFunc(ctx);

    return Scaffold(
      backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                ),
              ),
              child: const Icon(
                Icons.assistant_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Assistant',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.dialogTitleColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: _makeOptionList(ctx),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
