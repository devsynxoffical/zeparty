import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/live_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_provider.dart';
import '../../providers/room_overlay_provider.dart';
import '../../widgets/animated_live_comment_item.dart';
import '../../widgets/gift_dialog.dart';
import '../games/rocket_game_sheet.dart';
import '../../widgets/svip_entry_banner.dart';
import '../party_room/widgets/room_info_sheet.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../pk_battle/pk_match_screen.dart';
import '../pk_battle/pk_battle_screen.dart';
import '../../models/pk_battle_model.dart';
import '../../core/services/api_client.dart';
import '../../core/services/socket_service.dart';
import '../games/game_lobby_screen.dart';
import '../games/game_center_sheet.dart';
import '../../widgets/emoji_reaction_overlay.dart';
import '../../widgets/tiktok_user_join_banner.dart';
import '../../widgets/emoji_picker_sheet.dart';
import '../../widgets/tiktok_gift_overlay.dart';
import 'widgets/high_value_announcement.dart';
import '../../providers/emoji_reaction_provider.dart';
import '../../providers/live_gift_provider.dart';
import '../../core/services/room_share_service.dart';
import '../../core/services/agora_rtc_service.dart';
import '../../widgets/user_avatar.dart';
import '../../models/party_participant_model.dart';
import 'widgets/live_viewers_sheet.dart';

class FloatingHeart {
  final Key id;
  final Offset position;
  final Color color;

  FloatingHeart({required this.id, required this.position, required this.color});
}

class LiveRoomScreen extends StatefulWidget {
  final LiveRoomModel room;
  final bool isHost;

  const LiveRoomScreen({super.key, required this.room, this.isHost = false});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final GlobalKey _hostAvatarKey = GlobalKey();
  int? _remoteHostUid;

  Timer? _durationTimer;
  int _streamDurationSeconds = 0;

  final List<FloatingHeart> _hearts = [];
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey<GiftAnimationOverlayState>();

  StreamSubscription? _socketLikeSub;
  StreamSubscription? _remoteUsersSub;
  StreamSubscription? _firstFrameSub;
  StreamSubscription? _kickedSub;
  StreamSubscription? _pkInviteSub;
  StreamSubscription? _pkStartedSub;
  StreamSubscription? _roomClosedSub;
  StreamSubscription? _liveProvClosedSub;
  bool _isEndedDialogShown = false;

  late AnimationController _vsPulseController;
  late Animation<double> _vsScale;

  void _handleStreamEnded([String? reason]) {
    if (_isEndedDialogShown || !mounted) return;
    _isEndedDialogShown = true;

    try {
      context.read<LiveProvider>().leaveRoom();
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Live Ended',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              imageUrl: widget.room.host.avatarUrl,
              name: widget.room.host.name,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              widget.room.host.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              reason != null && reason.isNotEmpty
                  ? reason
                  : 'The host has ended this live broadcast.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.live,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Back to Discover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMic() {
    final liveProv = context.read<LiveProvider>();
    if (liveProv.isRoomMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Room microphone is currently locked by admin moderation.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nowMuted = liveProv.toggleLocalMic();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowMuted ? 'Mic Muted 🔇' : 'Mic Live 🎙️'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _switchCamera() {
    AgoraRtcService().switchCamera();
  }

  @override
  void initState() {
    super.initState();
    _startDurationTimer();

    _vsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _vsScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _vsPulseController, curve: Curves.easeInOut),
    );

    // Listen to remote host video stream arrival for audience viewers
    _remoteUsersSub = AgoraRtcService().remoteUsersStream.listen((uids) {
      if (!mounted) return;
      if (uids.isNotEmpty) {
        setState(() {
          _remoteHostUid = uids.first;
        });
      } else if (!widget.isHost && _remoteHostUid != null) {
        _handleStreamEnded('The host has disconnected from the live broadcast.');
      }
    });

    _firstFrameSub = AgoraRtcService().firstRemoteVideoFrameStream.listen((uid) {
      if (mounted) {
        setState(() {
          _remoteHostUid = uid;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().currentUser;
      final liveProv = context.read<LiveProvider>();
      if (liveProv.activeRoom?.id != widget.room.id) {
        liveProv.joinRoom(widget.room, currentUser: currentUser);
      }
      context.read<LiveGiftProvider>().setActiveRoom(widget.room.id);
      final emojiProv = context.read<EmojiReactionProvider>();
      emojiProv.setActiveRoom(widget.room.id);
      emojiProv.registerAnchor('live_host_avatar', _hostAvatarKey);
      emojiProv.registerAnchor('user_${widget.room.host.id}', _hostAvatarKey);
      
      // Mock SVIP entry for demonstration
      emojiProv.registerAnchor('user_${currentUser.id}', _hostAvatarKey);

      _liveProvClosedSub = liveProv.onRoomClosed.listen((data) {
        if (!widget.isHost && mounted) {
          _handleStreamEnded(data['reason']?.toString());
        }
      });

      _roomClosedSub = SocketService.instance.roomClosedStream.listen((data) {
        if (!widget.isHost && mounted) {
          _handleStreamEnded(data['reason']?.toString());
        }
      });

      _socketLikeSub = liveProv.onLikeReceived.listen((data) {
        final rand = Random();
        final dx = 180.0 + rand.nextDouble() * 120.0;
        final dy = 350.0 + rand.nextDouble() * 150.0;
        if (mounted) {
          _showFloatingHeartAnimation(Offset(dx, dy));
        }
      });

      _kickedSub = liveProv.onKickedReceived.listen((reason) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              title: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Room Alert', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Text(
                reason.isNotEmpty ? reason : 'You were removed from this room by the host.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('OK', style: TextStyle(color: AppColors.live)),
                ),
              ],
            ),
          );
        }
      });

      _pkInviteSub = liveProv.onPkInvitationReceived.listen((data) {
        if (!mounted) return;
        final inviterUser = data['inviterUser'] is Map ? Map<String, dynamic>.from(data['inviterUser']) : {};
        final inviterName = inviterUser['name'] ?? inviterUser['displayName'] ?? inviterUser['username'] ?? 'Live Host';
        final inviterAvatar = inviterUser['avatarUrl'] ?? '';
        final invitationId = data['invitationId'] ?? data['id'] ?? '';
        _showIncomingPKInvitationDialog(invitationId.toString(), inviterName.toString(), inviterAvatar.toString());
      });

      _pkStartedSub = SocketService.instance.onPkStarted.listen((data) {
        if (!mounted) return;
        try {
          final pk = PKBattleModel.fromJson(data);
          liveProv.setPkBattle(pk);
        } catch (e) {
          debugPrint('[LiveRoomScreen] PK Started parse error: $e');
        }
      });

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentUser.isVip || (currentUser.nobleTitle != null && currentUser.nobleTitle!.isNotEmpty)) {
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

  /// Displays floating heart animation locally without sending network events
  void _showFloatingHeartAnimation(Offset position) {
    if (!mounted) return;
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

  /// Sends 1 like and renders floating heart for local user
  void _sendLikeWithHeart([Offset? position]) {
    try {
      context.read<LiveProvider>().sendLike(count: 1);
    } catch (_) {}
    _showFloatingHeartAnimation(position ?? const Offset(250, 450));
  }

  void _triggerFloatingHeartAt(Offset position) => _sendLikeWithHeart(position);
  void _triggerFloatingHeart() => _sendLikeWithHeart(const Offset(250, 450));

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

  Widget _buildVideoStream(bool isDark, bool isHost, LiveRoomModel activeRoom) {
    final liveProv = context.watch<LiveProvider>();
    final pk = liveProv.activePkBattle;

    if (pk != null && !pk.isEnded) {
      return _buildPkSplitVideoStream(isDark, isHost, activeRoom, pk);
    }

    final agora = AgoraRtcService.instance;

    if (isHost) {
      if (agora.engine != null) {
        agora.startPreview();
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: agora.engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      }
    } else {
      // Audience Viewer
      final targetUid = _remoteHostUid ?? (agora.remoteUids.isNotEmpty ? agora.remoteUids.first : null);
      if (agora.engine != null && targetUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: agora.engine!,
            canvas: VideoCanvas(uid: targetUid),
            connection: RtcConnection(channelId: activeRoom.agoraChannelName ?? activeRoom.id),
          ),
        );
      }
    }

    // Fallback if video is connecting or audio-only
    return _buildLiveHostBackground(isDark);
  }

  /// TikTok-Style Side-by-Side Split Video Screen inside Live Room
  Widget _buildPkSplitVideoStream(
    bool isDark,
    bool isHost,
    LiveRoomModel activeRoom,
    PKBattleModel pk,
  ) {
    final authUser = context.read<AuthProvider>().currentUser;
    final currentUserId = authUser.id;
    final creatorId = activeRoom.creatorUserId ?? activeRoom.host.id;
    final isHostA = (currentUserId.isNotEmpty && currentUserId == pk.hostA.id) || (isHost && creatorId == pk.hostA.id);
    final isHostB = (currentUserId.isNotEmpty && currentUserId == pk.hostB.id) || (isHost && creatorId == pk.hostB.id);

    final agoraService = AgoraRtcService();
    final remoteUids = agoraService.remoteUids.toList();
    final firstRemoteUid = _remoteHostUid ?? (remoteUids.isNotEmpty ? remoteUids.first : null);
    final secondRemoteUid = remoteUids.length > 1 ? remoteUids[1] : (remoteUids.isNotEmpty && remoteUids.first != _remoteHostUid ? remoteUids.first : null);

    Widget? videoWidgetA;
    Widget? videoWidgetB;

    if (isHostA) {
      videoWidgetA = agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: agoraService.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          : null;
      videoWidgetB = firstRemoteUid != null && agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: agoraService.engine!,
                canvas: VideoCanvas(uid: firstRemoteUid),
                connection: RtcConnection(channelId: activeRoom.agoraChannelName ?? activeRoom.id),
              ),
            )
          : null;
    } else if (isHostB) {
      videoWidgetB = agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: agoraService.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          : null;
      videoWidgetA = firstRemoteUid != null && agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: agoraService.engine!,
                canvas: VideoCanvas(uid: firstRemoteUid),
                connection: RtcConnection(channelId: activeRoom.agoraChannelName ?? activeRoom.id),
              ),
            )
          : null;
    } else {
      videoWidgetA = firstRemoteUid != null && agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: agoraService.engine!,
                canvas: VideoCanvas(uid: firstRemoteUid),
                connection: RtcConnection(channelId: activeRoom.agoraChannelName ?? activeRoom.id),
              ),
            )
          : null;
      videoWidgetB = secondRemoteUid != null && agoraService.engine != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: agoraService.engine!,
                canvas: VideoCanvas(uid: secondRemoteUid),
                connection: RtcConnection(channelId: activeRoom.agoraChannelName ?? activeRoom.id),
              ),
            )
          : null;
    }

    final scoreA = pk.scoreA;
    final scoreB = pk.scoreB;
    final isLeadingA = scoreA >= scoreB;

    return Container(
      color: const Color(0xFF0A071B),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top spacing below header & PK score pill bar
            const SizedBox(height: 125),

            // Side-by-Side Video Area (Left: Team Blue / Host A, Right: Team Red / Host B)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Host A (Left / Team Blue)
                    Expanded(
                      child: _buildPkHostVideoCard(
                        host: pk.hostA,
                        score: scoreA,
                        isLeading: isLeadingA,
                        sideColor: const Color(0xFF00E5FF),
                        teamLabel: 'Team Blue',
                        isLeft: true,
                        videoWidget: videoWidgetA,
                        onSupportTap: () => _openPkGiftSheet(context, true, pk),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Host B (Right / Team Red)
                    Expanded(
                      child: _buildPkHostVideoCard(
                        host: pk.hostB,
                        score: scoreB,
                        isLeading: !isLeadingA,
                        sideColor: const Color(0xFFFF4081),
                        teamLabel: 'Team Red',
                        isLeft: false,
                        videoWidget: videoWidgetB,
                        onSupportTap: () => _openPkGiftSheet(context, false, pk),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Lower flex for chat feed & bottom controls
            const Spacer(flex: 5),
          ],
        ),
      ),
    );
  }

  /// Clean Video Card for Host in PK Split Screen
  Widget _buildPkHostVideoCard({
    required dynamic host,
    required int score,
    required bool isLeading,
    required Color sideColor,
    required String teamLabel,
    required bool isLeft,
    required Widget? videoWidget,
    required VoidCallback onSupportTap,
  }) {
    final avatar = host.avatarUrl != null && host.avatarUrl.toString().isNotEmpty
        ? host.avatarUrl.toString()
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sideColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: sideColor.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or Avatar Background
            if (videoWidget != null)
              videoWidget
            else
              Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1E1035),
                  child: const Icon(Icons.person, color: Colors.white54, size: 48),
                ),
              ),

            // Top-down & Bottom-up subtle vignettes
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Top Host Badge (Avatar + Name)
            Positioned(
              top: 8,
              left: isLeft ? 8 : null,
              right: !isLeft ? 8 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sideColor.withValues(alpha: 0.8), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(imageUrl: avatar, name: host.name ?? '', radius: 10),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        host.name ?? 'Host',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Leading Indicator 🔥
            if (isLeading && score > 0)
              Positioned(
                top: 8,
                right: isLeft ? 8 : null,
                left: !isLeft ? 8 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFAB00)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🔥 LEADING',
                    style: TextStyle(
                      color: Color(0xFF0A071B),
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Bottom Support Host Button
            Positioned(
              bottom: 8,
              left: 6,
              right: 6,
              child: GestureDetector(
                onTap: onSupportTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLeft
                          ? const [Color(0xFF00B0FF), Color(0xFF00E5FF)]
                          : const [Color(0xFFD81B60), Color(0xFFFF4081)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: sideColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLeft ? '💙' : '❤️', style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Support ${host.name != null ? host.name.toString().split(' ').first : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPkGiftSheet(BuildContext context, bool forHostA, PKBattleModel pk) {
    final targetHost = forHostA ? pk.hostA : pk.hostB;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (c) => GiftDialog(
        streamerName: targetHost.name,
        targetReceiver: targetHost,
        onGiftSent: (gift) {
          final currentUser = context.read<AuthProvider>().currentUser;
          context.read<LiveProvider>().addPkScore(forHostA, gift.diamondPrice);
          context.read<LiveProvider>().sendGift(gift, currentUser.name);
          _giftOverlayKey.currentState?.playGiftAnimation(gift, senderName: currentUser.name);
        },
      ),
    );
  }

  /// TikTok-Style PK Score Bar with Animated Ratio and Pulsing Timer
  Widget _buildPkScoreAndTimerBar(PKBattleModel pk, int seconds, bool isHost) {
    final scoreA = pk.scoreA;
    final scoreB = pk.scoreB;
    final totalScore = (scoreA + scoreB) == 0 ? 1 : (scoreA + scoreB);
    final ratioA = (scoreA / totalScore).clamp(0.08, 0.92);

    final minutes = (seconds / 60).floor();
    final remSecs = (seconds % 60).toString().padLeft(2, '0');
    final isStarted = pk.isStarted;

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: Column(
        children: [
          // Points & Pulsing Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Blue Side Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
                ),
                child: Row(
                  children: [
                    const Text('💎 ', style: TextStyle(fontSize: 10)),
                    Text(
                      '$scoreA pts',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Timer Pill ("⚔️ PK 04:59" or "PK READY")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: !isStarted
                      ? const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF1E1035)])
                      : (seconds < 30
                          ? const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD50000)])
                          : LinearGradient(colors: [Colors.black.withValues(alpha: 0.8), const Color(0xFF1E1035)])),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isStarted
                        ? Colors.purpleAccent
                        : (seconds < 30 ? const Color(0xFFFF5252) : const Color(0xFFFFD700)),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !isStarted ? Icons.hourglass_top_rounded : Icons.flash_on_rounded,
                      color: !isStarted ? Colors.purpleAccent : const Color(0xFFFFD700),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      !isStarted ? 'PK READY' : 'PK $minutes:$remSecs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          context.read<LiveProvider>().endPkBattle();
                        },
                        child: const Text('End', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),

              // Red Side Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF4081), width: 1.0),
                ),
                child: Row(
                  children: [
                    Text(
                      '$scoreB pts',
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const Text(' 💎', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Integrated Split Score Bar with 3D VS Emblem
          SizedBox(
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      AnimatedExpandedBar(
                        widthRatio: ratioA,
                        color: const Color(0xFF00E5FF),
                        gradientColors: const [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                      ),
                      AnimatedExpandedBar(
                        widthRatio: 1 - ratioA,
                        color: const Color(0xFFFF4081),
                        gradientColors: const [Color(0xFFFF4081), Color(0xFFD81B60)],
                      ),
                    ],
                  ),
                ),

                ScaleTransition(
                  scale: _vsScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.0),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Color(0xFF0A071B),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Victory Overlay when Battle Ends in Live Room
  Widget _buildPkVictoryOverlay(PKBattleModel pk) {
    final scoreA = pk.scoreA;
    final scoreB = pk.scoreB;
    final isWinnerA = scoreA >= scoreB;
    final winner = isWinnerA ? pk.hostA : pk.hostB;
    final winScore = isWinnerA ? scoreA : scoreB;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFFD81B60)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 8),
              const Text(
                'PK VICTORY!',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                winner.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Won with $winScore 💎 diamonds!',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF0A071B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                onPressed: () {
                  context.read<LiveProvider>().endPkBattle();
                },
                child: const Text('Continue Stream', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketLikeSub?.cancel();
    _remoteUsersSub?.cancel();
    _firstFrameSub?.cancel();
    _kickedSub?.cancel();
    _pkInviteSub?.cancel();
    _pkStartedSub?.cancel();
    _roomClosedSub?.cancel();
    _liveProvClosedSub?.cancel();
    _vsPulseController.dispose();
    _durationTimer?.cancel();
    _chatController.dispose();
    try {
      context.read<LiveProvider>().leaveRoom();
    } catch (_) {}
    super.dispose();
  }

  void _showIncomingPKInvitationDialog(String invitationId, String inviterName, String inviterAvatar) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFF4081), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF4081)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'PK Challenge!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(imageUrl: inviterAvatar, name: inviterName, radius: 36),
            const SizedBox(height: 12),
            Text(
              '$inviterName challenged you to a live PK Battle!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compete in real-time with live diamond gifting & audience votes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.post(
                  '/v1/pk/invite/$invitationId/respond',
                  data: {'action': 'DECLINE'},
                );
              } catch (_) {}
            },
            child: const Text('Decline', style: TextStyle(color: Colors.white60, fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.post(
                  '/v1/pk/invite/$invitationId/respond',
                  data: {'action': 'ACCEPT'},
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept PK: $e')),
                  );
                }
              }
            },
            child: const Text('Accept ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExitConfirmation(BuildContext context, bool isHost, LiveProvider liveProvider) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isHost ? Colors.redAccent : AppColors.live).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHost ? Icons.power_settings_new_rounded : Icons.logout_rounded,
                color: isHost ? Colors.redAccent : AppColors.live,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isHost ? 'End Live Stream?' : 'Leave Live Stream?',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isHost
              ? 'Are you sure you want to end your live stream? All viewers will be disconnected.'
              : 'Are you sure you want to leave this live stream?',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHost ? Colors.redAccent : AppColors.live,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'End Stream' : 'Leave', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      try {
        await liveProvider.leaveRoom();
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveProvider = context.watch<LiveProvider>();
    final activeRoom = liveProvider.activeRoom ?? widget.room;
    final activeGift = liveProvider.activeGiftAnimation;
    final currentUser = context.read<AuthProvider>().currentUser;
    final isHost = widget.isHost ||
        (activeRoom.host.id == currentUser.id) ||
        (activeRoom.creatorUserId == currentUser.id) ||
        (currentUser.name.trim().isNotEmpty && currentUser.name.trim().toLowerCase() == activeRoom.host.name.trim().toLowerCase());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExitConfirmation(context, isHost, liveProvider);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background Stream (Native Agora Video or Cover Image fallback)
            Positioned.fill(
              child: _buildVideoStream(isDark, isHost, activeRoom),
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

          // TikTok-Style Live Gifting Animation Overlay
          TikTokGiftOverlay(roomId: widget.room.id),

          // Real-time Moderation Warning Banner Overlay
          if (liveProvider.activeWarningMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'MODERATION WARNING',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            liveProvider.activeWarningMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                                participants: liveProvider.viewers.map((u) => PartyParticipantModel(
                                  user: u,
                                  role: ParticipantRole.listener,
                                  joinedAt: DateTime.now(),
                                )).toList(),
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
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      LiveViewersSheet.show(
                                        context,
                                        viewers: liveProvider.viewers,
                                        roomId: widget.room.id,
                                        roomTitle: widget.room.title,
                                        isDark: isDark,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 13),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${liveProvider.viewers.isNotEmpty ? liveProvider.viewers.length : (activeRoom.viewerCount > 0 ? activeRoom.viewerCount : 0)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
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

                              // Minimize to Floating Overlay
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    Provider.of<RoomOverlayProvider>(context, listen: false).minimizeRoom(
                                      roomType: 'LIVE',
                                      room: widget.room,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
                                ),
                              ),

                              // Close
                              GestureDetector(
                                onTap: () => _handleExitConfirmation(context, isHost, liveProvider),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (liveProvider.activePkBattle != null && !liveProvider.activePkBattle!.isEnded)
                    _buildPkScoreAndTimerBar(
                      liveProvider.activePkBattle!,
                      liveProvider.pkTimeRemainingSeconds,
                      isHost,
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
                  Icons.people_alt_rounded,
                  'Viewers',
                  AppColors.cyan,
                  onTap: () {
                    LiveViewersSheet.show(
                      context,
                      viewers: liveProvider.viewers,
                      roomId: widget.room.id,
                      roomTitle: widget.room.title,
                      isDark: isDark,
                    );
                  },
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
                            final isSystem = msg.sender.toLowerCase().contains('system') || msg.sender.contains('🛡️');
                            final isHostMsg = msg.isHost || msg.sender == widget.room.host.name;

                            return AnimatedLiveCommentItem(
                              key: ValueKey('${msg.sender}_${msg.text}_${msg.id}_$index'),
                              senderId: msg.senderId.isNotEmpty ? msg.senderId : (isHostMsg ? widget.room.host.id : 'user_$index'),
                              senderName: msg.sender,
                              avatarUrl: msg.avatarUrl,
                              text: msg.text,
                              isHost: isHostMsg,
                              isMod: msg.isMod,
                              isVip: msg.isVip,
                              nobleTitle: msg.nobleTitle,
                              isSystem: isSystem,
                              isGift: msg.isGift,
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
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => PkMatchScreen(currentRoomId: widget.room.id)));
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
                                      final text = _chatController.text.trim();
                                      if (text.isNotEmpty) {
                                        final currentUser = context.read<AuthProvider>().currentUser;
                                        liveProvider.sendMessage(text, currentUser.name, user: currentUser);
                                        _chatController.clear();
                                        if (mounted) setState(() {});
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
                                           final text = _chatController.text.trim();
                                           if (text.isNotEmpty) {
                                             final currentUser = context.read<AuthProvider>().currentUser;
                                             liveProvider.sendMessage(text, currentUser.name, user: currentUser);
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
                            liveProvider.isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: liveProvider.isMicMuted ? Colors.redAccent : const Color(0xFF00E676),
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

          // TikTok User Join Entrance Banner
          TikTokUserJoinBanner(roomId: widget.room.id, bottomOffset: 240),

          // Realtime Animated Emoji Reaction Overlay (Top of Stack)
          EmojiReactionOverlay(roomId: widget.room.id),

          // Onscreen 3D Gift Animation Overlay
          GiftAnimationOverlay(key: _giftOverlayKey),

          // PK Victory Celebration Overlay
          if (liveProvider.activePkBattle != null && (liveProvider.activePkBattle!.isEnded || liveProvider.pkTimeRemainingSeconds == 0))
            Positioned.fill(
              child: _buildPkVictoryOverlay(liveProvider.activePkBattle!),
            ),
        ],
      ),
    ));
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
                  // ── Share Room Invite Link ──────────────────────
                  _buildToolItem(
                    icon: Icons.share_rounded,
                    label: 'Share Link',
                    color: Colors.lightBlueAccent,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(c);
                      RoomShareService.shareRoom(
                        context,
                        roomId: widget.room.id,
                        roomTitle: widget.room.title,
                        isParty: false,
                      );
                    },
                  ),

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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PkMatchScreen(currentRoomId: widget.room.id)));
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
    final liveProv = context.read<LiveProvider>();
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
                title: Text('Viewers List (${liveProv.viewers.length})', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
                subtitle: Text('${liveProv.viewers.isNotEmpty ? liveProv.viewers.length : widget.room.viewerCount} active viewers • Tap to view all profiles', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                onTap: () {
                  Navigator.pop(c);
                  LiveViewersSheet.show(
                    context,
                    viewers: liveProv.viewers,
                    roomId: widget.room.id,
                    roomTitle: widget.room.title,
                    isDark: isDark,
                  );
                },
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
