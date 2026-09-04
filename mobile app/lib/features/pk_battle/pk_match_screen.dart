import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/user_avatar.dart';
import '../../providers/auth_provider.dart';
import 'pk_battle_screen.dart';

class PkMatchScreen extends StatefulWidget {
  const PkMatchScreen({super.key});

  @override
  State<PkMatchScreen> createState() => _PkMatchScreenState();
}

class _PkMatchScreenState extends State<PkMatchScreen> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _vsPulseController;
  late Animation<double> _radarAnimation;
  late Animation<double> _vsScale;

  Timer? _matchTimer;
  bool _isMatched = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _radarAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );

    _vsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _vsScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _vsPulseController, curve: Curves.easeInOut),
    );

    // Simulate matchmaking
    _matchTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isMatched = true);
        _radarController.stop();

        // Navigate to TikTok PK Arena
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const PKBattleScreen()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _vsPulseController.dispose();
    _matchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A071B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Glow
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF2E124D),
                  Color(0xFF0A071B),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'TikTok 1v1 PK Matchmaking',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Matchmaking Arena Scanner
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar Pulse Rings
                          if (!_isMatched)
                            AnimatedBuilder(
                              animation: _radarAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 170 * _radarAnimation.value,
                                  height: 170 * _radarAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF).withValues(
                                        alpha: (2.0 - _radarAnimation.value).clamp(0.0, 1.0),
                                      ),
                                      width: 2.0,
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Host Avatars Side-by-Side Arena Preview
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Current Host (Team Blue)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                ),
                                child: UserAvatar(
                                  imageUrl: user.avatarUrl,
                                  radius: 46,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Central Pulsating VS Badge
                              ScaleTransition(
                                scale: _vsScale,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'VS',
                                    style: TextStyle(
                                      color: Color(0xFF0A071B),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Opponent Host (Team Red)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: _isMatched ? const Color(0xFFFF4081) : Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: UserAvatar(
                                  imageUrl: _isMatched
                                      ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'
                                      : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                                  radius: 46,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // Status Indicator Text
                      Text(
                        _isMatched ? 'Opponent Found! Connecting...' : 'Finding live opponent...',
                        style: TextStyle(
                          color: _isMatched ? const Color(0xFF00E5FF) : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Global 1v1 live matching based on room popularity',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Cancel Matchmaking Button
                if (!_isMatched)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                      ),
                      child: const Text('Cancel Matching', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
