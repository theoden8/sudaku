import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';
import 'SudokuScreen.dart';
import 'TrophyRoomScreen.dart';
import 'demo_data.dart';

class MenuScreen extends StatefulWidget {
  Function(BuildContext) sudokuThemeFunc;

  MenuScreen({required this.sudokuThemeFunc});

  State createState() => MenuScreenState();
}

// Separate widget for size selection with its own animation controller
class _SizeSelectionContent extends StatefulWidget {
  final Function(BuildContext) sudokuThemeFunc;
  final BuildContext parentContext;

  const _SizeSelectionContent({
    required this.sudokuThemeFunc,
    required this.parentContext,
  });

  @override
  State<_SizeSelectionContent> createState() => _SizeSelectionContentState();
}

class _SizeSelectionContentState extends State<_SizeSelectionContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _selectionPulseController;
  int _selectedSize = -1;
  bool _isDemoMode = false;
  // null = hard (from file), otherwise generated with this difficulty level
  double? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectionPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(); // Run continuously for smooth animation

    // Check for demo mode and pre-selected grid size
    _loadDemoSettings();
  }

  Future<void> _loadDemoSettings() async {
    final isDemo = await isDemoMode();
    final demoSize = await getDemoSelectedGridSize();
    if (mounted) {
      setState(() {
        _isDemoMode = isDemo;
        if (demoSize != null) {
          _selectedSize = demoSize;
        }
      });
    }
  }

  @override
  void dispose() {
    _selectionPulseController.dispose();
    super.dispose();
  }

  // Build difficulty selector for 9x9 (Easy/Hard) and 16x16 (Easy/Medium/Hard)
  Widget _buildDifficultySelector(BuildContext context) {
    final theme = widget.sudokuThemeFunc(context);

    // Define difficulty options based on grid size
    // 9x9: Easy (generated 1.0), Hard (from file = null)
    // 16x16: Easy (generated 0.5), Medium (generated 1.0), Hard (from file = null)
    final List<({String label, double? difficulty, IconData icon})> options;
    if (_selectedSize == 3) {
      options = [
        (label: 'Easy', difficulty: 1.0, icon: Icons.sentiment_satisfied_rounded),
        (label: 'Hard', difficulty: null, icon: Icons.local_fire_department_rounded),
      ];
    } else if (_selectedSize == 4) {
      options = [
        (label: 'Easy', difficulty: 0.5, icon: Icons.sentiment_satisfied_rounded),
        (label: 'Medium', difficulty: 1.0, icon: Icons.psychology_rounded),
        (label: 'Hard', difficulty: null, icon: Icons.local_fire_department_rounded),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: options.map((opt) {
          final isSelected = _selectedDifficulty == opt.difficulty;
          final color = _sizeColors[_selectedSize]?[0] ?? AppColors.primaryPurple;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedDifficulty = opt.difficulty;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    border: Border.all(
                      color: isSelected ? color : theme.mutedPrimary.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.icon,
                        size: 18,
                        color: isSelected ? color : theme.mutedPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color : theme.mutedPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build a mini sudoku grid preview with optional animation
  Widget _buildMiniGrid(int n, double size, Color primaryColor, Color secondaryColor, {bool animate = false, bool isSketchedStyle = false}) {
    final int gridSize = n * n;

    Widget gridContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSketchedStyle ? 4 : 8),
        border: isSketchedStyle ? null : Border.all(color: primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSketchedStyle ? 2 : 6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            final int row = index ~/ gridSize;
            final int col = index % gridSize;
            final int boxRow = row ~/ n;
            final int boxCol = col ~/ n;
            final bool isEvenBox = (boxRow + boxCol) % 2 == 0;

            if (isSketchedStyle) {
              // Simpler look for pen-and-paper style - no cell borders, subtle coloring
              return Container(
                color: isEvenBox
                    ? primaryColor.withOpacity(0.08)
                    : secondaryColor.withOpacity(0.04),
              );
            }

            if (animate) {
              // Create smooth continuous wave animation based on cell position
              final double cellDelay = (row + col) / (gridSize * 2);
              return AnimatedBuilder(
                animation: _selectionPulseController,
                builder: (context, child) {
                  // Continuous wave that wraps around smoothly
                  final double phase = (_selectionPulseController.value + cellDelay) * 2 * 3.14159;
                  final double wave = (sin(phase) + 1) / 2 * 0.35; // 0 to 0.35 range
                  final double opacity = isEvenBox ? 0.25 + wave : 0.15 + wave * 0.6;

                  return Container(
                    decoration: BoxDecoration(
                      color: isEvenBox
                          ? primaryColor.withOpacity(opacity.clamp(0.1, 0.6))
                          : secondaryColor.withOpacity((opacity * 0.7).clamp(0.05, 0.4)),
                      border: Border(
                        right: BorderSide(
                          color: (col + 1) % n == 0 && col < gridSize - 1
                              ? primaryColor
                              : primaryColor.withOpacity(0.2),
                          width: (col + 1) % n == 0 ? 1.5 : 0.5,
                        ),
                        bottom: BorderSide(
                          color: (row + 1) % n == 0 && row < gridSize - 1
                              ? primaryColor
                              : primaryColor.withOpacity(0.2),
                          width: (row + 1) % n == 0 ? 1.5 : 0.5,
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isEvenBox ? primaryColor.withOpacity(0.3) : secondaryColor.withOpacity(0.2),
                border: Border(
                  right: BorderSide(
                    color: (col + 1) % n == 0 && col < gridSize - 1
                        ? primaryColor
                        : primaryColor.withOpacity(0.2),
                    width: (col + 1) % n == 0 ? 1.5 : 0.5,
                  ),
                  bottom: BorderSide(
                    color: (row + 1) % n == 0 && row < gridSize - 1
                        ? primaryColor
                        : primaryColor.withOpacity(0.2),
                    width: (row + 1) % n == 0 ? 1.5 : 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    // For sketched style, overlay hand-drawn grid lines
    if (isSketchedStyle) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            gridContent,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SketchedGridPainter(
                    n: n,
                    lineColor: primaryColor,
                    size: size,
                    wobbleAmount: 2.0,  // Less wobble for smaller grids
                    thinLineWidth: 0.8,
                    thickLineWidth: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return gridContent;
  }

  // Colors for each grid size
  static const Map<int, List<Color>> _sizeColors = {
    2: [AppColors.success, AppColors.successLight], // Green
    3: [AppColors.accent, AppColors.accentLight], // Blue
    4: [AppColors.constraintPurple, AppColors.constraintPurpleLight], // Purple
  };

  Widget _makeSudokuSizeCard(BuildContext ctx, int n, double cardSize, {bool isSketchedStyle = false, Color? sketchedLineColor}) {
    final bool isSelected = _selectedSize == n;
    final colors = _sizeColors[n]!;
    final int totalCells = n * n;
    final String sizeLabel = '${totalCells}×$totalCells';
    final String difficultyLabel = n == 2 ? 'Easy' : n == 3 ? 'Classic' : 'Challenge';

    return GestureDetector(
      onTap: () {
        setState(() {
          // Simply toggle selection - animation runs continuously
          final newSize = (_selectedSize == n) ? -1 : n;
          _selectedSize = newSize;
          // Reset difficulty to default (Hard) when changing size
          // For n>=3, default to Hard (null = load from files)
          _selectedDifficulty = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: cardSize,
        height: cardSize,
        margin: EdgeInsets.all(cardSize * 0.04),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [colors[0], colors[1]]
                : [colors[0].withOpacity(0.7), colors[1].withOpacity(0.7)],
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(isSelected ? 0.5 : 0.3),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
        transform: isSelected
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        child: Padding(
          padding: EdgeInsets.all(cardSize * 0.06),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini grid preview with animation when selected
                _buildMiniGrid(
                  n,
                  cardSize * 0.42,
                  isSketchedStyle ? (sketchedLineColor ?? Colors.white) : Colors.white,
                  isSketchedStyle ? (sketchedLineColor ?? Colors.white) : Colors.white,
                  animate: isSelected && !isSketchedStyle,
                  isSketchedStyle: isSketchedStyle,
                ),
                SizedBox(height: cardSize * 0.03),
                // Size label with optional check icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sizeLabel,
                      style: TextStyle(
                        fontSize: cardSize * 0.11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      SizedBox(width: cardSize * 0.03),
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: cardSize * 0.09,
                      ),
                    ],
                  ],
                ),
                // Difficulty label
                Text(
                  difficultyLabel,
                  style: TextStyle(
                    fontSize: cardSize * 0.07,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.sudokuThemeFunc(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Choose Your Grid',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.palette,
              color: theme.iconColor,
            ),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'light':
                    theme.onThemeModeChange(ThemeMode.light);
                    break;
                  case 'dark':
                    theme.onThemeModeChange(ThemeMode.dark);
                    break;
                  case 'system':
                    theme.onThemeModeChange(ThemeMode.system);
                    break;
                  case 'modern':
                    theme.onThemeStyleChange(ThemeStyle.modern);
                    break;
                  case 'penAndPaper':
                    theme.onThemeStyleChange(ThemeStyle.penAndPaper);
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'BRIGHTNESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.mutedPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'light',
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny, size: 20),
                    const SizedBox(width: 12),
                    const Text('Light'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'dark',
                child: Row(
                  children: [
                    const Icon(Icons.nights_stay, size: 20),
                    const SizedBox(width: 12),
                    const Text('Dark'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'system',
                child: Row(
                  children: [
                    const Icon(Icons.settings_brightness, size: 20),
                    const SizedBox(width: 12),
                    const Text('System'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'STYLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.mutedPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'modern',
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: theme.currentStyle == ThemeStyle.modern
                          ? AppColors.primaryPurple
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Modern',
                      style: TextStyle(
                        fontWeight: theme.currentStyle == ThemeStyle.modern
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: theme.currentStyle == ThemeStyle.modern
                            ? AppColors.primaryPurple
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'penAndPaper',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 20,
                      color: theme.currentStyle == ThemeStyle.penAndPaper
                          ? AppColors.primaryPurple
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pen & Paper',
                      style: TextStyle(
                        fontWeight: theme.currentStyle == ThemeStyle.penAndPaper
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: theme.currentStyle == ThemeStyle.penAndPaper
                            ? AppColors.primaryPurple
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.iconColor,
            ),
            onSelected: (value) {
              if (value == 'licenses') {
                showLicensePage(
                  context: context,
                  applicationName: 'Sudaku',
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'licenses',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Licenses'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;

            // Calculate card size with minimum sizes for usability
            double cardSize;
            const double minCardSize = 120.0;

            if (isPortrait) {
              // Reserve space for START button (88px) + difficulty selector (62px when visible) + padding (24px)
              final double reservedHeight = 88 + 62 + 24;
              final double availableForCards = availableHeight - reservedHeight;
              cardSize = max(minCardSize, min(
                availableWidth * 0.65,
                availableForCards / 3.2,
              ));
            } else {
              cardSize = max(minCardSize, min(
                availableHeight * 0.7,
                (availableWidth - 48) / 3.5,
              ));
            }

            final cards = [
              _makeSudokuSizeCard(context, 2, cardSize,
                  isSketchedStyle: theme.isSketchedStyle,
                  sketchedLineColor: theme.foreground),
              _makeSudokuSizeCard(context, 3, cardSize,
                  isSketchedStyle: theme.isSketchedStyle,
                  sketchedLineColor: theme.foreground),
              _makeSudokuSizeCard(context, 4, cardSize,
                  isSketchedStyle: theme.isSketchedStyle,
                  sketchedLineColor: theme.foreground),
            ];

            final double totalCardsHeight = cardSize * 3 + cardSize * 0.08 * 6;
            final double reservedForControls = 88 + 62 + 24; // START + difficulty selector + padding
            final bool needsScroll = isPortrait && totalCardsHeight > (availableHeight - reservedForControls);

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Expanded(
                    child: isPortrait
                        ? (needsScroll
                            ? ListView(children: cards)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: cards,
                              ))
                        : Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: cards,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(height: min(16, availableHeight * 0.02)),
                  // Difficulty selection (for 9x9 and 16x16)
                  AnimatedOpacity(
                    opacity: _selectedSize >= 3 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSlide(
                      offset: _selectedSize >= 3
                          ? Offset.zero
                          : const Offset(0, 0.5),
                      duration: const Duration(milliseconds: 200),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: min(availableWidth * 0.9, 350),
                          maxHeight: min(50, availableHeight * 0.08),
                        ),
                        child: _buildDifficultySelector(context),
                      ),
                    ),
                  ),
                  if (_selectedSize >= 3) SizedBox(height: min(12, availableHeight * 0.015)),
                  // Play button
                  AnimatedOpacity(
                    opacity: _selectedSize == -1 ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSlide(
                      offset: _selectedSize == -1
                          ? const Offset(0, 0.5)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: min(availableWidth * 0.8, 300),
                          maxHeight: min(56, availableHeight * 0.1),
                        ),
                        child: ElevatedButton(
                          onPressed: _selectedSize == -1 ? null : () {
                            Navigator.pushNamed(
                              widget.parentContext,
                              SudokuScreen.routeName,
                              arguments: SudokuScreenArguments(
                                n: _selectedSize,
                                isDemoMode: _isDemoMode,
                                demoPuzzle: _isDemoMode && _selectedSize == 3
                                    ? parseDemoPuzzle(demoPuzzle9x9)
                                    : null,
                                addDemoConstraints: _isDemoMode && _selectedSize == 3,
                                generatedDifficulty: _selectedDifficulty,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sizeColors[_selectedSize]?[0] ?? Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(min(28, availableHeight * 0.05)),
                            ),
                            elevation: 8,
                            shadowColor: _sizeColors[_selectedSize]?[0]?.withOpacity(0.5),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 32),
                                  SizedBox(width: 8),
                                  Text(
                                    'START',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: min(16, availableHeight * 0.02)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Map<String, dynamic>? _savedPuzzle;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _loadSavedPuzzle();
  }

  Future<void> _loadSavedPuzzle() async {
    final saved = await SudokuScreenState.loadSavedPuzzle();
    if (mounted) {
      setState(() {
        _savedPuzzle = saved;
      });
    }
  }

  void _continueSavedPuzzle() async {
    if (_savedPuzzle == null) return;
    final n = _savedPuzzle!['n'] as int;
    final buffer = (_savedPuzzle!['buffer'] as List).cast<int>();
    final hints = (_savedPuzzle!['hints'] as List).cast<int>();

    // Don't clear saved puzzle - let it persist until explicit exit or victory
    Navigator.pushNamed(
      context,
      SudokuScreen.routeName,
      arguments: SudokuScreenArguments(
        n: n,
        savedBuffer: buffer,
        savedHints: hints,
        savedState: _savedPuzzle,
      ),
    ).then((_) => _loadSavedPuzzle());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Build a mini sudoku grid preview (static version for main menu)
  Widget _buildMiniGrid(int n, double size, Color primaryColor, Color secondaryColor, {bool isSketchedStyle = false}) {
    final int gridSize = n * n;

    Widget gridContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSketchedStyle ? 4 : 8),
        border: isSketchedStyle ? null : Border.all(color: primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSketchedStyle ? 2 : 6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            final int row = index ~/ gridSize;
            final int col = index % gridSize;
            final int boxRow = row ~/ n;
            final int boxCol = col ~/ n;
            final bool isEvenBox = (boxRow + boxCol) % 2 == 0;

            if (isSketchedStyle) {
              // Simpler look for pen-and-paper style
              return Container(
                color: isEvenBox
                    ? primaryColor.withOpacity(0.1)
                    : secondaryColor.withOpacity(0.05),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isEvenBox ? primaryColor.withOpacity(0.3) : secondaryColor.withOpacity(0.2),
                border: Border(
                  right: BorderSide(
                    color: (col + 1) % n == 0 && col < gridSize - 1
                        ? primaryColor
                        : primaryColor.withOpacity(0.2),
                    width: (col + 1) % n == 0 ? 1.5 : 0.5,
                  ),
                  bottom: BorderSide(
                    color: (row + 1) % n == 0 && row < gridSize - 1
                        ? primaryColor
                        : primaryColor.withOpacity(0.2),
                    width: (row + 1) % n == 0 ? 1.5 : 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    // For sketched style, overlay hand-drawn grid lines
    if (isSketchedStyle) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            gridContent,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SketchedGridPainter(
                    n: n,
                    lineColor: primaryColor,
                    size: size,
                    wobbleAmount: 2.0,
                    thinLineWidth: 0.8,
                    thickLineWidth: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return gridContent;
  }

  Future<void> _showPlayDialog(BuildContext ctx) async {
    await showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Select sudoku size',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      pageBuilder: (_, __, ___) {
        return _SizeSelectionContent(
          sudokuThemeFunc: widget.sudokuThemeFunc,
          parentContext: this.context,
        );
      },
    );
  }

  Widget _buildDecorationGrid(double size, Color color, {bool isSketchedStyle = false}) {
    return Opacity(
      opacity: isSketchedStyle ? 0.15 : 0.1,
      child: _buildMiniGrid(3, size, color, color, isSketchedStyle: isSketchedStyle),
    );
  }

  Widget build(BuildContext ctx) {
    final theme = widget.sudokuThemeFunc(ctx);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SUDAKU',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: 4,
            color: theme.dialogTitleColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.emoji_events_rounded,
              color: theme.iconColor,
            ),
            onPressed: () => Navigator.pushNamed(context, TrophyRoomScreen.routeName),
            tooltip: 'Trophy Room',
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.palette,
              color: theme.iconColor,
            ),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'light':
                    theme.onThemeModeChange(ThemeMode.light);
                    break;
                  case 'dark':
                    theme.onThemeModeChange(ThemeMode.dark);
                    break;
                  case 'system':
                    theme.onThemeModeChange(ThemeMode.system);
                    break;
                  case 'modern':
                    theme.onThemeStyleChange(ThemeStyle.modern);
                    break;
                  case 'penAndPaper':
                    theme.onThemeStyleChange(ThemeStyle.penAndPaper);
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'BRIGHTNESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.mutedPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'light',
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny, size: 20),
                    const SizedBox(width: 12),
                    const Text('Light'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'dark',
                child: Row(
                  children: [
                    const Icon(Icons.nights_stay, size: 20),
                    const SizedBox(width: 12),
                    const Text('Dark'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'system',
                child: Row(
                  children: [
                    const Icon(Icons.settings_brightness, size: 20),
                    const SizedBox(width: 12),
                    const Text('System'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'STYLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.mutedPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'modern',
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: theme.currentStyle == ThemeStyle.modern
                          ? AppColors.primaryPurple
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Modern',
                      style: TextStyle(
                        fontWeight: theme.currentStyle == ThemeStyle.modern
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: theme.currentStyle == ThemeStyle.modern
                            ? AppColors.primaryPurple
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'penAndPaper',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 20,
                      color: theme.currentStyle == ThemeStyle.penAndPaper
                          ? AppColors.primaryPurple
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pen & Paper',
                      style: TextStyle(
                        fontWeight: theme.currentStyle == ThemeStyle.penAndPaper
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: theme.currentStyle == ThemeStyle.penAndPaper
                            ? AppColors.primaryPurple
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.iconColor,
            ),
            onSelected: (value) {
              if (value == 'licenses') {
                showLicensePage(
                  context: context,
                  applicationName: 'Sudaku',
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'licenses',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Licenses'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;
            final double shortestSide = min(availableWidth, availableHeight);

            // Scale logo size based on screen - larger on bigger screens
            final double logoSize = min(shortestSide * 0.4, 280);
            final double buttonWidth = min(shortestSide * 0.5, 320);
            final double buttonHeight = min(shortestSide * 0.15, 72);

            // Decoration grid sizes scale with screen
            final double decorSize = shortestSide * 0.2;

            return Stack(
              children: [
                // Decorative background grids - positioned to avoid app bar
                Positioned(
                  top: availableHeight * 0.15,
                  left: -decorSize * 0.4,
                  child: Transform.rotate(
                    angle: theme.isSketchedStyle ? -0.15 : -0.2,
                    child: _buildDecorationGrid(
                      decorSize,
                      theme.foreground ?? theme.dialogTitleColor,
                      isSketchedStyle: theme.isSketchedStyle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -decorSize * 0.3,
                  right: -decorSize * 0.3,
                  child: Transform.rotate(
                    angle: theme.isSketchedStyle ? 0.2 : 0.3,
                    child: _buildDecorationGrid(
                      decorSize * 1.2,
                      theme.foreground ?? theme.dialogTitleColor,
                      isSketchedStyle: theme.isSketchedStyle,
                    ),
                  ),
                ),
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated mini grid as logo
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: theme.isSketchedStyle ? 1.0 : (1.0 + (_pulseController.value * 0.05)),
                            child: _buildMiniGrid(
                              3,
                              logoSize,
                              theme.isSketchedStyle
                                  ? (theme.foreground ?? Colors.black)
                                  : theme.logoColorPrimary,
                              theme.isSketchedStyle
                                  ? (theme.foreground ?? Colors.black)
                                  : theme.logoColorSecondary,
                              isSketchedStyle: theme.isSketchedStyle,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: shortestSide * 0.06),
                      // Continue button (if saved puzzle exists)
                      if (_savedPuzzle != null) ...[
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.03),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: _continueSavedPuzzle,
                            child: Container(
                              width: buttonWidth,
                              height: buttonHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(buttonHeight * 0.5),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.success,
                                    AppColors.successLight,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.4),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: buttonHeight * 0.5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CONTINUE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: buttonHeight * 0.35,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: shortestSide * 0.03),
                      ],
                      // Play button
                      GestureDetector(
                        onTap: () => _showPlayDialog(ctx),
                        child: Container(
                          width: buttonWidth,
                          height: _savedPuzzle != null ? buttonHeight * 0.7 : buttonHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(buttonHeight * 0.5),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _savedPuzzle != null
                                  ? [
                                      AppColors.primaryPurple.withOpacity(0.7),
                                      AppColors.secondaryPurple.withOpacity(0.7),
                                    ]
                                  : [
                                      AppColors.primaryPurple,
                                      AppColors.secondaryPurple,
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withOpacity(_savedPuzzle != null ? 0.2 : 0.4),
                                blurRadius: _savedPuzzle != null ? 15 : 25,
                                offset: Offset(0, _savedPuzzle != null ? 5 : 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _savedPuzzle != null ? Icons.add_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: (_savedPuzzle != null ? buttonHeight * 0.7 : buttonHeight) * 0.5,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _savedPuzzle != null ? 'NEW' : 'PLAY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (_savedPuzzle != null ? buttonHeight * 0.7 : buttonHeight) * 0.35,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: shortestSide * 0.04),
                      // Subtitle
                      Text(
                        _savedPuzzle != null ? 'Continue or start new' : 'Tap to begin',
                        style: TextStyle(
                          color: theme.subtitleColor,
                          fontSize: min(16, shortestSide * 0.025),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
