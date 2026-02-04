import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';
import 'SudokuScreen.dart';

class MenuScreen extends StatefulWidget {
  Function(BuildContext) sudokuThemeFunc;

  MenuScreen({required this.sudokuThemeFunc});

  State createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Build a mini sudoku grid preview
  Widget _buildMiniGrid(int n, double size, Color primaryColor, Color secondaryColor) {
    final int gridSize = n * n;
    final double cellSize = size / gridSize;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
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
  }

  // Colors for each grid size
  static const Map<int, List<Color>> _sizeColors = {
    2: [Color(0xFF4CAF50), Color(0xFF81C784)], // Green
    3: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Blue
    4: [Color(0xFF9C27B0), Color(0xFFBA68C8)], // Purple
  };

  Widget _makeSudokuSizeCard(BuildContext ctx, Function setState, int n, double cardSize) {
    final bool isSelected = _selectedSize == n;
    final colors = _sizeColors[n]!;
    final int totalCells = n * n;
    final String sizeLabel = '${totalCells}×$totalCells';
    final String difficultyLabel = n == 2 ? 'Easy' : n == 3 ? 'Classic' : 'Challenge';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSize = isSelected ? -1 : n;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.all(cardSize * 0.05),
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
          padding: EdgeInsets.all(cardSize * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mini grid preview
              Expanded(
                flex: 3,
                child: Center(
                  child: _buildMiniGrid(
                    n,
                    cardSize * 0.45,
                    Colors.white,
                    Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Size label
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: cardSize * 0.12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              // Difficulty label
              Text(
                difficultyLabel,
                style: TextStyle(
                  fontSize: cardSize * 0.08,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: cardSize * 0.1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _selectedSize = -1;

  Future<void> _showPlayDialog(BuildContext ctx) async {
    _selectedSize = -1;
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
        return StatefulBuilder(
          builder: (ctx, setState) {
            final theme = widget.sudokuThemeFunc(ctx);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF1a1a2e) : const Color(0xFFF5F5F5),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'Choose Your Grid',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(isDark ? Icons.wb_sunny : Icons.nights_stay),
                    onPressed: () {
                      setState(() {
                        theme.onChange(isDark ? ThemeMode.light : ThemeMode.dark);
                      });
                    },
                  ),
                ],
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
                    final double availableWidth = constraints.maxWidth;
                    final double availableHeight = constraints.maxHeight;

                    double cardSize;
                    if (isPortrait) {
                      cardSize = min(availableWidth * 0.85, availableHeight * 0.28);
                    } else {
                      cardSize = min(availableHeight * 0.7, availableWidth * 0.28);
                    }

                    final cards = [
                      _makeSudokuSizeCard(ctx, setState, 2, cardSize),
                      _makeSudokuSizeCard(ctx, setState, 3, cardSize),
                      _makeSudokuSizeCard(ctx, setState, 4, cardSize),
                    ];

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: isPortrait
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: cards.map((c) => Expanded(child: c)).toList(),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: cards.map((c) => Expanded(child: c)).toList(),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          // Play button
                          AnimatedOpacity(
                            opacity: _selectedSize == -1 ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedSlide(
                              offset: _selectedSize == -1
                                  ? const Offset(0, 0.5)
                                  : Offset.zero,
                              duration: const Duration(milliseconds: 200),
                              child: SizedBox(
                                width: min(availableWidth * 0.8, 300),
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _selectedSize == -1 ? null : () {
                                    Navigator.pushNamed(
                                      this.context,
                                      SudokuScreen.routeName,
                                      arguments: SudokuScreenArguments(n: _selectedSize),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _sizeColors[_selectedSize]?[0] ?? Colors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 8,
                                    shadowColor: _sizeColors[_selectedSize]?[0].withOpacity(0.5),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDecorationGrid(double size, Color color) {
    return Opacity(
      opacity: 0.1,
      child: _buildMiniGrid(3, size, color, color),
    );
  }

  Widget build(BuildContext ctx) {
    final theme = widget.sudokuThemeFunc(ctx);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1a2e) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SUDAKU',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: 4,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny : Icons.nights_stay,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              setState(() {
                theme.onChange(isDark ? ThemeMode.light : ThemeMode.dark);
              });
            },
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
                // Decorative background grids
                Positioned(
                  top: -decorSize * 0.25,
                  left: -decorSize * 0.25,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: _buildDecorationGrid(
                      decorSize,
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -decorSize * 0.3,
                  right: -decorSize * 0.3,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: _buildDecorationGrid(
                      decorSize * 1.2,
                      isDark ? Colors.white : Colors.black,
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
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: _buildMiniGrid(
                              3,
                              logoSize,
                              isDark ? Colors.blue[300]! : Colors.blue[600]!,
                              isDark ? Colors.blue[200]! : Colors.blue[400]!,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: shortestSide * 0.06),
                      // Play button
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.03),
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: () => _showPlayDialog(ctx),
                          child: Container(
                            width: buttonWidth,
                            height: buttonHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(buttonHeight * 0.5),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF667eea),
                                  Color(0xFF764ba2),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.4),
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
                                  'PLAY',
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
                      SizedBox(height: shortestSide * 0.04),
                      // Subtitle
                      Text(
                        'Tap to begin',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
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
