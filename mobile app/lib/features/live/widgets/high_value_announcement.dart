import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/announcement_event.dart';
import '../../../widgets/user_avatar.dart';

class AnnouncementManager {
  static final AnnouncementManager _instance = AnnouncementManager._internal();
  factory AnnouncementManager() => _instance;
  AnnouncementManager._internal();

  final _eventController = StreamController<AnnouncementEvent>.broadcast();
  Stream<AnnouncementEvent> get onEvent => _eventController.stream;

  void showAnnouncement(AnnouncementEvent event) {
    _eventController.add(event);
  }
}

class HighValueAnnouncementOverlay extends StatefulWidget {
  const HighValueAnnouncementOverlay({super.key});

  @override
  State<HighValueAnnouncementOverlay> createState() => _HighValueAnnouncementOverlayState();
}

class _HighValueAnnouncementOverlayState extends State<HighValueAnnouncementOverlay> with TickerProviderStateMixin {
  final List<AnnouncementEvent> _queue = [];
  AnnouncementEvent? _currentEvent;
  bool _isAnimating = false;
  late StreamSubscription _subscription;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _subscription = AnnouncementManager().onEvent.listen((event) {
      if (event.amount >= 100000) {
        _queue.add(event);
        _processQueue();
      }
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

    setState(() {
      _currentEvent = null;
      _isAnimating = false;
    });

    _processQueue(); // Check if more are in queue
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEvent == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build the banner based on tier
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 60.h, left: 16.w, right: 16.w),
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildBanner(_currentEvent!, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(AnnouncementEvent event, bool isDark) {
    LinearGradient bgGradient;
    Color borderColor;
    
    switch (event.tier) {
      case AnnouncementTier.megaValue:
        bgGradient = const LinearGradient(colors: [Colors.purple, Colors.deepPurple, Colors.orange, Colors.yellow]);
        borderColor = Colors.yellowAccent;
        break;
      case AnnouncementTier.superValue:
        bgGradient = const LinearGradient(colors: [Colors.pinkAccent, Colors.purple, Colors.blue]);
        borderColor = Colors.pinkAccent;
        break;
      case AnnouncementTier.highValue:
        bgGradient = const LinearGradient(colors: [Color(0xFF0A1929), Color(0xFF0D47A1), Colors.purple]);
        borderColor = Colors.purpleAccent;
        break;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 70.h,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(35.r),
            border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              UserAvatar(imageUrl: event.avatarUrl, radius: 24.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          event.userName,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event.vipLevel > 0) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('VIP${event.vipLevel}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                          ),
                        ]
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      event.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.sp, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (event.iconAsset != null) ...[
                SizedBox(width: 8.w),
                Image.asset(event.iconAsset!, height: 40.r, width: 40.r, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.card_giftcard, color: Colors.white)),
              ]
            ],
          ),
        ),
        
        // Crown/Wings overlay effect for high tiers
        if (event.tier == AnnouncementTier.megaValue || event.tier == AnnouncementTier.superValue)
          Positioned(
            top: -30.h,
            child: Image.asset('assets/images/gift_gold_crown.jpg', height: 60.h, errorBuilder: (c,e,s) => Icon(Icons.emoji_events, color: Colors.amber, size: 50.h)),
          ),
      ],
    );
  }
}
