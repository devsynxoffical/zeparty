import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/utils/noble_badge_helper.dart';
import 'user_avatar.dart';

class SvipEntryEvent {
  final UserModel user;
  final Map<String, dynamic>? entryEffect;
  final String? dedupKey;
  final bool suppressAnimation;

  const SvipEntryEvent({
    required this.user,
    this.entryEffect,
    this.dedupKey,
    this.suppressAnimation = false,
  });
}

class SvipEntryManager {
  static final SvipEntryManager _instance = SvipEntryManager._internal();
  factory SvipEntryManager() => _instance;
  SvipEntryManager._internal();

  final _eventController = StreamController<SvipEntryEvent>.broadcast();
  Stream<SvipEntryEvent> get onEntry => _eventController.stream;

  final Map<String, int> _lastShownEntryTimestamp = {};
  final Set<String> _playedRoomSessions = {};
  static const int _dedupWindowMs = 8000;

  bool hasPlayedForSession(String roomId, String userId) {
    if (roomId.isEmpty || userId.isEmpty) return false;
    return _playedRoomSessions.contains('${roomId}_$userId');
  }

  void markPlayedForSession(String roomId, String userId) {
    if (roomId.isNotEmpty && userId.isNotEmpty) {
      _playedRoomSessions.add('${roomId}_$userId');
    }
  }

  void clearSession(String roomId) {
    if (roomId.isNotEmpty) {
      _playedRoomSessions.removeWhere((k) => k.startsWith('${roomId}_'));
    }
  }

  bool isRecentlyShown(String userId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final key = userId.trim().toLowerCase();
    return _lastShownEntryTimestamp.containsKey(key) &&
        (now - _lastShownEntryTimestamp[key]! < _dedupWindowMs);
  }

  void showEntry(UserModel user, {Map<String, dynamic>? entryEffect, String? dedupKey, bool suppressAnimation = false}) {
    if (suppressAnimation) return;
    final hasVipOrNoble = user.isVip ||
        (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) ||
        (user.vipLevel.isNotEmpty && user.vipLevel != 'None') ||
        (entryEffect != null && entryEffect.isNotEmpty);
    if (!hasVipOrNoble) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _lastShownEntryTimestamp.removeWhere((_, ts) => now - ts > 30000);

    final key = (dedupKey != null && dedupKey.isNotEmpty)
        ? dedupKey.trim().toLowerCase()
        : (user.id.isNotEmpty ? user.id.trim().toLowerCase() : user.name.trim().toLowerCase());
    if (key.isNotEmpty) {
      if (_lastShownEntryTimestamp.containsKey(key)) {
        if (now - _lastShownEntryTimestamp[key]! < _dedupWindowMs) {
          return; // Suppress duplicate banner during reconnection or rapid events
        }
      }
      _lastShownEntryTimestamp[key] = now;
    }

    _eventController.add(SvipEntryEvent(
      user: user,
      entryEffect: entryEffect,
      dedupKey: dedupKey,
      suppressAnimation: suppressAnimation,
    ));
  }
}

class SvipEntryBanner extends StatefulWidget {
  const SvipEntryBanner({super.key});

  @override
  State<SvipEntryBanner> createState() => _SvipEntryBannerState();
}

class _SvipEntryBannerState extends State<SvipEntryBanner> with TickerProviderStateMixin {
  final List<SvipEntryEvent> _queue = [];
  SvipEntryEvent? _currentEvent;
  bool _isAnimating = false;
  late StreamSubscription _subscription;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.5, 0), end: Offset.zero).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _subscription = SvipEntryManager().onEntry.listen((event) {
      _queue.add(event);
      _processQueue();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _processQueue() async {
    if (_isAnimating || _queue.isEmpty) return;

    setState(() {
      _isAnimating = true;
      _currentEvent = _queue.removeAt(0);
    });

    await _slideController.forward();
    await Future.delayed(const Duration(seconds: 4));
    await _slideController.reverse();

    if (mounted) {
      setState(() {
        _currentEvent = null;
        _isAnimating = false;
      });
      _processQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEvent == null) return const SizedBox.shrink();

    final user = _currentEvent!.user;
    final effect = _currentEvent!.entryEffect;
    final effectName = effect?['name']?.toString();
    final effectMedia = effect?['thumbnailUrl']?.toString() ??
        effect?['mediaUrl']?.toString() ??
        effect?['iconUrl']?.toString() ??
        effect?['animationUrl']?.toString();

    final nobleTitle = (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) ? user.nobleTitle : null;
    final vipLevel = (user.vipLevel.isNotEmpty && user.vipLevel != 'None')
        ? user.vipLevel
        : null;
    final badgeAsset = NobleBadgeHelper.getBadgeAsset(nobleTitle ?? vipLevel);
    final tierLabel = effectName ?? nobleTitle ?? vipLevel ?? (user.isVip ? 'VIP' : 'Member');

    return IgnorePointer(
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFF57C00), Color(0xFFE64A19)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: UserAvatar(imageUrl: user.avatarUrl, radius: 10.5),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeAsset != null) ...[
                            Image.asset(
                              badgeAsset,
                              height: 11,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            tierLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.flash_on, color: Colors.white, size: 9),
                        ],
                      ),
                      NobleBadgeHelper.buildStyledUsername(
                        text: effectName != null && effectName.isNotEmpty
                            ? '${user.name} arrived in $effectName!'
                            : '${user.name} entered!',
                        nobleTitle: user.nobleTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (effectMedia != null && effectMedia.isNotEmpty)
                  effectMedia.startsWith('http')
                      ? Image.network(
                          effectMedia,
                          width: 20,
                          height: 15,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 13),
                        )
                      : Image.asset(
                          effectMedia,
                          width: 24,
                          height: 18,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 16),
                        )
                else
                  const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
