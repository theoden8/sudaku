import 'package:flutter/material.dart';

import 'main.dart';

/// Data class representing a single tutorial help page.
class TutorialHelpPage {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String body;
  final Widget? illustration;

  const TutorialHelpPage({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.body,
    this.illustration,
  });
}

/// Paginated full-screen dialog for displaying tutorial help pages.
class TutorialHelpDialog extends StatefulWidget {
  final List<TutorialHelpPage> pages;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final VoidCallback? onSkip;

  const TutorialHelpDialog({
    Key? key,
    required this.pages,
    this.dismissLabel = 'Got it',
    required this.onDismiss,
    this.onSkip,
  }) : super(key: key);

  @override
  State<TutorialHelpDialog> createState() => _TutorialHelpDialogState();
}

class _TutorialHelpDialogState extends State<TutorialHelpDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == widget.pages.length - 1;
    final theme = Theme.of(context);
    final dialogBg = theme.colorScheme.surface;
    final titleColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final bodyColor = theme.brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
    final dotActiveColor = AppColors.primaryPurple;
    final dotInactiveColor = theme.brightness == Brightness.dark
        ? Colors.white24
        : Colors.black12;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Material(
          color: dialogBg,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page content
                Flexible(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final page = widget.pages[index];
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: page.gradientColors,
                                ),
                              ),
                              child: Icon(page.icon, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 16),
                            // Title
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Body
                            Text(
                              page.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: bodyColor,
                              ),
                            ),
                            // Optional illustration
                            if (page.illustration != null) ...[
                              const SizedBox(height: 16),
                              page.illustration!,
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Dot indicators
                if (widget.pages.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.pages.length, (index) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? dotActiveColor
                              : dotInactiveColor,
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 16),
                // Navigation buttons
                Row(
                  children: [
                    // Skip Tutorial (if callback provided)
                    if (widget.onSkip != null)
                      TextButton(
                        onPressed: widget.onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: bodyColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: const Text('Skip Tutorial'),
                      ),
                    const Spacer(),
                    // Back button
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: bodyColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Back'),
                      ),
                    const SizedBox(width: 8),
                    // Next / Dismiss button
                    TextButton(
                      onPressed: isLastPage
                          ? widget.onDismiss
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(isLastPage ? widget.dismissLabel : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static class containing all tutorial help page content.
class TutorialHelpContent {
  TutorialHelpContent._();

  /// Stage 0 — Concept introduction (shown after "Start Tutorial").
  static const stage0_conceptIntro = [
    TutorialHelpPage(
      icon: Icons.lightbulb_rounded,
      gradientColors: [AppColors.primaryPurple, AppColors.secondaryPurple],
      title: 'What is a Constraint?',
      body: 'A constraint is a rule about a group of cells. '
          'In standard Sudoku, each row, column, and box must contain unique values — '
          'those are constraints!\n\n'
          'Sudaku lets you express these rules explicitly so the app can do the bookkeeping for you.',
    ),
    TutorialHelpPage(
      icon: Icons.auto_awesome_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
      title: 'Why Constraints Matter',
      body: 'When you add a constraint, the assistant automatically eliminates '
          'impossible values from cells.\n\n'
          'You focus on solving strategy — the app handles the mechanical deductions.',
    ),
    TutorialHelpPage(
      icon: Icons.touch_app_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      title: 'How It Works',
      body: 'To create a constraint:\n\n'
          '1. Long-press a cell to start selecting\n'
          '2. Tap more cells to add them to the group\n'
          '3. Choose a constraint type from the panel\n\n'
          'Let\'s try it! The highlighted cells show where to start.',
    ),
  ];

  /// Stage 2 — AllDiff explanation (shown when cells are correctly selected).
  static const stage2_allDiff = [
    TutorialHelpPage(
      icon: Icons.difference_rounded,
      gradientColors: [AppColors.accent, AppColors.accentLight],
      title: 'All Different',
      body: 'The most fundamental Sudoku rule: every selected cell must have a unique value.\n\n'
          'This is exactly how rows, columns, and boxes work in standard Sudoku — '
          'each one is an "All Different" constraint.',
    ),
    TutorialHelpPage(
      icon: Icons.play_circle_outline_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      title: 'Try It Now',
      body: 'Tap "All different" in the constraint panel to apply it to your selected cells.\n\n'
          'Watch how the possible values change — the assistant will eliminate '
          'numbers that would violate the rule!',
    ),
  ];

  /// Stage 3 — Propagation explanation (shown after AllDiff is applied).
  static const stage3_propagation = [
    TutorialHelpPage(
      icon: Icons.account_tree_rounded,
      gradientColors: [AppColors.primaryPurple, AppColors.secondaryPurple],
      title: 'Constraint Propagation',
      body: 'Notice fewer candidate numbers in the cells? '
          'The assistant eliminated values that would violate your constraint.\n\n'
          'This is constraint propagation — one rule cascades through the puzzle, '
          'narrowing down possibilities automatically.',
    ),
  ];

  /// Stage 5 — Other constraint types (informational overview).
  static const stage5_otherConstraints = [
    TutorialHelpPage(
      icon: Icons.looks_one_rounded,
      gradientColors: [AppColors.success, AppColors.successLight],
      title: 'One Of',
      body: 'Exactly one of the selected cells contains a specific value.\n\n'
          'This helps narrow down where a particular number must go — '
          'useful when you know a value is in one of a few cells but not which one.',
    ),
    TutorialHelpPage(
      icon: Icons.link_rounded,
      gradientColors: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
      title: 'Equivalence',
      body: 'Selected cells must all have the same value.\n\n'
          'Useful for advanced solving techniques where you discover '
          'that certain cells must contain the same number.',
    ),
    TutorialHelpPage(
      icon: Icons.block_rounded,
      gradientColors: [AppColors.constraintOrange, AppColors.constraintOrangeLight],
      title: 'Eliminate',
      body: 'Manually cross off specific numbers from cells\' possibilities.\n\n'
          'Sometimes you can deduce that a value is impossible in certain cells '
          'even without a formal constraint — Eliminate lets you record that.',
    ),
  ];

  /// Stage 6 — Completion page.
  static const stage6_completion = [
    TutorialHelpPage(
      icon: Icons.emoji_events_rounded,
      gradientColors: [AppColors.warning, AppColors.warningLight],
      title: 'You\'re Ready!',
      body: 'You now know how to use Sudaku\'s constraint system.\n\n'
          'Tip: Enable default Sudoku rules in the Assistant settings '
          '(toolbar menu) to automatically add row, column, and box constraints.\n\n'
          'You can always revisit these explanations through "Constraint Help" in the toolbar menu.',
    ),
  ];

  /// All pages combined for standalone help access.
  static List<TutorialHelpPage> get fullReference => [
    ...stage0_conceptIntro,
    ...stage2_allDiff,
    ...stage3_propagation,
    ...stage5_otherConstraints,
    ...stage6_completion,
  ];
}
