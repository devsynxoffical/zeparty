import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import 'energy_sheet.dart';
import 'game_leaderboard_sheet.dart';

class GameDetailSheet extends StatefulWidget {
  final Map<String, dynamic> game;
  final VoidCallback onPlay;

  const GameDetailSheet({
    super.key,
    required this.game,
    required this.onPlay,
  });

  static void show(BuildContext context, {required Map<String, dynamic> game, required VoidCallback onPlay}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GameDetailSheet(game: game, onPlay: onPlay),
    );
  }

  @override
  State<GameDetailSheet> createState() => _GameDetailSheetState();
}

class _GameDetailSheetState extends State<GameDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatScore(int val) {
    final s = val.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final artGradient = game['artGradient'] as List<Color>? ?? [const Color(0xFF2FD3E6), const Color(0xFF041E2E)];
    final usesEnergy = game['usesEnergy'] == true;
    final energyCost = game['energyCost'] ?? 1;

    final gameProvider = context.watch<GameProvider>();
    final authProvider = context.watch<AuthProvider>();
    final personalBest = gameProvider.personalBests[game['id']] ?? 0;
    final personalLevel = gameProvider.personalLevels[game['id']] ?? 1;
    final energy = gameProvider.energy;
    final maxEnergy = gameProvider.maxEnergy;
    final user = authProvider.currentUser;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0A12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Hero Art Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: artGradient,
              ),
            ),
            child: Stack(
              children: [
                // Art Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black12, Colors.transparent, Color(0xFF0C0A12)],
                      ),
                    ),
                  ),
                ),
                // Emoji Icon
                Center(
                  child: Text(game['icon'] ?? '🎮', style: const TextStyle(fontSize: 60)),
                ),
                // Back Button
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFFEDEDF2), size: 18),
                      ),
                    ),
                  ),
                ),
                // Mode Tag Pill
                Positioned(
                  bottom: 12,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12).withOpacity(0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Text(
                      game['badge'] ?? 'SKILL GAME',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Color(0xFF9FE8C8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title & Description Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game['name'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    color: Color(0xFFEDEDF2),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  game['description'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: Color(0xFFA69FC0),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pills Row
                  Row(
                    children: [
                      _buildPill(game['category'] ?? 'Arcade'),
                      const SizedBox(width: 6),
                      _buildPill(game['duration'] ?? '3 min'),
                      const SizedBox(width: 6),
                      _buildPill(game['rpCap'] ?? 'Up to 50 RP', isGold: true),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3 Stats Cards: High Score, Max Level, RP Balance
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          personalBest > 0 ? _formatScore(personalBest) : '0',
                          'High Score',
                          icon: Icons.emoji_events,
                          iconColor: const Color(0xFFF5B942),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'Level $personalLevel',
                          'Max Level',
                          icon: Icons.military_tech,
                          iconColor: const Color(0xFF9FE8C8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          '${gameProvider.rpBalance}',
                          'RP Balance',
                          icon: Icons.star,
                          iconColor: const Color(0xFFFFB45C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Big Play Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context);
                      widget.onPlay();
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D7E), Color(0xFFE8265C), Color(0xFFC81A4C)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE8265C).withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Play',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (usesEnergy) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.flash_on, color: Colors.white, size: 18),
                            Text(
                              '$energyCost',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Energy Status Row
                  if (usesEnergy)
                    GestureDetector(
                      onTap: () => EnergySheet.show(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ...List.generate(maxEnergy, (i) {
                                final on = i < energy;
                                return Icon(
                                  Icons.flash_on,
                                  color: on ? const Color(0xFFF5B942) : Colors.white24,
                                  size: 14,
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                '$energy of $maxEnergy Energy',
                                style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 11),
                              ),
                            ],
                          ),
                          const Text(
                            'Refill',
                            style: TextStyle(color: Color(0xFFE8265C), fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Boosters Header
                  const Text(
                    'Skill Boosters',
                    style: TextStyle(color: Color(0xFFEDEDF2), fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),

                  // Boosters Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildBoosterChip('Double Cannon', '150 RP', [const Color(0xFF2FD3E6), const Color(0xFF0C6A8C)]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBoosterChip('Extra Moves', '100 RP', [const Color(0xFFFFB45C), const Color(0xFFE8641C)]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBoosterChip('Shield Boost', '150 RP', [const Color(0xFFFFE08A), const Color(0xFFE8902A)]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Leaderboard & Personal Best Record
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Record & Standings',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          color: Color(0xFFEDEDF2),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          GameLeaderboardSheet.show(
                            context,
                            gameId: game['id'] ?? '',
                            gameName: game['name'] ?? 'Game',
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'Leaderboard',
                              style: TextStyle(
                                color: Color(0xFFF5B942),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, color: Color(0xFFF5B942), size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Detailed Personal Record Card
                  _buildPersonalRecordCard(
                    user: user,
                    personalBest: personalBest,
                    personalLevel: personalLevel,
                    rpBalance: gameProvider.rpBalance,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, {bool isGold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGold ? const Color(0xFFF5B942).withOpacity(0.12) : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isGold ? const Color(0xFFF5B942).withOpacity(0.55) : Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGold) ...[
            const Icon(Icons.star, color: Color(0xFFF5B942), size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isGold ? const Color(0xFFF5B942) : const Color(0xFFEDEDF2),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, {IconData? icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16121F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? const Color(0xFFF5B942), size: 16),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Sora',
              color: Color(0xFFEDEDF2),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFA69FC0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoosterChip(String title, String cost, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF16121F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFEDEDF2), fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Text(
            cost,
            style: const TextStyle(color: Color(0xFFF5B942), fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecordCard({
    required dynamic user,
    required int personalBest,
    required int personalLevel,
    required int rpBalance,
  }) {
    final hasPlayed = personalBest > 0;
    final userName = user?.name ?? 'You';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasPlayed
              ? [const Color(0xFF261845), const Color(0xFF161028)]
              : [const Color(0xFF1A1426), const Color(0xFF100C19)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPlayed ? const Color(0xFFF5B942).withOpacity(0.45) : Colors.white.withOpacity(0.08),
        ),
        boxShadow: hasPlayed
            ? [
                BoxShadow(
                  color: const Color(0xFFF5B942).withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasPlayed
                        ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                        : [Colors.white24, Colors.white12],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    hasPlayed ? '#1' : '-',
                    style: TextStyle(
                      color: hasPlayed ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8265C), Color(0xFF7C4DFF)],
                  ),
                  border: Border.all(color: const Color(0xFFF5B942), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // User Name & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              color: Color(0xFFEDEDF2),
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B942).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.6)),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Color(0xFFF5B942),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPlayed ? 'Max Level Reached: Level $personalLevel' : 'Not played yet (Level 1)',
                      style: TextStyle(
                        color: hasPlayed ? const Color(0xFF9FE8C8) : const Color(0xFFA69FC0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // RP Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5B942).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.4)),
                ),
                child: Text(
                  '$rpBalance RP',
                  style: const TextStyle(color: Color(0xFFF5B942), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // High Score & Level Summary Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric(
                label: 'High Score',
                value: hasPlayed ? '${_formatScore(personalBest)} pts' : '0 pts',
                valueColor: const Color(0xFFF5B942),
              ),
              Container(width: 1, height: 26, color: Colors.white12),
              _buildMiniMetric(
                label: 'Highest Level',
                value: 'Level $personalLevel',
                valueColor: const Color(0xFF9FE8C8),
              ),
              Container(width: 1, height: 26, color: Colors.white12),
              _buildMiniMetric(
                label: 'Standing',
                value: hasPlayed ? 'Rank #1' : 'Unranked',
                valueColor: hasPlayed ? const Color(0xFFFFB45C) : const Color(0xFFA69FC0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({required String label, required String value, required Color valueColor}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Sora',
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA69FC0),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
