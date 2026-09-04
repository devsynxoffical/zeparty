import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';

class RocketGameSheet extends StatefulWidget {
  const RocketGameSheet({super.key});

  @override
  State<RocketGameSheet> createState() => _RocketGameSheetState();
}

class _RocketGameSheetState extends State<RocketGameSheet> with TickerProviderStateMixin {
  int currentLevel = 1;
  int currentContribution = 0;
  
  // Top contributors
  List<Map<String, dynamic>> contributors = [];
  
  late AnimationController _rocketController;
  late Animation<double> _rocketAnimation;

  @override
  void initState() {
    super.initState();
    _rocketController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _rocketAnimation = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut));
    
    // Mock initial contributors
    contributors = [
      {'name': 'Sophia', 'amount': 0},
      {'name': 'Alex', 'amount': 0},
      {'name': 'Danial', 'amount': 0},
    ];
  }

  @override
  void dispose() {
    _rocketController.dispose();
    super.dispose();
  }

  void _contribute(int amount) {
    final wallet = context.read<WalletProvider>();
    if (!wallet.spendDiamonds(amount, 'Rocket Game Bet')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient Diamonds')));
      return;
    }

    final levelTargets = context.read<GameProvider>().rocketLevelTargets;

    setState(() {
      currentContribution += amount;
      
      // Add to own contribution
      final me = context.read<AuthProvider>().currentUser.name;
      final existing = contributors.indexWhere((c) => c['name'] == me);
      if (existing != -1) {
        contributors[existing]['amount'] = (contributors[existing]['amount'] as int) + amount;
      } else {
        contributors.add({'name': me, 'amount': amount});
      }
      
      // Sort contributors
      contributors.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

      // Level up logic: calculate against active level target
      while (currentLevel < 5 && currentContribution >= levelTargets[currentLevel - 1]) {
        currentLevel++;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rocket Reached Level $currentLevel! 🚀')));
      }

      // Check for High-Bet announcements
      if (amount >= 100000) {
        _showAnnouncement('PREMIUM HIGH-BET: $me bet $amount! 🔥🚀', isPremium: true);
      } else if (amount >= 50000) {
        _showAnnouncement('HIGH-BET: $me bet $amount! 🚀', isPremium: false);
      }
    });
  }

  void _showAnnouncement(String message, {required bool isPremium}) {
    // ScaffoldMessenger is used for mock global announcement
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isPremium ? Colors.purple : Colors.orange,
        duration: const Duration(seconds: 4),
      )
    );
  }

  void _endGame() {
    // Reward distribution logic
    if (contributors.isEmpty) return;
    
    final me = context.read<AuthProvider>().currentUser.name;
    final wallet = context.read<WalletProvider>();
    
    int myReward = 0;
    // Mock reward logic: Top 1 gets 50% of total pool
    final top1 = contributors.first;
    if (top1['name'] == me && top1['amount'] > 0) {
      myReward = (currentContribution * 0.5).toInt();
      wallet.earnCoins(myReward, 'Rocket Game Top 1 Reward');
      _showAnnouncement('🎉 LUCKY WIN: You won $myReward coins in Rocket Game! 🎉', isPremium: true);
    }
    
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
        title: const Text('Game Results 🚀'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rocket reached Level $currentLevel'),
            const SizedBox(height: 16),
            ...contributors.take(5).map((c) => ListTile(
              title: Text(c['name']),
              trailing: Text('${c['amount']} 💎', style: const TextStyle(color: Colors.cyan)),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final gameProvider = context.watch<GameProvider>();
    final levelTargets = gameProvider.rocketLevelTargets;
    
    int target = levelTargets[(currentLevel - 1).clamp(0, 4)];
    double progress = (currentContribution / target).clamp(0.0, 1.0);
    String formattedTarget = GameProvider.formatRocketTarget(target);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Rocket Game 🚀', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // 5-Level Targets Progression Sequence Bar (Rocket 1: 100K -> Rocket 5: 1M)
          _buildLevelProgressionBar(levelTargets, currentLevel, isDark, primary),
          const SizedBox(height: 12),
          
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rocketAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _rocketAnimation.value),
                      child: const Text('🚀', style: TextStyle(fontSize: 90)),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary),
                    ),
                    child: Text('Level $currentLevel', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress: ${AppFormatters.formatNumber(currentContribution)} / ${AppFormatters.formatNumber(target)} ($formattedTarget)'),
                    Text('${(progress * 100).toInt()}%', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade800,
                  color: primary,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _betButton(1000, primary),
                    _betButton(50000, Colors.orange),
                    _betButton(100000, Colors.redAccent), // 100K bet
                    _betButton(250000, Colors.purple), // 250K bet
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _endGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getSurface(isDark),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('End Game & Distribute Rewards'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _betButton(int amount, Color color) {
    return GestureDetector(
      onTap: () => _contribute(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.diamond, color: Colors.cyan, size: 16),
            const SizedBox(height: 4),
            Text(amount >= 1000 ? '${amount ~/ 1000}k' : '$amount', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgressionBar(List<int> levelTargets, int currentLevel, bool isDark, Color primary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final levelNum = index + 1;
            final targetVal = levelTargets.length > index ? levelTargets[index] : 0;
            final formatted = GameProvider.formatRocketTarget(targetVal);
            final isCompleted = currentLevel > levelNum;
            final isActive = currentLevel == levelNum;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withValues(alpha: 0.2)
                    : (isActive ? primary.withValues(alpha: 0.2) : AppColors.getCard(isDark)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green
                      : (isActive ? primary : Colors.grey.shade700),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCompleted)
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 10)
                      else if (isActive)
                        Icon(Icons.rocket_launch_rounded, color: primary, size: 10),
                      if (isCompleted || isActive) const SizedBox(width: 3),
                      Text(
                        'Rocket $levelNum',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? Colors.green
                              : (isActive ? primary : AppColors.getTextSecondary(isDark)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? primary : AppColors.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
