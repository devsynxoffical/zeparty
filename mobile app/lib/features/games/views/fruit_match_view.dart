import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FruitMatchView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const FruitMatchView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<FruitMatchView> createState() => _FruitMatchViewState();
}

enum FruitType {
  strawberry, // 🍓
  orange,     // 🍊
  grape,      // 🍇
  banana,     // 🍌
  kiwi,       // 🥝
  blueberry,  // 🫐
}

enum SpecialType { none, striped, rainbow }

class FruitTile {
  FruitType type;
  SpecialType special;
  bool isMatched;

  FruitTile({
    required this.type,
    this.special = SpecialType.none,
    this.isMatched = false,
  });
}

class _FruitMatchViewState extends State<FruitMatchView> {
  static const int _rows = 8;
  static const int _cols = 8;

  int _score = 0;
  int _movesLeft = 20;
  int _targetStrawberry = 15;
  int _collectedStrawberry = 0;
  int _level = 1;
  bool _showingLevelClearModal = false;

  int? _selectedRow;
  int? _selectedCol;
  bool _isProcessing = false;

  late List<List<FruitTile>> _board;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel > 1 ? widget.initialLevel : 1;
    _targetStrawberry = 15 + (_level * 4);
    _movesLeft = 18 + min(6, _level);
    _initBoard();
  }

  void _initBoard() {
    _board = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        return FruitTile(type: _getRandomFruitExcluding([]));
      });
    });

    _resolveInitialBoard();
  }

  FruitType _getRandomFruitExcluding(List<FruitType> exclude) {
    final available = FruitType.values.where((f) => !exclude.contains(f)).toList();
    return available[_rand.nextInt(available.length)];
  }

  void _resolveInitialBoard() {
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        while ((c >= 2 && _board[r][c].type == _board[r][c - 1].type && _board[r][c].type == _board[r][c - 2].type) ||
            (r >= 2 && _board[r][c].type == _board[r - 1][c].type && _board[r][c].type == _board[r - 2][c].type)) {
          _board[r][c].type = _getRandomFruitExcluding([]);
        }
      }
    }
  }

  void _onTileTap(int r, int c) {
    if (_isProcessing || _movesLeft <= 0) return;

    if (_selectedRow == null || _selectedCol == null) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedRow = r;
        _selectedCol = c;
      });
    } else {
      final sr = _selectedRow!;
      final sc = _selectedCol!;

      final isAdjacent = (sr == r && (sc - c).abs() == 1) || (sc == c && (sr - r).abs() == 1);

      if (isAdjacent) {
        _swapAndCheck(sr, sc, r, c);
      } else {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedRow = r;
          _selectedCol = c;
        });
      }
    }
  }

  void _swapAndCheck(int r1, int c1, int r2, int c2) async {
    _isProcessing = true;
    HapticFeedback.mediumImpact();

    setState(() {
      final temp = _board[r1][c1];
      _board[r1][c1] = _board[r2][c2];
      _board[r2][c2] = temp;
      _selectedRow = null;
      _selectedCol = null;
      _movesLeft--;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    final matches = _findMatches();

    if (matches.isEmpty) {
      setState(() {
        final temp = _board[r1][c1];
        _board[r1][c1] = _board[r2][c2];
        _board[r2][c2] = temp;
        _movesLeft++;
      });
      _isProcessing = false;
    } else {
      await _processMatches(matches);
      _checkGameStatus();
    }
  }

  List<Point<int>> _findMatches() {
    final matchedCoords = <Point<int>>{};

    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols - 2; c++) {
        final type = _board[r][c].type;
        if (type == _board[r][c + 1].type && type == _board[r][c + 2].type) {
          matchedCoords.add(Point(r, c));
          matchedCoords.add(Point(r, c + 1));
          matchedCoords.add(Point(r, c + 2));
        }
      }
    }

    for (int c = 0; c < _cols; c++) {
      for (int r = 0; r < _rows - 2; r++) {
        final type = _board[r][c].type;
        if (type == _board[r + 1][c].type && type == _board[r + 2][c].type) {
          matchedCoords.add(Point(r, c));
          matchedCoords.add(Point(r + 1, c));
          matchedCoords.add(Point(r + 2, c));
        }
      }
    }

    return matchedCoords.toList();
  }

  Future<void> _processMatches(List<Point<int>> matches) async {
    HapticFeedback.heavyImpact();

    for (final p in matches) {
      final t = _board[p.x][p.y];
      if (t.type == FruitType.strawberry) _collectedStrawberry++;
      _score += 40;
    }

    setState(() {
      for (final p in matches) {
        _board[p.x][p.y].isMatched = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 220));

    setState(() {
      for (int c = 0; c < _cols; c++) {
        int emptySlots = 0;
        for (int r = _rows - 1; r >= 0; r--) {
          if (_board[r][c].isMatched) {
            emptySlots++;
          } else if (emptySlots > 0) {
            _board[r + emptySlots][c] = _board[r][c];
            _board[r][c] = FruitTile(type: _getRandomFruitExcluding([]), isMatched: true);
          }
        }
        for (int r = 0; r < emptySlots; r++) {
          final isRainbow = _rand.nextDouble() < 0.05;
          final isStriped = _rand.nextDouble() < 0.10;
          _board[r][c] = FruitTile(
            type: _getRandomFruitExcluding([]),
            special: isRainbow ? SpecialType.rainbow : (isStriped ? SpecialType.striped : SpecialType.none),
          );
        }
      }

      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          _board[r][c].isMatched = false;
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 220));

    final cascadeMatches = _findMatches();
    if (cascadeMatches.isNotEmpty) {
      await _processMatches(cascadeMatches);
    } else {
      _isProcessing = false;
    }
  }

  void _useBoosterHammer() {
    if (_selectedRow != null && _selectedCol != null && !_isProcessing) {
      final r = _selectedRow!;
      final c = _selectedCol!;
      HapticFeedback.heavyImpact();
      setState(() {
        _board[r][c].type = _getRandomFruitExcluding([_board[r][c].type]);
        _selectedRow = null;
        _selectedCol = null;
      });
      final matches = _findMatches();
      if (matches.isNotEmpty) {
        _processMatches(matches);
      }
    }
  }

  void _checkGameStatus() {
    final targetsMet = _collectedStrawberry >= _targetStrawberry;
    if (targetsMet) {
      final levelBonus = 400 + (_movesLeft * 35);
      _score += levelBonus;
      HapticFeedback.heavyImpact();
      setState(() {
        _showingLevelClearModal = true;
      });
    } else if (_movesLeft <= 0) {
      Future.delayed(const Duration(milliseconds: 600), () {
        widget.onGameOver(_score, {
          'targetsCompleted': false,
          'level': _level,
          'movesLeft': _movesLeft,
          'strawberries': _collectedStrawberry,
        });
      });
    }
  }

  void _startNextLevel() {
    _level++;
    _collectedStrawberry = 0;
    _targetStrawberry = 15 + (_level * 4);
    _movesLeft = 18 + min(6, _level);
    _selectedRow = null;
    _selectedCol = null;
    _isProcessing = false;
    _initBoard();

    setState(() {
      _showingLevelClearModal = false;
    });
  }

  void _claimAndExit() {
    widget.onGameOver(_score, {
      'targetsCompleted': true,
      'level': _level,
      'strawberries': _collectedStrawberry,
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final availableWidth = constraints.maxWidth - 24;
        final availableHeight = constraints.maxHeight - 270;
        final boardConstraint = min(availableWidth, availableHeight);
        final tileSize = ((boardConstraint - 40) / _cols).floorToDouble().clamp(20.0, 44.0);

        return Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -0.6),
              radius: 1.2,
              colors: [Color(0xFF3B1E12), Color(0xFF2A1410), Color(0xFF140806)],
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Top HUD (Level, Moves, Score, Pause)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A3D), Color(0xFFE8265C)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFE8265C).withOpacity(0.4), blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'LEVEL $_level',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Moves Left Mid Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0A12).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Text(
                          'Moves: $_movesLeft',
                          style: TextStyle(
                            color: _movesLeft <= 5 ? const Color(0xFFFF4D4D) : const Color(0xFFEDEDF2),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      // Live Score Pill
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

                      // Pause Button
                      GestureDetector(
                        onTap: () {
                          widget.onGameOver(_score, {
                            'targetsCompleted': _collectedStrawberry >= _targetStrawberry,
                            'level': _level,
                            'movesLeft': _movesLeft,
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

              // Target Glass Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🍓', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                'Target: $_targetStrawberry Strawberries',
                                style: const TextStyle(color: Color(0xFFEDEDF2), fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            '$_collectedStrawberry / $_targetStrawberry',
                            style: const TextStyle(
                              color: Color(0xFFF5B942),
                              fontFamily: 'Sora',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Progress Meter
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_collectedStrawberry / _targetStrawberry).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A3D), Color(0xFFFFD166)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFF8A3D).withOpacity(0.5), blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 8x8 Wooden Board (Design Kit `07_fruit_match.html`)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B1E12), Color(0xFF1E0E08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6B3A1E), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 14)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_rows, (r) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_cols, (c) {
                            final tile = _board[r][c];
                            final isSelected = _selectedRow == r && _selectedCol == c;

                            return GestureDetector(
                              onTap: () => _onTileTap(r, c),
                              child: Container(
                                width: tileSize,
                                height: tileSize,
                                margin: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  gradient: tile.special == SpecialType.rainbow
                                      ? const SweepGradient(
                                          colors: [Color(0xFFE8265C), Color(0xFFFFD166), Color(0xFF2FBF71), Color(0xFF2E7CF6), Color(0xFF8B5CF6), Color(0xFFE8265C)],
                                        )
                                      : (isSelected
                                          ? const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFE8891C)])
                                          : const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [Color(0xFF4A2A1A), Color(0xFF2E170D)],
                                            )),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 2, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _getFruitEmoji(tile.type),
                                    style: TextStyle(fontSize: tileSize * 0.58),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Bottom Booster Toolbar (`88x68` Glass Cards from `07_fruit_match.html`)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 18, right: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDesignKitBoosterCard(
                        gradient: const LinearGradient(colors: [Color(0xFFFFB45C), Color(0xFFE8641C)]),
                        icon: Icons.gavel,
                        label: 'Hammer',
                        badge: '2',
                        onTap: _useBoosterHammer,
                      ),
                      const SizedBox(width: 12),
                      _buildDesignKitBoosterCard(
                        gradient: const LinearGradient(colors: [Color(0xFF6FB3FF), Color(0xFF1E55C4)]),
                        icon: Icons.shuffle,
                        label: 'Shuffle',
                        badge: '1',
                        onTap: () => setState(() => _initBoard()),
                      ),
                      const SizedBox(width: 12),
                      _buildDesignKitBoosterCard(
                        gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFE8902A)]),
                        icon: Icons.add_circle,
                        label: '+5 Moves',
                        badge: '1',
                        onTap: () => setState(() => _movesLeft += 5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Level Cleared Modal Overlay
          if (_showingLevelClearModal)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.80),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A1410), Color(0xFF140806)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF5B942), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF5B942).withOpacity(0.3),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LEVEL $_level COMPLETE!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Sora',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Target Fruits Collected! ★★★',
                          style: TextStyle(
                            color: Color(0xFF9FE8C8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total Score: ${_formatScore(_score)}',
                          style: const TextStyle(
                            color: Color(0xFFC9C9D6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _claimAndExit,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Exit & Claim', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _startNextLevel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE8265C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  'Next Level (${_level + 1})',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesignKitBoosterCard({
    required Gradient gradient,
    required IconData icon,
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
            width: 88,
            height: 64,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 14),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFEDEDF2),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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

  String _getFruitEmoji(FruitType type) {
    switch (type) {
      case FruitType.strawberry:
        return '🍓';
      case FruitType.orange:
        return '🍊';
      case FruitType.grape:
        return '🍇';
      case FruitType.banana:
        return '🍌';
      case FruitType.kiwi:
        return '🥝';
      case FruitType.blueberry:
        return '🫐';
    }
  }
}
