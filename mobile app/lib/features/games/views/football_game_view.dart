import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FootballGameView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const FootballGameView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<FootballGameView> createState() => _FootballGameViewState();
}

enum ShootZone { topLeft, topRight, bottomLeft, bottomRight, center }

class _FootballGameViewState extends State<FootballGameView> with TickerProviderStateMixin {
  final ValueNotifier<int> _playerAScoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> _playerBScoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> _currentShotNotifier = ValueNotifier(1);
  final ValueNotifier<List<bool?>> _playerAHistoryNotifier = ValueNotifier([null, null, null, null, null]);
  final ValueNotifier<List<bool?>> _playerBHistoryNotifier = ValueNotifier([null, null, null, null, null]);
  final ValueNotifier<ShootZone> _aimZoneNotifier = ValueNotifier(ShootZone.center);
  final ValueNotifier<String> _feedbackNotifier = ValueNotifier('');
  final ValueNotifier<Color> _feedbackColorNotifier = ValueNotifier(Colors.white);
  final ValueNotifier<bool> _isShootingNotifier = ValueNotifier(false);

  static const int _totalShots = 5;
  int _goalsScored = 0;
  int _maxStreak = 0;
  int _streak = 0;
  int _round = 1;
  int _cumulativeScore = 0;
  bool _showingRoundClearModal = false;
  int _lastRoundBonus = 0;
  bool _lastRoundWon = false;

  // Power Bar Animation
  late AnimationController _powerController;
  late Animation<double> _powerAnimation;

  // Shot Flight Controller
  late AnimationController _shotFlightController;
  ShootZone _keeperDiveZone = ShootZone.center;
  bool _isKeeperDiving = false;
  bool _isOverpowered = false;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _round = widget.initialLevel > 1 ? widget.initialLevel : 1;
    _powerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _powerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _powerController, curve: Curves.easeInOut),
    );

    _shotFlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _powerController.dispose();
    _shotFlightController.dispose();
    _playerAScoreNotifier.dispose();
    _playerBScoreNotifier.dispose();
    _currentShotNotifier.dispose();
    _playerAHistoryNotifier.dispose();
    _playerBHistoryNotifier.dispose();
    _aimZoneNotifier.dispose();
    _feedbackNotifier.dispose();
    _feedbackColorNotifier.dispose();
    _isShootingNotifier.dispose();
    super.dispose();
  }

  void _selectZone(ShootZone zone) {
    if (_isShootingNotifier.value || _showingRoundClearModal) return;
    HapticFeedback.selectionClick();
    _aimZoneNotifier.value = zone;
  }

  void _takeShot() {
    if (_isShootingNotifier.value || _showingRoundClearModal) return;
    _isShootingNotifier.value = true;
    _powerController.stop();

    final powerValue = _powerAnimation.value;
    final isSweetSpot = powerValue >= 0.45 && powerValue <= 0.65;
    _isOverpowered = powerValue > 0.88;

    // AI Goalkeeper decision
    final allZones = ShootZone.values;
    _keeperDiveZone = allZones[_rand.nextInt(allZones.length)];
    _isKeeperDiving = true;

    HapticFeedback.heavyImpact();

    // Determine Shot outcome
    bool isGoal = false;
    String feedback = '';
    Color fbColor = Colors.white;

    final selectedZone = _aimZoneNotifier.value;
    if (_isOverpowered) {
      isGoal = false;
      feedback = 'OVER THE BAR! (Overpowered)';
      fbColor = const Color(0xFFFF4D4D);
      _streak = 0;
    } else if (_keeperDiveZone == selectedZone && !isSweetSpot) {
      isGoal = false;
      feedback = 'SAVED BY GOALKEEPER!';
      fbColor = const Color(0xFFF5B942);
      _streak = 0;
    } else {
      isGoal = true;
      _goalsScored++;
      _streak++;
      _maxStreak = max(_maxStreak, _streak);
      _playerAScoreNotifier.value++;

      if (selectedZone == ShootZone.topLeft || selectedZone == ShootZone.topRight) {
        feedback = 'TOP CORNER GOLAZO! (+150)';
        fbColor = const Color(0xFFF5B942);
      } else {
        feedback = 'GOAL! (+100)';
        fbColor = const Color(0xFF9FE8C8);
      }
    }

    _feedbackNotifier.value = feedback;
    _feedbackColorNotifier.value = fbColor;

    // Update Player A history
    final curShotIdx = _currentShotNotifier.value - 1;
    final newAHistory = List<bool?>.from(_playerAHistoryNotifier.value);
    newAHistory[curShotIdx] = isGoal;
    _playerAHistoryNotifier.value = newAHistory;

    // Simulate Player B (AI opponent)
    final aiGoal = _rand.nextDouble() < (0.45 + (_round * 0.05).clamp(0.0, 0.35));
    final newBHistory = List<bool?>.from(_playerBHistoryNotifier.value);
    newBHistory[curShotIdx] = aiGoal;
    _playerBHistoryNotifier.value = newBHistory;
    if (aiGoal) {
      _playerBScoreNotifier.value++;
    }

    // Trigger ball flight animation
    _shotFlightController.forward(from: 0.0);

    // Prepare next shot or finish round
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_currentShotNotifier.value >= _totalShots) {
        _finishRound();
      } else {
        _currentShotNotifier.value++;
        _isShootingNotifier.value = false;
        _isKeeperDiving = false;
        _isOverpowered = false;
        _feedbackNotifier.value = '';
        _shotFlightController.reset();
        _powerController.repeat(reverse: true);
      }
    });
  }

  void _finishRound() {
    final aScore = _playerAScoreNotifier.value;
    final bScore = _playerBScoreNotifier.value;
    final wonMatch = aScore >= bScore;

    final roundScore = (aScore * 120) + (_maxStreak * 60) + (wonMatch ? 300 : 80);
    _cumulativeScore += roundScore;
    _lastRoundBonus = roundScore;
    _lastRoundWon = wonMatch;

    setState(() {
      _showingRoundClearModal = true;
    });
  }

  void _startNextRound() {
    _round++;
    _playerAScoreNotifier.value = 0;
    _playerBScoreNotifier.value = 0;
    _currentShotNotifier.value = 1;
    _playerAHistoryNotifier.value = [null, null, null, null, null];
    _playerBHistoryNotifier.value = [null, null, null, null, null];
    _feedbackNotifier.value = '';
    _isShootingNotifier.value = false;
    _isKeeperDiving = false;
    _isOverpowered = false;
    _shotFlightController.reset();

    final newDurationMs = max(450, 900 - (_round * 60));
    _powerController.duration = Duration(milliseconds: newDurationMs);
    _powerController.repeat(reverse: true);

    setState(() {
      _showingRoundClearModal = false;
    });
  }

  void _claimAndExit() {
    widget.onGameOver(_cumulativeScore, {
      'goalsScored': _goalsScored,
      'roundsCompleted': _round,
      'maxStreak': _maxStreak,
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Container(
          width: size.width,
          height: size.height,
          color: const Color(0xFF04110B),
          child: Stack(
            children: [
              // Pitch & Stadium Direct Hardware Canvas
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _shotFlightController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _FootballStadiumDesignKitPainter(
                          flightProgress: _shotFlightController.value,
                          selectedZone: _aimZoneNotifier.value,
                          keeperZone: _keeperDiveZone,
                          isKeeperDiving: _isKeeperDiving,
                          isOverpowered: _isOverpowered,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Design Kit Top HUD (Round, Score, Shot & Rival)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Round / Stage Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2FBF71), Color(0xFF1E8A52)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2FBF71).withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                        child: Text(
                          'ROUND $_round',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Shot Count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0A12).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _currentShotNotifier,
                          builder: (context, shot, _) {
                            return Text(
                              'Shot $shot of 5',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            );
                          },
                        ),
                      ),

                      // Live Cumulative Score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            ValueListenableBuilder<int>(
                              valueListenable: _playerAScoreNotifier,
                              builder: (context, aScore, _) {
                                final liveScore = _cumulativeScore + (aScore * 100);
                                return Text(
                                  '$liveScore',
                                  style: const TextStyle(
                                    color: Color(0xFFF5B942),
                                    fontFamily: 'Sora',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Score Dots Strip (Top Center from Design Kit)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Player A Dots
                          ValueListenableBuilder<List<bool?>>(
                            valueListenable: _playerAHistoryNotifier,
                            builder: (context, historyA, _) {
                              return Row(
                                children: historyA.map(_buildDot).toList(),
                              );
                            },
                          ),
                          const SizedBox(width: 12),

                          // Score in Sora Font
                          ValueListenableBuilder<int>(
                            valueListenable: _playerAScoreNotifier,
                            builder: (context, scoreA, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: _playerBScoreNotifier,
                                builder: (context, scoreB, _) {
                                  return Text(
                                    '$scoreA : $scoreB',
                                    style: const TextStyle(
                                      color: Color(0xFFEDEDF2),
                                      fontFamily: 'Sora',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 12),

                          // Player B Dots
                          ValueListenableBuilder<List<bool?>>(
                            valueListenable: _playerBHistoryNotifier,
                            builder: (context, historyB, _) {
                              return Row(
                                children: historyB.map(_buildDot).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Interactive Goal Aim Grid (Tap Zones)
              Positioned(
                left: size.width * 0.18,
                top: size.height * 0.20,
                width: size.width * 0.64,
                height: size.height * 0.22,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isShootingNotifier,
                  builder: (context, isShooting, _) {
                    return ValueListenableBuilder<ShootZone>(
                      valueListenable: _aimZoneNotifier,
                      builder: (context, selectedZone, _) {
                        return Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _buildAimZone(ShootZone.topLeft, 'TOP L', selectedZone, isShooting),
                                  _buildAimZone(ShootZone.center, 'MID', selectedZone, isShooting),
                                  _buildAimZone(ShootZone.topRight, 'TOP R', selectedZone, isShooting),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  _buildAimZone(ShootZone.bottomLeft, 'LOW L', selectedZone, isShooting),
                                  _buildAimZone(ShootZone.center, 'CENTER', selectedZone, isShooting),
                                  _buildAimZone(ShootZone.bottomRight, 'LOW R', selectedZone, isShooting),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Round Feedback (e.g. TOP CORNER GOLAZO!)
              ValueListenableBuilder<String>(
                valueListenable: _feedbackNotifier,
                builder: (context, feedback, _) {
                  if (feedback.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    top: size.height * 0.15,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: ValueListenableBuilder<Color>(
                        valueListenable: _feedbackColorNotifier,
                        builder: (context, color, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0A12).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: color, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 14),
                              ],
                            ),
                            child: Text(
                              feedback,
                              style: TextStyle(
                                color: color,
                                fontFamily: 'Sora',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              // Bottom Power Bar Card (from Design Kit `06_football.html`)
              Positioned(
                left: 14,
                right: 14,
                bottom: 22,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'POWER · release in the gold zone',
                          style: TextStyle(
                            color: Color(0xFFA69FC0),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Moving Power Bar with Sweet Spot Zone
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2FBF71), Color(0xFFF5B942), Color(0xFFFF4D4D)],
                              stops: [0.0, 0.55, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFF5B942).withOpacity(0.35), blurRadius: 16),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Golden sweet spot zone
                              Positioned(
                                left: (size.width - 52) * 0.45,
                                width: (size.width - 52) * 0.18,
                                top: -3,
                                bottom: -3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 8)],
                                  ),
                                ),
                              ),

                              // Sliding Cursor
                              AnimatedBuilder(
                                animation: _powerAnimation,
                                builder: (context, child) {
                                  return Positioned(
                                    left: _powerAnimation.value * (size.width - 56),
                                    top: -6,
                                    child: Container(
                                      width: 5,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 8)],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Controls Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: const Text(
                                'Swipe to curve',
                                style: TextStyle(color: Color(0xFFEDEDF2), fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),

                            // Shoot Button
                            ValueListenableBuilder<bool>(
                              valueListenable: _isShootingNotifier,
                              builder: (context, isShooting, _) {
                                return GestureDetector(
                                  onTap: isShooting ? null : _takeShot,
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    decoration: BoxDecoration(
                                      gradient: isShooting
                                          ? null
                                          : const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Color(0xFFFF4D7E), Color(0xFFE8265C), Color(0xFFC81A4C)],
                                            ),
                                      color: isShooting ? Colors.white12 : null,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: isShooting
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFFE8265C).withOpacity(0.45),
                                                blurRadius: 16,
                                              ),
                                            ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Shoot',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Round Cleared Modal Overlay
              if (_showingRoundClearModal)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.78),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E2333), Color(0xFF0C101A)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _lastRoundWon ? const Color(0xFFF5B942) : const Color(0xFF2E7CF6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: (_lastRoundWon ? const Color(0xFFF5B942) : const Color(0xFF2E7CF6)).withOpacity(0.3),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _lastRoundWon ? Icons.emoji_events_rounded : Icons.sports_soccer_rounded,
                              size: 54,
                              color: _lastRoundWon ? const Color(0xFFF5B942) : const Color(0xFF6FB3FF),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _lastRoundWon ? 'ROUND $_round VICTORY!' : 'ROUND $_round FINISHED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Sora',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '+$_lastRoundBonus RP Score',
                              style: const TextStyle(
                                color: Color(0xFF9FE8C8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Score: $_cumulativeScore',
                              style: const TextStyle(
                                color: Color(0xFFC9C9D6),
                                fontSize: 13,
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
                                    onPressed: _startNextRound,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2FBF71),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text(
                                      'Next Round (${_round + 1})',
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

  Widget _buildDot(bool? res) {
    Color bg = Colors.white.withOpacity(0.2);
    BoxShadow? shadow;

    if (res == true) {
      bg = const Color(0xFF9FE8C8);
      shadow = const BoxShadow(color: Color(0xFF9FE8C8), blurRadius: 8);
    } else if (res == false) {
      bg = const Color(0xFFFF4D4D);
      shadow = const BoxShadow(color: Color(0xFFFF4D4D), blurRadius: 8);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: shadow != null ? [shadow] : null,
      ),
    );
  }

  Widget _buildAimZone(ShootZone zone, String label, ShootZone selectedZone, bool isShooting) {
    final isSelected = selectedZone == zone;
    return Expanded(
      child: GestureDetector(
        onTap: isShooting ? null : () => _selectZone(zone),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF5B942).withOpacity(0.35) : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: isSelected ? const Color(0xFFF5B942) : Colors.white10,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFF5B942) : Colors.white54,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FootballStadiumDesignKitPainter extends CustomPainter {
  final double flightProgress;
  final ShootZone selectedZone;
  final ShootZone keeperZone;
  final bool isKeeperDiving;
  final bool isOverpowered;

  _FootballStadiumDesignKitPainter({
    required this.flightProgress,
    required this.selectedZone,
    required this.keeperZone,
    required this.isKeeperDiving,
    required this.isOverpowered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Stadium Grass Pitch Gradient (#0B2A1C -> #1E8A52 -> #36C97A)
    final pitchRect = Rect.fromLTWH(0, 0, width, height);
    final pitchPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B2A1C), Color(0xFF1E8A52), Color(0xFF36C97A)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(pitchRect);
    canvas.drawRect(pitchRect, pitchPaint);

    // Top Dark Stand Area
    canvas.drawRect(Rect.fromLTWH(0, 0, width, 240), Paint()..color = const Color(0xFF04110B));

    // Pitch Stripes
    final stripePaint = Paint()..color = Colors.white.withOpacity(0.045);
    for (double y = 260; y < height; y += 45) {
      canvas.drawRect(Rect.fromLTWH(0, y, width, 22), stripePaint);
    }

    // 2. Crowd Gallery Backdrop
    final crowdRect = Rect.fromLTWH(0, 200, width, 40);
    canvas.drawRect(crowdRect, Paint()..color = const Color(0xFF1B1B33));

    final crowdColors = [const Color(0xFF3B3B6B), const Color(0xFF5A3B6B), const Color(0xFF3B5A6B), const Color(0xFF6B3B4A)];
    for (double cx = 15; cx < width; cx += 25) {
      final color = crowdColors[(cx ~/ 25) % crowdColors.length];
      canvas.drawCircle(Offset(cx, 220), 6.5, Paint()..color = color);
    }

    // 3. Floodlights
    _drawFloodlight(canvas, Offset(width * 0.18, 55), width);
    _drawFloodlight(canvas, Offset(width * 0.82, 55), width);

    // 4. Goal Net & Post Frame
    final goalL = width * 0.18;
    final goalR = width * 0.82;
    final goalT = height * 0.20;
    final goalB = height * 0.42;

    // Goal Net Mesh
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0;
    for (double gx = goalL; gx <= goalR; gx += 14) {
      canvas.drawLine(Offset(gx, goalT), Offset(gx, goalB), netPaint);
    }
    for (double gy = goalT; gy <= goalB; gy += 12) {
      canvas.drawLine(Offset(goalL, gy), Offset(goalR, gy), netPaint);
    }

    // Goal Posts & Crossbar
    final postPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(goalL, goalB), Offset(goalL, goalT), postPaint);
    canvas.drawLine(Offset(goalL, goalT), Offset(goalR, goalT), postPaint);
    canvas.drawLine(Offset(goalR, goalT), Offset(goalR, goalB), postPaint);

    // 5. Goalkeeper Character (Design Kit SVG model)
    double keeperTargetX = width * 0.5;
    double keeperTargetY = goalT + (goalB - goalT) * 0.55;

    if (isKeeperDiving) {
      final keeperProg = Curves.easeOutQuad.transform(flightProgress.clamp(0.0, 1.0));
      switch (keeperZone) {
        case ShootZone.topLeft:
          keeperTargetX = width * 0.5 - (width * 0.22 * keeperProg);
          keeperTargetY = goalT + (goalB - goalT) * 0.25;
          break;
        case ShootZone.topRight:
          keeperTargetX = width * 0.5 + (width * 0.22 * keeperProg);
          keeperTargetY = goalT + (goalB - goalT) * 0.25;
          break;
        case ShootZone.bottomLeft:
          keeperTargetX = width * 0.5 - (width * 0.22 * keeperProg);
          keeperTargetY = goalT + (goalB - goalT) * 0.75;
          break;
        case ShootZone.bottomRight:
          keeperTargetX = width * 0.5 + (width * 0.22 * keeperProg);
          keeperTargetY = goalT + (goalB - goalT) * 0.75;
          break;
        case ShootZone.center:
          keeperTargetX = width * 0.5;
          keeperTargetY = goalT + (goalB - goalT) * 0.55;
          break;
      }
    }

    // Draw Goalkeeper
    canvas.save();
    canvas.translate(keeperTargetX, keeperTargetY);

    // Goalkeeper Jersey Body
    final jerseyRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -18, 32, 34), const Radius.circular(8));
    final jerseyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6FB3FF), Color(0xFF1E55C4)],
      ).createShader(jerseyRect.outerRect);
    canvas.drawRRect(jerseyRect, jerseyPaint);

    // White Jersey Center Stripe
    canvas.drawRect(const Rect.fromLTWH(-5, -18, 10, 34), Paint()..color = Colors.white.withOpacity(0.18));

    // Head & Hair
    canvas.drawCircle(const Offset(0, -30), 12, Paint()..color = const Color(0xFFE9C3A0));
    final hairPath = Path()
      ..moveTo(-12, -36)
      ..quadraticBezierTo(0, -48, 12, -36)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF3A2A1E));

    // Gloves (Yellow Gold)
    canvas.drawCircle(const Offset(-22, -10), 6, Paint()..color = const Color(0xFFF5B942));
    canvas.drawCircle(const Offset(22, -10), 6, Paint()..color = const Color(0xFFF5B942));

    // Shorts
    canvas.drawRect(const Rect.fromLTWH(-14, 16, 11, 18), Paint()..color = const Color(0xFF111111));
    canvas.drawRect(const Rect.fromLTWH(3, 16, 11, 18), Paint()..color = const Color(0xFF111111));

    canvas.restore();

    // 6. Aiming Curve Line (from ball to target)
    final ballOrigin = Offset(width * 0.5, height * 0.72);
    final targetOffset = _getTargetOffset(selectedZone, goalL, goalR, goalT, goalB, width);

    final curvePath = Path();
    curvePath.moveTo(ballOrigin.dx, ballOrigin.dy);
    curvePath.quadraticBezierTo(width * 0.52, height * 0.48, targetOffset.dx, targetOffset.dy);

    final dashPaint = Paint()
      ..color = const Color(0xFFFFE08A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(curvePath, dashPaint);
    canvas.drawCircle(targetOffset, 8, dashPaint);

    // 7. Football Flight Trajectory
    final p = Curves.easeOutCubic.transform(flightProgress);
    final currentBallX = ballOrigin.dx + (targetOffset.dx - ballOrigin.dx) * p;
    final currentBallY = ballOrigin.dy + (targetOffset.dy - ballOrigin.dy) * p - (sin(p * pi) * 40.0);
    final currentScale = 1.0 - (p * 0.55);

    // Ball Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(currentBallX, ballOrigin.dy + (targetOffset.dy - ballOrigin.dy) * p),
        width: 32 * currentScale,
        height: 12 * currentScale,
      ),
      Paint()..color = Colors.black.withOpacity(0.35 * (1.0 - p)),
    );

    // Draw Football
    canvas.save();
    canvas.translate(currentBallX, currentBallY);
    canvas.scale(currentScale);

    canvas.drawCircle(Offset.zero, 24, Paint()..color = Colors.white);
    final ballBorder = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset.zero, 24, ballBorder);

    // Pentagons on ball
    final centerHex = Path()
      ..moveTo(0, -18)
      ..lineTo(10, -7)
      ..lineTo(6, 6)
      ..lineTo(-6, 6)
      ..lineTo(-10, -7)
      ..close();
    canvas.drawPath(centerHex, Paint()..color = const Color(0xFF111111));

    canvas.restore();
  }

  void _drawFloodlight(Canvas canvas, Offset pos, double screenWidth) {
    // Light Beam
    final beam = Path()
      ..moveTo(pos.dx, pos.dy)
      ..lineTo(pos.dx > screenWidth * 0.5 ? pos.dx - 110 : 0, 300)
      ..lineTo(pos.dx > screenWidth * 0.5 ? screenWidth : pos.dx + 110, 300)
      ..close();
    canvas.drawPath(beam, Paint()..color = Colors.white.withOpacity(0.07));

    // Floodlight lamp
    canvas.drawCircle(pos, 32, Paint()..color = Colors.white.withOpacity(0.18));
    canvas.drawCircle(pos, 15, Paint()..color = Colors.white);
  }

  Offset _getTargetOffset(ShootZone zone, double gl, double gr, double gt, double gb, double width) {
    switch (zone) {
      case ShootZone.topLeft:
        return Offset(gl + 25, isOverpowered ? gt - 25 : gt + 25);
      case ShootZone.topRight:
        return Offset(gr - 25, isOverpowered ? gt - 25 : gt + 25);
      case ShootZone.bottomLeft:
        return Offset(gl + 25, gb - 25);
      case ShootZone.bottomRight:
        return Offset(gr - 25, gb - 25);
      case ShootZone.center:
        return Offset(width * 0.5, isOverpowered ? gt - 25 : gt + (gb - gt) * 0.5);
    }
  }

  @override
  bool shouldRepaint(covariant _FootballStadiumDesignKitPainter oldDelegate) => true;
}
