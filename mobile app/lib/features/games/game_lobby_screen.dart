import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import 'game_screen.dart';
import 'game_detail_sheet.dart';
import 'rp_wallet_sheet.dart';
import 'rp_shop_sheet.dart';
import 'energy_sheet.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final List<Map<String, dynamic>> _games = [
    {
      'id': 'fishing',
      'name': 'Fishing',
      'category': 'Arcade',
      'tagline': 'Catch, combo, beat the boss',
      'description': 'Aim and shoot nets to catch swimming fish, build combo multipliers up to 3x, survive 10 waves and defeat the giant Boss Shark.',
      'icon': '🎣',
      'badge': 'ARCADE',
      'artGradient': [Color(0xFF2FD3E6), Color(0xFF0C6A8C), Color(0xFF041E2E)],
      'accentColor': Color(0xFF1FB6C8),
      'usesEnergy': true,
      'energyCost': 1,
      'duration': '3 to 4 min',
      'rpCap': 'Up to 50 RP',
      'modes': ['Classic (10 Waves)', 'Boss Rush', 'Endless Challenge'],
    },
    {
      'id': 'football',
      'name': 'Football',
      'category': 'Sports & Skill',
      'tagline': 'Penalty shootout',
      'description': 'Aim with curve swipe, time the power bar golden sweet spot, score top-corner golazos, and dive as goalkeeper in best of 5.',
      'icon': '⚽',
      'badge': 'SPORTS',
      'artGradient': [Color(0xFF0B2A1C), Color(0xFF1E8A52), Color(0xFF36C97A)],
      'accentColor': Color(0xFF2FBF71),
      'usesEnergy': false,
      'energyCost': 0,
      'duration': '2 min',
      'rpCap': 'Up to 45 RP',
      'modes': ['Quick Shootout vs AI', '1 vs 1 Realtime', 'Host Challenge', 'Daily Ladder'],
    },
    {
      'id': 'fruit_match',
      'name': 'Fruit Match',
      'category': 'Match-3 Puzzle',
      'tagline': 'Match-3 levels',
      'description': 'Swap adjacent fruits to clear targets within move limits. Create striped, bomb, and rainbow special fruit combos.',
      'icon': '🍓',
      'badge': 'PUZZLE',
      'artGradient': [Color(0xFFFFB45C), Color(0xFFE8641C), Color(0xFF9E1F5C)],
      'accentColor': Color(0xFFFF8A3D),
      'usesEnergy': false,
      'energyCost': 0,
      'duration': '2 to 3 min',
      'rpCap': 'Up to 50 RP',
      'modes': ['Level Journey (60 Levels)', 'Star Challenge', 'Endless Match'],
    },
    {
      'id': 'rocket_challenge',
      'name': 'Rocket Challenge',
      'category': 'Reflex & Timing',
      'tagline': 'Stop at the target',
      'description': 'Launch the rocket and tap STOP at the exact target altitude. Precision timing scores Perfects and streak multipliers.',
      'icon': '🚀',
      'badge': 'TIMING',
      'artGradient': [Color(0xFF03041A), Color(0xFF1A2566), Color(0xFF6DB4F0)],
      'accentColor': Color(0xFF2E7CF6),
      'usesEnergy': false,
      'energyCost': 0,
      'duration': '90 sec',
      'rpCap': 'Up to 50 RP',
      'modes': ['Classic (10 Rounds)', 'Endurance', 'Duel Mode'],
    },
    {
      'id': 'lion_adventure',
      'name': 'Lion Adventure',
      'category': 'Endless Runner',
      'tagline': 'Run and collect',
      'description': 'Swipe left/right to change lanes, jump over logs and slide under branches. Collect gems, shields, and speed boosts.',
      'icon': '🦁',
      'badge': 'RUNNER',
      'artGradient': [Color(0xFF0E2B14), Color(0xFF2E7A36), Color(0xFF8A5A24)],
      'accentColor': Color(0xFFF5A623),
      'usesEnergy': true,
      'energyCost': 1,
      'duration': '3 to 5 min',
      'rpCap': 'Up to 50 RP',
      'modes': ['Jungle Run', 'Ruins Sprint', 'Night Hunt'],
    },
    {
      'id': 'seven_puzzle',
      'name': 'Seven Puzzle',
      'category': 'Number Merge',
      'tagline': 'Merge numbers to 7',
      'description': 'Drop numbered tiles into columns. Merge equal numbers to reach 7, clear neighbors, and trigger chain reactions.',
      'icon': '🧩',
      'badge': 'PUZZLE',
      'artGradient': [Color(0xFF200B3B), Color(0xFF654EA3), Color(0xFFEAAFC8)],
      'accentColor': Color(0xFF8B5CF6),
      'usesEnergy': false,
      'energyCost': 0,
      'duration': '3 min',
      'rpCap': 'Up to 50 RP',
      'modes': ['Classic Strategy', 'Timed Rush (2 Mins)', 'Daily Board'],
    },
  ];

  void _openGame(BuildContext context, Map<String, dynamic> game) {
    final gameProvider = context.read<GameProvider>();
    final usesEnergy = game['usesEnergy'] == true;
    final cost = (game['energyCost'] as int? ?? 1);

    if (usesEnergy && gameProvider.energy < cost) {
      EnergySheet.show(context);
      return;
    }

    if (usesEnergy) {
      gameProvider.consumeEnergy(cost);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: game['id'],
          gameName: game['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final authProvider = context.watch<AuthProvider>();

    final rpBalance = gameProvider.rpBalance;
    final energy = gameProvider.energy;
    final maxEnergy = gameProvider.maxEnergy;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A12),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF2E2152),
              Color(0xFF17122A),
              Color(0xFF0C0A12),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Games',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          color: Color(0xFFEDEDF2),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),

                      // RP Balance Pill
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          RpWalletSheet.show(
                            context,
                            onShop: () => RpShopSheet.show(context),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B942).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.55)),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFF5B942).withOpacity(0.15), blurRadius: 10),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFF5B942), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                '$rpBalance RP',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  color: Color(0xFFF5B942),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Energy 5-Bolts Indicator Pill
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          EnergySheet.show(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: List.generate(maxEnergy, (index) {
                              final isFilled = index < energy;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                child: Icon(
                                  Icons.flash_on,
                                  color: isFilled ? const Color(0xFFF5B942) : Colors.white24,
                                  size: 13,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // User Avatar Pill
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8265C), Color(0xFF7C4DFF)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'Z',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tournament Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE8265C).withOpacity(0.28),
                          const Color(0xFF7C4DFF).withOpacity(0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8265C).withOpacity(0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE8265C).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B942).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.emoji_events, color: Color(0xFFF5B942), size: 30),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WEEKEND TOURNAMENT',
                                style: TextStyle(
                                  color: Color(0xFFFFB3C8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Fruit Match Cup',
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  color: Color(0xFFEDEDF2),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Cosmetic prizes · ends Sunday',
                                style: TextStyle(color: Color(0xFFC9C9D6), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            final fruitGame = _games.firstWhere((g) => g['id'] == 'fruit_match');
                            _openGame(context, fruitGame);
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D7E), Color(0xFFE8265C), Color(0xFFC81A4C)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE8265C).withOpacity(0.45),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Join',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Daily Missions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily missions',
                            style: TextStyle(
                              color: Color(0xFFEDEDF2),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Reset 00:00',
                            style: TextStyle(
                              color: const Color(0xFFA69FC0).withOpacity(0.8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMissionCard(context, 'Catch 50 fish', 0.64, '32/50', false, 30),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMissionCard(context, 'Score 3 penalties', 0.33, '1/3', false, 30),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMissionCard(context, 'Clear 5 levels', 1.0, 'Claim +60', true, 60),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2-Column Game Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.86,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final game = _games[index];
                      return _buildGameGridCard(context, game);
                    },
                    childCount: _games.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, String title, double progress, String sub, bool isClaimable, int rewardRp) {
    return GestureDetector(
      onTap: isClaimable
          ? () {
              HapticFeedback.heavyImpact();
              final granted = context.read<GameProvider>().addRp(rewardRp, 'Daily Mission: $title');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF2FBF71),
                  content: Text('+$granted RP Claimed successfully!'),
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF16121F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isClaimable ? const Color(0xFF9FE8C8).withOpacity(0.4) : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFEDEDF2), fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isClaimable ? const Color(0xFF9FE8C8) : const Color(0xFFF5B942),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              sub,
              style: TextStyle(
                color: isClaimable ? const Color(0xFF9FE8C8) : const Color(0xFFA69FC0),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameGridCard(BuildContext context, Map<String, dynamic> game) {
    final artGradient = game['artGradient'] as List<Color>;
    final gameProvider = context.watch<GameProvider>();
    final bestScore = gameProvider.personalBests[game['id']] ?? 0;
    final personalLevel = gameProvider.personalLevels[game['id']] ?? 1;
    final bestStr = bestScore > 0 ? _formatScore(bestScore) : 'Play';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        GameDetailSheet.show(
          context,
          game: game,
          onPlay: () => _openGame(context, game),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1730), Color(0xFF120F1D)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game Art Area
            Container(
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: artGradient,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white.withOpacity(0.22), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Text(game['icon'], style: const TextStyle(fontSize: 42)),
                  // Level Badge on Art
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Lv. $personalLevel',
                        style: const TextStyle(
                          color: Color(0xFF9FE8C8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Game Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game['name'],
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      color: Color(0xFFEDEDF2),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game['tagline'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA69FC0),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Bottom modes and best score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        game['category'] ?? 'Arcade',
                        style: const TextStyle(
                          color: Color(0xFF9FE8C8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFF5B942), size: 11),
                          const SizedBox(width: 3),
                          Text(
                            bestStr,
                            style: const TextStyle(
                              color: Color(0xFFF5B942),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
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
