import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SevenPuzzleView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const SevenPuzzleView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<SevenPuzzleView> createState() => _SevenPuzzleViewState();
}

class PuzzleTile {
  int value;
  bool isBursting;

  PuzzleTile({required this.value, this.isBursting = false});
}

class _SevenPuzzleViewState extends State<SevenPuzzleView> {
  static const int _cols = 5;
  static const int _rows = 7;

  int _score = 0;
  int _sevensCreated = 0;
  int _maxChain = 1;
  int _currentChain = 1;

  late List<List<PuzzleTile?>> _grid; // grid[row][col] where 0 is top, 6 is bottom
  int _nextTile = 3;
  int _futureTile = 2;

  // Undo snapshot
  List<List<PuzzleTile?>>? _previousGridSnapshot;
  int? _previousScore;
  int _undoCount = 3;
  int _swapCount = 1;
  int _clearColCount = 1;

  bool _isProcessing = false;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _sevensCreated = widget.initialLevel > 1 ? (widget.initialLevel - 1) * 3 : 0;
    _initGame();
  }

  void _initGame() {
    _grid = List.generate(_rows, (_) => List.generate(_cols, (_) => null));
    _nextTile = 3;
    _futureTile = 2;

    // Seed Starter layout matching design kit `10_seven_puzzle.html`
    _grid[4][0] = PuzzleTile(value: 3);
    _grid[4][4] = PuzzleTile(value: 2);
    _grid[5][0] = PuzzleTile(value: 1);
    _grid[5][1] = PuzzleTile(value: 4);
    _grid[5][3] = PuzzleTile(value: 5);
    _grid[5][4] = PuzzleTile(value: 6);
    _grid[6][0] = PuzzleTile(value: 2);
    _grid[6][1] = PuzzleTile(value: 3);
    _grid[6][2] = PuzzleTile(value: 7);
    _grid[6][3] = PuzzleTile(value: 1);
    _grid[6][4] = PuzzleTile(value: 4);
  }

  void _dropInColumn(int col) async {
    if (_isProcessing) return;

    int targetRow = -1;
    for (int r = _rows - 1; r >= 0; r--) {
      if (_grid[r][col] == null) {
        targetRow = r;
        break;
      }
    }

    if (targetRow == -1) {
      HapticFeedback.vibrate();
      return;
    }

    _saveSnapshot();
    _isProcessing = true;
    HapticFeedback.lightImpact();

    final droppedVal = _nextTile;

    setState(() {
      _grid[targetRow][col] = PuzzleTile(value: droppedVal);
      _nextTile = _futureTile;
      _futureTile = 1 + _rand.nextInt(5);
    });

    await _processGravityAndMerges(0);
    _checkBoardStatus();
  }

  void _saveSnapshot() {
    _previousGridSnapshot = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        final t = _grid[r][c];
        return t == null ? null : PuzzleTile(value: t.value);
      });
    });
    _previousScore = _score;
  }

  void _useUndo() {
    if (_undoCount > 0 && _previousGridSnapshot != null && !_isProcessing) {
      HapticFeedback.mediumImpact();
      setState(() {
        _undoCount--;
        _grid = _previousGridSnapshot!;
        _score = _previousScore ?? _score;
        _previousGridSnapshot = null;
      });
    }
  }

  void _useSwap() {
    if (_swapCount > 0 && !_isProcessing) {
      HapticFeedback.selectionClick();
      setState(() {
        _swapCount--;
        final temp = _nextTile;
        _nextTile = _futureTile;
        _futureTile = temp;
      });
    }
  }

  void _useClearColumn(int col) {
    if (_clearColCount > 0 && !_isProcessing) {
      _saveSnapshot();
      HapticFeedback.heavyImpact();
      setState(() {
        _clearColCount--;
        for (int r = 0; r < _rows; r++) {
          _grid[r][col] = null;
        }
      });
    }
  }

  Future<void> _processGravityAndMerges(int chainCount) async {
    bool hadAction = false;

    // 1. Gravity
    for (int c = 0; c < _cols; c++) {
      for (int r = _rows - 2; r >= 0; r--) {
        if (_grid[r][c] != null && _grid[r + 1][c] == null) {
          int fallRow = r;
          while (fallRow + 1 < _rows && _grid[fallRow + 1][c] == null) {
            fallRow++;
          }
          _grid[fallRow][c] = _grid[r][c];
          _grid[r][c] = null;
          hadAction = true;
        }
      }
    }

    if (hadAction) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // 2. Merges
    bool mergedSomething = false;
    final sevensToBurst = <Point<int>>[];

    for (int r = _rows - 1; r >= 0; r--) {
      for (int c = 0; c < _cols; c++) {
        final tile = _grid[r][c];
        if (tile == null) continue;

        if (tile.value >= 7) {
          sevensToBurst.add(Point(r, c));
          continue;
        }

        if (r + 1 < _rows && _grid[r + 1][c] != null && _grid[r + 1][c]!.value == tile.value) {
          final newVal = tile.value + _grid[r + 1][c]!.value;
          _grid[r + 1][c] = PuzzleTile(value: newVal);
          _grid[r][c] = null;
          _score += newVal * 5;
          mergedSomething = true;
          HapticFeedback.selectionClick();
        }
      }
    }

    // 3. Detonate 7s
    if (sevensToBurst.isNotEmpty) {
      HapticFeedback.heavyImpact();
      chainCount++;
      _currentChain = chainCount;
      _maxChain = max(_maxChain, chainCount);
      _sevensCreated += sevensToBurst.length;

      final multiplier = chainCount > 1 ? chainCount : 1;
      _score += (70 * sevensToBurst.length * multiplier);

      setState(() {
        for (final p in sevensToBurst) {
          final r = p.x;
          final c = p.y;
          _grid[r][c] = null;
          if (r > 0) _grid[r - 1][c] = null;
          if (r < _rows - 1) _grid[r + 1][c] = null;
          if (c > 0) _grid[r][c - 1] = null;
          if (c < _cols - 1) _grid[r][c + 1] = null;
        }
      });

      await Future.delayed(const Duration(milliseconds: 220));
      await _processGravityAndMerges(chainCount);
    } else if (mergedSomething) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 160));
      await _processGravityAndMerges(chainCount);
    } else {
      _isProcessing = false;
      setState(() {});
    }
  }

  void _checkBoardStatus() {
    bool isFull = true;
    for (int c = 0; c < _cols; c++) {
      if (_grid[0][c] == null) {
        isFull = false;
        break;
      }
    }

    if (isFull) {
      widget.onGameOver(_score, {
        'sevensCreated': _sevensCreated,
        'maxChain': _maxChain,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final maxColWidth = (size.width - 48) / _cols;
        final maxRowHeight = (size.height - 230) / _rows;
        final tileSize = min(maxColWidth, maxRowHeight).clamp(32.0, 56.0);

        return Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -0.6),
              radius: 1.3,
              colors: [Color(0xFF20133E), Color(0xFF120C26), Color(0xFF0A0618)],
            ),
          ),
          child: Column(
            children: [
              // Top HUD (Level, Score, Best, Pause)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF654EA3)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.extension, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'LEVEL ${(_sevensCreated ~/ 3) + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Color(0xFFF5B942), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatScore(_score),
                              style: const TextStyle(
                                color: Color(0xFFF5B942),
                                fontFamily: 'Sora',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 7s Created Counter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0A12).withOpacity(0.65),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(
                          '7s: $_sevensCreated',
                          style: const TextStyle(
                            color: Color(0xFF9FE8C8),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      // Pause Button
                      GestureDetector(
                        onTap: () {
                          widget.onGameOver(_score, {
                            'sevensCreated': _sevensCreated,
                            'maxChain': _maxChain,
                          });
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0A12).withOpacity(0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Center(
                            child: Icon(Icons.pause, color: Color(0xFFEDEDF2), size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Next Tile Glass Bar (from `10_seven_puzzle.html`)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'NEXT',
                        style: TextStyle(
                          color: Color(0xFFA69FC0),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Next Tile Chip (42x42)
                      _buildDesignKitTileChip(_nextTile, 42),
                      const SizedBox(width: 8),
                      _buildDesignKitTileChip(_futureTile, 30),

                      const Spacer(),

                      // Chain Multiplier Gold Pill
                      if (_currentChain > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFFF5B942).withOpacity(0.25), const Color(0xFFF5B942).withOpacity(0.08)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.55)),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFF5B942).withOpacity(0.25), blurRadius: 14),
                            ],
                          ),
                          child: Text(
                            'Chain ${_currentChain}x',
                            style: const TextStyle(
                              color: Color(0xFFF5B942),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 5x7 Puzzle Board (Design Kit `10_seven_puzzle.html`)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E1636), Color(0xFF110C20)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 36, offset: const Offset(0, 16)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_cols, (c) {
                      return GestureDetector(
                        onTap: () => _dropInColumn(c),
                        child: Container(
                          width: tileSize,
                          height: tileSize * _rows + 14,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: List.generate(_rows, (r) {
                              final tile = _grid[r][c];
                              return Container(
                                width: tileSize,
                                height: tileSize + 2,
                                padding: const EdgeInsets.all(2),
                                child: tile != null
                                    ? _buildDesignKitTileChip(tile.value, tileSize - 4)
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                                        ),
                                      ),
                              );
                            }),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const Spacer(),

              // Bottom Booster Toolbar (`Undo`, `Swap`, `Clear column` from `10_seven_puzzle.html`)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 18, right: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDesignKitBoosterPill(
                        label: 'Undo',
                        badge: '$_undoCount',
                        onTap: _useUndo,
                      ),
                      const SizedBox(width: 12),
                      _buildDesignKitBoosterPill(
                        label: 'Swap',
                        badge: '$_swapCount',
                        onTap: _useSwap,
                      ),
                      const SizedBox(width: 12),
                      _buildDesignKitBoosterPill(
                        label: 'Clear col',
                        badge: '$_clearColCount',
                        onTap: () => _useClearColumn(2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesignKitTileChip(int value, double size) {
    Gradient gradient;
    Color textColor = Colors.white;
    BoxShadow? aura;

    switch (value) {
      case 1:
        gradient = const LinearGradient(colors: [Color(0xFFC39BFF), Color(0xFF6A3BD6)]);
        break;
      case 2:
        gradient = const LinearGradient(colors: [Color(0xFF6FB3FF), Color(0xFF1E55C4)]);
        break;
      case 3:
        gradient = const LinearGradient(colors: [Color(0xFF7FE6F2), Color(0xFF0F8EA3)]);
        break;
      case 4:
        gradient = const LinearGradient(colors: [Color(0xFF8AF0B0), Color(0xFF1E8A52)]);
        break;
      case 5:
        gradient = const LinearGradient(colors: [Color(0xFFFFD27A), Color(0xFFE8891C)]);
        break;
      case 6:
        gradient = const LinearGradient(colors: [Color(0xFFFFB45C), Color(0xFFE8641C)]);
        break;
      default: // 7
        gradient = const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFE8902A)]);
        textColor = const Color(0xFF1A1626);
        aura = const BoxShadow(color: Color(0xFFF5B942), blurRadius: 24, spreadRadius: 2);
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: aura != null
            ? [aura]
            : [
                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4)),
              ],
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            color: textColor,
            fontFamily: 'Sora',
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            shadows: textColor == Colors.white
                ? [Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDesignKitBoosterPill({
    required String label,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFEDEDF2),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE8265C),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE8265C).withOpacity(0.6), blurRadius: 8),
                ],
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatScore(int val) {
    final s = val.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
