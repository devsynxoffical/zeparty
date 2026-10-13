import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/socket_service.dart';
import 'user_avatar.dart';

class TikTokUserJoinBanner extends StatefulWidget {
  final String roomId;
  final String? secondaryRoomId;
  final double bottomOffset;

  const TikTokUserJoinBanner({
    super.key,
    required this.roomId,
    this.secondaryRoomId,
    this.bottomOffset = 210,
  });

  @override
  State<TikTokUserJoinBanner> createState() => _TikTokUserJoinBannerState();
}

class _TikTokUserJoinBannerState extends State<TikTokUserJoinBanner> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _joinQueue = [];
  Map<String, dynamic>? _currentJoin;
  bool _isShowing = false;
  StreamSubscription? _sub;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _sub = SocketService.instance.userJoinedStream.listen((data) {
      final incomingRoomId = (data['roomId'] ?? '').toString().trim().toLowerCase();
      final incomingClientRoomId = (data['clientRoomId'] ?? data['room'] ?? '').toString().trim().toLowerCase();
      final primary = widget.roomId.trim().toLowerCase();
      final secondary = (widget.secondaryRoomId ?? '').trim().toLowerCase();

      final validRoomIds = <String>{
        if (primary.isNotEmpty) primary,
        if (secondary.isNotEmpty) secondary,
      };

      if (validRoomIds.isNotEmpty) {
        final matches = (incomingRoomId.isNotEmpty && validRoomIds.contains(incomingRoomId)) ||
            (incomingClientRoomId.isNotEmpty && validRoomIds.contains(incomingClientRoomId)) ||
            (incomingRoomId.isEmpty && incomingClientRoomId.isEmpty);
        if (!matches) return;
      }

      final userObj = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : <String, dynamic>{};
      final userId = (data['userId'] ?? data['id'] ?? userObj['id'] ?? userObj['userId'] ?? '').toString().trim();
      final displayName = userObj['displayName']?.toString() ?? userObj['name']?.toString() ?? userObj['username']?.toString() ?? data['name']?.toString() ?? 'Viewer';
      final avatarUrl = userObj['avatarUrl']?.toString() ?? data['avatarUrl']?.toString() ?? '';
      final isVip = userObj['isVip'] == true || data['isVip'] == true;
      final nobleLevel = userObj['nobleLevel']?.toString();

      _queueJoin({
        'userId': userId,
        'name': displayName,
        'avatarUrl': avatarUrl,
        'isVip': isVip,
        'nobleLevel': nobleLevel,
      });
    });
  }

  // Sliding deduplication window: Maps stable user identity (or event ID) to last shown timestamp
  final Map<String, int> _lastShownUserTimestamp = {};
  static const int _dedupWindowMs = 8000; // 8-second debounce per specific user ID

  void _queueJoin(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    if (name.isEmpty) return;

    final userId = (item['userId']?.toString().isNotEmpty == true)
        ? item['userId'].toString().trim().toLowerCase()
        : name.trim().toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Prune stale timestamps older than 60 seconds
    _lastShownUserTimestamp.removeWhere((_, ts) => now - ts > 60000);

    // Filter duplicates within sliding cooldown window
    if (userId.isNotEmpty && userId != 'viewer' && userId != 'a user') {
      if (_lastShownUserTimestamp.containsKey(userId)) {
        if (now - _lastShownUserTimestamp[userId]! < _dedupWindowMs) {
          return; // Ignore bounce/reconnect duplicate within 8s
        }
      }
      _lastShownUserTimestamp[userId] = now;
    }

    // Limit queue size to 8 items to prevent extreme backpressure
    if (_joinQueue.length >= 8) {
      // Remove oldest non-VIP item to prioritize new or VIP entrants
      final nonVipIdx = _joinQueue.indexWhere((it) => it['isVip'] != true);
      if (nonVipIdx != -1) {
        _joinQueue.removeAt(nonVipIdx);
      } else {
        _joinQueue.removeAt(0);
      }
    }

    _joinQueue.add(item);
    if (!_isShowing) {
      _processNext();
    }
  }

  void _processNext() async {
    if (_joinQueue.isEmpty || !mounted) {
      _isShowing = false;
      return;
    }

    _isShowing = true;
    setState(() {
      _currentJoin = _joinQueue.removeAt(0);
    });

    // Dynamic duration based on backlog pressure
    final hasBacklog = _joinQueue.length >= 2;
    final displayDurationMs = hasBacklog ? 1000 : 1600;

    await _controller.forward();
    await Future.delayed(Duration(milliseconds: displayDurationMs));

    if (mounted) {
      await _controller.reverse();
      setState(() {
        _currentJoin = null;
      });
      _processNext();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentJoin == null) return const SizedBox.shrink();

    final name = _currentJoin!['name']?.toString() ?? 'Viewer';
    final avatarUrl = _currentJoin!['avatarUrl']?.toString() ?? '';
    final isVip = _currentJoin!['isVip'] == true;
    final nobleLevel = _currentJoin!['nobleLevel']?.toString();

    return Positioned(
      left: 14,
      bottom: widget.bottomOffset,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isVip
                        ? [
                            const Color(0xFFFF9100).withValues(alpha: 0.92),
                            const Color(0xFFFF3D00).withValues(alpha: 0.85),
                            const Color(0xFF651FFF).withValues(alpha: 0.7),
                          ]
                        : [
                            const Color(0xFF1E1B2E).withValues(alpha: 0.88),
                            const Color(0xFF311B92).withValues(alpha: 0.82),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isVip ? const Color(0xFFFFD54F) : const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                    width: isVip ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isVip
                          ? Colors.orangeAccent.withValues(alpha: 0.4)
                          : Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with glow ring
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isVip ? Colors.amber : Colors.white,
                          width: 1.2,
                        ),
                      ),
                      child: UserAvatar(imageUrl: avatarUrl, radius: 14),
                    ),
                    const SizedBox(width: 7),
                    // User Badge + Name + "joined"
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isVip || nobleLevel != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    nobleLevel ?? 'VIP',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'joined the live 👋',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
