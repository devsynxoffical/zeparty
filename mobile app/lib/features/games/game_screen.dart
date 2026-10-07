import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import 'views/fishing_game_view.dart';
import 'views/football_game_view.dart';
import 'views/fruit_match_view.dart';
import 'views/rocket_challenge_view.dart';
import 'views/lion_adventure_view.dart';
import 'views/seven_puzzle_view.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final bool inRoom;

  const GameScreen({
    super.key,
    required this.gameId,
    required this.gameName,
    this.inRoom = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isPaused = false;
  bool _soundEnabled = true;
  Key _gameKey = UniqueKey();

  void _onGameOver(int score, Map<String, dynamic> stats) {
    HapticFeedback.heavyImpact();

    int levelReached = 1;
    if (stats['level'] is int) {
      levelReached = stats['level'] as int;
    } else if (stats['wave'] is int) {
      levelReached = stats['wave'] as int;
    } else if (stats['roundsCompleted'] is int) {
      levelReached = stats['roundsCompleted'] as int;
    } else if (stats['stage'] is int) {
      levelReached = stats['stage'] as int;
    } else if (stats['distance'] is int) {
      levelReached = ((stats['distance'] as int) ~/ 400) + 1;
    } else if (stats['sevensCreated'] is int) {
      levelReached = ((stats['sevensCreated'] as int) ~/ 3) + 1;
    }

    int earnedRp = 10;
    if (score >= 3000) {
      earnedRp = 50;
    } else if (score >= 1500) {
      earnedRp = 35;
    } else if (score >= 500) {
      earnedRp = 20;
    }

    final gameProvider = context.read<GameProvider>();
    final recordResult = gameProvider.recordGameScore(
      widget.gameId,
      score,
      earnedRp: earnedRp,
      level: levelReached,
      stats: stats,
    );

    final isNewBest = recordResult['isNewBest'] as bool? ?? false;
    final grantedRp = recordResult['grantedRp'] as int? ?? earnedRp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildResultDialog(score, grantedRp, isNewBest, stats, gameProvider, levelReached: levelReached),
    );
  }

  void _showPauseDialog() {
    HapticFeedback.selectionClick();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16121F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE8265C), width: 1.5),
        ),
        title: const Center(
          child: Text(
            'GAME PAUSED',
            style: TextStyle(
              fontFamily: 'Sora',
              color: Color(0xFFEDEDF2),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off, color: const Color(0xFF1FB6C8)),
              title: Text(_soundEnabled ? 'Sound: ON' : 'Sound: OFF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => _soundEnabled = !_soundEnabled);
                Navigator.pop(ctx);
                _showPauseDialog();
              },
            ),
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () {
                setState(() => _isPaused = false);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8265C),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('RESUME GAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('QUIT TO LOBBY', style: TextStyle(color: Color(0xFFA69FC0), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDialog(
    int score,
    int earnedRp,
    bool isNewBest,
    Map<String, dynamic> stats,
    GameProvider gameProvider, {
    int levelReached = 1,
  }) {
    final dailyRpProgress = (gameProvider.dailyRpEarned / gameProvider.dailyRpCap).clamp(0.0, 1.0);
    final personalBest = gameProvider.personalBests[widget.gameId] ?? score;
    final personalLevel = gameProvider.personalLevels[widget.gameId] ?? levelReached;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF211A36), Color(0xFF120F1D)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trophy
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5B942).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.emoji_events, color: Color(0xFFF5B942), size: 38),
                ),
              ),
            ),
            const SizedBox(height: 6),

            const Text(
              'RUN COMPLETE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA69FC0),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),

            // Big Score
            Text(
              _formatScore(score),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Sora',
                color: Color(0xFFF5B942),
                fontSize: 38,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Color(0xFFF5B942), blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 6),

            // Level Reached & New Best Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FE8C8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF9FE8C8).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech, color: Color(0xFF9FE8C8), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Level $levelReached',
                        style: const TextStyle(color: Color(0xFF9FE8C8), fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isNewBest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B942).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.55)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Color(0xFFF5B942), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'New Best Record!',
                          style: TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Summary Stats Card (High Score & Highest Level)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _formatScore(personalBest),
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          color: Color(0xFFEDEDF2),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Best Record',
                        style: TextStyle(color: Color(0xFFA69FC0), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 22, color: Colors.white12),
                  Column(
                    children: [
                      Text(
                        'Level $personalLevel',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          color: Color(0xFF9FE8C8),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Max Level',
                        style: TextStyle(color: Color(0xFFA69FC0), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Reward Points Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reward Points', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('+$earnedRp RP', style: const TextStyle(fontFamily: 'Sora', color: Color(0xFFF5B942), fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: dailyRpProgress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5B942)),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${gameProvider.dailyRpEarned} / ${gameProvider.dailyRpCap} RP today',
                    style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Missions Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Missions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Catch 50 fish', style: TextStyle(color: Color(0xFFA69FC0), fontSize: 11.5)),
                      Text('50/50 · complete', style: TextStyle(color: Color(0xFF9FE8C8), fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Play Again (Magenta)
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _gameKey = UniqueKey();
                });
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D7E), Color(0xFFE8265C), Color(0xFFC81A4C)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE8265C).withOpacity(0.4), blurRadius: 12),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Play again',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Back to Games
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'Back to Games',
                style: TextStyle(color: Color(0xFFA69FC0), fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),

            const Text(
              'Reward Points have no cash value',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA69FC0), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    final gameProvider = context.watch<GameProvider>();
    final startLevel = gameProvider.personalLevels[widget.gameId] ?? 1;
    final gid = widget.gameId.toLowerCase().replaceAll(RegExp(r'[-_]'), '');

    if (gid.contains('fishing')) {
      return FishingGameView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    } else if (gid.contains('football')) {
      return FootballGameView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    } else if (gid.contains('fruit')) {
      return FruitMatchView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    } else if (gid.contains('rocket')) {
      return RocketChallengeView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    } else if (gid.contains('lion')) {
      return LionAdventureView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    } else if (gid.contains('seven')) {
      return SevenPuzzleView(
        key: _gameKey,
        onGameOver: _onGameOver,
        inRoom: widget.inRoom,
        initialLevel: startLevel,
      );
    }

    return FishingGameView(
      key: _gameKey,
      onGameOver: _onGameOver,
      inRoom: widget.inRoom,
      initialLevel: startLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A12),
      body: SafeArea(
        child: Stack(
          children: [
            _buildGameView(),

            // Top HUD Overlay
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0A12).withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: _showPauseDialog,
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0A12).withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.pause, color: Colors.white, size: 18),
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

  String _formatScore(int val) {
    final s = val.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
