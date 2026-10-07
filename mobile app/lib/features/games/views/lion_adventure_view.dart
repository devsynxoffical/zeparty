import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LionAdventureView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const LionAdventureView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<LionAdventureView> createState() => _LionAdventureViewState();
}

enum ObstacleType { log, branch, rock }
enum PowerUpType { none, shield, magnet, dash, doubleGems }

class TrackEntity {
  final int id;
  final int lane; // 0: Left, 1: Center, 2: Right
  double y; // 0.0 (far horizon) to 1.0 (player position)
  final bool isObstacle;
  final ObstacleType? obstacleType;
  final bool isGem;
  final bool isGoldGem;
  final PowerUpType powerUp;
  bool isCollected;

  TrackEntity({
    required this.id,
    required this.lane,
    required this.y,
    this.isObstacle = false,
    this.obstacleType,
    this.isGem = false,
    this.isGoldGem = false,
    this.powerUp = PowerUpType.none,
    this.isCollected = false,
  });
}

class FloatingText {
  double x;
  double y;
  String text;
  Color color;
  double opacity;

  FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.opacity = 1.0,
  });
}

class _LionAdventureViewState extends State<LionAdventureView> with SingleTickerProviderStateMixin {
  late final ValueNotifier<int> _distanceNotifier;
  final ValueNotifier<int> _gemsNotifier = ValueNotifier(0);
  final ValueNotifier<PowerUpType> _powerUpNotifier = ValueNotifier(PowerUpType.none);
  final ValueNotifier<double> _powerUpPercentNotifier = ValueNotifier(0.0);

  int _lane = 1; // 0: Left, 1: Center, 2: Right
  double _smoothLane = 1.0;
  bool _isJumping = false;
  double _jumpProgress = 0.0;
  bool _isSliding = false;
  double _slideProgress = 0.0;
  bool _isDead = false;

  final List<TrackEntity> _entities = [];
  final List<FloatingText> _floatingTexts = [];
  double _trackOffset = 0.0;

  late AnimationController _tickerController;
  Timer? _spawnTimer;
  Timer? _powerUpTimer;
  int _powerUpSecondsLeft = 0;
  int _nextEntityId = 1;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    final startLevel = widget.initialLevel > 1 ? widget.initialLevel : 1;
    _distanceNotifier = ValueNotifier((startLevel - 1) * 400);
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickerController.addListener(_onGameTick);
    _startSpawning();
  }

  @override
  void dispose() {
    _tickerController.removeListener(_onGameTick);
    _tickerController.dispose();
    _spawnTimer?.cancel();
    _powerUpTimer?.cancel();
    _distanceNotifier.dispose();
    _gemsNotifier.dispose();
    _powerUpNotifier.dispose();
    _powerUpPercentNotifier.dispose();
    super.dispose();
  }

  void _startSpawning() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      _spawnEntity();
    });
  }

  void _spawnEntity() {
    if (_isDead) return;

    final lane = _rand.nextInt(3);
    final roll = _rand.nextDouble();

    if (roll < 0.45) {
      final obsType = ObstacleType.values[_rand.nextInt(ObstacleType.values.length)];
      _entities.add(
        TrackEntity(
          id: _nextEntityId++,
          lane: lane,
          y: 0.0,
          isObstacle: true,
          obstacleType: obsType,
        ),
      );
    } else if (roll < 0.85) {
      final isGold = _rand.nextDouble() < 0.25;
      _entities.add(
        TrackEntity(
          id: _nextEntityId++,
          lane: lane,
          y: 0.0,
          isGem: true,
          isGoldGem: isGold,
        ),
      );
    } else {
      final ptypes = [PowerUpType.shield, PowerUpType.magnet, PowerUpType.dash, PowerUpType.doubleGems];
      final ptype = ptypes[_rand.nextInt(ptypes.length)];
      _entities.add(
        TrackEntity(
          id: _nextEntityId++,
          lane: lane,
          y: 0.0,
          powerUp: ptype,
        ),
      );
    }
  }

  void _onGameTick() {
    if (_isDead || !mounted) return;

    _smoothLane += (_lane - _smoothLane) * 0.25;

    if (_isJumping) {
      _jumpProgress += 0.045;
      if (_jumpProgress >= 1.0) {
        _isJumping = false;
        _jumpProgress = 0.0;
      }
    }

    if (_isSliding) {
      _slideProgress += 0.045;
      if (_slideProgress >= 1.0) {
        _isSliding = false;
        _slideProgress = 0.0;
      }
    }

    _distanceNotifier.value += 1;
    final currentDist = _distanceNotifier.value;

    final isDash = _powerUpNotifier.value == PowerUpType.dash;
    final baseSpeed = isDash ? 0.038 : (0.019 + (currentDist / 45000.0));
    _trackOffset = (_trackOffset + baseSpeed) % 1.0;

    for (int i = _entities.length - 1; i >= 0; i--) {
      final e = _entities[i];
      e.y += baseSpeed;

      // Magnet attraction
      if (_powerUpNotifier.value == PowerUpType.magnet && (e.isGem || e.powerUp != PowerUpType.none)) {
        if (e.y > 0.35 && !e.isCollected) {
          e.y += 0.015;
        }
      }

      // Collision Check
      if (e.y >= 0.80 && e.y <= 0.94 && !e.isCollected) {
        final laneDiff = (e.lane - _smoothLane).abs();
        if (laneDiff < 0.55) {
          if (e.isObstacle) {
            _handleObstacleCollision(e);
          } else if (e.isGem) {
            _collectGem(e);
          } else if (e.powerUp != PowerUpType.none) {
            _collectPowerUp(e);
          }
        }
      }

      if (e.y > 1.15) {
        _entities.removeAt(i);
      }
    }

    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y -= 0.005;
      ft.opacity -= 0.035;
      if (ft.opacity <= 0) {
        _floatingTexts.removeAt(i);
      }
    }
  }

  void _handleObstacleCollision(TrackEntity e) {
    if (_powerUpNotifier.value == PowerUpType.dash) {
      e.isCollected = true;
      _floatingTexts.add(FloatingText(x: 0.5, y: 0.7, text: 'SMASH! +50', color: const Color(0xFFE8265C)));
      HapticFeedback.lightImpact();
      return;
    }

    if (_powerUpNotifier.value == PowerUpType.shield) {
      e.isCollected = true;
      _powerUpNotifier.value = PowerUpType.none;
      _powerUpPercentNotifier.value = 0.0;
      _powerUpTimer?.cancel();
      _floatingTexts.add(FloatingText(x: 0.5, y: 0.7, text: 'SHIELD BLOCKED!', color: const Color(0xFF2E7CF6)));
      HapticFeedback.mediumImpact();
      return;
    }

    if (e.obstacleType == ObstacleType.log && _isJumping && _jumpProgress > 0.15 && _jumpProgress < 0.85) {
      return;
    }
    if (e.obstacleType == ObstacleType.branch && _isSliding && _slideProgress > 0.15 && _slideProgress < 0.85) {
      return;
    }

    // Dead
    _isDead = true;
    _tickerController.stop();
    _spawnTimer?.cancel();
    _powerUpTimer?.cancel();
    HapticFeedback.heavyImpact();

    final finalScore = _distanceNotifier.value + (_gemsNotifier.value * 10);
    widget.onGameOver(finalScore, {
      'distance': _distanceNotifier.value,
      'gems': _gemsNotifier.value,
    });
  }

  void _collectGem(TrackEntity e) {
    e.isCollected = true;
    final isDouble = _powerUpNotifier.value == PowerUpType.doubleGems;
    final gemVal = (e.isGoldGem ? 5 : 1) * (isDouble ? 2 : 1);
    _gemsNotifier.value += gemVal;

    _floatingTexts.add(
      FloatingText(
        x: 0.5,
        y: 0.75,
        text: '+$gemVal ${e.isGoldGem ? "⭐" : "💎"}',
        color: e.isGoldGem ? const Color(0xFFF5B942) : const Color(0xFF6FB3FF),
      ),
    );
    HapticFeedback.selectionClick();
  }

  void _collectPowerUp(TrackEntity e) {
    e.isCollected = true;
    _powerUpNotifier.value = e.powerUp;
    _powerUpSecondsLeft = 10;
    _powerUpPercentNotifier.value = 1.0;

    _floatingTexts.add(
      FloatingText(
        x: 0.5,
        y: 0.65,
        text: '${_getPowerUpName(e.powerUp)} ACTIVE!',
        color: const Color(0xFFF5B942),
      ),
    );
    HapticFeedback.heavyImpact();

    _powerUpTimer?.cancel();
    _powerUpTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _powerUpSecondsLeft--;
      _powerUpPercentNotifier.value = (_powerUpSecondsLeft / 100.0).clamp(0.0, 1.0);
      if (_powerUpSecondsLeft <= 0) {
        _powerUpNotifier.value = PowerUpType.none;
        _powerUpPercentNotifier.value = 0.0;
        t.cancel();
      }
    });
  }

  void _swipeLeft() {
    if (_lane > 0 && !_isDead) {
      HapticFeedback.selectionClick();
      _lane--;
    }
  }

  void _swipeRight() {
    if (_lane < 2 && !_isDead) {
      HapticFeedback.selectionClick();
      _lane++;
    }
  }

  void _swipeUp() {
    if (!_isJumping && !_isSliding && !_isDead) {
      HapticFeedback.lightImpact();
      _isJumping = true;
      _jumpProgress = 0.0;
    }
  }

  void _swipeDown() {
    if (!_isSliding && !_isJumping && !_isDead) {
      HapticFeedback.lightImpact();
      _isSliding = true;
      _slideProgress = 0.0;
    }
  }

  String _getPowerUpName(PowerUpType p) {
    switch (p) {
      case PowerUpType.shield:
        return 'Shield';
      case PowerUpType.magnet:
        return 'Magnet';
      case PowerUpType.dash:
        return 'Dash Speed';
      case PowerUpType.doubleGems:
        return '2X Gems';
      case PowerUpType.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final vel = details.primaryVelocity ?? 0;
            if (vel < -100) {
              _swipeLeft();
            } else if (vel > 100) {
              _swipeRight();
            }
          },
          onVerticalDragEnd: (details) {
            final vel = details.primaryVelocity ?? 0;
            if (vel < -100) {
              _swipeUp();
            } else if (vel > 100) {
              _swipeDown();
            }
          },
          child: Container(
            width: size.width,
            height: size.height,
            color: const Color(0xFF0E2B14),
            child: Stack(
              children: [
                // Direct Hardware Jungle Canvas Painter
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LionJungleDesignKitPainter(
                        repaint: _tickerController,
                        entities: _entities,
                        floatingTexts: _floatingTexts,
                        smoothLane: _smoothLane,
                        jumpProgress: _jumpProgress,
                        isJumping: _isJumping,
                        slideProgress: _slideProgress,
                        isSliding: _isSliding,
                        activePowerUp: _powerUpNotifier.value,
                        trackOffset: _trackOffset,
                      ),
                    ),
                  ),
                ),

              // Design Kit Top HUD (Zone, Score, Gems, Pause)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Zone / Level Badge
                      ValueListenableBuilder<int>(
                        valueListenable: _distanceNotifier,
                        builder: (context, dist, _) {
                          final zone = (dist ~/ 400) + 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF5A623), Color(0xFFD0021B)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.4), blurRadius: 10),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield, color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'ZONE $zone',
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

                      // Live Score Pill
                      ValueListenableBuilder<int>(
                        valueListenable: _distanceNotifier,
                        builder: (context, dist, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _gemsNotifier,
                            builder: (context, gems, _) {
                              final score = dist + (gems * 10);
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
                                      '$score',
                                      style: const TextStyle(
                                        color: Color(0xFFF5B942),
                                        fontFamily: 'Sora',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Center Gems Mid Pill
                      ValueListenableBuilder<int>(
                        valueListenable: _gemsNotifier,
                        builder: (context, gems, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0A12).withOpacity(0.65),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.diamond, color: Color(0xFF6FB3FF), size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  '$gems',
                                  style: const TextStyle(
                                    color: Color(0xFFEDEDF2),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                        // Pause Button
                        GestureDetector(
                          onTap: () {
                            widget.onGameOver(_distanceNotifier.value + (_gemsNotifier.value * 10), {
                              'distance': _distanceNotifier.value,
                              'gems': _gemsNotifier.value,
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

                // Power-up Glass Card (Top Left from `09_lion.html`)
                ValueListenableBuilder<PowerUpType>(
                  valueListenable: _powerUpNotifier,
                  builder: (context, powerUp, _) {
                    if (powerUp == PowerUpType.none) return const SizedBox.shrink();
                    return Positioned(
                      top: 66,
                      left: 14,
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
                              Text(
                                _getPowerUpName(powerUp),
                                style: const TextStyle(
                                  color: Color(0xFFEDEDF2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 120,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _powerUpPercentNotifier,
                                  builder: (context, pct, _) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: pct,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF2E7CF6), Color(0xFF6FB3FF)],
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFF2E7CF6).withOpacity(0.6), blurRadius: 8),
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

                // Bottom Hint Pill (Design Kit `09_lion.html`)
                Positioned(
                  left: 30,
                  right: 30,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                      ),
                      child: const Center(
                        child: Text(
                          'Swipe to change lane · up to jump · down to slide',
                          style: TextStyle(
                            color: Color(0xFFE8E8F0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
}

class _LionJungleDesignKitPainter extends CustomPainter {
  final List<TrackEntity> entities;
  final List<FloatingText> floatingTexts;
  final double smoothLane;
  final double jumpProgress;
  final bool isJumping;
  final double slideProgress;
  final bool isSliding;
  final PowerUpType activePowerUp;
  final double trackOffset;

  _LionJungleDesignKitPainter({
    required super.repaint,
    required this.entities,
    required this.floatingTexts,
    required this.smoothLane,
    required this.jumpProgress,
    required this.isJumping,
    required this.slideProgress,
    required this.isSliding,
    required this.activePowerUp,
    required this.trackOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final horizonY = height * 0.42;
    final centerX = width * 0.5;

    // 1. Jungle Canopy Gradient (#0E2B14 -> #2E7A36 -> #8A5A24)
    final bgRect = Rect.fromLTWH(0, 0, width, height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0E2B14), Color(0xFF2E7A36), Color(0xFF8A5A24)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Sun Ray Glow in sky
    canvas.drawCircle(Offset(centerX, 120), 180, Paint()..color = const Color(0xFFFFD27A).withOpacity(0.12));

    // 2. Ancient Temple Backdrop on Horizon
    final tPaint1 = Paint()..color = const Color(0xFF5B5B5B);
    final tPaint2 = Paint()..color = const Color(0xFF6E6E6E);
    final tPaint3 = Paint()..color = const Color(0xFF7E7E7E);
    canvas.drawRect(Rect.fromLTWH(centerX - 60, horizonY - 110, 120, 60), tPaint1);
    canvas.drawRect(Rect.fromLTWH(centerX - 45, horizonY - 145, 90, 35), tPaint2);
    canvas.drawRect(Rect.fromLTWH(centerX - 30, horizonY - 170, 60, 25), tPaint3);

    // 3. Jungle Trees on Sides
    _drawJungleTree(canvas, const Offset(40, 250), 1.2);
    _drawJungleTree(canvas, Offset(width - 40, 240), 1.3);
    _drawJungleTree(canvas, const Offset(90, 330), 0.85);
    _drawJungleTree(canvas, Offset(width - 90, 340), 0.9);

    // 4. 3D Perspective Dirt Trail Track
    final trackPath = Path()
      ..moveTo(centerX - 50, horizonY)
      ..lineTo(centerX + 50, horizonY)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(trackPath, Paint()..color = const Color(0xFFA86A2A));

    // Wooden Track Ties
    final tiePaint = Paint()
      ..color = const Color(0xFFC48A48).withOpacity(0.5)
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 9; i++) {
      final p = ((i / 9.0) + (trackOffset / 9.0)) % 1.0;
      final ty = horizonY + (p * (height - horizonY));
      final spread = 20 + (p * 70);
      tiePaint.strokeWidth = 2.0 + (p * 8.0);
      canvas.drawLine(Offset(centerX - spread, ty), Offset(centerX + spread, ty), tiePaint);
    }

    // Lane Side Curbs
    final curbPaint = Paint()..color = const Color(0xFF7A4A1A);
    final curbL = Path()
      ..moveTo(centerX - 19, horizonY)
      ..lineTo(centerX - 17, horizonY)
      ..lineTo(width * 0.33, height)
      ..lineTo(width * 0.24, height)
      ..close();
    canvas.drawPath(curbL, curbPaint);

    final curbR = Path()
      ..moveTo(centerX + 17, horizonY)
      ..lineTo(centerX + 19, horizonY)
      ..lineTo(width * 0.76, height)
      ..lineTo(width * 0.67, height)
      ..close();
    canvas.drawPath(curbR, curbPaint);

    // 5. Draw Entities (Logs, Branches, Diamonds, Power-ups)
    final sortedEntities = List<TrackEntity>.from(entities)
      ..sort((a, b) => a.y.compareTo(b.y));

    for (final e in sortedEntities) {
      if (e.isCollected) continue;
      final laneX = _calcLaneX(e.lane.toDouble(), e.y, width);
      final entityY = horizonY + (e.y * (height - horizonY));
      final scale = 0.25 + (e.y * 0.85);

      canvas.save();
      canvas.translate(laneX, entityY);
      canvas.scale(scale);

      if (e.isObstacle) {
        _drawDesignKitObstacle(canvas, e.obstacleType!);
      } else if (e.isGem) {
        _drawDesignKitGem(canvas, e.isGoldGem);
      } else {
        _drawDesignKitPowerUp(canvas, e.powerUp);
      }

      canvas.restore();
    }

    // 6. Draw Lion Character (Design Kit SVG model from `09_lion.html`)
    final playerYNorm = 0.86;
    final playerBaseX = _calcLaneX(smoothLane, playerYNorm, width);
    final playerBaseY = horizonY + (playerYNorm * (height - horizonY));

    double jumpOffset = 0.0;
    if (isJumping) {
      jumpOffset = sin(jumpProgress * pi) * 75.0;
    }
    double slideSquish = 1.0;
    if (isSliding) {
      slideSquish = 0.60;
    }

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(playerBaseX, playerBaseY + 62),
        width: 96 * (1.0 - (jumpOffset / 150.0)),
        height: 18 * (1.0 - (jumpOffset / 150.0)),
      ),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    canvas.save();
    canvas.translate(playerBaseX, playerBaseY - jumpOffset);
    canvas.scale(1.0, slideSquish);

    // Power-up Aura Ring
    if (activePowerUp == PowerUpType.shield || activePowerUp == PowerUpType.magnet) {
      canvas.drawCircle(Offset.zero, 82, Paint()..color = const Color(0xFF2E7CF6).withOpacity(0.16));
      canvas.drawCircle(
        Offset.zero,
        82,
        Paint()
          ..color = const Color(0xFFBFF0FF).withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Lion Body
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD27A), Color(0xFFE8891C)],
      ).createShader(const Rect.fromLTWH(-36, 6, 72, 48));
    canvas.drawOval(const Rect.fromLTWH(-36, 6, 72, 48), bodyPaint);

    // Lion Mane
    final manePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE07A1A), Color(0xFF9A4A0E)],
      ).createShader(const Rect.fromLTWH(-46, -46, 92, 92));
    canvas.drawCircle(const Offset(0, -8), 38, manePaint);

    // Lion Face
    canvas.drawCircle(const Offset(0, -4), 28, bodyPaint);

    // Eyes
    canvas.drawCircle(const Offset(-11, -9), 4, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(const Offset(11, -9), 4, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(const Offset(-10, -10), 1.3, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(12, -10), 1.3, Paint()..color = Colors.white);

    // Nose & Mouth
    canvas.drawOval(const Rect.fromLTWH(-6, 0, 12, 8), Paint()..color = const Color(0xFF3A1F0A));

    // Royal Crown on Lion Head
    final crownPath = Path()
      ..moveTo(-22, -46)
      ..lineTo(-16, -60)
      ..lineTo(-10, -51)
      ..lineTo(0, -65)
      ..lineTo(10, -51)
      ..lineTo(16, -60)
      ..lineTo(22, -46)
      ..close();
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE08A), Color(0xFFE8902A)],
      ).createShader(const Rect.fromLTWH(-22, -65, 44, 20));
    canvas.drawPath(crownPath, crownPaint);

    // Crown Gems (Ruby & Sapphire)
    canvas.drawCircle(const Offset(-6, -52), 2.2, Paint()..color = const Color(0xFFE8265C));
    canvas.drawCircle(const Offset(6, -52), 2.2, Paint()..color = const Color(0xFF2E7CF6));

    // Paws
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-28, 44, 14, 24), const Radius.circular(6)), Paint()..color = const Color(0xFFD47A1C));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 44, 14, 24), const Radius.circular(6)), Paint()..color = const Color(0xFFD47A1C));

    canvas.restore();

    // 7. Floating Text popups
    for (final ft in floatingTexts) {
      final textP = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(ft.opacity.clamp(0.0, 1.0)),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Sora',
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textP.paint(canvas, Offset((width * ft.x) - textP.width / 2, (height * ft.y) - textP.height / 2));
    }
  }

  void _drawJungleTree(Canvas canvas, Offset pos, double scale) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

    canvas.drawRect(const Rect.fromLTWH(-6, 0, 12, 60), Paint()..color = const Color(0xFF4A2E12));
    canvas.drawCircle(const Offset(0, -10), 46, Paint()..color = const Color(0xFF1F5A26));
    canvas.drawCircle(const Offset(-26, 8), 30, Paint()..color = const Color(0xFF2A7A32));
    canvas.drawCircle(const Offset(26, 6), 32, Paint()..color = const Color(0xFF2A7A32));
    canvas.drawCircle(const Offset(0, -30), 26, Paint()..color = const Color(0xFF3C9A44));

    canvas.restore();
  }

  void _drawDesignKitObstacle(Canvas canvas, ObstacleType type) {
    if (type == ObstacleType.log) {
      // Fallen Wood Log from `09_lion.html`
      canvas.drawOval(const Rect.fromLTWH(-62, 8, 124, 20), Paint()..color = Colors.black.withOpacity(0.3));
      final logRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-60, -14, 120, 30), const Radius.circular(15));
      canvas.drawRRect(logRect, Paint()..color = const Color(0xFF5B3A1A));
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-52, -9, 104, 7), const Radius.circular(3)),
        Paint()..color = const Color(0xFF8A5A2A),
      );
      canvas.drawCircle(const Offset(-60, 1), 15, Paint()..color = const Color(0xFF3E2611));
      canvas.drawCircle(const Offset(-60, 1), 8, Paint()..color = const Color(0xFF6B4320));
    } else if (type == ObstacleType.branch) {
      // Jungle Slide Branch
      final branchRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-70, -20, 140, 14), const Radius.circular(7));
      canvas.drawRRect(branchRect, Paint()..color = const Color(0xFF3E6B2A));
      canvas.drawCircle(const Offset(-60, -20), 18, Paint()..color = const Color(0xFF2A7A32));
      canvas.drawCircle(const Offset(60, -22), 20, Paint()..color = const Color(0xFF2A7A32));
      canvas.drawCircle(const Offset(0, -26), 14, Paint()..color = const Color(0xFF3C9A44));
    } else {
      // Rock
      canvas.drawCircle(Offset.zero, 24, Paint()..color = Colors.grey.shade800);
      canvas.drawCircle(const Offset(-4, -4), 16, Paint()..color = Colors.grey.shade600);
    }
  }

  void _drawDesignKitGem(Canvas canvas, bool isGold) {
    final gemPath = Path()
      ..moveTo(0, -14)
      ..lineTo(12, 0)
      ..lineTo(0, 16)
      ..lineTo(-12, 0)
      ..close();

    final gemPaint = Paint()
      ..shader = LinearGradient(
        colors: isGold
            ? [const Color(0xFFFFE08A), const Color(0xFFE8902A)]
            : [const Color(0xFFBFF0FF), const Color(0xFF2E7CF6), const Color(0xFF1A3FA8)],
      ).createShader(const Rect.fromLTWH(-12, -14, 24, 30));

    canvas.drawPath(gemPath, gemPaint);

    final highlightPath = Path()
      ..moveTo(0, -14)
      ..lineTo(12, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withOpacity(0.35));
  }

  void _drawDesignKitPowerUp(Canvas canvas, PowerUpType type) {
    canvas.drawCircle(Offset.zero, 18, Paint()..color = const Color(0xFF2E7CF6));
    canvas.drawCircle(Offset.zero, 18, Paint()..color = const Color(0xFF2E7CF6).withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    final tp = TextPainter(
      text: const TextSpan(text: '⚡', style: TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  double _calcLaneX(double lane, double yProgress, double width) {
    final horizonCenter = width * 0.5;
    final spread = 30 + (yProgress * (width * 0.55));
    final laneOffset = (lane - 1.0) * spread;
    return horizonCenter + laneOffset;
  }

  @override
  bool shouldRepaint(covariant _LionJungleDesignKitPainter oldDelegate) => true;
}
