import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

class EnergySheet extends StatefulWidget {
  const EnergySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const EnergySheet(),
    );
  }

  @override
  State<EnergySheet> createState() => _EnergySheetState();
}

class _EnergySheetState extends State<EnergySheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final energy = gameProvider.energy;
    final maxEnergy = gameProvider.maxEnergy;
    final timeUntilNext = gameProvider.timeUntilNextEnergy;
    final isFull = energy >= maxEnergy;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF160926),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Arcade Energy',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Energy Bolts Indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D253F), Color(0xFF041122)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(maxEnergy, (index) {
                    final isFilled = index < energy;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 42,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isFilled ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFilled ? const Color(0xFF00E5FF) : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.bolt,
                          color: isFilled ? const Color(0xFF00E5FF) : Colors.white24,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Text(
                  '$energy / $maxEnergy Energy Available',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isFull
                      ? 'Energy is fully charged!'
                      : 'Next energy restores in ${_formatDuration(timeUntilNext)} (+1 / 20 min)',
                  style: TextStyle(
                    color: isFull ? const Color(0xFF9FE8C8) : Colors.white54,
                    fontSize: 12,
                    fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Option 1: Watch Rewarded Video Ad
          ListTile(
            onTap: isFull
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    gameProvider.refillEnergy(1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF38EF7D),
                        content: Text('+1 Energy restored from sponsored video!'),
                      ),
                    );
                  },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white.withOpacity(0.06),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF2A6D).withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_fill, color: Color(0xFFFF2A6D), size: 24),
            ),
            title: const Text('Watch Short Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('+1 Energy instantly', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: isFull
                ? const Text('FULL', style: TextStyle(color: Color(0xFF9FE8C8), fontWeight: FontWeight.bold, fontSize: 11))
                : const Icon(Icons.chevron_right, color: Colors.white60),
          ),
          const SizedBox(height: 10),

          // Option 2: Instant Refill with Coins (50 Coins)
          ListTile(
            onTap: isFull
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    final needed = maxEnergy - energy;
                    final cost = needed * 10;
                    if (walletProvider.coins < cost) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Insufficient coins for energy refill.')),
                      );
                      return;
                    }
                    gameProvider.buyEnergyWithCoins(walletProvider, cost, needed);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFF38EF7D), content: Text('Energy fully restored! (-$cost Coins)')),
                    );
                  },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white.withOpacity(0.06),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), shape: BoxShape.circle),
              child: const Text('🪙', style: TextStyle(fontSize: 20)),
            ),
            title: const Text('Instant Full Refill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${(maxEnergy - energy) * 10} Coins for ${maxEnergy - energy} energy',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: isFull
                ? const Text('FULL', style: TextStyle(color: Color(0xFF9FE8C8), fontWeight: FontWeight.bold, fontSize: 11))
                : Text('${walletProvider.coins} 🪙', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
