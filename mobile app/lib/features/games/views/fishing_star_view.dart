import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class FishingStarView extends StatefulWidget {
  final int wager;
  const FishingStarView({super.key, required this.wager});

  @override
  State<FishingStarView> createState() => _FishingStarViewState();
}

class _FishingStarViewState extends State<FishingStarView> {
  late int cannonBet;
  List<Map<String, dynamic>> swimmingFish = [];
  List<Map<String, dynamic>> activeBullets = [];
  Timer? _gameLoopTimer;
  double cannonAngle = 0.0;
  String? hitMessage;

  @override
  void initState() {
    super.initState();
    cannonBet = widget.wager;
    _initFishList();
    _startGameLoop();
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  void _initFishList() {
    final rand = Random();
    final fishTypes = [
      {'name': 'Clownfish', 'icon': '🐠', 'value': 2, 'speed': 2.5, 'size': 36.0},
      {'name': 'Swordfish', 'icon': '🐟', 'value': 5, 'speed': 3.8, 'size': 42.0},
      {'name': 'Golden Whale', 'icon': '🐳', 'value': 25, 'speed': 1.2, 'size': 54.0},
      {'name': 'Shark', 'icon': '🦈', 'value': 12, 'speed': 2.8, 'size': 48.0},
      {'name': 'Jellyfish', 'icon': '🪼', 'value': 4, 'speed': 2.0, 'size': 38.0},
    ];

    swimmingFish = List.generate(6, (i) {
      final type = fishTypes[rand.nextInt(fishTypes.length)];
      return {
        ...type,
        'id': i,
        'x': rand.nextDouble() * 260,
        'y': 40.0 + i * 45.0,
        'direction': rand.nextBool() ? 1.0 : -1.0,
      };
    });
  }

  void _startGameLoop() {
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) return;
      setState(() {
        // Move fish horizontally
        for (var fish in swimmingFish) {
          double dx = (fish['x'] as double) + (fish['speed'] as double) * (fish['direction'] as double);
          if (dx > 320) {
            dx = -40;
          } else if (dx < -40) {
            dx = 320;
          }
          fish['x'] = dx;
        }

        // Update active bullets moving towards target
        for (int i = activeBullets.length - 1; i >= 0; i--) {
          var b = activeBullets[i];
          b['progress'] = (b['progress'] as double) + 0.15;
          if (b['progress'] >= 1.0) {
            activeBullets.removeAt(i);
          }
        }
      });
    });
  }

  void _shootCannonAtPos(TapDownDetails details) {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < cannonBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient coins for Cannon Shot!')),
      );
      return;
    }

    // Deduct coins immediately on tap
    wallet.spendCoins(cannonBet, 'Fishing Cannon Ammo');

    final tapPos = details.localPosition;
    final screenWidth = MediaQuery.of(context).size.width;
    final cannonOrigin = Offset(screenWidth * 0.5, 360);

    // Calculate angle towards tap position
    final dx = tapPos.dx - cannonOrigin.dx;
    final dy = cannonOrigin.dy - tapPos.dy;
    final angle = atan2(dx, dy);

    setState(() {
      cannonAngle = angle;
      activeBullets.add({
        'start': cannonOrigin,
        'target': tapPos,
        'progress': 0.0,
      });
    });

    // Check hit collision with swimming fish
    final rand = Random();
    int? hitIdx;
    for (int i = 0; i < swimmingFish.length; i++) {
      final f = swimmingFish[i];
      final fishCenter = Offset((f['x'] as double) + 20, (f['y'] as double) + 20);
      final dist = (tapPos - fishCenter).distance;
      if (dist < 40) {
        hitIdx = i;
        break;
      }
    }

    if (hitIdx != null) {
      final int targetIdx = hitIdx;
      final fish = swimmingFish[targetIdx];
      final reward = (cannonBet * (fish['value'] as int)).toInt();
      wallet.earnCoins(reward, 'Fishing Star Capture Payout');

      setState(() {
        hitMessage = '🎯 CAPTURED ${fish['icon']} ${fish['name']}! +$reward 🪙';
        // Respawn fish
        final fishTypes = [
          {'name': 'Clownfish', 'icon': '🐠', 'value': 2, 'speed': 2.5, 'size': 36.0},
          {'name': 'Swordfish', 'icon': '🐟', 'value': 5, 'speed': 3.8, 'size': 42.0},
          {'name': 'Golden Whale', 'icon': '🐳', 'value': 25, 'speed': 1.2, 'size': 54.0},
          {'name': 'Shark', 'icon': '🦈', 'value': 12, 'speed': 2.8, 'size': 48.0},
        ];
        final newType = fishTypes[rand.nextInt(fishTypes.length)];
        swimmingFish[targetIdx] = {
          ...newType,
          'id': targetIdx,
          'x': -50.0,
          'y': 40.0 + (rand.nextInt(5)) * 45.0,
          'direction': 1.0,
        };
      });
    } else {
      setState(() {
        hitMessage = '💦 Missed target!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF001F3F), Color(0xFF000B1A)],
        ),
      ),
      child: Column(
        children: [
          // Underwater Shooting Arena
          Expanded(
            child: GestureDetector(
              onTapDown: _shootCannonAtPos,
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Swimming Fish Sprites
                    RepaintBoundary(
                      child: Stack(
                        children: swimmingFish.map((fish) {
                          return Positioned(
                            left: fish['x'] as double,
                            top: fish['y'] as double,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.cyanAccent, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.cyan, blurRadius: 8)],
                              ),
                              child: Text(
                                fish['icon'] as String,
                                style: TextStyle(fontSize: (fish['size'] as double) * 0.7),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Laser Bullets Flying
                    ...activeBullets.map((b) {
                      final Offset start = b['start'] as Offset;
                      final Offset target = b['target'] as Offset;
                      final double p = b['progress'] as double;
                      final Offset current = Offset(
                        start.dx + (target.dx - start.dx) * p,
                        start.dy + (target.dy - start.dy) * p,
                      );

                      return Positioned(
                        left: current.dx - 6,
                        top: current.dy - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.cyan, blurRadius: 10, spreadRadius: 2)],
                          ),
                        ),
                      );
                    }),

                    // Hit Status Announcement Banner
                    if (hitMessage != null)
                      Positioned(
                        top: 10,
                        left: 20,
                        right: 20,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.cyanAccent),
                            ),
                            child: Text(
                              hitMessage!,
                              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),

                    // Rotating Cannon at Bottom Center
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Transform.rotate(
                          angle: cannonAngle,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.amber, blurRadius: 12)],
                                ),
                              ),
                              Container(
                                width: 48,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade900,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: Colors.cyanAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cannon Ammo Controls Bottom Tray (FIXED NO OVERFLOW WITH SingleChildScrollView)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF000A14),
              border: Border(top: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TAP ANYWHERE TO AIM & FIRE CANNON 🎯',
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [10, 50, 100, 500, 1000].map((b) {
                        final isSelected = cannonBet == b;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('$b 🪙 Cannon'),
                            selected: isSelected,
                            selectedColor: Colors.cyanAccent,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => cannonBet = b);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
