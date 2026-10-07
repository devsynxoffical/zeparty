import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RocketChallengeView extends StatefulWidget {
  final Function(int score, Map<String, dynamic> stats) onGameOver;
  final bool inRoom;
  final int initialLevel;

  const RocketChallengeView({
    super.key,
    required this.onGameOver,
    this.inRoom = false,
    this.initialLevel = 1,
  });

  @override
  State<RocketChallengeView> createState() => _RocketChallengeViewState();
}

class _RocketChallengeViewState extends State<RocketChallengeView> with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _scoreNotifier = ValueNotifier(0);
  late final ValueNotifier<int> _roundNotifier;
  final ValueNotifier<int> _streakNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _isLaunchingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _feedbackNotifier = ValueNotifier('');
  final ValueNotifier<Color> _feedbackColorNotifier = ValueNotifier(const Color(0xFF5FE39A));

  static const int _totalRounds = 10;
  int _maxStreak = 0;
  int _perfectCount = 0;
  int _stage = 1;
  bool _showingStageClearModal = false;

  double _targetAltitude = 2450.0;
  double _finalStopAltitude = 0.0;
  bool _isRoundFinished = false;

  late AnimationController _flightController;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _stage = widget.initialLevel > 1 ? widget.initialLevel : 1;
    _roundNotifier = ValueNotifier(1);
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _flightController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isRoundFinished && _isLaunchingNotifier.value) {
        _stopRocket(isAutoMiss: true);
      }
    });

    _prepareNewRound();
  }

  @override
  void dispose() {
    _flightController.dispose();
    _scoreNotifier.dispose();
    _roundNotifier.dispose();
    _streakNotifier.dispose();
    _isLaunchingNotifier.dispose();
    _feedbackNotifier.dispose();
    _feedbackColorNotifier.dispose();
    super.dispose();
  }

  void _prepareNewRound() {
    _finalStopAltitude = 0.0;
    _isRoundFinished = false;
    _isLaunchingNotifier.value = false;
    _feedbackNotifier.value = '';
    _flightController.reset();

    // Random target altitude between 1250m and 4500m
    _targetAltitude = (1250 + _rand.nextInt(3250)).toDouble();
    setState(() {});
  }

  void _launchRocket() {
    if (_isLaunchingNotifier.value || _isRoundFinished) return;
    HapticFeedback.mediumImpact();
    _isLaunchingNotifier.value = true;
    _flightController.forward(from: 0.0);
  }

  void _stopRocket({bool isAutoMiss = false}) {
    if (!_isLaunchingNotifier.value || _isRoundFinished) return;
    _isRoundFinished = true;
    _isLaunchingNotifier.value = false;
    _flightController.stop();

    final progress = _flightController.value;
    _finalStopAltitude = (pow(progress, 1.15) * 5000.0).toDouble();

    final errorDiff = (_finalStopAltitude - _targetAltitude).abs();
    final errorPercent = errorDiff / _targetAltitude;

    int roundPoints = 0;
    String text;
    Color color;

    final curStreak = _streakNotifier.value;
    if (isAutoMiss || errorPercent > 0.07) {
      roundPoints = 0;
      text = 'Miss! (${errorDiff.toInt()}m off)';
      color = const Color(0xFFFF4D4D);
      _streakNotifier.value = 0;
      HapticFeedback.vibrate();
    } else if (errorPercent <= 0.015) {
      roundPoints = 100;
      _perfectCount++;
      _streakNotifier.value = curStreak + 1;
      text = 'Perfect! +${(roundPoints * _getStreakMultiplier(_streakNotifier.value)).round()}';
      color = const Color(0xFF5FE39A);
      HapticFeedback.heavyImpact();
    } else if (errorPercent <= 0.035) {
      roundPoints = 60;
      _streakNotifier.value = curStreak + 1;
      text = 'Great! +${(roundPoints * _getStreakMultiplier(_streakNotifier.value)).round()}';
      color = const Color(0xFF9FE8C8);
      HapticFeedback.mediumImpact();
    } else {
      roundPoints = 30;
      _streakNotifier.value = curStreak + 1;
      text = 'Good! +${(roundPoints * _getStreakMultiplier(_streakNotifier.value)).round()}';
      color = const Color(0xFFF5B942);
      HapticFeedback.lightImpact();
    }

    _maxStreak = max(_maxStreak, _streakNotifier.value);
    _scoreNotifier.value += (roundPoints * _getStreakMultiplier(_streakNotifier.value)).round();

    _feedbackNotifier.value = text;
    _feedbackColorNotifier.value = color;

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      if (_roundNotifier.value % 10 == 0) {
        _scoreNotifier.value += 500 * _stage;
        HapticFeedback.heavyImpact();
        setState(() {
          _showingStageClearModal = true;
        });
      } else {
        _roundNotifier.value++;
        _prepareNewRound();
      }
    });
  }

  void _startNextStage() {
    _stage++;
    _roundNotifier.value++;
    _flightController.duration = Duration(milliseconds: max(1200, 3000 - (_stage * 350)));
    _prepareNewRound();

    setState(() {
      _showingStageClearModal = false;
    });
  }

  void _claimAndExit() {
    widget.onGameOver(_scoreNotifier.value, {
      'maxStreak': _maxStreak,
      'perfectCount': _perfectCount,
      'roundsCompleted': _roundNotifier.value,
      'stage': _stage,
    });
  }

  double _getStreakMultiplier(int streak) {
    if (streak >= 5) return 2.0;
    if (streak >= 3) return 1.5;
    if (streak >= 2) return 1.2;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Container(
          width: size.width,
          height: size.height,
          color: const Color(0xFF03041A),
          child: Stack(
            children: [
              // Direct Hardware Space & Rocket Canvas Painter
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RocketDesignKitPainter(
                      flightProgress: _flightController,
                      targetAltitude: _targetAltitude,
                      isRoundFinished: _isRoundFinished,
                      finalStopAltitude: _finalStopAltitude,
                    ),
                  ),
                ),
              ),

              // Design Kit Top HUD (Stage, Round, Score, Pause)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stage & Round Pill
                      ValueListenableBuilder<int>(
                        valueListenable: _roundNotifier,
                        builder: (context, round, _) {
                          final curRound = ((round - 1) % 10) + 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2E7CF6), Color(0xFF6A3BD6)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2E7CF6).withOpacity(0.4), blurRadius: 10),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.rocket_launch, color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'STAGE $_stage • R$curRound/10',
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

                      // Score Mid Pill
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
                              border: Border.all(color: const Color(0xFF5FE39A).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, color: Color(0xFF5FE39A), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$score pts',
                                  style: const TextStyle(
                                    color: Color(0xFF5FE39A),
                                    fontFamily: 'Sora',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
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
                          widget.onGameOver(_scoreNotifier.value, {
                            'maxStreak': _maxStreak,
                            'perfectCount': _perfectCount,
                            'roundsCompleted': _roundNotifier.value,
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

              // Target Altitude Glass Card (Top Center from `08_rocket.html`)
              Positioned(
                top: 66,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TARGET',
                            style: TextStyle(
                              color: Color(0xFFA69FC0),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_targetAltitude.toInt()} m',
                            style: const TextStyle(
                              color: Color(0xFFEDEDF2),
                              fontFamily: 'Sora',
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Streak Pill
                          ValueListenableBuilder<int>(
                            valueListenable: _streakNotifier,
                            builder: (context, streak, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [const Color(0xFFF5B942).withOpacity(0.25), const Color(0xFFF5B942).withOpacity(0.08)],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.55)),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFF5B942).withOpacity(0.25), blurRadius: 12),
                                  ],
                                ),
                                child: Text(
                                  'Streak ${_getStreakMultiplier(streak)}x',
                                  style: const TextStyle(
                                    color: Color(0xFFF5B942),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Feedback Pill (Right Side, e.g. Perfect! +100)
              ValueListenableBuilder<String>(
                valueListenable: _feedbackNotifier,
                builder: (context, feedback, _) {
                  if (feedback.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    top: size.height * 0.36,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2FBF71).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF5FE39A)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2FBF71).withOpacity(0.4), blurRadius: 14),
                        ],
                      ),
                      child: Text(
                        feedback,
                        style: const TextStyle(
                          color: Color(0xFFC8FFE8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Big Action Stop / Launch Button (98px Pill from `08_rocket.html`)
              Positioned(
                left: 18,
                right: 18,
                bottom: 28,
                child: SafeArea(
                  top: false,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isLaunchingNotifier,
                    builder: (context, isLaunching, _) {
                      return GestureDetector(
                        onTap: isLaunching ? () => _stopRocket() : _launchRocket,
                        child: Container(
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFF4D7E), Color(0xFFE8265C), Color(0xFFC81A4C)],
                              stops: [0.0, 0.55, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8265C).withOpacity(0.5),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isLaunching ? 'STOP' : 'LAUNCH',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Sora',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Stage Cleared Modal Overlay
              if (_showingStageClearModal)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.82),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF161936), Color(0xFF07091B)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF5FE39A), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5FE39A).withOpacity(0.3),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.rocket_launch_rounded,
                              size: 54,
                              color: Color(0xFF5FE39A),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'STAGE $_stage COMPLETE!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Sora',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '+${500 * _stage} Orbit Bonus RP Score',
                              style: const TextStyle(
                                color: Color(0xFF9FE8C8),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<int>(
                              valueListenable: _scoreNotifier,
                              builder: (context, score, _) {
                                return Text(
                                  'Total Score: $score',
                                  style: const TextStyle(
                                    color: Color(0xFFC9C9D6),
                                    fontSize: 14,
                                  ),
                                );
                              },
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
                                    onPressed: _startNextStage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5FE39A),
                                      foregroundColor: const Color(0xFF03041A),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text(
                                      'Next Stage (${_stage + 1})',
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
}

class _RocketDesignKitPainter extends CustomPainter {
  final Animation<double> flightProgress;
  final double targetAltitude;
  final bool isRoundFinished;
  final double finalStopAltitude;

  _RocketDesignKitPainter({
    required this.flightProgress,
    required this.targetAltitude,
    required this.isRoundFinished,
    required this.finalStopAltitude,
  }) : super(repaint: flightProgress);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Sky Gradient (#03041A -> #1A2566 -> #6DB4F0)
    final skyRect = Rect.fromLTWH(0, 0, width, height);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03041A), Color(0xFF1A2566), Color(0xFF6DB4F0)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Cosmic Nebula Soft Blurs
    canvas.drawOval(
      Rect.fromCenter(center: Offset(80, height * 0.25), width: 280, height: 180),
      Paint()..color = const Color(0xFF7C4DFF).withOpacity(0.18),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(width - 60, height * 0.15), width: 220, height: 150),
      Paint()..color = const Color(0xFFE8265C).withOpacity(0.14),
    );

    // 3. Moon with Craters
    final moonCenter = Offset(width - 70, height * 0.12);
    canvas.drawCircle(moonCenter, 26, Paint()..color = const Color(0xFFC9CCD6));
    canvas.drawCircle(Offset(moonCenter.dx - 8, moonCenter.dy - 6), 6, Paint()..color = const Color(0xFF9A9EAD));
    canvas.drawCircle(Offset(moonCenter.dx + 8, moonCenter.dy + 8), 4, Paint()..color = const Color(0xFF9A9EAD));

    // 4. Twinkling Stars
    final rand = Random(42);
    final starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 35; i++) {
      final sx = rand.nextDouble() * width;
      final sy = rand.nextDouble() * height * 0.65;
      final sr = 0.8 + rand.nextDouble() * 1.4;
      final so = 0.5 + rand.nextDouble() * 0.4;
      canvas.drawCircle(Offset(sx, sy), sr, starPaint..color = Colors.white.withOpacity(so));
    }

    // 5. Ground Clouds Atmosphere (at bottom)
    final cloudPath = Path()
      ..moveTo(0, height * 0.88)
      ..quadraticBezierTo(60, height * 0.82, 130, height * 0.88)
      ..quadraticBezierTo(200, height * 0.94, 260, height * 0.88)
      ..quadraticBezierTo(330, height * 0.82, width, height * 0.88)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(cloudPath, Paint()..color = Colors.white.withOpacity(0.20));

    // 6. Coordinates calculation
    final currentAlt = isRoundFinished
        ? finalStopAltitude
        : (pow(flightProgress.value, 1.15) * 5000.0).toDouble();

    final altProgress = (currentAlt / 5000.0).clamp(0.0, 1.0);
    final targetProgress = (targetAltitude / 5000.0).clamp(0.0, 1.0);

    final gaugeTop = height * 0.22;
    final gaugeBottom = height * 0.76;
    final gaugeH = gaugeBottom - gaugeTop;

    final rocketY = gaugeBottom - (altProgress * gaugeH);
    final targetY = gaugeBottom - (targetProgress * gaugeH);

    // 7. Left Vertical Gauge (from `08_rocket.html`)
    final gaugeX = 20.0;
    final gaugeW = 16.0;

    // Gauge Glass Background Pill
    final gaugeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(gaugeX, gaugeTop, gaugeW, gaugeH),
      const Radius.circular(999),
    );
    canvas.drawRRect(gaugeRect, Paint()..color = Colors.black.withOpacity(0.4));
    canvas.drawRRect(
      gaugeRect,
      Paint()
        ..color = Colors.white.withOpacity(0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Sweet Spot Green Zone on Gauge
    final zoneH = gaugeH * 0.07;
    final zoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(gaugeX + gaugeW / 2, targetY), width: gaugeW - 4, height: zoneH),
      const Radius.circular(999),
    );
    final zonePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5FE39A), Color(0xFF2FBF71)],
      ).createShader(zoneRect.outerRect);
    canvas.drawRRect(zoneRect, zonePaint);

    // Sliding White Mark Pointer
    final markRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(gaugeX + gaugeW / 2, rocketY), width: 28, height: 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(markRect, Paint()..color = Colors.white);

    // Altitude Ticks Labels (5,000, 3,750, 2,500, 1,250, 0)
    final tickLabels = ['5,000', '3,750', '2,500', '1,250', '0'];
    for (int i = 0; i < tickLabels.length; i++) {
      final ty = gaugeTop + (i / (tickLabels.length - 1)) * gaugeH;
      final tp = TextPainter(
        text: TextSpan(
          text: tickLabels[i],
          style: const TextStyle(
            color: Color(0xFFDDE0EE),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(gaugeX + gaugeW + 6, ty - tp.height / 2));
    }

    // 8. Flame Trail behind Climbing Rocket
    final rocketCenterX = width * 0.58;
    final startLaunchY = gaugeBottom;

    final trailPath = Path()
      ..moveTo(rocketCenterX, startLaunchY)
      ..cubicTo(rocketCenterX + 16, (startLaunchY + rocketY) * 0.65, rocketCenterX - 14, (startLaunchY + rocketY) * 0.45, rocketCenterX, rocketY + 28);

    canvas.drawPath(
      trailPath,
      Paint()
        ..color = const Color(0xFFFF6B6B).withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      trailPath,
      Paint()
        ..color = const Color(0xFFFFD166).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // 9. Aerodynamic Rocket Ship (Design Kit SVG model from `08_rocket.html`)
    canvas.save();
    canvas.translate(rocketCenterX, rocketY);

    // Main Rocket Body (#FF8A8A -> #FF3B3B -> #A81818)
    final bodyPath = Path()
      ..moveTo(-18, 28)
      ..lineTo(0, -32)
      ..lineTo(18, 28)
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF8A8A), Color(0xFFFF3B3B), Color(0xFFA81818)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(-18, -32, 36, 60));
    canvas.drawPath(bodyPath, bodyPaint);

    // Nose Cone Tip (#FFE08A)
    final tipPath = Path()
      ..moveTo(-4, -22)
      ..lineTo(0, -32)
      ..lineTo(4, -22)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = const Color(0xFFFFE08A));

    // Porthole Window
    canvas.drawCircle(const Offset(0, 2), 7, Paint()..color = const Color(0xFFBFF0FF));
    canvas.drawCircle(
      const Offset(0, 2),
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Fins
    final finPath = Path()
      ..moveTo(-18, 28)
      ..lineTo(-30, 42)
      ..lineTo(30, 42)
      ..lineTo(18, 28)
      ..close();
    canvas.drawPath(finPath, Paint()..color = const Color(0xFFA81818));

    // Exhaust Flame when climbing
    if (!isRoundFinished && flightProgress.value > 0.0 && flightProgress.value < 1.0) {
      final flame1 = Path()
        ..moveTo(-8, 30)
        ..quadraticBezierTo(0, 60 + sin(flightProgress.value * 40) * 8, 8, 30)
        ..close();
      canvas.drawPath(
        flame1,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4B0), Color(0xFFFFA726), Color(0x00FF3B3B)],
          ).createShader(const Rect.fromLTWH(-8, 30, 16, 40)),
      );

      final flame2 = Path()
        ..moveTo(-4, 30)
        ..quadraticBezierTo(0, 46, 4, 30)
        ..close();
      canvas.drawPath(flame2, Paint()..color = const Color(0xFFFFF4B0));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RocketDesignKitPainter oldDelegate) => true;
}
