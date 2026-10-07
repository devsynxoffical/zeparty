import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FishingGameView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const FishingGameView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<FishingGameView> createState() => _FishingGameViewState();
}

enum FishType { small, medium, large, golden, boss, freeze, bomb }

class FishItem {
  final int id;
  final FishType type;
  double x;
  double y;
  double speed;
  int direction;
  int hp;
  int maxHp;
  int points;
  double size;
  List<Color> gradientColors;
  String name;
  bool isFrozen;

  FishItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.speed,
    required this.direction,
    required this.hp,
    required this.maxHp,
    required this.points,
    required this.size,
    required this.gradientColors,
    required this.name,
    this.isFrozen = false,
  });
}

class NetProjectile {
  double x;
  double y;
  double targetX;
  double targetY;
  double progress;
  double radius;
  bool isWide;

  NetProjectile({
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    this.progress = 0.0,
    this.radius = 45.0,
    this.isWide = false,
  });
}

class FloatingScore {
  double x;
  double y;
  String text;
  Color color;
  double opacity;

  FloatingScore({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.opacity = 1.0,
  });
}

class Bubble {
  double x;
  double y;
  double radius;
  double speed;
  double opacity;

  Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class _FishingGameViewState extends State<FishingGameView> with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _scoreNotifier = ValueNotifier(0);
  late final ValueNotifier<int> _waveNotifier;
  final ValueNotifier<double> _comboNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> _heatNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _isOverheatedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _bossActiveNotifier = ValueNotifier(false);
  final ValueNotifier<double> _bossHpPercentNotifier = ValueNotifier(1.0);

  int _fishCaught = 0;
  DateTime? _lastCatchTime;
  bool _bossDefeated = false;

  // Boosters
  bool _doubleCannon = false;
  bool _freezeActive = false;

  final List<FishItem> _fishList = [];
  final List<NetProjectile> _nets = [];
  final List<FloatingScore> _floatingScores = [];
  final List<Bubble> _bubbles = [];

  double _cannonAngle = -pi / 2;
  late AnimationController _tickerController;
  Timer? _spawnTimer;
  Timer? _freezeTimer;
  int _nextFishId = 1;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _waveNotifier = ValueNotifier(widget.initialLevel > 1 ? widget.initialLevel : 1);
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _initBubbles();
    _tickerController.addListener(_onTick);
    _startWave();
  }

  @override
  void dispose() {
    _tickerController.removeListener(_onTick);
    _tickerController.dispose();
    _spawnTimer?.cancel();
    _freezeTimer?.cancel();
    _scoreNotifier.dispose();
    _waveNotifier.dispose();
    _comboNotifier.dispose();
    _heatNotifier.dispose();
    _isOverheatedNotifier.dispose();
    _bossActiveNotifier.dispose();
    _bossHpPercentNotifier.dispose();
    super.dispose();
  }

  void _initBubbles() {
    for (int i = 0; i < 22; i++) {
      _bubbles.add(
        Bubble(
          x: _rand.nextDouble(),
          y: _rand.nextDouble(),
          radius: 2.5 + _rand.nextDouble() * 5.0,
          speed: 0.001 + _rand.nextDouble() * 0.002,
          opacity: 0.2 + _rand.nextDouble() * 0.4,
        ),
      );
    }
  }

  void _onTick() {
    // Heat cooldown
    if (_heatNotifier.value > 0) {
      _heatNotifier.value = max(0.0, _heatNotifier.value - 0.008);
      if (_heatNotifier.value < 0.2 && _isOverheatedNotifier.value) {
        _isOverheatedNotifier.value = false;
      }
    }

    // Combo decay
    if (_lastCatchTime != null && DateTime.now().difference(_lastCatchTime!).inMilliseconds > 2000) {
      if (_comboNotifier.value != 1.0) {
        _comboNotifier.value = 1.0;
      }
    }

    // Bubbles float up
    for (final b in _bubbles) {
      b.y -= b.speed;
      if (b.y < 0) {
        b.y = 1.0;
        b.x = _rand.nextDouble();
      }
    }

    // Move fish
    for (final fish in _fishList) {
      if (!fish.isFrozen && !_freezeActive) {
        fish.x += fish.speed * fish.direction;
      }
    }
    _fishList.removeWhere((f) => f.direction == 1 ? f.x > 1.25 : f.x < -0.25);

    // Move projectiles
    for (int i = _nets.length - 1; i >= 0; i--) {
      final net = _nets[i];
      net.progress += 0.12;
      net.x += (net.targetX - net.x) * 0.25;
      net.y += (net.targetY - net.y) * 0.25;

      if (net.progress >= 1.0) {
        _detonateNet(net);
        _nets.removeAt(i);
      }
    }

    // Update floating scores
    for (int i = _floatingScores.length - 1; i >= 0; i--) {
      final fs = _floatingScores[i];
      fs.y -= 0.003;
      fs.opacity -= 0.03;
      if (fs.opacity <= 0) {
        _floatingScores.removeAt(i);
      }
    }
  }

  void _startWave() {
    _spawnTimer?.cancel();
    if (_waveNotifier.value == 10) {
      _spawnBoss();
    } else {
      _bossActiveNotifier.value = false;
      _spawnTimer = Timer.periodic(const Duration(milliseconds: 850), (t) {
        if (_fishList.length < 16) {
          _spawnRandomFish();
        }
      });
    }
  }

  void _spawnBoss() {
    _bossActiveNotifier.value = true;
    _bossHpPercentNotifier.value = 1.0;
    _fishList.add(
      FishItem(
        id: _nextFishId++,
        type: FishType.boss,
        x: 0.1,
        y: 0.25,
        speed: 0.0018,
        direction: 1,
        hp: 40,
        maxHp: 40,
        points: 1500,
        size: 96,
        gradientColors: const [Color(0xFF5B6F85), Color(0xFF1E2A38)],
        name: 'Boss Shark',
      ),
    );
  }

  void _spawnRandomFish() {
    final roll = _rand.nextDouble();
    FishType type;
    int hp;
    int pts;
    double size;
    List<Color> colors;
    String name;

    if (roll < 0.40) {
      type = FishType.small;
      hp = 1;
      pts = 20;
      size = 32;
      colors = const [Color(0xFF6FB3FF), Color(0xFF1E55C4)]; // Blue
      name = 'Blue Minnow';
    } else if (roll < 0.65) {
      type = FishType.medium;
      hp = 2;
      pts = 50;
      size = 42;
      colors = const [Color(0xFFFFB45C), Color(0xFFE8641C)]; // Orange
      name = 'Clownfish';
    } else if (roll < 0.82) {
      type = FishType.large;
      hp = 3;
      pts = 100;
      size = 54;
      colors = const [Color(0xFFC39BFF), Color(0xFF6A3BD6)]; // Purple
      name = 'Purple Ray';
    } else if (roll < 0.92) {
      type = FishType.golden;
      hp = 4;
      pts = 250;
      size = 46;
      colors = const [Color(0xFFFFE08A), Color(0xFFE8902A)]; // Gold
      name = 'Golden Carp';
    } else {
      type = FishType.freeze;
      hp = 2;
      pts = 80;
      size = 38;
      colors = const [Color(0xFFC8FFE8), Color(0xFF3FB890)]; // Mint Freeze
      name = 'Freeze Puffer';
    }

    final fromLeft = _rand.nextBool();
    _fishList.add(
      FishItem(
        id: _nextFishId++,
        type: type,
        x: fromLeft ? -0.15 : 1.15,
        y: 0.12 + _rand.nextDouble() * 0.60,
        speed: 0.002 + (_rand.nextDouble() * 0.003),
        direction: fromLeft ? 1 : -1,
        hp: hp,
        maxHp: hp,
        points: pts,
        size: size,
        gradientColors: colors,
        name: name,
      ),
    );
  }

  void _shoot(Offset pos, Size size) {
    if (_isOverheatedNotifier.value) return;

    final cannonX = size.width * 0.5;
    final cannonY = size.height * 0.88;
    _cannonAngle = atan2(pos.dy - cannonY, pos.dx - cannonX);

    final normX = pos.dx / size.width;
    final normY = pos.dy / size.height;

    _nets.add(
      NetProjectile(
        x: 0.5,
        y: 0.88,
        targetX: normX,
        targetY: normY,
        radius: 48.0,
        isWide: _doubleCannon,
      ),
    );

    if (_doubleCannon) {
      _nets.add(
        NetProjectile(
          x: 0.5,
          y: 0.88,
          targetX: (normX + 0.08).clamp(0.05, 0.95),
          targetY: normY,
          radius: 48.0,
          isWide: true,
        ),
      );
    }

    _heatNotifier.value = min(1.0, _heatNotifier.value + 0.12);
    if (_heatNotifier.value >= 0.95) {
      _isOverheatedNotifier.value = true;
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _detonateNet(NetProjectile net) {
    final capturedFish = <FishItem>[];
    final radiusNorm = net.radius / 390.0;

    for (final fish in _fishList) {
      final dist = sqrt(pow(fish.x - net.targetX, 2) + pow(fish.y - net.targetY, 2));
      if (dist < radiusNorm) {
        fish.hp -= 1;
        if (fish.type == FishType.boss) {
          _bossHpPercentNotifier.value = (fish.hp / fish.maxHp).clamp(0.0, 1.0);
        }
        if (fish.hp <= 0) {
          capturedFish.add(fish);
        } else {
          _addFloatingScore(fish.x, fish.y, 'HIT!', const Color(0xFFF5B942));
        }
      }
    }

    for (final fish in capturedFish) {
      _fishList.remove(fish);
      _fishCaught++;
      _lastCatchTime = DateTime.now();
      _comboNotifier.value = min(3.0, _comboNotifier.value + 0.2);

      final pts = (fish.points * _comboNotifier.value).round();
      _scoreNotifier.value += pts;

      _addFloatingScore(
        fish.x,
        fish.y,
        '+$pts${_comboNotifier.value > 1.0 ? ' (${_comboNotifier.value.toStringAsFixed(1)}x)' : ''}',
        fish.type == FishType.golden ? const Color(0xFFF5B942) : const Color(0xFF9FE8C8),
      );

      if (fish.type == FishType.freeze) {
        _triggerFreeze();
      } else if (fish.type == FishType.boss) {
        _bossDefeated = true;
        _scoreNotifier.value += 2000;
        _addFloatingScore(0.5, 0.3, 'BOSS DEFEATED! +2000', const Color(0xFFF5B942));
        HapticFeedback.heavyImpact();
        // Advance to next prestige round/wave cycle
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _waveNotifier.value++;
          _addFloatingScore(0.5, 0.4, 'PRESTIGE WAVE ${_waveNotifier.value}!', const Color(0xFF2FBF71));
          _startWave();
        });
      }
    }

    if (!_bossActiveNotifier.value && _fishCaught >= _waveNotifier.value * 7) {
      _waveNotifier.value++;
      _scoreNotifier.value += _waveNotifier.value * 100;
      _addFloatingScore(0.5, 0.4, 'WAVE ${_waveNotifier.value} STARTED!', const Color(0xFF2FBF71));
      _startWave();
    }
  }

  void _triggerFreeze() {
    _freezeActive = true;
    for (final f in _fishList) {
      f.isFrozen = true;
    }
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _freezeActive = false;
        for (final f in _fishList) {
          f.isFrozen = false;
        }
      }
    });
  }

  void _addFloatingScore(double x, double y, String text, Color color) {
    _floatingScores.add(FloatingScore(x: x, y: y, text: text, color: color));
  }

  void _endGame() {
    _tickerController.stop();
    _spawnTimer?.cancel();
    widget.onGameOver(_scoreNotifier.value, {
      'wave': _waveNotifier.value,
      'fishCaught': _fishCaught,
      'bossDefeated': _bossDefeated,
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapDown: (details) => _shoot(details.localPosition, size),
          onPanUpdate: (details) => _shoot(details.localPosition, size),
          child: Container(
            width: size.width,
            height: size.height,
            color: const Color(0xFF041E2E),
            child: Stack(
              children: [
                // Direct Hardware Canvas Painter
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _FishingGameDesignKitPainter(
                        repaint: _tickerController,
                        fishList: _fishList,
                        nets: _nets,
                        floatingScores: _floatingScores,
                        bubbles: _bubbles,
                        cannonAngle: _cannonAngle,
                      ),
                    ),
                  ),
                ),

                // Design Kit Top HUD
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Wave / Level Badge
                        ValueListenableBuilder<int>(
                          valueListenable: _waveNotifier,
                          builder: (context, wave, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2FD3E6), Color(0xFF0C6A8C)],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF2FD3E6).withOpacity(0.4), blurRadius: 10),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.waves, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    wave > 10 ? 'PRESTIGE $wave' : 'WAVE $wave/10',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Center Score Pill
                        ValueListenableBuilder<int>(
                          valueListenable: _scoreNotifier,
                          builder: (context, score, _) {
                            return Container(
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
                                    _formatScore(score),
                                    style: const TextStyle(
                                      color: Color(0xFFF5B942),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Sora',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Pause Button
                        GestureDetector(
                          onTap: _endGame,
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

                // Boss Shark Health Bar Card (Top Right when active)
                ValueListenableBuilder<bool>(
                  valueListenable: _bossActiveNotifier,
                  builder: (context, isBoss, _) {
                    if (!isBoss) return const SizedBox.shrink();
                    return Positioned(
                      top: 62,
                      right: 14,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Boss Shark 🦈',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _bossHpPercentNotifier,
                                  builder: (context, hp, _) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: hp,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF4D4D), Color(0xFFFF8A8A)],
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFFFF4D4D).withOpacity(0.6), blurRadius: 8),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Left Boosters (60x60 Glass Cards from Design Kit)
                Positioned(
                  left: 12,
                  bottom: 130,
                  child: Column(
                    children: [
                      _buildDesignKitBooster(
                        title: 'x2',
                        label: 'Double Cannon',
                        isActive: _doubleCannon,
                        onTap: () => setState(() => _doubleCannon = !_doubleCannon),
                      ),
                      const SizedBox(height: 8),
                      _buildDesignKitBooster(
                        title: '1',
                        label: 'Freeze Net',
                        isActive: _freezeActive,
                        onTap: _triggerFreeze,
                      ),
                    ],
                  ),
                ),

                // Bottom Meters: Combo & Heat
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Combo x2 Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: _comboNotifier,
                                builder: (context, combo, _) {
                                  return Text(
                                    'Combo ${combo > 1.0 ? "${combo.toStringAsFixed(1)}x" : "x1"}',
                                    style: const TextStyle(color: Color(0xFFEDEDF2), fontSize: 12, fontWeight: FontWeight.w800),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 90,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _comboNotifier,
                                  builder: (context, combo, _) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ((combo - 1.0) / 2.0).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE8265C), Color(0xFFFF7AA0)],
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFFE8265C).withOpacity(0.6), blurRadius: 6),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Heat Meter Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: _isOverheatedNotifier,
                                builder: (context, overheated, _) {
                                  return Text(
                                    overheated ? 'OVERHEAT! 🔥' : 'Heat',
                                    style: TextStyle(
                                      color: overheated ? const Color(0xFFFF4D4D) : const Color(0xFFEDEDF2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 110,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _heatNotifier,
                                  builder: (context, heat, _) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: heat.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF8A3D), Color(0xFFFFD166)],
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesignKitBooster({
    required String title,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [const Color(0xFFF5B942).withOpacity(0.4), const Color(0xFFE8902A).withOpacity(0.2)]
                : [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFFF5B942) : const Color(0xFFF5B942).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? const Color(0xFFF5B942).withOpacity(0.3) : Colors.black26,
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF5B942),
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC9C9D6),
                fontSize: 8,
                fontWeight: FontWeight.w800,
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

class _FishingGameDesignKitPainter extends CustomPainter {
  final List<FishItem> fishList;
  final List<NetProjectile> nets;
  final List<FloatingScore> floatingScores;
  final List<Bubble> bubbles;
  final double cannonAngle;

  _FishingGameDesignKitPainter({
    required super.repaint,
    required this.fishList,
    required this.nets,
    required this.floatingScores,
    required this.bubbles,
    required this.cannonAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Sea Gradient Background (#2FD3E6 -> #0C6A8C -> #041E2E)
    final seaRect = Rect.fromLTWH(0, 0, width, height);
    final seaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2FD3E6), Color(0xFF0C6A8C), Color(0xFF041E2E)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(seaRect);
    canvas.drawRect(seaRect, seaPaint);

    // 2. Light Shaft Rays
    final ray1 = Path()
      ..moveTo(width * 0.1, 0)
      ..lineTo(width * 0.3, 0)
      ..lineTo(width * 0.55, height)
      ..lineTo(width * 0.05, height)
      ..close();
    canvas.drawPath(ray1, Paint()..color = Colors.white.withOpacity(0.07));

    final ray2 = Path()
      ..moveTo(width * 0.5, 0)
      ..lineTo(width * 0.7, 0)
      ..lineTo(width * 0.95, height * 0.8)
      ..lineTo(width * 0.65, height)
      ..close();
    canvas.drawPath(ray2, Paint()..color = Colors.white.withOpacity(0.06));

    // 3. Bubbles
    final bubblePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final b in bubbles) {
      canvas.drawCircle(
        Offset(b.x * width, b.y * height),
        b.radius,
        bubblePaint..color = Colors.white.withOpacity(b.opacity),
      );
    }

    // 4. Sea Bottom Coral Silhouettes
    final coralPaint1 = Paint()..color = const Color(0xFFE8265C).withOpacity(0.85);
    final coralPaint2 = Paint()..color = const Color(0xFF8B5CF6).withOpacity(0.85);
    final coralPaint3 = Paint()..color = const Color(0xFFFF8A3D).withOpacity(0.85);

    final coralPath1 = Path()
      ..moveTo(30, height)
      ..quadraticBezierTo(30, height - 60, 50, height - 80)
      ..quadraticBezierTo(60, height - 50, 50, height)
      ..close();
    canvas.drawPath(coralPath1, coralPaint1);

    final coralPath2 = Path()
      ..moveTo(width - 50, height)
      ..quadraticBezierTo(width - 55, height - 50, width - 35, height - 70)
      ..quadraticBezierTo(width - 25, height - 45, width - 35, height)
      ..close();
    canvas.drawPath(coralPath2, coralPaint2);

    final coralPath3 = Path()
      ..moveTo(110, height)
      ..quadraticBezierTo(110, height - 40, 125, height - 50)
      ..quadraticBezierTo(133, height - 30, 125, height)
      ..close();
    canvas.drawPath(coralPath3, coralPaint3);

    // 5. Draw Fishes (SVG styled fish from design kit)
    for (final fish in fishList) {
      final cx = fish.x * width;
      final cy = fish.y * height;
      final scale = fish.size / 40.0;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(-fish.direction * scale, scale);

      if (fish.type == FishType.boss) {
        // Shark Boss
        final sharkPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF5B6F85), Color(0xFF1E2A38)],
          ).createShader(const Rect.fromLTWH(-38, -15, 76, 30));
        canvas.drawOval(const Rect.fromLTWH(-38, -15, 76, 30), sharkPaint);

        // Shark Tail
        final tail = Path()
          ..moveTo(34, 0)
          ..lineTo(58, -18)
          ..lineTo(54, 0)
          ..lineTo(58, 18)
          ..close();
        canvas.drawPath(tail, sharkPaint);

        // Shark Fin
        final fin = Path()
          ..moveTo(-2, -14)
          ..lineTo(8, -36)
          ..lineTo(18, -14)
          ..close();
        canvas.drawPath(fin, sharkPaint);

        // Belly
        canvas.drawOval(
          const Rect.fromLTWH(-17, 0, 52, 14),
          Paint()..color = const Color(0xFFC9D3DD).withOpacity(0.55),
        );

        // Eye
        canvas.drawCircle(const Offset(-22, -5), 3.5, Paint()..color = const Color(0xFFFF4D4D));
      } else {
        // Regular Multi-Gradient Fish
        final fRect = const Rect.fromLTWH(-20, -11, 40, 22);
        final fishPaint = Paint()
          ..shader = LinearGradient(colors: fish.gradientColors).createShader(fRect);
        canvas.drawOval(fRect, fishPaint);

        // Tail
        final tail = Path()
          ..moveTo(17, 0)
          ..lineTo(32, -11)
          ..lineTo(29, 0)
          ..lineTo(32, 11)
          ..close();
        canvas.drawPath(tail, fishPaint);

        // Top Fin
        final fin = Path()
          ..moveTo(-4, -10)
          ..quadraticBezierTo(0, -16, 6, -10)
          ..close();
        canvas.drawPath(fin, fishPaint..color = fish.gradientColors.first.withOpacity(0.8));

        // Highlight
        canvas.drawOval(
          const Rect.fromLTWH(-7, 0, 18, 8),
          Paint()..color = Colors.white.withOpacity(0.25),
        );

        // Eye
        canvas.drawCircle(const Offset(-10, -3), 3.0, Paint()..color = Colors.white);
        canvas.drawCircle(const Offset(-9, -3), 1.6, Paint()..color = const Color(0xFF111111));
      }

      canvas.restore();
    }

    // 6. Draw Expanding Nets with Grid mesh
    for (final net in nets) {
      final nx = net.x * width;
      final ny = net.y * height;
      final r = net.radius * max(0.4, net.progress);

      final netFill = Paint()
        ..color = (net.isWide ? const Color(0xFFF5B942) : const Color(0xFF9FE8C8)).withOpacity(0.15);
      canvas.drawCircle(Offset(nx, ny), r, netFill);

      final netRing = Paint()
        ..color = net.isWide ? const Color(0xFFF5B942) : const Color(0xFF9FE8C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(nx, ny), r, netRing);

      // Grid Pattern
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 1.0;
      for (double d = -r + 8; d < r; d += 12) {
        canvas.drawLine(Offset(nx + d, ny - r), Offset(nx + d, ny + r), gridPaint);
        canvas.drawLine(Offset(nx - r, ny + d), Offset(nx + r, ny + d), gridPaint);
      }
    }

    // 7. Gold Metallic Cannon (at bottom center)
    final cannonCx = width * 0.5;
    final cannonCy = height * 0.90;

    canvas.save();
    canvas.translate(cannonCx, cannonCy);
    canvas.rotate(cannonAngle + (pi / 2));

    // Barrel
    final barrelRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -75, 24, 75),
      const Radius.circular(9),
    );
    final barrelPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE9A8), Color(0xFFF5B942), Color(0xFFB86E1A)],
      ).createShader(barrelRect.outerRect);
    canvas.drawRRect(barrelRect, barrelPaint);

    // Barrel Muzzle Ring
    final muzzleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, -82, 30, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(muzzleRect, Paint()..color = const Color(0xFFB86E1A));

    // Mount Base
    canvas.drawCircle(
      Offset.zero,
      22,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE9A8), Color(0xFFF5B942), Color(0xFFB86E1A)],
        ).createShader(const Rect.fromLTWH(-22, -22, 44, 44)),
    );
    canvas.drawCircle(Offset.zero, 10, Paint()..color = const Color(0xFFC97A1E));
    canvas.drawCircle(Offset.zero, 5, Paint()..color = const Color(0xFFFFE08A));

    canvas.restore();

    // 8. Floating Score popups
    for (final fs in floatingScores) {
      final textP = TextPainter(
        text: TextSpan(
          text: fs.text,
          style: TextStyle(
            color: fs.color.withOpacity(fs.opacity.clamp(0.0, 1.0)),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Sora',
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textP.layout();
      textP.paint(canvas, Offset((width * fs.x) - textP.width / 2, (height * fs.y) - textP.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FishingGameDesignKitPainter oldDelegate) => true;
}
