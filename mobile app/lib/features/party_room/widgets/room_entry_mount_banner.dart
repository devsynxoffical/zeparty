import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/privacy_settings_provider.dart';
import '../../../../widgets/user_avatar.dart';

class RoomEntryBannerItem {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String mountTitle; // e.g. "Phantom Dragon Mount 🐉", "SVIP 11 Noble Phantom 👑", "CP Pair Arrival 💕"
  final String? partnerAvatar;
  final String? partnerName;
  final Color glowColor;
  final bool isStealthMode;

  const RoomEntryBannerItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.mountTitle,
    this.partnerAvatar,
    this.partnerName,
    this.glowColor = Colors.amberAccent,
    this.isStealthMode = false,
  });
}

class RoomEntryMountBannerWidget extends StatefulWidget {
  final String roomId;
  final RoomEntryBannerItem? currentBanner;
  final VoidCallback? onBannerComplete;

  const RoomEntryMountBannerWidget({
    super.key,
    required this.roomId,
    this.currentBanner,
    this.onBannerComplete,
  });

  @override
  State<RoomEntryMountBannerWidget> createState() => _RoomEntryMountBannerWidgetState();
}

class _RoomEntryMountBannerWidgetState extends State<RoomEntryMountBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide in from right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    if (widget.currentBanner != null) {
      _triggerBanner(widget.currentBanner!);
    }
  }

  @override
  void didUpdateWidget(covariant RoomEntryMountBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentBanner != null && widget.currentBanner != oldWidget.currentBanner) {
      _triggerBanner(widget.currentBanner!);
    }
  }

  void _triggerBanner(RoomEntryBannerItem item) {
    // Check Stealth Room Entry Privacy Setting
    final privacy = context.read<PrivacySettingsProvider>();
    if (item.isStealthMode || privacy.stealthRoomEntry) {
      // Suppress banner and sound for stealth room entry
      widget.onBannerComplete?.call();
      return;
    }

    _animController.forward(from: 0.0);

    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        await _animController.reverse();
        widget.onBannerComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.currentBanner;
    final privacy = context.watch<PrivacySettingsProvider>();

    if (item == null || item.isStealthMode || privacy.stealthRoomEntry) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.glowColor.withValues(alpha: 0.8),
                const Color(0xFF1E1035),
                const Color(0xFF0F081D),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: item.glowColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: item.glowColor.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Dual Avatars for CP Pair or Single Avatar with Mount Frame
              if (item.partnerAvatar != null)
                SizedBox(
                  width: 50,
                  height: 32,
                  child: Stack(
                    children: [
                      Positioned(left: 0, child: UserAvatar(imageUrl: item.userAvatar, radius: 16)),
                      Positioned(right: 0, child: UserAvatar(imageUrl: item.partnerAvatar!, radius: 16)),
                    ],
                  ),
                )
              else
                UserAvatar(imageUrl: item.userAvatar, radius: 18, showVipFrame: true),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.partnerName != null ? '${item.userName} & ${item.partnerName}' : item.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ARRIVED',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.mountTitle,
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Animated Glow Crest
              const Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
