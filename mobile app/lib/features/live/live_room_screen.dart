import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/live_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_provider.dart';
import '../../widgets/gift_dialog.dart';
import '../games/rocket_game_sheet.dart';
import '../../widgets/svip_entry_banner.dart';
import '../party_room/widgets/room_info_sheet.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../pk_battle/pk_match_screen.dart';
import '../games/game_lobby_screen.dart';
import '../games/game_center_sheet.dart';
import 'widgets/high_value_announcement.dart';
import '../../widgets/emoji_reaction_overlay.dart';
import '../../widgets/emoji_picker_sheet.dart';
import '../../widgets/tiktok_gift_overlay.dart';
import '../../providers/emoji_reaction_provider.dart';
import '../../providers/live_gift_provider.dart';
import '../../core/services/room_share_service.dart';
import '../../core/services/agora_rtc_service.dart';
import '../../widgets/user_avatar.dart';

class FloatingHeart {
  final Key id;
  final Offset position;
  final Color color;

  FloatingHeart({required this.id, required this.position, required this.color});
}

class LiveRoomScreen extends StatefulWidget {
  final LiveRoomModel room;

  const LiveRoomScreen({super.key, required this.room});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final GlobalKey _hostAvatarKey = GlobalKey();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isMicMuted = false;

  Timer? _durationTimer;
  int _streamDurationSeconds = 0;

  final List<FloatingHeart> _hearts = [];
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey<GiftAnimationOverlayState>();

  void _toggleMic() {
    setState(() => _isMicMuted = !_isMicMuted);
    try {
      AgoraRtcService().muteLocalAudio(_isMicMuted);
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMicMuted ? 'Mic Muted 🔇' : 'Mic Live 🎙️'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  StreamSubscription? _socketLikeSub;

  @override
  void initState() {
    super.initState();
    _initLiveCamera();
    _startDurationTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().currentUser;
      final liveProv = context.read<LiveProvider>();
      liveProv.joinRoom(widget.room, currentUser: currentUser);
      context.read<LiveGiftProvider>().setActiveRoom(widget.room.id);
      final emojiProv = context.read<EmojiReactionProvider>();
      emojiProv.setActiveRoom(widget.room.id);
      emojiProv.registerAnchor('live_host_avatar', _hostAvatarKey);
      emojiProv.registerAnchor('user_${widget.room.host.id}', _hostAvatarKey);
      
      // Mock SVIP entry for demonstration
      emojiProv.registerAnchor('user_${currentUser.id}', _hostAvatarKey);

      _socketLikeSub = liveProv.onLikeReceived.listen((data) {
        final rand = Random();
        final dx = 180.0 + rand.nextDouble() * 120.0;
        final dy = 350.0 + rand.nextDouble() * 150.0;
        if (mounted) {
          _triggerFloatingHeartAt(Offset(dx, dy));
        }
      });

      if (currentUser.isVip) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            SvipEntryManager().showEntry(currentUser);
          }
        });
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _streamDurationSeconds++);
    });
  }

  Future<void> _initLiveCamera() async {
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      final isHost = (widget.room.host.id == currentUser.id) ||
          (widget.room.creatorUserId == currentUser.id) ||
          (currentUser.name.trim().isNotEmpty && currentUser.name.trim().toLowerCase() == widget.room.host.name.trim().toLowerCase()) ||
          (currentUser.username.trim().isNotEmpty && currentUser.username.trim().toLowerCase() == widget.room.host.username.trim().toLowerCase());

      // Guest viewers joining someone else's live stream should NOT have camera opened automatically
      if (!isHost) {
        if (mounted) setState(() => _isCameraInitialized = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      try {
        await [Permission.camera, Permission.microphone].request();
      } catch (_) {}

      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        int frontIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupCamera(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Live stream camera init safely skipped: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _setupCamera(CameraDescription desc) async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
        _cameraController = null;
      } catch (_) {}
    }
    try {
      final ctrl = CameraController(
        desc,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = ctrl;
      await ctrl.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Live camera setup error: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  void _switchCamera() async {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      setState(() => _isCameraInitialized = false);
      await _setupCamera(_cameras[_selectedCameraIndex]);
    }
  }

  void _triggerFloatingHeartAt(Offset position) {
    try {
      context.read<LiveProvider>().sendLike();
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rand = Random();
    final colors = isDark
        ? [AppColors.live, AppColors.warmGold, AppColors.lightGold, AppColors.metallicGold, AppColors.goldHighlight]
        : [AppColors.live, AppColors.royalBlue, AppColors.lightBlue, AppColors.metallicBlue, AppColors.cyan];

    final heart = FloatingHeart(
      id: UniqueKey(),
      position: position,
      color: colors[rand.nextInt(colors.length)],
    );

    setState(() {
      _hearts.add(heart);
      if (_hearts.length > 20) _hearts.removeAt(0);
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.id == heart.id);
        });
      }
    });
  }

  void _triggerFloatingHeart() {
    _triggerFloatingHeartAt(const Offset(250, 450));
  }

  Widget _buildLiveHostBackground(bool isDark) {
    final bgUrl = widget.room.coverUrl.isNotEmpty
        ? widget.room.coverUrl
        : widget.room.host.avatarUrl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF161129), Color(0xFF0D0A18), Color(0xFF050508)]
              : const [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF020617)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background cover / host avatar image
          if (bgUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.45,
                child: bgUrl.startsWith('http')
                    ? Image.network(
                        bgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.black26),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              (isDark ? AppColors.warmGold : AppColors.royalBlue).withValues(alpha: 0.3),
                              Colors.black,
                            ],
                          ),
                        ),
                      ),
              ),
            ),

          // Glowing radial center highlight
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.warmGold : AppColors.royalBlue).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Host Avatar & Live status centerpiece
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark ? AppColors.metallicGoldGradient : AppColors.metallicBlueGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.metallicGold : AppColors.royalBlue).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    imageUrl: widget.room.host.avatarUrl,
                    name: widget.room.host.name,
                    radius: 48,
                    isLive: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.room.host.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.room.roomType == 'AUDIO_PARTY' ? 'VOICE PARTY LIVE' : 'LIVE BROADCASTING',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socketLikeSub?.cancel();
    _durationTimer?.cancel();
    _cameraController?.dispose();
    _chatController.dispose();
    try {
      context.read<LiveProvider>().leaveRoom();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveProvider = context.watch<LiveProvider>();
    final activeRoom = liveProvider.activeRoom ?? widget.room;
    final activeGift = liveProvider.activeGiftAnimation;

    return Scaffold(
      body: Stack(
        children: [
          // Background Stream (Camera preview or Cover Image/Live Host fallback)
          Positioned.fill(
            child: _isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 1,
                      height: _cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                : _buildLiveHostBackground(isDark),
          ),

          // Double Tap Screen for Like Hearts
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (details) {
                AuthGuard.require(context, () {
                  _triggerFloatingHeartAt(details.localPosition);
                }, reason: 'Sign in to send like hearts');
              },
              onDoubleTap: () {},
            ),
          ),

          // Dark Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.6),
                      AppColors.transparent,
                      AppColors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Gift Animated Overlay
          if (activeGift != null) const GiftAnimationOverlay(),

          // High Value Announcement Overlay
          const HighValueAnnouncementOverlay(),
          const SvipEntryBanner(),

          // Realtime Animated Emoji Reaction Overlay
          EmojiReactionOverlay(roomId: widget.room.id),

          // TikTok-Style Live Gifting Animation Overlay
          TikTokGiftOverlay(roomId: widget.room.id),

          // Floating Hearts Stack
          for (final heart in _hearts)
            Positioned(
              key: heart.id,
              left: heart.position.dx - 20,
              top: heart.position.dy - 40,
              child: _AnimatedFloatingHeart(color: heart.color),
            ),

          // Header Overlay Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Room Profile Area (Avatar, Name, ID)
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => RoomInfoSheet(
                                room: widget.room,
                                canManage: widget.room.host.id == context.read<AuthProvider>().currentUser.id,
                                isDark: isDark,
                                participants: null, // liveProvider doesn't have participants yet
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                key: _hostAvatarKey,
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.room.coverUrl,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 34, height: 34, color: Colors.grey,
                                    child: const Icon(Icons.music_note, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.room.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ID:${widget.room.id.length > 8 ? widget.room.id.substring(0, 8) : widget.room.id}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Follow Button (Small Purple Pill)
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final isFollowing = auth.isFollowing(widget.room.host.id);
                          return GestureDetector(
                            onTap: () {
                              AuthGuard.require(context, () {
                                auth.toggleFollow(widget.room.host.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(!isFollowing ? '✔ Following ${widget.room.host.name}!' : 'Unfollowed ${widget.room.host.name}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }, reason: 'Sign in to follow hosts');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isFollowing ? AppColors.liveGreen : const Color(0xFF9B51E0),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isFollowing ? Icons.check_rounded : Icons.add_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 6),

                      // Right Controls (Viewers, Likes, Trophy, Settings, Close)
                      Flexible(
                        fit: FlexFit.loose,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Viewers, Likes & Trophy Badges
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    '${activeRoom.viewerCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 14),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    liveProvider.likeCountFormatted,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 14),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    liveProvider.pointsFormatted,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              
                              // Settings (if authorized)
                              if (widget.room.host.id == context.read<AuthProvider>().currentUser.id)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _showRoomTools(context, isDark),
                                    child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                                  ),
                                ),
                                
                              // Switch Camera
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: _switchCamera,
                                  child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
                                ),
                              ),

                              // Close
                              GestureDetector(
                                onTap: () {
                                  context.read<LiveProvider>().leaveRoom();
                                  Navigator.pop(context);
                                },
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Side Floating Quick-Access Icons
          Positioned(
            right: 16,
            bottom: 270,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  clipBehavior: Clip.none,
                  children: [
                    _buildQuickActionBtn(
                      isDark,
                      Icons.card_giftcard_rounded,
                      liveProvider.luckyBagActive ? 'Claim!' : 'Lucky',
                      liveProvider.luckyBagActive ? Colors.orangeAccent : AppColors.liveRed,
                      onTap: () => _showLuckyBagQuickActionDialog(context, isDark, liveProvider),
                    ),
                    if (liveProvider.luckyBagActive)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('🎁 Active', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildQuickActionBtn(
                  isDark,
                  Icons.rocket_launch_rounded,
                  'Rocket',
                  Colors.purpleAccent,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const RocketGameSheet(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionBtn(
                  isDark,
                  Icons.videogame_asset_rounded,
                  'Games',
                  AppColors.cyan,
                  onTap: () {
                    GameCenterSheet.show(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionBtn(
                  isDark,
                  Icons.home_rounded,
                  'Room',
                  AppColors.getPrimary(isDark),
                  onTap: () => _showRoomDetailsSheet(context, isDark),
                ),
                const SizedBox(height: 12),
                _buildQuickActionBtn(
                  isDark,
                  Icons.share_rounded,
                  'Share',
                  Colors.white,
                  onTap: () {
                    RoomShareService.shareRoom(
                      context,
                      roomId: widget.room.id,
                      roomTitle: widget.room.title,
                      isParty: false,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionBtn(isDark, Icons.more_horiz_rounded, 'More', Colors.white, onTap: () {
                  // Phase 6: Room Tools panel
                  _showRoomTools(context, isDark);
                }),
              ],
            ),
          ),

          // Bottom Live Chat & Actions Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Messages List
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        reverse: true,
                        itemCount: liveProvider.messages.length,
                        itemBuilder: (context, index) {
                          final msg = liveProvider.messages.reversed.toList()[index];
                          final isSystem = msg.sender == 'System';
                          final isGift = msg.isGift;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isGift
                                  ? const Color(0xFFE91E63).withValues(alpha: 0.28)
                                  : (isSystem
                                      ? const Color(0xFFFF9800).withValues(alpha: 0.18)
                                      : Colors.black.withValues(alpha: 0.55)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isGift
                                    ? const Color(0xFFFF4081).withValues(alpha: 0.45)
                                    : (isSystem
                                        ? const Color(0xFFFFB74D).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.08)),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (msg.avatarUrl != null && msg.avatarUrl!.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      msg.avatarUrl!,
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 14, color: Colors.white70),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${msg.sender}: ',
                                          style: TextStyle(
                                            color: isSystem
                                                ? const Color(0xFFFFD54F)
                                                : (isGift ? const Color(0xFFFF80AB) : (isDark ? AppColors.warmGold : AppColors.lightBlue)),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: msg.text,
                                          style: TextStyle(
                                            color: isGift ? const Color(0xFFFFF176) : Colors.white,
                                            fontWeight: isGift ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Actions Bar (WhatsApp Toolbar Layout matching reference image)
                    Row(
                      children: [
                        // Far Left: Standalone "+" Button
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 28),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF1E1B2E),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                              builder: (bCtx) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Wrap(
                                    spacing: 20,
                                    runSpacing: 20,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.rocket_launch_rounded, color: Colors.indigoAccent, size: 28),
                                        onPressed: () {
                                          Navigator.pop(bCtx);
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) => const RocketGameSheet(),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.card_giftcard_rounded, color: Colors.pinkAccent, size: 28),
                                        onPressed: () {
                                          Navigator.pop(bCtx);
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: AppColors.transparent,
                                            builder: (c) {
                                              final currentUser = context.read<AuthProvider>().currentUser;
                                              final effectiveHost = (widget.room.host.id == currentUser.id && currentUser.avatarUrl.isNotEmpty)
                                                  ? widget.room.host.copyWith(avatarUrl: currentUser.avatarUrl, name: currentUser.name)
                                                  : widget.room.host;
                                              return GiftDialog(
                                                streamerName: effectiveHost.name,
                                                targetReceiver: effectiveHost,
                                                onGiftSent: (gift) {
                                                  liveProvider.sendGift(gift, currentUser.name);
                                                  _giftOverlayKey.currentState?.playGiftAnimation(gift, senderName: currentUser.name);
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.sports_esports_rounded, color: Colors.amber, size: 28),
                                        onPressed: () {
                                          Navigator.pop(bCtx);
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLobbyScreen()));
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.flash_on_rounded, color: Colors.deepOrangeAccent, size: 28),
                                        onPressed: () {
                                          Navigator.pop(bCtx);
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PkMatchScreen()));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 10),

                        // Center: WhatsApp Dark Pill Input Field
                        Expanded(
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _chatController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    cursorColor: Colors.white,
                                    decoration: InputDecoration(
                                      hintText: 'Say something...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 14,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onSubmitted: (_) {
                                       if (_chatController.text.isNotEmpty) {
                                         final currentUser = context.read<AuthProvider>().currentUser;
                                         final text = _chatController.text.trim();
                                         liveProvider.sendMessage(text, currentUser.name);
                                         context.read<EmojiReactionProvider>().sendReaction(
                                           roomId: widget.room.id,
                                           senderId: currentUser.id,
                                           emoji: text,
                                           senderName: currentUser.name,
                                         );
                                         _chatController.clear();
                                       }
                                     },
                                     onChanged: (val) {
                                       if (mounted) setState(() {});
                                     },
                                  ),
                                ),
                                 _chatController.text.isNotEmpty
                                     ? GestureDetector(
                                         onTap: () {
                                           final currentUser = context.read<AuthProvider>().currentUser;
                                           final text = _chatController.text.trim();
                                           if (text.isNotEmpty) {
                                             liveProvider.sendMessage(text, currentUser.name);
                                             _chatController.clear();
                                             if (mounted) setState(() {});
                                           }
                                         },
                                         child: const Padding(
                                           padding: EdgeInsets.symmetric(horizontal: 4),
                                           child: Icon(Icons.send_rounded, color: Color(0xFFFF416C), size: 20),
                                         ),
                                       )
                                     : IconButton(
                                         icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.amber, size: 22),
                                         onPressed: () {
                                           AuthGuard.require(context, () {
                                             EmojiPickerSheet.show(context, onEmojiSelected: (emoji) {
                                               final currentUser = context.read<AuthProvider>().currentUser;
                                               liveProvider.sendMessage(emoji, currentUser.name);
                                               context.read<EmojiReactionProvider>().sendReaction(
                                                 roomId: widget.room.id,
                                                 senderId: currentUser.id,
                                                 emoji: emoji,
                                                 senderName: currentUser.name,
                                               );
                                             });
                                           }, reason: 'Sign in to send reactions');
                                         },
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                         tooltip: 'Emojis & Reactions',
                                       ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Far Right Action Icons (Gift & Like Heart)
                        IconButton(
                          icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 25),
                          onPressed: () {
                            AuthGuard.require(context, () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: AppColors.transparent,
                                builder: (c) {
                                  final currentUser = context.read<AuthProvider>().currentUser;
                                  final effectiveHost = (widget.room.host.id == currentUser.id && currentUser.avatarUrl.isNotEmpty)
                                      ? widget.room.host.copyWith(avatarUrl: currentUser.avatarUrl, name: currentUser.name)
                                      : widget.room.host;
                                  return GiftDialog(
                                    streamerName: effectiveHost.name,
                                    targetReceiver: effectiveHost,
                                    onGiftSent: (gift) {
                                      liveProvider.sendGift(gift, currentUser.name);
                                      _giftOverlayKey.currentState?.playGiftAnimation(gift, senderName: currentUser.name);
                                    },
                                  );
                                },
                              );
                            }, reason: 'Sign in to send gifts');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),

                        IconButton(
                          icon: Icon(
                            _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: _isMicMuted ? Colors.redAccent : const Color(0xFF00E676),
                            size: 25,
                          ),
                          onPressed: _toggleMic,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Microphone Toggle',
                        ),
                        const SizedBox(width: 12),

                        IconButton(
                          icon: const Icon(Icons.favorite_outline_rounded, color: Colors.white, size: 26),
                          onPressed: () {
                            AuthGuard.require(context, () {
                              _triggerFloatingHeart();
                            }, reason: 'Sign in to send likes');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Onscreen 3D Gift Animation Overlay
          GiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(bool isDark, IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showRoomTools(BuildContext context, bool isDark) {
    final liveProvider = context.read<LiveProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Text('Room Tools', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  // ── YouTube ──────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.play_circle_fill_rounded,
                    label: 'YouTube',
                    color: Colors.red,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      showDialog(
                        context: context,
                        builder: (d) {
                          final ctrl = TextEditingController();
                          return AlertDialog(
                            backgroundColor: AppColors.getCard(isDark),
                            title: Text('Share YouTube', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                            content: TextField(
                              controller: ctrl,
                              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                              decoration: InputDecoration(
                                hintText: 'Paste YouTube URL...',
                                hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                                filled: true,
                                fillColor: AppColors.getBackground(isDark),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  Navigator.pop(d);
                                  if (ctrl.text.isNotEmpty) {
                                    liveProvider.sendMessage('Sharing video: ${ctrl.text}', 'Host');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('YouTube video shared with viewers!')),
                                    );
                                  }
                                },
                                child: const Text('Share', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  // ── Super Wheel ───────────────────────────────────
                  _buildToolItem(
                    icon: Icons.casino_rounded,
                    label: 'Super Wheel',
                    color: Colors.purple,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      final participants = ['Sophia', 'Alex', 'Elena', 'Marcus', 'Zayn', 'Aisha'];
                      showDialog(
                        context: context,
                        builder: (d) => AlertDialog(
                          backgroundColor: AppColors.getCard(isDark),
                          title: Row(children: [
                            const Icon(Icons.casino_rounded, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text('Super Wheel', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                          ]),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Spin to pick a random winner from ${participants.length} viewers!',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                              const SizedBox(height: 16),
                              const Icon(Icons.rotate_right_rounded, size: 64, color: Colors.purple),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                              onPressed: () {
                                Navigator.pop(d);
                                liveProvider.spinSuperWheel(participants);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Spinning the wheel for ${participants.length} participants...'),
                                    backgroundColor: Colors.purple,
                                  ),
                                );
                              },
                              child: const Text('Spin!', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Lucky Bag ─────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Lucky Bag',
                    color: Colors.orange,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      final amounts = [50, 100, 200, 500, 1000];
                      int selected = 100;
                      showDialog(
                        context: context,
                        builder: (d) => StatefulBuilder(
                          builder: (d, setSt) => AlertDialog(
                            backgroundColor: AppColors.getCard(isDark),
                            title: Row(children: [
                              const Icon(Icons.card_giftcard_rounded, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('Lucky Bag', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                            ]),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Choose diamond amount to drop:', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: amounts.map((a) => GestureDetector(
                                    onTap: () => setSt(() => selected = a),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: selected == a ? Colors.orange : Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text('$a', style: TextStyle(
                                        color: selected == a ? Colors.white : AppColors.getTextPrimary(isDark),
                                        fontWeight: FontWeight.bold,
                                      )),
                                    ),
                                  )).toList(),
                                ),
                                const SizedBox(height: 12),
                                Row(children: [
                                  const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 16),
                                  const SizedBox(width: 4),
                                  Text('$selected diamonds for 12 seconds', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                                ]),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () {
                                  Navigator.pop(d);
                                  liveProvider.startLuckyBag(selected);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lucky Bag dropped! $selected diamonds available!'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                                child: const Text('Drop Bag!', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // ── Music ─────────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.music_note_rounded,
                    label: 'Music',
                    color: Colors.blue,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      final tracks = [
                        'Chill Lofi Beats',
                        'Party Anthem Mix',
                        'Romantic Piano',
                        'Hip-Hop Vibes',
                        'Electronic Dance',
                        'Nature Sounds',
                      ];
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.getCard(isDark),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (m) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Background Music', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Current: ${liveProvider.isMusicPlaying ? liveProvider.currentMusicTrack! : "Off"}',
                                    style: TextStyle(color: Colors.blue, fontSize: 12)),
                                const SizedBox(height: 12),
                                ...tracks.map((t) => ListTile(
                                  leading: Icon(Icons.music_note_rounded, color: liveProvider.currentMusicTrack == t ? Colors.blue : Colors.grey),
                                  title: Text(t, style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                                  trailing: liveProvider.currentMusicTrack == t
                                      ? const Icon(Icons.equalizer_rounded, color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(m);
                                    liveProvider.playMusic(t);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Now playing: $t'), backgroundColor: Colors.blue),
                                    );
                                  },
                                )),
                                if (liveProvider.isMusicPlaying)
                                  ListTile(
                                    leading: const Icon(Icons.stop_rounded, color: Colors.red),
                                    title: const Text('Stop Music', style: TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(m);
                                      liveProvider.stopMusic();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ── PK ────────────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.sports_esports_rounded,
                    label: 'PK',
                    color: Colors.cyan,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PkMatchScreen()));
                    },
                  ),

                  // ── Settings ──────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    color: Colors.grey,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      showDialog(
                        context: context,
                        builder: (d) {
                          bool allowComments = true;
                          bool showGiftAnimations = true;
                          return StatefulBuilder(
                            builder: (d, setSt) => AlertDialog(
                              backgroundColor: AppColors.getCard(isDark),
                              title: Row(children: [
                                const Icon(Icons.settings_rounded, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('Live Settings', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                              ]),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile(
                                    title: Text('Allow Comments', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                                    value: allowComments,
                                    activeThumbColor: AppColors.getPrimary(isDark),
                                    onChanged: (v) => setSt(() => allowComments = v),
                                  ),
                                  SwitchListTile(
                                    title: Text('Gift Animations', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                                    value: showGiftAnimations,
                                    activeThumbColor: AppColors.getPrimary(isDark),
                                    onChanged: (v) => setSt(() => showGiftAnimations = v),
                                  ),
                                  ListTile(
                                    title: Text('Stream Quality', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                                    trailing: const Text('HD', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.getPrimary(isDark)),
                                  onPressed: () {
                                    Navigator.pop(d);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Settings saved!')),
                                    );
                                  },
                                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // ── Clear Chat ────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.clear_all_rounded,
                    label: 'Clear Chat',
                    color: Colors.amber,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      showDialog(
                        context: context,
                        builder: (d) => AlertDialog(
                          backgroundColor: AppColors.getCard(isDark),
                          title: Text('Clear Chat?', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                          content: Text('This will remove all messages from the live chat.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                              onPressed: () {
                                Navigator.pop(d);
                                liveProvider.clearMessages();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chat cleared!')),
                                );
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Lock Room ─────────────────────────────────────
                  _buildToolItem(
                    icon: liveProvider.isRoomLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    label: liveProvider.isRoomLocked ? 'Unlock Room' : 'Lock Room',
                    color: Colors.redAccent,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      liveProvider.toggleRoomLock();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(liveProvider.isRoomLocked
                              ? 'Room locked. No new viewers can join.'
                              : 'Room unlocked.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    },
                  ),

                  // ── Mic Stats ─────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.mic_rounded,
                    label: 'Mic Stats',
                    color: Colors.green,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      final lp = context.read<LiveProvider>();
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.getCard(isDark),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (m) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mic Status', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                ...['Host Mic', 'Seat 1', 'Seat 2', 'Seat 3', 'Seat 4'].asMap().entries.map((e) {
                                  final isOn = e.key == 0;
                                  return ListTile(
                                    leading: Icon(isOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: isOn ? Colors.green : Colors.red),
                                    title: Text(e.value, style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOn ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(isOn ? 'ON' : 'OFF', style: TextStyle(color: isOn ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.mic_off_rounded),
                                    label: const Text('Mute All'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                      Navigator.pop(m);
                                      lp.sendMessage('Host muted all microphones.', 'System');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('All mics muted!')),
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

                  // ── Effects ───────────────────────────────────────
                  _buildToolItem(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Effects',
                    color: Colors.pink,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      final effects = ['None', 'Beauty', 'Blur BG', 'Vintage', 'Neon Glow', 'Black & White'];
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.getCard(isDark),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (m) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Visual Effects', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Active: ${liveProvider.activeEffect}', style: const TextStyle(color: Colors.pink, fontSize: 12)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: effects.map((ef) => GestureDetector(
                                    onTap: () {
                                      liveProvider.setEffect(ef);
                                      Navigator.pop(m);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Effect applied: $ef'), backgroundColor: Colors.pink),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: liveProvider.activeEffect == ef
                                            ? Colors.pink
                                            : Colors.pink.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.pink.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(ef, style: TextStyle(
                                        color: liveProvider.activeEffect == ef ? Colors.white : AppColors.getTextPrimary(isDark),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      )),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLuckyBagQuickActionDialog(BuildContext context, bool isDark, LiveProvider liveProvider) {
    if (liveProvider.luckyBagActive) {
      // Claim if active
      final randomDiamonds = 5 + Random().nextInt(15);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Claimed $randomDiamonds diamonds from the Lucky Bag!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amounts = [50, 100, 200, 500, 1000];
    int selected = 100;
    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setSt) => AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          title: Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Lucky Bag', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose diamond amount to drop:', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: amounts.map((a) => GestureDetector(
                  onTap: () => setSt(() => selected = a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected == a ? Colors.orange : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('$a', style: TextStyle(
                      color: selected == a ? Colors.white : AppColors.getTextPrimary(isDark),
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 4),
                  Text('$selected diamonds for 12 seconds', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(d);
                liveProvider.startLuckyBag(selected);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lucky Bag dropped! $selected diamonds available! 🎁'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Drop Bag!', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDetailsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Room Details', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.live_tv_rounded, color: AppColors.getPrimary(isDark)),
                title: Text(widget.room.title, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${widget.room.id} • Host: ${widget.room.host.name}', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed_rounded, color: Colors.green),
                title: Text('Stream Quality & Latency', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                subtitle: const Text('Quality: Ultra HD (1080p) • Ping: 18ms (Stable)', style: TextStyle(color: Colors.green)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_rounded, color: Colors.blue),
                title: Text('Viewer Occupancy', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
                subtitle: Text('${widget.room.viewerCount} concurrent viewers online', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getPrimary(isDark),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon, 
    required String label, 
    required Color color, 
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 11)),
        ],
      ),
    );
  }
}

class _AnimatedFloatingHeart extends StatefulWidget {
  final Color color;

  const _AnimatedFloatingHeart({required this.color});

  @override
  State<_AnimatedFloatingHeart> createState() => _AnimatedFloatingHeartState();
}

class _AnimatedFloatingHeartState extends State<_AnimatedFloatingHeart> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _translateY = Tween<double>(begin: 0, end: -200).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale = Tween<double>(begin: 0.6, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Icon(Icons.favorite_rounded, color: widget.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
