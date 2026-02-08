import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'TrophyRoom.dart';
import 'SudokuScreen.dart';
import 'sudoku_native.dart';

Color _getDifficultyColor(double normalized) {
  if (normalized < 0.15) return AppColors.success;
  if (normalized < 0.35) return AppColors.accent;
  if (normalized < 0.55) return AppColors.warning;
  if (normalized < 0.75) return AppColors.constraintPurple;
  return AppColors.error;
}

class TrophyRoomScreen extends StatefulWidget {
  static const String routeName = '/trophy_room';
  final Function(BuildContext) sudokuThemeFunc;

  TrophyRoomScreen({required this.sudokuThemeFunc});

  @override
  State createState() => TrophyRoomScreenState();
}

class TrophyRoomScreenState extends State<TrophyRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PuzzleRecord> _puzzleRecords = [];
  Map<AchievementType, Achievement> _achievements = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await TrophyRoomStorage.loadPuzzleRecords();
    final achievements = await TrophyRoomStorage.loadAchievements();

    // Compute difficulty for any puzzles missing it
    bool needsSave = false;
    for (int i = 0; i < records.length; i++) {
      if (records[i].difficultyForwards == null) {
        try {
          final puzzleBuffer = records[i].buildLaunchBuffer();
          final stats = SudokuNative.estimateDifficulty(puzzleBuffer, records[i].n, numSamples: 10);
          if (stats != null && stats['avgForwards'] != null) {
            records[i] = PuzzleRecord(
              id: records[i].id,
              n: records[i].n,
              hints: records[i].hints,
              hintValues: records[i].hintValues,
              completedAt: records[i].completedAt,
              moveCount: records[i].moveCount,
              nickname: records[i].nickname,
              difficultyForwards: stats['avgForwards'],
            );
            needsSave = true;
          }
        } catch (e) {
          // Native library might not be available, skip
        }
      }
    }

    // Save updated records if any were modified
    if (needsSave) {
      await TrophyRoomStorage.savePuzzleRecords(records);
    }

    if (mounted) {
      setState(() {
        _puzzleRecords = records;
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sharePuzzle(PuzzleRecord record) {
    final dotNotation = record.toDotNotation();
    final gridSize = record.ne2;
    final shareText = 'Sudaku Puzzle (${gridSize}x$gridSize):\n$dotNotation';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Puzzle copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _launchPuzzle(PuzzleRecord record) {
    Navigator.pushNamed(
      context,
      SudokuScreen.routeName,
      arguments: SudokuScreenArguments(
        n: record.n,
        savedBuffer: record.buildLaunchBuffer(),
        savedHints: record.hints,
      ),
    );
  }

  Future<void> _deletePuzzle(PuzzleRecord record) async {
    final theme = widget.sudokuThemeFunc(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Text('Delete Puzzle', style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.dialogTitleColor,
            )),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this puzzle?',
          style: TextStyle(color: theme.dialogTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.cancelButtonColor)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TrophyRoomStorage.deletePuzzleRecord(record.id);
      _loadData();
    }
  }

  Future<void> _showImportDialog() async {
    final theme = widget.sudokuThemeFunc(context);
    String inputNotation = '';
    int selectedN = 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.download_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Text('Import Puzzle', style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.dialogTitleColor,
              )),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grid Size:', style: TextStyle(
                  color: theme.dialogTextColor,
                  fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('4x4')),
                    ButtonSegment(value: 3, label: Text('9x9')),
                    ButtonSegment(value: 4, label: Text('16x16')),
                  ],
                  selected: {selectedN},
                  onSelectionChanged: (selection) {
                    setDialogState(() => selectedN = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                Text('Dot Notation:', style: TextStyle(
                  color: theme.dialogTextColor,
                  fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 4,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: theme.dialogTitleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste puzzle here...\n(use . for empty cells)',
                    hintStyle: TextStyle(color: theme.mutedPrimary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => inputNotation = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: theme.cancelButtonColor)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final record = PuzzleRecord.fromDotNotation(inputNotation, selectedN);
                if (record != null) {
                  TrophyRoomStorage.addPuzzleRecord(record);
                  Navigator.of(ctx).pop();
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Puzzle imported!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invalid notation for ${selectedN * selectedN}x${selectedN * selectedN} grid'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGrid(int n, double size, Color lineColor, List<int> hints, List<int> hintValues) {
    final ne2 = n * n;
    final ne4 = ne2 * ne2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: lineColor.withOpacity(0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ne2,
          ),
          itemCount: ne4,
          itemBuilder: (context, index) {
            final hintIndex = hints.indexOf(index);
            final hasValue = hintIndex != -1;
            final row = index ~/ ne2;
            final col = index % ne2;
            final boxRow = row ~/ n;
            final boxCol = col ~/ n;
            final isEvenBox = (boxRow + boxCol) % 2 == 0;

            return Container(
              decoration: BoxDecoration(
                color: hasValue
                    ? lineColor.withOpacity(0.15)
                    : isEvenBox
                        ? lineColor.withOpacity(0.05)
                        : Colors.transparent,
                border: Border(
                  right: BorderSide(
                    color: (col + 1) % n == 0 && col < ne2 - 1
                        ? lineColor.withOpacity(0.5)
                        : lineColor.withOpacity(0.1),
                    width: (col + 1) % n == 0 ? 1 : 0.5,
                  ),
                  bottom: BorderSide(
                    color: (row + 1) % n == 0 && row < ne2 - 1
                        ? lineColor.withOpacity(0.5)
                        : lineColor.withOpacity(0.1),
                    width: (row + 1) % n == 0 ? 1 : 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPuzzleCard(PuzzleRecord record, SudokuTheme theme) {
    final gridSize = record.ne2;
    final dateStr = '${record.completedAt.day}/${record.completedAt.month}/${record.completedAt.year}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildMiniGrid(
              record.n,
              60,
              theme.foreground ?? Colors.grey,
              record.hints,
              record.hintValues,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.nickname ?? '${gridSize}x$gridSize Puzzle',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.dialogTitleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed: $dateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.mutedPrimary,
                    ),
                  ),
                  Text(
                    '${record.hints.length} hints, ${record.moveCount} moves',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.mutedPrimary,
                    ),
                  ),
                  if (record.difficultyNormalized != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _getDifficultyColor(record.difficultyNormalized!),
                      ),
                      child: Text(
                        record.difficultyLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  color: AppColors.accent,
                  onPressed: () => _sharePuzzle(record),
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  color: AppColors.success,
                  onPressed: () => _launchPuzzle(record),
                  tooltip: 'Replay',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  onPressed: () => _deletePuzzle(record),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, SudokuTheme theme) {
    final isUnlocked = achievement.isUnlocked;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      elevation: isUnlocked ? 4 : 1,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isUnlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: achievement.gradientColors,
                        )
                      : null,
                  color: isUnlocked ? null : theme.disabledBg,
                ),
                child: Icon(
                  isUnlocked ? achievement.icon : Icons.lock_rounded,
                  color: isUnlocked ? Colors.white : theme.disabledFg,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.dialogTitleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.mutedPrimary,
                      ),
                    ),
                    if (achievement.target != null && !isUnlocked) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: achievement.progressPercent,
                        backgroundColor: theme.disabledBg,
                        valueColor: AlwaysStoppedAnimation(
                          achievement.gradientColors.first,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${achievement.progress ?? 0}/${achievement.target}',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.mutedSecondary,
                        ),
                      ),
                    ],
                    // Note: Unlock dates are not displayed since achievements
                    // are now derived from stats (not stored with timestamps)
                  ],
                ),
              ),
              if (isUnlocked)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzlesTab(SudokuTheme theme) {
    if (_puzzleRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off_rounded,
              size: 64,
              color: theme.mutedPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              'No puzzles yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.mutedPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete puzzles to see them here',
              style: TextStyle(
                fontSize: 14,
                color: theme.mutedSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _puzzleRecords.length,
      itemBuilder: (ctx, index) => _buildPuzzleCard(_puzzleRecords[index], theme),
    );
  }

  Widget _buildSectionHeader(String title, SudokuTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.mutedPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAchievementsTab(SudokuTheme theme) {
    // Define achievement sections
    final sections = <String, List<AchievementType>>{
      'COMPLETION': [
        AchievementType.firstSolve,
        AchievementType.tenPuzzles,
        AchievementType.twentyFivePuzzles,
        AchievementType.fiftyPuzzles,
      ],
      'SIZE': [
        AchievementType.size4x4Master,
        AchievementType.size9x9Master,
        AchievementType.size16x16Master,
        AchievementType.allSizesMaster,
      ],
      'SKILL': [
        AchievementType.speedDemon,
        AchievementType.constraintMaster,
        AchievementType.constraintOnly9x9,
      ],
      'LEARNING': [
        AchievementType.tutorialComplete,
      ],
      'EASY': [
        AchievementType.easy1,
        AchievementType.easy5,
        AchievementType.easy10,
      ],
      'MEDIUM': [
        AchievementType.medium1,
        AchievementType.medium5,
        AchievementType.medium10,
      ],
      'HARD': [
        AchievementType.hard1,
        AchievementType.hard5,
        AchievementType.hard10,
      ],
      'EXPERT': [
        AchievementType.expert1,
        AchievementType.expert5,
      ],
      'EXTREME': [
        AchievementType.extreme1,
        AchievementType.extreme3,
      ],
    };

    // Build list items with section headers
    final items = <Widget>[];
    for (final entry in sections.entries) {
      final sectionAchievements = entry.value
          .where((type) => _achievements.containsKey(type))
          .map((type) => _achievements[type]!)
          .toList();

      if (sectionAchievements.isNotEmpty) {
        items.add(_buildSectionHeader(entry.key, theme));
        for (final achievement in sectionAchievements) {
          items.add(_buildAchievementCard(achievement, theme));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.sudokuThemeFunc(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trophy Room',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.dialogTitleColor,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.dialogTitleColor,
          unselectedLabelColor: theme.mutedPrimary,
          indicatorColor: AppColors.primaryPurple,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Puzzles'),
            Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Achievements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPuzzlesTab(theme),
          _buildAchievementsTab(theme),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showImportDialog,
              backgroundColor: AppColors.primaryPurple,
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text('Import', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}
