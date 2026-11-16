import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/utils/noble_badge_helper.dart';
import '../models/user_model.dart';
import 'svip_entry_banner.dart';
import 'user_avatar.dart';

/// ZP-BUG-014: Full-screen / Centered Animated SVIP VIP Vehicle Entry Overlay
/// Plays high-definition animated vehicle arrival (animated WebP or MP4 video)
/// centered on the live party room for all participants upon genuine room join.
class SvipVehicleEntryOverlay extends StatefulWidget {
  final String roomId;

  const SvipVehicleEntryOverlay({
    super.key,
    required this.roomId,
  });

  @override
  State<SvipVehicleEntryOverlay> createState() => _SvipVehicleEntryOverlayState();
}

class _SvipVehicleEntryOverlayState extends State<SvipVehicleEntryOverlay>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<SvipEntryEvent> _entrySub;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  SvipEntryEvent? _activeEvent;
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  Timer? _dismissTimer;

  static const List<double> _lumaKeyColorMatrix = <double>[
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    3.0, 3.0, 3.0, 0.0, -45.0,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Slide in from right (Offset(1.2, 0)), stay centered (Offset.zero), slide off to left (Offset(-1.2, 0))
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(1.2, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 64,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(-1.2, 0.0))
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
    ]).animate(_animController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 18,
      ),
    ]).animate(_animController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 18,
      ),
    ]).animate(_animController);

    _entrySub = SvipEntryManager().onEntry.listen(_handleEntryEvent);
  }

  void _handleEntryEvent(SvipEntryEvent event) {
    if (!mounted || event.suppressAnimation) return;

    final user = event.user;
    final effect = event.entryEffect;

    // Check if user is eligible for vehicle entry animation
    final hasVehiclePrivilege = user.svipLevel >= 3 ||
        user.isVip ||
        (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) ||
        (effect != null && effect.isNotEmpty);

    if (!hasVehiclePrivilege) return;

    // Resolve vehicle asset path
    final vehicleAsset = _resolveVehicleAsset(user, effect);
    if (vehicleAsset == null || vehicleAsset.isEmpty) return;

    _playVehicleAnimation(event, vehicleAsset);
  }

  String? _resolveVehicleAsset(UserModel user, Map<String, dynamic>? effect) {
    // 1. Explicit animation/video URL from entryEffect map
    if (effect != null) {
      final videoUrl = effect['videoUrl']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) return videoUrl;

      final animUrl = effect['animationUrl']?.toString() ??
          effect['mediaUrl']?.toString() ??
          effect['thumbnailUrl']?.toString();
      if (animUrl != null && animUrl.isNotEmpty) return animUrl;
    }

    // 2. SVIP Level vehicle mapping (SVIP 6+ luxury hypercar)
    final svipLvl = user.svipLevel;
    if (svipLvl >= 10) {
      return 'assets/svip/svip10_entry.webp';
    } else if (svipLvl >= 8) {
      return 'assets/svip/svip8_entry.webp';
    } else if (svipLvl >= 6) {
      return 'assets/svip/svip6_entry.webp';
    } else if (svipLvl >= 3) {
      return 'assets/svip/svip3_entry.webp';
    }

    // 3. Fallback for VIP / Nobles: default SVIP hypercar
    if (user.isVip || (user.nobleTitle != null && user.nobleTitle!.isNotEmpty)) {
      return 'assets/svip/svip6_entry.webp';
    }

    return null;
  }

  Future<void> _playVehicleAnimation(SvipEntryEvent event, String assetPath) async {
    // Stop any existing animation cleanly
    _dismissTimer?.cancel();
    _animController.stop();
    _videoController?.dispose();
    _videoController = null;

    final isMp4 = assetPath.toLowerCase().endsWith('.mp4');
    _isVideo = isMp4;

    if (isMp4) {
      try {
        if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(assetPath));
        } else {
          _videoController = VideoPlayerController.asset(assetPath);
        }
        await _videoController!.initialize();
        await _videoController!.play();
      } catch (_) {
        _isVideo = false;
        _videoController = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _activeEvent = event;
    });

    _animController.forward(from: 0.0);

    _dismissTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        setState(() {
          _activeEvent = null;
          _videoController?.dispose();
          _videoController = null;
          _isVideo = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _entrySub.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeEvent == null) return const SizedBox.shrink();

    final user = _activeEvent!.user;
    final effect = _activeEvent!.entryEffect;
    final effectName = effect?['name']?.toString() ??
        (user.svipLevel > 0 ? 'SVIP ${user.svipLevel} VIP Vehicle' : 'VIP Supercar');
    final vehicleAsset = _resolveVehicleAsset(user, effect) ?? 'assets/svip/svip6_entry.webp';

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Arrival Badge Header with User Identity
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFF8F00),
                            Color(0xFFFF6F00),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: Colors.white70, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: UserAvatar(imageUrl: user.avatarUrl, radius: 14),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.directions_car_filled_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      effectName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                NobleBadgeHelper.buildStyledUsername(
                                  text: user.displayName,
                                  nobleTitle: user.nobleTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Centered Vehicle Artwork / Video
                    SizedBox(
                      width: 340,
                      height: 240,
                      child: _isVideo && _videoController != null && _videoController!.value.isInitialized
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.matrix(_lumaKeyColorMatrix),
                              child: AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          : vehicleAsset.startsWith('http')
                              ? Image.network(
                                  vehicleAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/svip/svip6_entry.webp',
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Image.asset(
                                  vehicleAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/svip/svip6_vehicle.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                    ),
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
