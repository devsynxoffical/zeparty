import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/api_client.dart';

class RocketGameSheet extends StatefulWidget {
  final String? roomId;
  const RocketGameSheet({super.key, this.roomId});

  @override
  State<RocketGameSheet> createState() => _RocketGameSheetState();
}

class _RocketGameSheetState extends State<RocketGameSheet> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _milestones = [
    {'level': 1, 'target': 100000, 'reward': 5000, 'label': '100K', 'rewardLabel': '5K'},
    {'level': 2, 'target': 300000, 'reward': 6000, 'label': '300K', 'rewardLabel': '6K'},
    {'level': 3, 'target': 400000, 'reward': 7000, 'label': '400K', 'rewardLabel': '7K'},
    {'level': 4, 'target': 500000, 'reward': 10000, 'label': '500K', 'rewardLabel': '10K'},
    {'level': 5, 'target': 1000000, 'reward': 15000, 'label': '1M', 'rewardLabel': '15K'},
  ];

  int currentLevel = 1;
  int cumulativePoints = 0;
  Set<int> unlockedLevels = {};
  List<Map<String, dynamic>> contributors = [];
  Map<String, dynamic>? topSender;

  late AnimationController _rocketController;
  late Animation<double> _rocketAnimation;
  StreamSubscription? _progressSub;
  StreamSubscription? _unlockSub;

  @override
  void initState() {
    super.initState();
    _rocketController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _rocketAnimation = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut));

    _loadRoomRocketProgress();
    _initSocketListeners();
  }

  Future<void> _loadRoomRocketProgress() async {
    final rid = widget.roomId;
    if (rid != null && rid.isNotEmpty) {
      try {
        final res = await ApiClient.instance.dio.get('/v1/games/rocket/room/$rid');
        if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
          final data = res.data['data'] as Map<String, dynamic>;
          _applyRocketData(data);
        }
      } catch (_) {
        // Fallback to initial default state
      }
    }
  }

  void _initSocketListeners() {
    final socket = SocketService.instance;
    _progressSub = socket.onEvent('room:rocket_progress').listen((data) {
      if (data is Map<String, dynamic> && mounted) {
        _applyRocketData(data);
      }
    });

    _unlockSub = socket.onEvent('room:rocket_unlocked').listen((data) {
      if (data is Map<String, dynamic> && mounted) {
        final lvl = data['rocketLevel'] ?? 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ROCKET $lvl UNLOCKED! Top contributor rewarded! 🚀', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.amber.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
        _applyRocketData(data);
      }
    });
  }

  void _applyRocketData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      cumulativePoints = data['cumulativePoints'] is int
          ? data['cumulativePoints']
          : int.tryParse(data['cumulativePoints']?.toString() ?? '0') ?? cumulativePoints;

      currentLevel = data['activeRocketLevel'] is int
          ? data['activeRocketLevel']
          : int.tryParse(data['activeRocketLevel']?.toString() ?? '1') ?? currentLevel;

      if (data['unlockedLevels'] is List) {
        unlockedLevels = Set<int>.from((data['unlockedLevels'] as List).map((e) => int.tryParse(e.toString()) ?? 1));
      }

      if (data['contributors'] is List) {
        contributors = List<Map<String, dynamic>>.from(data['contributors']);
      }

      if (data['topSender'] is Map) {
        topSender = Map<String, dynamic>.from(data['topSender']);
      } else if (contributors.isNotEmpty) {
        topSender = contributors.first;
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _unlockSub?.cancel();
    _rocketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = (currentLevel - 1).clamp(0, 4);
    final activeMilestone = _milestones[activeIndex];
    final int target = activeMilestone['target'] as int;
    final int reward = activeMilestone['reward'] as int;

    // Relative progress in current milestone
    int prevTarget = activeIndex > 0 ? (_milestones[activeIndex - 1]['target'] as int) : 0;
    int progressSpan = target - prevTarget;
    int pointsInSpan = (cumulativePoints - prevTarget).clamp(0, progressSpan);
    double progressRatio = progressSpan > 0 ? (pointsInSpan / progressSpan).clamp(0.0, 1.0) : 0.0;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: const Color(0xFF161324),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.2),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🚀 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Rocket Game',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5-Level Milestone Cards (Rocket 1: 100K to Rocket 5: 1M)
              _buildMilestoneCards(activeIndex),
              const SizedBox(height: 20),

              // Rocket Animated Center Visual
              SizedBox(
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rocketAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _rocketAnimation.value),
                          child: const Text('🚀', style: TextStyle(fontSize: 84)),
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFB800)),
                        ),
                        child: Text(
                          'Level $currentLevel',
                          style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Bar & Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${AppFormatters.formatNumber(cumulativePoints)} / ${AppFormatters.formatNumber(target)} (${activeMilestone['label']})',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(progressRatio * 100).toInt()}%',
                          style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Sender Reward Box (matching reference design)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B1D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E6B43)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOP SENDER REWARD | ROCKET $currentLevel',
                                style: const TextStyle(
                                  color: Color(0xFF57DF95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E6B43),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Reward $reward Coins',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            topSender != null
                                ? '${topSender!['name']} is leading with ${AppFormatters.formatNumber(topSender!['amount'] ?? 0)} points! ($reward coins will be credited to personal wallet on unlock)'
                                : 'Send gifts in the room to add rocket points. Top contributor wins $reward coins credited to personal wallet on unlock!',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Contributors Leaderboard
                    if (contributors.isNotEmpty) ...[
                      const Text(
                        'Room Contributors (Active Cycle)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ...contributors.take(5).map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white24,
                              backgroundImage: (c['avatar'] != null && c['avatar'].toString().isNotEmpty)
                                  ? NetworkImage(c['avatar'])
                                  : null,
                              child: (c['avatar'] == null || c['avatar'].toString().isEmpty)
                                  ? Text(
                                      c['name'] != null && c['name'].toString().isNotEmpty
                                          ? c['name'][0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(c['name'] ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            Text(
                              '${AppFormatters.formatNumber(c['amount'] ?? 0)} pts',
                              style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCards(int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: _milestones.map((m) {
          final level = m['level'] as int;
          final isUnlocked = unlockedLevels.contains(level);
          final isActive = level == currentLevel;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2E2412)
                  : (isUnlocked ? const Color(0xFF14291D) : const Color(0xFF221F35)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFFB800)
                    : (isUnlocked ? Colors.green : Colors.white24),
                width: isActive ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnlocked)
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 12)
                    else if (isActive)
                      const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFFB800), size: 12),
                    if (isUnlocked || isActive) const SizedBox(width: 3),
                    Text(
                      'Rocket $level',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFFFFD56B)
                            : (isUnlocked ? Colors.greenAccent : Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reward ${m['rewardLabel']}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFFFFD56B) : Colors.white38,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
