import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:bit_array/bit_array.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'main.dart';
import 'Sudoku.dart';
import 'SudokuAssist.dart';
import 'SudokuBuffer.dart';
import 'SudokuDomain.dart';
import 'SudokuNumpadScreen.dart';
import 'SudokuAssistScreen.dart';
import 'TrophyRoom.dart';
import 'demo_data.dart';
import 'sudoku_native.dart';


/// Helper widget that renders text with a slight random wobble for pen-and-paper style
/// Uses index-based seeding for consistent randomness
class WobblyText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int seed;
  final double wobbleAngle;
  final double wobbleOffset;

  const WobblyText({
    Key? key,
    required this.text,
    required this.style,
    required this.seed,
    this.wobbleAngle = 0.06,   // Max rotation in radians (~3.5 degrees)
    this.wobbleOffset = 1.5,   // Max offset in pixels
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use seed to create consistent random values
    final random = Random(seed);
    final angle = (random.nextDouble() - 0.5) * wobbleAngle * 2;
    final offsetX = (random.nextDouble() - 0.5) * wobbleOffset * 2;
    final offsetY = (random.nextDouble() - 0.5) * wobbleOffset * 2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(offsetX, offsetY)
        ..rotateZ(angle),
      child: Text(text, style: style),
    );
  }
}

class SudokuScreen extends StatefulWidget {
  static const String routeName = '/sudoku_arguments';

  Function(BuildContext) sudokuThemeFunc;

  SudokuScreen({required this.sudokuThemeFunc});

  State createState() => SudokuScreenState();
}

class SudokuScreenArguments {
  final int n;
  final bool isDemoMode;
  final List<int>? demoPuzzle;
  final bool addDemoConstraints;
  final List<int>? savedBuffer;
  final List<int>? savedHints;
  // Full saved state from persistence
  final Map<String, dynamic>? savedState;
  // Generate puzzle with specified difficulty (0.0=easy, 1.0=hard)
  // null = load from hard puzzle files (top1465/top44)
  final double? generatedDifficulty;

  SudokuScreenArguments({
    required this.n,
    this.isDemoMode = false,
    this.demoPuzzle,
    this.addDemoConstraints = false,
    this.savedBuffer,
    this.savedHints,
    this.savedState,
    this.generatedDifficulty,
  });
}

abstract class ConstraintInteraction {
  late SudokuScreenState self;
  late Sudoku sd;

  ConstraintInteraction(SudokuScreenState ss) {
    this.self = ss;
    this.sd = ss.sd!;
  }

  void finishOnSelection() {
    self.interact = null;
    self.endMultiSelect();
    self.runSetState();
    if(self._showTutorial && self._tutorialStage == 2) {
      self._tutorialStage = 3;
      // Auto-show final tutorial hint
      WidgetsBinding.instance.addPostFrameCallback((_) {
        self._showTutorialMessage(
            title: "New constraint",
            message: 'Assistant is used to simplify mechanical deductions. It will now account for the new rule.',
            nextFunc: () {
              self._showTutorialMessage(
                title: 'Assistant',
                message: 'Once you get used to using constraints, you should enable default rules through the settings.',
                nextFunc: () {
                  self._completeTutorial();
                }
              );
            }
        );
      });
    }
  }

  Future<void> onSelection();
}

class OneofInteraction extends ConstraintInteraction {
  OneofInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    BitArray dom = self.sd!.getEmptyDomain();
    for(int v in self._multiSelect!.asIntIterable()) {
      dom = dom | self.sd!.getDomain(v);
    }
    var val = await self._showSelectionNumpad(NumpadInteractionType.SELECT_VALUE, 1);
    if(val == null) {
      return;
    }
    final constraint = ConstraintOneOf(sd, self._multiSelect!, val);
    sd.assist.addConstraint(constraint);
    self._lastUserAddedConstraint = constraint;
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EqualInteraction extends ConstraintInteraction {
  EqualInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    final constraint = ConstraintEqual(sd, this.self._multiSelect!);
    sd.assist.addConstraint(constraint);
    self._lastUserAddedConstraint = constraint;
    self.runAssistant();
    this.finishOnSelection();
  }
}

class AlldiffInteraction extends ConstraintInteraction {
  AlldiffInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.MULTISELECTION, self._multiSelect!.cardinality);
    if(selection == null || selection.cardinality != self._multiSelect!.cardinality) {
      return;
    }
    final constraint = ConstraintAllDiff(sd, self._multiSelect!, selection);
    sd.assist.addConstraint(constraint);
    self._lastUserAddedConstraint = constraint;
    self.runAssistant();
    this.finishOnSelection();
  }
}

class EliminatorInteraction extends ConstraintInteraction {
  EliminatorInteraction(SudokuScreenState ss) : super(ss) {}

  @override
  Future<void> onSelection() async {
    var selection = await self._showSelectionNumpad(NumpadInteractionType.ANTISELECTION, -1);
    if(selection == null) {
      return;
    }
    EliminatorInteractionReturnType changes = selection;
    for(int v in self._multiSelect!.asIntIterable()) {
      var diff = (sd.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd.assist.elim[v].invertBits(diff.asIntIterable());
    }
    self.runAssistant();
    this.finishOnSelection();
  }
}

class SudokuScreenState extends State<SudokuScreen> {
  Sudoku? sd = null;
  ConstraintInteraction? interact = null;

  BitArray? _multiSelect = null;
  int _selectedCell = -1;

  double screenWidth = 0,
         screenHeight = 0;

  // Demo mode flag - no saving/restoring in demo mode
  bool _isDemoMode = false;

  // Difficulty tracking
  int? _initialDifficultyForwards;  // Difficulty of original puzzle (hints only)
  int? _currentDifficultyForwards;  // Live difficulty (current state)
  bool _difficultyLoading = false;

  // Track last constraint added by user in current session (not restored)
  Constraint? _lastUserAddedConstraint;

  // Track if this puzzle has already been won (don't show victory again)
  bool _puzzleAlreadyWon = false;

  void runSetState() {
    setState((){});
    // Skip saving in demo mode
    if (!_isDemoMode) {
      _autoSavePuzzleState();
      _saveAssistantSettings(); // Save settings globally
    }
    // Update live difficulty if enabled
    if (sd != null && sd!.assist.showDifficulty && sd!.assist.showLiveDifficulty) {
      _estimateDifficulty(isInitial: false);
    }
  }

  // Auto-save with debouncing to avoid excessive writes
  DateTime? _lastAutoSave;
  void _autoSavePuzzleState() {
    final now = DateTime.now();
    if (_lastAutoSave != null && now.difference(_lastAutoSave!).inMilliseconds < 500) {
      return; // Debounce: skip if last save was less than 500ms ago
    }
    _lastAutoSave = now;
    _savePuzzleState();
  }

  // Persistence keys
  static const String _savedPuzzleKey = 'savedPuzzle';
  static const String _assistantSettingsKey = 'assistantSettings';

  /// Save assistant settings as global preferences
  Future<void> _saveAssistantSettings() async {
    if (sd == null) return;
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'autoComplete': sd!.assist.autoComplete,
      'useDefaultConstraints': sd!.assist.useDefaultConstraints,
      'hintAvailable': sd!.assist.hintAvailable,
      'hintConstrained': sd!.assist.hintConstrained,
      'hintContradictions': sd!.assist.hintContradictions,
      'showDifficulty': sd!.assist.showDifficulty,
      'showLiveDifficulty': sd!.assist.showLiveDifficulty,
      'showDifficultyNumbers': sd!.assist.showDifficultyNumbers,
    };
    await prefs.setString(_assistantSettingsKey, jsonEncode(settings));
  }

  /// Restore assistant settings from global preferences
  Future<void> _restoreAssistantSettings() async {
    if (sd == null) return;
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_assistantSettingsKey);
    if (settingsJson == null) return;

    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      if (settings.containsKey('autoComplete')) {
        sd!.assist.autoComplete = settings['autoComplete'] as bool;
      }
      if (settings.containsKey('useDefaultConstraints')) {
        sd!.assist.useDefaultConstraints = settings['useDefaultConstraints'] as bool;
      }
      if (settings.containsKey('hintAvailable')) {
        sd!.assist.hintAvailable = settings['hintAvailable'] as bool;
      }
      if (settings.containsKey('hintConstrained')) {
        sd!.assist.hintConstrained = settings['hintConstrained'] as bool;
      }
      if (settings.containsKey('hintContradictions')) {
        sd!.assist.hintContradictions = settings['hintContradictions'] as bool;
      }
      if (settings.containsKey('showDifficulty')) {
        sd!.assist.showDifficulty = settings['showDifficulty'] as bool;
      }
      if (settings.containsKey('showLiveDifficulty')) {
        sd!.assist.showLiveDifficulty = settings['showLiveDifficulty'] as bool;
      }
      if (settings.containsKey('showDifficultyNumbers')) {
        sd!.assist.showDifficultyNumbers = settings['showDifficultyNumbers'] as bool;
      }
      // Propagate default constraints if settings enabled them
      // Use post-frame callback to ensure puzzle is fully loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sd != null && mounted) {
          runAssistant();
        }
      });
    } catch (e) {
      // Invalid settings, ignore
    }
  }

  Future<void> _savePuzzleState() async {
    if (sd == null) return;
    final prefs = await SharedPreferences.getInstance();

    // Serialize constraints
    final constraintsData = sd!.assist.constraints.map((c) {
      final data = <String, dynamic>{
        'type': c.type.index,
        'variables': c.variables.asIntIterable().toList(),
      };
      if (c is ConstraintOneOf) {
        data['value'] = c.value;
      } else if (c is ConstraintAllDiff) {
        data['domain'] = c.domain.asIntIterable().toList();
      }
      return data;
    }).toList();

    // Extract hint values
    final hintIndices = sd!.hints.asIntIterable().toList();
    final hintValues = hintIndices.map((i) => sd!.buf[i]).toList();

    // Serialize manual changes (non-assisted only)
    // Only save manual changes (not assisted ones)
    final manualChanges = sd!.changes.where((c) => !c.assisted).toList();
    final changesData = manualChanges.map((c) => {
      'variable': c.variable,
      'value': c.value,
      'prevValue': c.prevValue,
      'assisted': c.assisted,
    }).toList();

    // Only save manual values (hints + user-entered), not assistant-propagated ones
    final manualBuffer = List<int>.generate(sd!.ne4, (i) {
      if (sd!.isHint(i) || sd!.isVariableManual(i)) {
        return sd![i];
      }
      return 0;
    });

    final state = {
      'n': sd!.n,
      'buffer': manualBuffer,
      'hints': sd!.hints.asIntIterable().toList(),
      'changes': changesData,
      'puzzleAlreadyWon': _puzzleAlreadyWon,
      // Assistant settings
      'autoComplete': sd!.assist.autoComplete,
      'useDefaultConstraints': sd!.assist.useDefaultConstraints,
      'hintAvailable': sd!.assist.hintAvailable,
      'hintConstrained': sd!.assist.hintConstrained,
      'hintContradictions': sd!.assist.hintContradictions,
      'showDifficulty': sd!.assist.showDifficulty,
      'showLiveDifficulty': sd!.assist.showLiveDifficulty,
      'showDifficultyNumbers': sd!.assist.showDifficultyNumbers,
      // Constraints
      'constraints': constraintsData,
    };
    await prefs.setString(_savedPuzzleKey, jsonEncode(state));
  }

  void _restoreFullState(Map<String, dynamic> state) {
    if (sd == null) return;

    // Restore assistant settings FIRST (so propagation uses correct settings)
    if (state.containsKey('autoComplete')) {
      sd!.assist.autoComplete = state['autoComplete'] as bool;
    }
    if (state.containsKey('useDefaultConstraints')) {
      sd!.assist.useDefaultConstraints = state['useDefaultConstraints'] as bool;
    }
    if (state.containsKey('hintAvailable')) {
      sd!.assist.hintAvailable = state['hintAvailable'] as bool;
    }
    if (state.containsKey('hintConstrained')) {
      sd!.assist.hintConstrained = state['hintConstrained'] as bool;
    }
    if (state.containsKey('hintContradictions')) {
      sd!.assist.hintContradictions = state['hintContradictions'] as bool;
    }
    if (state.containsKey('showDifficulty')) {
      sd!.assist.showDifficulty = state['showDifficulty'] as bool;
    }
    if (state.containsKey('showLiveDifficulty')) {
      sd!.assist.showLiveDifficulty = state['showLiveDifficulty'] as bool;
    }
    if (state.containsKey('showDifficultyNumbers')) {
      sd!.assist.showDifficultyNumbers = state['showDifficultyNumbers'] as bool;
    }

    // Restore changes history
    if (state.containsKey('changes')) {
      final changesData = state['changes'] as List;
      sd!.changes.clear();
      for (final cData in changesData) {
        final data = cData as Map<String, dynamic>;
        sd!.changes.add(SudokuChange(
          variable: data['variable'] as int,
          value: data['value'] as int,
          prevValue: data['prevValue'] as int,
          assisted: data['assisted'] as bool,
        ));
      }
    }

    // Restore constraints
    if (state.containsKey('constraints')) {
      final constraintsData = state['constraints'] as List;
      for (final cData in constraintsData) {
        final data = cData as Map<String, dynamic>;
        final typeIndex = data['type'] as int;
        final variables = BitArray(sd!.ne4)
          ..setBits((data['variables'] as List).cast<int>());

        if (typeIndex == ConstraintType.ONE_OF.index) {
          final value = data['value'] as int;
          sd!.assist.addConstraint(ConstraintOneOf(sd!, variables, value));
        } else if (typeIndex == ConstraintType.EQUAL.index) {
          sd!.assist.addConstraint(ConstraintEqual(sd!, variables));
        } else if (typeIndex == ConstraintType.ALLDIFF.index) {
          final domain = BitArray(sd!.ne2 + 1)
            ..setBits((data['domain'] as List).cast<int>());
          sd!.assist.addConstraint(ConstraintAllDiff(sd!, variables, domain));
        }
      }
    }

    // Replay manual changes LAST (triggers propagation with correct settings)
    if (state.containsKey('manualChanges')) {
      final changes = state['manualChanges'] as List;
      for (final change in changes) {
        final data = change as Map<String, dynamic>;
        sd!.setManualChange(data['v'] as int, data['val'] as int);
      }
    }

    sd!.assist.updateCurrentCondition();

    // Restore puzzleAlreadyWon flag
    if (state.containsKey('puzzleAlreadyWon')) {
      _puzzleAlreadyWon = state['puzzleAlreadyWon'] as bool;
    }

    // Re-run assistant to propagate values and apply constraints
    // (we only save manual values, so assistant needs to re-propagate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sd != null && mounted) {
        runAssistant();
      }
    });
  }

  static Future<Map<String, dynamic>?> loadSavedPuzzle() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedPuzzleKey);
    if (saved == null) return null;
    try {
      return jsonDecode(saved) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearSavedPuzzle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPuzzleKey);
  }

  Color _getDifficultyColor(double normalized) {
    if (normalized < 0.15) return AppColors.success;
    if (normalized < 0.35) return AppColors.accent;
    if (normalized < 0.55) return AppColors.warning;
    if (normalized < 0.75) return AppColors.constraintPurple;
    return AppColors.error;
  }

  String _getDifficultyLabel(double normalized) {
    if (normalized < 0.15) return 'Easy';
    if (normalized < 0.35) return 'Medium';
    if (normalized < 0.55) return 'Hard';
    if (normalized < 0.75) return 'Expert';
    return 'Extreme';
  }

  double? _getDifficultyNormalized(int? forwards) {
    if (forwards == null) return null;
    const minLog = 8.3;
    const maxLog = 19.2;
    final logVal = forwards > 0 ? (log(forwards.toDouble()) / ln2) : 0.0;
    return ((logVal - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  Future<void> _estimateDifficulty({bool isInitial = false}) async {
    if (sd == null) return;
    if (!sd!.assist.showDifficulty) return;
    if (!isInitial && !sd!.assist.showLiveDifficulty) return;

    // Check if puzzle is loaded (has hints)
    if (sd!.hints.isEmpty) {
      // Puzzle not loaded yet, retry after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _estimateDifficulty(isInitial: isInitial);
      });
      return;
    }

    setState(() => _difficultyLoading = true);

    try {
      // Get current puzzle state (hints only for initial, current state for live)
      List<int> puzzleBuffer;
      if (isInitial) {
        // Use original hints only
        puzzleBuffer = List.filled(sd!.ne4, 0);
        for (final i in sd!.hints.asIntIterable()) {
          puzzleBuffer[i] = sd![i];
        }
      } else {
        // Use current puzzle state
        puzzleBuffer = List.generate(sd!.ne4, (i) => sd![i]);
      }

      final stats = SudokuNative.estimateDifficulty(puzzleBuffer, sd!.n, numSamples: 5);
      if (mounted) {
        setState(() {
          final difficulty = stats?['avgForwards'];
          if (isInitial) {
            _initialDifficultyForwards = difficulty;
          }
          _currentDifficultyForwards = difficulty;
          _difficultyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isInitial) {
            _initialDifficultyForwards = null;
          }
          _currentDifficultyForwards = null;
          _difficultyLoading = false;
        });
      }
    }
  }

  void _handleVictory() {
  }

  Future<void> _showVictoryDialog() async {
    final theme = widget.sudokuThemeFunc(context);

    // Create puzzle record with difficulty estimation
    final hints = sd!.hints.asIntIterable().toList();
    final hintValues = hints.map((i) => sd![i]).toList();

    // Estimate difficulty using native library
    int? difficultyForwards;
    try {
      final puzzleBuffer = List.filled(sd!.ne4, 0);
      for (int i = 0; i < hints.length; i++) {
        puzzleBuffer[hints[i]] = hintValues[i];
      }
      final stats = SudokuNative.estimateDifficulty(puzzleBuffer, sd!.n, numSamples: 10);
      difficultyForwards = stats?['avgForwards'];
    } catch (e) {
      // Native library might not be available on all platforms
      difficultyForwards = null;
    }

    final record = PuzzleRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_${sd!.n}',
      n: sd!.n,
      hints: hints,
      hintValues: hintValues,
      completedAt: DateTime.now(),
      moveCount: sd!.age,
      difficultyForwards: difficultyForwards,
    );

    // Save to trophy room
    await TrophyRoomStorage.addPuzzleRecord(record);

    // Check achievements
    final constraintTypes = sd!.assist.constraints
        .map((c) => c.type)
        .toSet()
        .length;
    final tracker = AchievementTracker();
    final newAchievements = await tracker.checkAchievements(
      completedPuzzle: record,
      timeSpent: null, // TODO: Track time in future
      constraintTypesUsed: constraintTypes,
      manualMoves: sd!.age,
    );

    // Clear saved puzzle state
    await SudokuScreenState.clearSavedPuzzle();

    showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 32),
              const SizedBox(width: 12),
              Text(
                'Victory!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.dialogTitleColor,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Congratulations on solving the puzzle!',
                style: TextStyle(
                  color: theme.dialogTextColor,
                ),
              ),
              if (record.difficultyNormalized != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Difficulty: ',
                      style: TextStyle(
                        color: theme.dialogTextColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _getDifficultyColor(record.difficultyNormalized!),
                      ),
                      child: Text(
                        record.difficultyLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (newAchievements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Achievements Unlocked:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.dialogTitleColor,
                  ),
                ),
                const SizedBox(height: 8),
                ...newAchievements.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: a.gradientColors,
                          ),
                        ),
                        child: Icon(a.icon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.dialogTitleColor,
                              ),
                            ),
                            Text(
                              a.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.mutedPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Awesome!'),
              onPressed: () {
                this._handleVictory();
                Navigator.of(ctx).pop();
              }
            ),
          ],
        );
      },
    );
  }

  void _checkVictoryConditions() async {
    // Don't show victory if puzzle was already won
    if (_puzzleAlreadyWon) {
      return;
    }
    if(sd!.checkIsComplete() && sd!.check()) {
      _puzzleAlreadyWon = true;
      this._showVictoryDialog();
    }
  }

  Future<void> _handleOnPressCell(int index) async {
    if(this._multiSelect!.isEmpty) {
      this._selectedCell = index;
      this._selectCellValue(index);
    } else {
      this._multiSelect!.invertBit(index);
    }
    this.runSetState();
  }

  Future<void> _handleLongPressCell(int index) async {
    if(this._multiSelect!.isEmpty) {
      this.startMultiSelect();
      this._multiSelect!.setBit(index);
      this.runSetState();
    }
  }

  BitArray getSelection() {
    if(this._multiSelect!.isEmpty) {
      var res = BitArray(sd!.ne4);
      if(this._selectedCell != -1) {
        res.setBit(this._selectedCell);
      }
      return res;
    }
    return this._multiSelect!.clone();
  }

  Future _showSelectionNumpad(NumpadInteractionType nitype, int count) async {
    var sel = this.getSelection();
    if(sel.isEmpty) {
      return null;
    }
    final val = await showGeneralDialog(
      context: this.context,
      barrierDismissible: true,
      barrierLabel: "Selecting value",
      transitionDuration: Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) {
        return NumpadScreen(
          sd: this.sd!,
          nitype: nitype,
          count: count,
          variables: this.getSelection(),
          sudokuThemeFunc: this.widget.sudokuThemeFunc,
        );
      },
    );
    return val;
  }

  Future<void> _selectCellValues(Iterable<int> variables) async {
    final ret = await this._showSelectionNumpad(NumpadInteractionType.ANTISELECTION, -1);
    this._processCellSelection(variables, ret);
  }

  Future<void> _selectCellValue(int variable) async {
    final ret = await this._showSelectionNumpad(NumpadInteractionType.SELECT_VALUE, 1);
    this._processCellSelection(variable, ret);
  }

  void _processCellValueSelection(int variable, int val) {
    sd!.setManualChange(variable, val);
    // for(int v in variables) {
    //   if(v == variables.first) {
    //     sd.setManualChange(v, val);
    //   } else {
    //     sd.setAssistantChange(v, val);
    //   }
    // }
    this.runAssistant(reapply: (val == 0));
  }

  void _processCellElimination(Iterable<int> variables, EliminatorInteractionReturnType changes) {
    for(int v in variables) {
      var diff = (sd!.assist.elim[v].asBitArray() ^ changes.forbidden) & changes.antiselectionChanges;
      sd!.assist.elim[v].invertBits(diff.asIntIterable());
    }
  }

  void _processCellSelection(dynamic variable_s, dynamic ret) {
    if(ret != null) {
      if(ret is int) {
        this._processCellValueSelection(variable_s, ret);
      } else if(ret is EliminatorInteractionReturnType) {
        if(variable_s is int) {
          this._processCellElimination(<int>[variable_s], ret);
        } else {
          this._processCellElimination(variable_s, ret);
        }
        // Propagate assistant after elimination to auto-complete cells
        // when only one value remains (if autoComplete is enabled)
        this.runAssistant();
      } else {
      }
      this.runSetState();
    }
    this.endMultiSelect();
  }

  Future<void> _showResetDialog(BuildContext ctx) async {
    final theme = widget.sudokuThemeFunc(context);
    return showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              Text(
                'Reset Puzzle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.dialogTitleColor,
                ),
              ),
            ],
          ),
          content: Text(
            'Reset the puzzle or return to grid selection.',
            style: TextStyle(
              color: theme.dialogTextColor,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.cancelButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.dialogTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Main Menu'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Reset'),
              onPressed: () {
                this._handleResetPress();
                Navigator.of(ctx).pop();
              }
            ),
          ],
        );
      },
    );
  }

  void _handleResetPress() {
    setState(() {
      this.sd = null;
    });
  }

  Future<void> _showExitDialog(BuildContext ctx) async {
    final theme = widget.sudokuThemeFunc(context);
    return showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.exit_to_app_rounded, color: AppColors.primaryPurple, size: 28),
              const SizedBox(width: 12),
              Text(
                'Exit Puzzle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.dialogTitleColor,
                ),
              ),
            ],
          ),
          content: Text(
            'Your progress will be discarded.',
            style: TextStyle(
              color: theme.dialogTextColor,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.cancelButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Exit'),
              onPressed: () async {
                await SudokuScreenState.clearSavedPuzzle();
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              }
            ),
          ],
        );
      },
    );
  }

  Future<void> _showThemeDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: this.context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Get fresh theme for current state
            final currentTheme = widget.sudokuThemeFunc(context);
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.palette_rounded, color: AppColors.primaryPurple, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: currentTheme.dialogTitleColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BRIGHTNESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.mutedPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildThemeChip(
                          icon: Icons.wb_sunny,
                          label: 'Light',
                          isSelected: currentTheme.currentMode == ThemeMode.light,
                          onTap: () {
                            currentTheme.onThemeModeChange(ThemeMode.light);
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                        _buildThemeChip(
                          icon: Icons.nights_stay,
                          label: 'Dark',
                          isSelected: currentTheme.currentMode == ThemeMode.dark,
                          onTap: () {
                            currentTheme.onThemeModeChange(ThemeMode.dark);
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                        _buildThemeChip(
                          icon: Icons.phone_android,
                          label: 'Auto',
                          isSelected: currentTheme.currentMode == ThemeMode.system,
                          onTap: () {
                            currentTheme.onThemeModeChange(ThemeMode.system);
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'STYLE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: currentTheme.mutedPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildThemeChip(
                          icon: Icons.auto_awesome,
                          label: 'Modern',
                          isSelected: currentTheme.currentStyle == ThemeStyle.modern,
                          onTap: () {
                            currentTheme.onThemeStyleChange(ThemeStyle.modern);
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                        _buildThemeChip(
                          icon: Icons.edit_note,
                          label: 'Paper',
                          isSelected: currentTheme.currentStyle == ThemeStyle.penAndPaper,
                          onTap: () {
                            currentTheme.onThemeStyleChange(ThemeStyle.penAndPaper);
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: currentTheme.cancelButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Done'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final theme = widget.sudokuThemeFunc(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? AppColors.primaryPurple.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : theme.disabledFg,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryPurple : theme.iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primaryPurple : theme.dialogTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Border getBorder(int i, int j, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);

    bool left = (j % sd!.n == 0);
    bool right = (j % sd!.n == sd!.n - 1);
    bool top = (i % sd!.n == 0);
    bool bottom = (i % sd!.n == sd!.n - 1);
    bool leftEdge = (j == 0), rightEdge = (j == sd!.ne2 - 1);
    bool topEdge = (i == 0), bottomEdge = (i == sd!.ne2 - 1);

    var side = BorderSide(
      width: 0.5,
      color: theme.foreground,
    );
    var edgeSide = BorderSide(
      width: 2.0,
      color: theme.foreground,
    );
    var leftSide = leftEdge ? edgeSide : side;
    var rightSide = rightEdge ? edgeSide : side;
    var topSide = topEdge ? edgeSide : side;
    var bottomSide = bottomEdge ? edgeSide : side;

    // corners
    if(left && top) {
      return Border(
        left: leftSide,
        top: topSide,
      );
    } else if(left && bottom) {
      return Border(
        left: leftSide,
        bottom: bottomSide,
      );
    } else if(right && top) {
      return Border(
        right: rightSide,
        top: topSide,
      );
    } else if(right && bottom) {
      return Border(
        right: rightSide,
        bottom: bottomSide,
      );
    }
    // sides
    else if(left) {
      return Border(left: leftSide);
    } else if(right) {
      return Border(right: rightSide);
    } else if(top) {
      return Border(top: topSide);
    } else if(bottom) {
      return Border(bottom: bottomSide);
    }
    return Border();
  }

  Widget _makeSudokuCellImmutable(int index, double sz, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    int sdval = sd![index];

    final textStyle = TextStyle(
      fontSize: sz * 0.85,
      height: 1.0,
      color: theme.cellForeground,
      fontWeight: FontWeight.w600,
    );

    final textWidget = theme.isSketchedStyle
        ? WobblyText(
            text: sd!.s_get(sdval),
            style: textStyle,
            seed: index * 17 + sdval,  // Unique seed per cell and value
          )
        : Text(sd!.s_get(sdval), style: textStyle);

    // For sketched style, use Container with border instead of Card with elevation
    if (theme.isSketchedStyle) {
      return Container(
        decoration: BoxDecoration(
          color: theme.cellHintColor,
          border: Border.all(
            color: theme.cellHintBorder ?? theme.foreground!.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        // Extra padding to prevent wobbly text from clipping at borders
        padding: const EdgeInsets.all(2.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(sz * 0.05),
            child: textWidget,
          ),
        ),
      );
    }

    // Modern style uses Card with elevation
    return Card(
      margin: const EdgeInsets.all(0.0),
      elevation: 1.0,
      color: theme.cellHintColor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(sz * 0.05),
          child: textWidget,
        ),
      ),
    );
  }

  void startMultiSelect() {
    this._selectedCell = -1;
    this._multiSelect ??= BitArray(sd!.ne4);
    this._multiSelect!.clearAll();
  }

  void endMultiSelect() {
    this._multiSelect!.clearAll();
  }

  Color? getCellColor(int index, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    if(sd!.assist.hintContradictions && sd!.assist.getDomain(index).isEmpty) {
      return theme.red;
    } else if(this._multiSelect!.isEmpty) {
      if(this._selectedCell == index) {
        return theme.cellBackground;
      } else if(this._selectedConstraint != null && this._selectedConstraint.variables[index]) {
        switch(this._selectedConstraint.type) {
          case ConstraintType.ONE_OF: return theme.constraintOneOf;
          case ConstraintType.EQUAL: return theme.constraintEqual;
          case ConstraintType.ALLDIFF: return theme.constraintAllDiff!;
        }
      }
    } else {
      if(this._multiSelect![index]) {
        return theme.cellSelectionColor;
      }
    }
    if(this._tutorialCells != null && this._tutorialCells![index] && sd![index] == 0) {
      return theme.orange;
    }
    return null;
  }

  Color? getCellTextColor(int index, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    if(sd!.isVariableManual(index)) {
      return theme.cellForeground;
    }
    return theme.cellInferColor;
  }

  Widget _makeSudokuCellMutable(int index, double sz, BuildContext ctx) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    int sdval = sd![index];

    final textStyle = TextStyle(
      fontSize: sz * 0.85,
      height: 1.0,
      color: this.getCellTextColor(index, ctx),
    );

    final textWidget = (theme.isSketchedStyle && sdval != 0)
        ? WobblyText(
            text: sd!.s_get_display(sdval),
            style: textStyle,
            seed: index * 17 + sdval,  // Unique seed per cell and value
          )
        : Text(sd!.s_get_display(sdval), style: textStyle);

    // Extra padding for sketched style to prevent wobbly text clipping
    final buttonPadding = theme.isSketchedStyle ? const EdgeInsets.all(2.0) : EdgeInsets.zero;

    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(buttonPadding),
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        )),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if(states.contains(WidgetState.pressed)) {
              return theme.cellSelectionColor;
            }
            return this.getCellColor(index, ctx);
          }
        ),
      ),
      onPressed: () {
        this._handleOnPressCell(index);
      },
      onLongPress: () {
        this._handleLongPressCell(index);
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(sz * 0.05),
          child: textWidget,
        ),
      ),
    );
  }

  Widget _makeSudokuCell(int index, double sz, BuildContext ctx) {
    if(sd!.isHint(index)) {
      return this._makeSudokuCellImmutable(index, sz, ctx);
    }
    return this._makeSudokuCellMutable(index, sz, ctx);
  }

  Widget _makeSudokuGridContent(BuildContext ctx, double size) {
    final theme = this.widget.sudokuThemeFunc(ctx);
    // For sketched style, reduce effective size to add margin for wobble
    final effectiveSize = theme.isSketchedStyle ? size - 6.0 : size;
    double sz = (effectiveSize - 1.0) / sd!.ne2;

    final gridContent = CustomScrollView(
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverGrid.count(
          crossAxisCount: sd!.ne2,
          children: List<Widget>.generate(sd!.ne4, (index) {
            int i = index ~/ sd!.ne2, j = index % sd!.ne2;
            return Container(
              margin: const EdgeInsets.all(0.0),
              decoration: BoxDecoration(
                // Use regular borders for modern style, none for sketched
                border: theme.isSketchedStyle ? null : getBorder(i, j, ctx),
              ),
              child: this._makeSudokuCell(index, sz, ctx),
            );
          }),
        )
      ],
    );

    // For sketched style, overlay hand-drawn grid lines with padding for wobble
    if (theme.isSketchedStyle) {
      return Padding(
        padding: const EdgeInsets.all(3.0),
        child: Stack(
          children: [
            gridContent,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SketchedGridPainter(
                    n: sd!.n,
                    lineColor: theme.foreground ?? Colors.black,
                    size: effectiveSize,
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

  var _scaffoldBodyContext = null;
  void _showAssistantResult() async {
    for(Constraint constr in sd!.assist.newlySucceeded) {
      ScaffoldMessenger.of(this._scaffoldBodyContext).showSnackBar(
        SnackBar(
          elevation: 4.0,
          // In demo mode, keep SnackBar visible indefinitely for screenshots
          duration: sd!.isDemo ? const Duration(days: 1) : const Duration(seconds: 4),
          backgroundColor: Colors.grey[200],
          content: Text(
            constr.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
            ),
          ),
        ),
      );
    }
  }

  bool _showTutorial = false;
  int _tutorialStage = 0;
  // Static so it persists across screen instances (survives navigation)
  static bool _tutorialDialogShownThisSession = false;
  // Store auto-complete state to restore after tutorial
  bool? _tutorialSavedAutoComplete;

  BitArray? _tutorialCells = null;
  void _selectTutorialCells() {
    // Select only cells that are currently empty (not hints and not filled)
    this._tutorialCells = BitArray(sd!.ne4)
      ..setBits(
          sd!.getUnsolvedRandomBC()
        .asIntIterable()
        .where((ind) => !sd!.isHint(ind) && sd![ind] == 0));
    if(this._tutorialCells == null || this._tutorialCells!.isEmpty) {
      this._tutorialCells = BitArray(sd!.ne4);
    }
    if (kDebugMode) print('tutorialcells ${this._tutorialCells!.asIntIterable()}');
  }

  Future<void> _completeTutorial() async {
    this._showTutorial = false;
    this._tutorialStage = 0;
    this._tutorialCells = null;
    // Restore auto-complete state
    if (this._tutorialSavedAutoComplete != null) {
      sd!.assist.autoComplete = this._tutorialSavedAutoComplete!;
      this._tutorialSavedAutoComplete = null;
    }
    // Mark tutorial as completed (updates stats, achievement derived from that)
    final achievement = await TrophyRoomStorage.markTutorialCompleted();
    this.runSetState();

    // Show achievement notification if newly unlocked
    if (achievement != null && mounted) {
      _showAchievementNotification(achievement);
    }
  }

  void _showAchievementNotification(Achievement achievement) {
    final theme = widget.sudokuThemeFunc(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.dialogBackgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(colors: achievement.gradientColors),
              ),
              child: Icon(achievement.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievement Unlocked!',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.mutedSecondary,
                    ),
                  ),
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.dialogTitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTutorialMessage({required String title, required String message, required Function() nextFunc}) async {
    final theme = widget.sudokuThemeFunc(context);
    return showDialog<void>(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                  ),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.dialogTitleColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: theme.dialogTextColor,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Got it'),
              onPressed: () {
                Navigator.of(ctx).pop();
                nextFunc();
              }
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTutorialOfferDialog() async {
    // Skip if tutorial already completed
    final tutorialDone = await TrophyRoomStorage.isAchievementUnlocked(AchievementType.tutorialComplete);
    if (tutorialDone) return;

    final theme = widget.sudokuThemeFunc(context);
    return showDialog<void>(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.secondaryPurple],
                  ),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.dialogTitleColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Would you like a quick tutorial on how to use the constraint assistant?',
            style: TextStyle(
              color: theme.dialogTextColor,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.cancelButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Skip'),
              onPressed: () {
                this._showTutorial = false;
                this.runSetState();
                Navigator.of(ctx).pop();
              }
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Start Tutorial'),
              onPressed: () {
                Navigator.of(ctx).pop();
                // Disable auto-complete during tutorial to prevent cells from being filled
                this._tutorialSavedAutoComplete = sd!.assist.autoComplete;
                sd!.assist.autoComplete = false;
                this._selectTutorialCells();
                this._showTutorial = true;
                this._tutorialStage = 1;
                this.runSetState();
                this._showTutorialMessage(
                  title: 'Select cells',
                  message: 'Long-press a highlighted cell to start selecting, then tap to add more cells to the constraint group.',
                  nextFunc: (){}
                );
              }
            ),
          ],
        );
      },
    );
  }

  Widget _makeTutorialButtonStage12(BuildContext ctx) {
    final iconSize = min(80.0, min(screenWidth, screenHeight) * 0.15);
    var tutorialCellsUnset = BitArray(sd!.ne4)
      ..setBits(
        this._tutorialCells!
          .asIntIterable()
          .where((ind) => (sd![ind] == 0))
      );
    bool passCondition = (
      this._multiSelect!.cardinality == tutorialCellsUnset.cardinality
      && this._multiSelect!.asIntIterable().every(
        (msel) => tutorialCellsUnset[msel]
      )
    );
    final bool justEnteredStage2 = passCondition && this._tutorialStage == 1;
    this._tutorialStage = !passCondition ? 1 : 2;

    // Auto-show hint when cells are correctly selected
    if (justEnteredStage2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        this._showTutorialMessage(
            title: 'Constraint Options',
            message: 'The panel now shows constraint options. Each constraint type works differently.',
            nextFunc: () {
              this._showTutorialMessage(
                title: 'All different',
                message: 'This constraint ensures all selected cells have different values. Tap "All different" to add it.',
                nextFunc: () {}
              );
            }
        );
      });
    }

    final gradientColors = passCondition
        ? [AppColors.success, AppColors.successLight] // Green when ready
        : [AppColors.warning, AppColors.warningLight]; // Orange when selecting

    return GestureDetector(
      onTap: () {
        if (passCondition) {
          this.runSetState();
          this._showTutorialMessage(
              title: 'Constraint Options',
              message: 'The panel now shows constraint options. Each constraint type works differently.',
              nextFunc: () {
                this._showTutorialMessage(
                  title: 'All different',
                  message: 'This constraint ensures all selected cells have different values. Tap "All different" to add it.',
                  nextFunc: () {
                  }
                );
              }
          );
        } else {
          this._showTutorialMessage(
              title: 'Select cells',
              message: 'Long-press a highlighted cell to start selecting, then tap to add more cells to the constraint group.',
              nextFunc: () {}
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(passCondition ? 0.4 : 0.2),
              blurRadius: passCondition ? 15 : 8,
              offset: Offset(0, passCondition ? 6 : 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            passCondition ? Icons.check_circle_outline_rounded : Icons.touch_app_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _makeTutorialButtonStage3(BuildContext ctx) {
    final iconSize = min(80.0, min(screenWidth, screenHeight) * 0.15);
    return GestureDetector(
      onTap: () {
        this._showTutorialMessage(
            title: "New constraint",
            message: 'Assistant is used to simplify mechanical deductions. It will now account for the new rule.',
            nextFunc: () {
              this._showTutorialMessage(
                title: 'Assistant',
                message: 'Once you get used to using constraints, you should enable default rules through the settings.',
                nextFunc: () {
                }
              );
            }
        );
        this._completeTutorial();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.success, AppColors.successLight],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _makeTutorialButton(BuildContext ctx) {
    final marginSize = min(16.0, min(screenWidth, screenHeight) * 0.03);
    final buttonSize = min(80.0, min(screenWidth, screenHeight) * 0.15);
    return Container(
      margin: EdgeInsets.all(marginSize),
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: (){
          switch(this._tutorialStage) {
            case 1:
            case 2:
              return this._makeTutorialButtonStage12(ctx);
            case 3:
              return this._makeTutorialButtonStage3(ctx);
            default:
              return const SizedBox.shrink();
          }
        }(),
      ),
    );
  }

  // Color mapping for constraint types
  static const Map<ConstraintType, List<Color>> _constraintColors = {
    ConstraintType.ONE_OF: [AppColors.success, AppColors.successLight],
    ConstraintType.EQUAL: [AppColors.constraintPurple, AppColors.constraintPurpleLight],
    ConstraintType.ALLDIFF: [AppColors.accent, AppColors.accentLight],
  };

  var _selectedConstraint = null;
  Widget _makeConstraintList(BuildContext ctx) {
    final theme = widget.sudokuThemeFunc(context);

    // Show constraint choices when cells are selected
    if (this._multiSelect != null && this._multiSelect!.cardinality > 0) {
      return _makeConstraintChoices(ctx);
    }

    final allConstraints = sd!.assist.constraints;
    final hasEmptyCells = !sd!.checkIsComplete();

    // Show all constraints if puzzle isn't complete, hide only SUCCESS ones when complete
    var constraints = allConstraints.where((Constraint c) {
      // Always show non-successful constraints (violated, insufficient, not run)
      if (c.status != Constraint.SUCCESS) return true;
      // Show all constraints while puzzle has empty cells
      if (hasEmptyCells) return true;
      return false;
    }).toList();

    // Theme-aware muted colors
    final mutedPrimary = theme.mutedPrimary;
    final mutedSecondary = theme.mutedSecondary;

    if (constraints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_rounded,
              size: 32,
              color: mutedSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'No constraints yet',
              style: TextStyle(
                color: mutedPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Long-press cells to select',
              style: TextStyle(
                color: mutedSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    var listTiles = List<Widget>.generate(constraints.length, (i) {
      final constraint = constraints[i];
      final colors = _constraintColors[constraint.type] ?? [Colors.grey, Colors.grey[400]!];
      final isViolated = constraint.status == Constraint.VIOLATED;
      final isSelected = this._selectedConstraint == constraint;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: GestureDetector(
          onTap: !constraint.isActive() ? null : () {
            this._multiSelect!.clearAll();
            this._selectedConstraint = constraint;
            this.runSetState();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isViolated
                  ? const LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: constraint.isActive()
                          ? colors
                          : [colors[0].withOpacity(0.4), colors[1].withOpacity(0.4)],
                    ),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isViolated ? Colors.red : colors[0]).withOpacity(isSelected ? 0.4 : 0.2),
                  blurRadius: isSelected ? 10 : 4,
                  offset: Offset(0, isSelected ? 4 : 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Checkbox
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: constraint.isActive(),
                      onChanged: (bool? b) {
                        if(b!) {
                          constraint.activate();
                        } else {
                          constraint.deactivate();
                          if(this._selectedConstraint == constraint) {
                            this._selectedConstraint = null;
                          }
                        }
                        this.runAssistant();
                      },
                      fillColor: WidgetStateProperty.all(Colors.white.withOpacity(0.3)),
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  // Constraint info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          constraint.s_display(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Values: ${constraint.getValues()}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    onPressed: () {
                      if(this._selectedConstraint == constraint) {
                        this._selectedConstraint = null;
                      }
                      if(this._lastUserAddedConstraint == constraint) {
                        this._lastUserAddedConstraint = null;
                      }
                      sd!.assist.constraints.remove(constraint);
                      this.runAssistant(reapply: true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    if(this._selectedConstraint != null) {
      listTiles.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: theme.cancelButtonColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Deselect constraint'),
            onPressed: () {
              this._selectedConstraint = null;
              this.runSetState();
            }
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      children: listTiles,
    );
  }

  Widget _makeConstraintChoiceButton({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final bool isEnabled = onTap != null;
    final theme = widget.sudokuThemeFunc(context);
    final disabledBg = theme.disabledBg;
    final disabledFg = theme.disabledFg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHighlighted
                        ? gradientColors
                        : [gradientColors[0].withOpacity(0.8), gradientColors[1].withOpacity(0.8)],
                  )
                : null,
            color: isEnabled ? null : disabledBg,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(isHighlighted ? 0.4 : 0.2),
                      blurRadius: isHighlighted ? 10 : 4,
                      offset: Offset(0, isHighlighted ? 3 : 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? Colors.white : disabledFg,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : disabledFg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _makeConstraintChoices(BuildContext ctx) {
    final theme = widget.sudokuThemeFunc(context);
    final bool isTutorialHighlight = this._showTutorial && this._tutorialStage == 2;
    final int selectedCount = this._multiSelect!.cardinality;

    final buttons = [
      _makeConstraintChoiceButton(
        icon: Icons.looks_one_rounded,
        title: 'One of',
        gradientColors: const [AppColors.success, AppColors.successLight],
        onTap: (selectedCount < 2) ? null : () async {
          this.interact = OneofInteraction(this);
          await this.interact!.onSelection();
          this.runSetState();
        },
      ),
      _makeConstraintChoiceButton(
        icon: Icons.link_rounded,
        title: 'Equivalence',
        gradientColors: const [AppColors.constraintPurple, AppColors.constraintPurpleLight],
        onTap: (selectedCount < 2) ? null : () async {
          this.interact = EqualInteraction(this);
          await this.interact!.onSelection();
          this.runSetState();
        },
      ),
      _makeConstraintChoiceButton(
        icon: Icons.difference_rounded,
        title: 'All different',
        gradientColors: const [AppColors.accent, AppColors.accentLight],
        onTap: (selectedCount < 2) ? null : () async {
          this.interact = AlldiffInteraction(this);
          await this.interact!.onSelection();
          this.runSetState();
        },
        isHighlighted: isTutorialHighlight,
      ),
      _makeConstraintChoiceButton(
        icon: Icons.block_rounded,
        title: 'Eliminate',
        gradientColors: const [AppColors.constraintOrange, AppColors.constraintOrangeLight],
        onTap: (selectedCount < 1) ? null : () async {
          this.interact = EliminatorInteraction(this);
          await this.interact!.onSelection();
          this.runSetState();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 2 columns if width >= 280, otherwise single column
        final bool useTwoColumns = constraints.maxWidth >= 280;

        Widget buttonGrid;
        if (useTwoColumns) {
          buttonGrid = Column(
            children: [
              Row(
                children: [
                  Expanded(child: buttons[0]),
                  Expanded(child: buttons[1]),
                ],
              ),
              Row(
                children: [
                  Expanded(child: buttons[2]),
                  Expanded(child: buttons[3]),
                ],
              ),
            ],
          );
        } else {
          buttonGrid = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buttons,
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: theme.mutedPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$selectedCount cell${selectedCount > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      color: theme.mutedPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Constraint options
            buttonGrid,
            const SizedBox(height: 4),
            // Hint
            Text(
              'Select 2+ cells for constraints',
              style: TextStyle(
                color: theme.mutedSecondary,
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }

  void backtrackAssistant() {
    this.sd!.assist.retract();
  }

  void runAssistant({bool reapply=false}) {
    if(reapply) {
      this.sd!.assist.reapply();
    } else {
      this.sd!.assist.apply();
    }
    this._showAssistantResult();
    this._checkVictoryConditions();
    this.runSetState();
  }

  void _showAssistantOptions(BuildContext ctx) async {
    await Navigator.pushNamed(
      this.context,
      SudokuAssistScreen.routeName,
      arguments: SudokuAssistScreenArguments(
        sd: this.sd!,
        sudokuThemeFunc: widget.sudokuThemeFunc,
      ),
    );
    this.runAssistant();
  }

  List<Widget> _makeToolBar(BuildContext ctx) {
    final theme = widget.sudokuThemeFunc(context);
    final iconColor = theme.iconColor;

    if(this._showTutorial && this._tutorialStage >= 1) {
      return <Widget>[];
    }
    const int
      TOOLBAR_ASSIST = 0,
      TOOLBAR_TUTOR = 1,
      TOOLBAR_RESET = 2,
      TOOLBAR_THEME = 3,
      TOOLBAR_LICENSE = 4;
    return <Widget>[
      IconButton(
        icon: Icon(Icons.undo_rounded, color: iconColor),
        onPressed: () {
          setState(() {
            if(this._multiSelect!.cardinality > 0) {
              this.endMultiSelect();
              return;
            }
            if(!this.sd!.changes.isEmpty) {
              this._selectedCell = sd!.getLastChange().assisted ? -1 : sd!.getLastChange().variable;
            }
            this.backtrackAssistant();
            this.sd!.undoChange();
            this.runAssistant();
          });
        },
      ),
      IconButton(
        icon: Icon(Icons.edit_rounded, color: iconColor),
        onPressed: () {
          if(this._multiSelect!.cardinality > 0) {
            this._selectCellValues(this._multiSelect!.asIntIterable());
          } else if(this._selectedCell != -1) {
            this._selectCellValue(this._selectedCell);
          }
        },
      ),
      PopupMenuButton<int>(
        icon: Icon(Icons.more_vert_rounded, color: iconColor),
        onSelected: (int opt) {
          switch(opt) {
            case TOOLBAR_RESET:
              this._showExitDialog(ctx);
            break;
            case TOOLBAR_TUTOR:
              this._showTutorialOfferDialog();
            break;
            case TOOLBAR_ASSIST:
              this._showAssistantOptions(ctx);
            break;
            case TOOLBAR_THEME:
              this._showThemeDialog(ctx);
            break;
            case TOOLBAR_LICENSE:
              showLicensePage(
                context: ctx,
                applicationName: 'Sudaku',
              );
            break;
          }
        },
        itemBuilder: (BuildContext ctx) => <PopupMenuEntry<int>>[
          const PopupMenuItem(
            value: TOOLBAR_ASSIST,
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20),
                SizedBox(width: 12),
                Text('Assistant'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TOOLBAR_TUTOR,
            child: Row(
              children: [
                Icon(Icons.school_rounded, size: 20),
                SizedBox(width: 12),
                Text('Tutorial'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TOOLBAR_THEME,
            child: Row(
              children: [
                Icon(Icons.palette_rounded, size: 20),
                SizedBox(width: 12),
                Text('Theme'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TOOLBAR_RESET,
            child: Row(
              children: [
                Icon(Icons.exit_to_app_rounded, size: 20),
                SizedBox(width: 12),
                Text('Exit'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: TOOLBAR_LICENSE,
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
    ];
  }

  Widget _buildResponsiveLayout(BuildContext ctx, BoxConstraints constraints) {
    final theme = widget.sudokuThemeFunc(ctx);
    final bool isPortrait = constraints.maxHeight > constraints.maxWidth;
    final double availableWidth = constraints.maxWidth;
    final double availableHeight = constraints.maxHeight;

    // Calculate optimal grid size based on orientation
    double gridSize;

    // Minimum width needed for the constraint list to be readable
    const double minConstraintListWidth = 200.0;

    if (isPortrait) {
      // In portrait, constraint list is below so grid can use full width
      gridSize = min(availableWidth, availableHeight * 0.7);
    } else {
      // In landscape, grid limited by height and must leave space for constraint list
      gridSize = min(availableHeight, availableWidth - minConstraintListWidth);
    }

    // Ensure grid doesn't exceed available space
    gridSize = min(gridSize, min(availableWidth, availableHeight));

    // Ensure minimum grid size for playability
    final minGridSize = 200.0;
    gridSize = max(gridSize, minGridSize);

    this.screenWidth = availableWidth;
    this.screenHeight = availableHeight;

    Widget gridWidget = Container(
      width: gridSize,
      height: gridSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: this._makeSudokuGridContent(ctx, gridSize),
        ),
      ),
    );

    // Show both tutorial button and constraint list during tutorial
    final bool showTutorialButton = this._showTutorial && this._tutorialStage >= 1;

    Widget secondaryContent;
    if (showTutorialButton) {
      if (isPortrait) {
        // Portrait: constraint list on left, tutorial button on right (Row)
        secondaryContent = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: this._makeConstraintList(ctx),
              ),
            ),
            const SizedBox(width: 8),
            this._makeTutorialButton(ctx),
          ],
        );
      } else {
        // Landscape: constraint list on top, tutorial button at bottom (Column)
        secondaryContent = Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: this._makeConstraintList(ctx),
              ),
            ),
            const SizedBox(height: 8),
            this._makeTutorialButton(ctx),
          ],
        );
      }
    } else {
      secondaryContent = SingleChildScrollView(
        child: this._makeConstraintList(ctx),
      );
    }

    // Wrap secondary content with max-width constraint for readability
    Widget secondaryWidget = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
        ),
        child: secondaryContent,
      ),
    );

    if (isPortrait) {
      // Check if content might overflow on very small screens
      final bool needsScroll = (gridSize + 100) > availableHeight;

      if (needsScroll) {
        // Use scrollable layout for very small screens
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(child: gridWidget),
              SizedBox(
                height: max(150, availableHeight * 0.3),
                child: secondaryWidget,
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(child: gridWidget),
          Expanded(child: secondaryWidget),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(child: gridWidget),
          Expanded(child: secondaryWidget),
        ],
      );
    }
  }

  Widget build(BuildContext ctx) {
    var args = ModalRoute.of(ctx)!.settings.arguments! as SudokuScreenArguments;
    final int n = args.n;
    final theme = widget.sudokuThemeFunc(ctx);

    if(sd == null || sd!.n != n) {
      if (args.savedBuffer != null && args.savedHints != null) {
        // Restore from saved state
        sd = Sudoku.fromSaved(n, args.savedBuffer!, args.savedHints!, () {
          this.runSetState();
        });
        // Restore full state if available
        if (args.savedState != null) {
          _restoreFullState(args.savedState!);
        }
      } else if (args.isDemoMode && args.demoPuzzle != null) {
        // Demo mode: use fixed puzzle
        _isDemoMode = true;
        sd = Sudoku.demo(n, args.demoPuzzle!, () {
          this.runSetState();
        });
        // Add demo constraints if requested
        if (args.addDemoConstraints) {
          setupDemoConstraints(sd!);
        }
        // In demo mode: force show difficulty as numbers, no restore/save
        sd!.assist.showDifficulty = true;
        sd!.assist.showDifficultyNumbers = true;
      } else {
        // Normal mode: load random puzzle or generate based on difficulty
        sd = Sudoku(n, DefaultAssetBundle.of(ctx), () {
          this.runSetState();
        }, generatedDifficulty: args.generatedDifficulty);
        // Restore global assistant settings for new puzzles
        _restoreAssistantSettings();
      }
      this._multiSelect = BitArray(sd!.ne4);
      // Initial difficulty estimation
      _currentDifficultyForwards = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _estimateDifficulty(isInitial: true);
      });
    }

    // Show tutorial offer dialog once per session (not after reset or navigation)
    if (!_tutorialDialogShownThisSession) {
      _tutorialDialogShownThisSession = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _showTutorialOfferDialog();
      });
    }

    // Build difficulty badge for app bar (scale based on available width)
    final screenWidth = MediaQuery.of(ctx).size.width;
    // Scale factor: 1.0 at 400px+, down to 0.7 at 280px
    final scale = ((screenWidth - 280) / 120).clamp(0.7, 1.0);

    Widget? difficultyBadge;
    if (sd != null && sd!.assist.showDifficulty) {
      // Use live difficulty if enabled, otherwise show initial difficulty
      final difficultyToShow = sd!.assist.showLiveDifficulty
          ? _currentDifficultyForwards
          : _initialDifficultyForwards;
      final norm = _getDifficultyNormalized(difficultyToShow);
      if (_difficultyLoading) {
        difficultyBadge = Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
          child: SizedBox(
            width: 14 * scale,
            height: 14 * scale,
            child: CircularProgressIndicator(
              strokeWidth: 2 * scale,
              color: theme.mutedPrimary,
            ),
          ),
        );
      } else if (norm != null) {
        final displayText = sd!.assist.showDifficultyNumbers
            ? difficultyToShow.toString()
            : _getDifficultyLabel(norm);
        difficultyBadge = Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * scale),
            color: _getDifficultyColor(norm),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11 * scale,
            ),
          ),
        );
      }
    }

    var appBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SUDOKU',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24 * scale,
              letterSpacing: 3 * scale,
              color: theme.dialogTitleColor,
            ),
          ),
          if (difficultyBadge != null) ...[
            SizedBox(width: 12 * scale),
            difficultyBadge,
          ],
        ],
      ),
      centerTitle: true,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      actions: this._makeToolBar(ctx),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: appBar,
        body: Builder(
          builder: (ctx) {
            this._scaffoldBodyContext = ctx;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildResponsiveLayout(context, constraints);
                  },
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
