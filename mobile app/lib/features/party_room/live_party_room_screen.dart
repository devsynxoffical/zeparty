import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/services/room_share_service.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';
import '../../core/utils/noble_badge_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backpack_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/live_party_provider.dart';
import '../../providers/room_overlay_provider.dart';
import '../../core/utils/formatters.dart';
import '../recharge/recharge_screen.dart';
import '../../models/party_participant_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/tiktok_gift_overlay.dart';
import '../../providers/live_gift_provider.dart';
import '../games/game_center_sheet.dart';
import '../pk_battle/pk_match_screen.dart';
import 'widgets/room_info_sheet.dart';
import 'widgets/room_sending_ranking_sheet.dart';
import 'widgets/room_type_selector_sheet.dart';
import 'widgets/room_entry_announcement_banner.dart';
import 'widgets/room_entry_mount_banner.dart';
import 'widgets/effects_settings_sheet.dart';
import 'widgets/mic_seat_management_sheet.dart';
import 'widgets/in_room_profile_card_sheet.dart';
import 'widgets/expanded_message_panel.dart';
import '../../widgets/multi_role_seat_grid.dart';
import '../../widgets/svip_entry_banner.dart';
import '../live/widgets/high_value_announcement.dart';
import '../../widgets/animated_live_comment_item.dart';
import '../../widgets/emoji_reaction_overlay.dart';
import '../../widgets/tiktok_user_join_banner.dart';
import '../../providers/emoji_reaction_provider.dart';
import '../profile/user_profile_details_screen.dart';
import '../messages/chat_screen.dart';

class LivePartyRoomScreen extends StatefulWidget {
  final LiveRoomModel room;
  const LivePartyRoomScreen({super.key, required this.room});

  @override
  State<LivePartyRoomScreen> createState() => _LivePartyRoomScreenState();
}

class _LivePartyRoomScreenState extends State<LivePartyRoomScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isMicMuted = false;
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey<GiftAnimationOverlayState>();
  String _activeChatFilter = 'All';
  bool _isNoticeExpanded = true;

  // ─── Room Tools State ───
  List<Color> _roomBackgroundGradient = [
    const Color(0xFF2B1055),
    const Color(0xFF130924),
    const Color(0xFF080411),
  ];
  String? _customBackgroundPath;
  Color _ambientGlowColor1 = const Color(0xFF9C27B0);
  Color _ambientGlowColor2 = const Color(0xFFFF4081);

  // Music Player State
  bool _isPlayingMusic = false;
  int _currentTrackIndex = 0;
  double _musicVolume = 0.8;
  final List<Map<String, String>> _musicPlaylist = [
    {'title': 'Lo-Fi Chill Beats', 'genre': 'Chillout / Beats', 'duration': '2:45'},
    {'title': 'Nightdrive Synthwave', 'genre': 'Electronic / Upbeat', 'duration': '3:12'},
    {'title': 'Acoustic Sunset Lounge', 'genre': 'Acoustic / Relax', 'duration': '3:05'},
    {'title': 'Deep House Party Mix', 'genre': 'Dance / Club', 'duration': '4:20'},
    {'title': 'Smooth Jazz Cafe', 'genre': 'Instrumental Jazz', 'duration': '2:58'},
  ];

  // Room Settings State
  bool _autoMuteNewSpeakers = false;
  bool _allowSeatRequests = true;
  bool _hdAudioMode = true;

  late final String _roomEntrySessionId;
  RoomEntryBannerItem? _currentMountBanner;
  StreamSubscription? _partyRoomClosedSub;
  bool _isPartyEndedDialogShown = false;

  void _handlePartyRoomEnded([String? reason]) {
    if (_isPartyEndedDialogShown || !mounted) return;
    _isPartyEndedDialogShown = true;

    try {
      Provider.of<LivePartyProvider>(context, listen: false).leaveParty();
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Row(
          children: [
            Icon(Icons.nightlife_rounded, color: Color(0xFFB524E4), size: 26),
            SizedBox(width: 10),
            Text('Party Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          reason != null && reason.isNotEmpty
              ? reason
              : 'This party room has ended.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB524E4),
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

  @override
  void initState() {
    super.initState();
    _roomEntrySessionId = 'session_${widget.room.id}_${DateTime.now().millisecondsSinceEpoch}';
    _requestMicPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
      if (partyProv.activeRoom?.id != widget.room.id) {
        partyProv.joinParty(widget.room, user);
      }
      Provider.of<EmojiReactionProvider>(context, listen: false).setActiveRoom(widget.room.id);
      Provider.of<LiveGiftProvider>(context, listen: false).setActiveRoom(widget.room.id);

      _partyRoomClosedSub?.cancel();
      _partyRoomClosedSub = partyProv.onRoomClosed.listen((data) {
        final isHost = widget.room.host.id == user.id || widget.room.creatorUserId == user.id;
        if (!isHost && mounted) {
          final reason = data['reason']?.toString();
          _handlePartyRoomEnded(
            reason == 'HOST_ABSENT_TIMEOUT'
                ? 'Party ended because the host was absent for 2 minutes.'
                : reason,
          );
        }
      });
      
      // Mock SVIP entry for demonstration
      if (user.isVip) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            SvipEntryManager().showEntry(user);
          }
        });
      }
    });
  }

  Future<void> _requestMicPermission() async {
    try {
      await Permission.microphone.request();
    } catch (_) {}
  }

  @override
  void dispose() {
    _partyRoomClosedSub?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _leaveRoom() {
    final provider = Provider.of<LivePartyProvider>(context, listen: false);
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final isHost = widget.room.host.id == currentUser.id || widget.room.creatorUserId == currentUser.id;

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Party Room?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHost
              ? 'You are about to leave this party room. The room will stay active so other speakers and listeners can continue chatting.'
              : 'Are you sure you want to leave this party room?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Stay', style: TextStyle(color: Colors.white60)),
          ),
          if (isHost)
            TextButton(
              onPressed: () async {
                Navigator.pop(d);
                await provider.closeRoom();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('End Room for All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB524E4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(d);
              // Leave without closing room so other users can stay inside
              await provider.leaveParty();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );
  }

  void _toggleMic() {
    final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;
    final isHost = partyProv.activeRoom?.host.id == user.id || partyProv.activeRoom?.creatorUserId == user.id;
    final isSeated = partyProv.participants.any((p) => (p.user.id == user.id || p.user.username == user.username) && p.seatNumber != null);

    if (!isHost && !isSeated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ You must take a mic seat to enable your microphone.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (partyProv.isRoomMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Room microphone is currently locked by admin moderation.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isMicMuted = !_isMicMuted);
    partyProv.muteLocalMic(_isMicMuted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMicMuted ? 'Microphone Muted 🔇' : 'Microphone Active 🎙️'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
      partyProv.sendMessage(user, text);
      _chatController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _openGiftDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GiftDialog(
        streamerName: widget.room.host.name,
        onGiftSent: (gift) {
          _giftOverlayKey.currentState?.playGiftAnimation(gift);
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          final provider = Provider.of<LivePartyProvider>(context, listen: false);
          final emojiProvider = Provider.of<EmojiReactionProvider>(context, listen: false);
          
          emojiProvider.sendReaction(
            roomId: widget.room.id,
            senderId: user.id,
            emoji: gift.icon,
            senderName: user.name,
          );

          if (provider.isPkActive) {
            provider.addPkScore(true, gift.diamondPrice);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final provider = Provider.of<LivePartyProvider>(context);
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final isHost = widget.room.host.id == currentUser.id;
    final canManage = isHost || provider.participants.any(
        (p) => p.user.id == currentUser.id && p.role == ParticipantRole.moderator);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveRoom();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF0D0B18),
      body: Stack(
        children: [
          // TikTok Live Gifting Overlay
          TikTokGiftOverlay(roomId: widget.room.id),
          // Ambient Gradient, Equipped Room Theme, or Custom Background Image
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final equippedTheme = context.watch<BackpackProvider>().equippedThemeUrl;
                final bgImage = _customBackgroundPath != null
                    ? FileImage(File(_customBackgroundPath!)) as ImageProvider
                    : (equippedTheme != null && equippedTheme.isNotEmpty
                        ? ((equippedTheme.startsWith('http://') || equippedTheme.startsWith('https://'))
                            ? NetworkImage(equippedTheme) as ImageProvider
                            : AssetImage(equippedTheme) as ImageProvider)
                        : null);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    image: bgImage != null
                        ? DecorationImage(
                            image: bgImage,
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.55),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    gradient: bgImage == null
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _roomBackgroundGradient,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Neon Glow Shapes
          Positioned(
            top: -60,
            left: -40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ambientGlowColor1.withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ambientGlowColor2.withValues(alpha: 0.2),
              ),
            ),
          ),

          // Overlays
          const HighValueAnnouncementOverlay(),

          // Admin Moderation Warning Banner
          if (provider.activeWarningMessage != null)
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
                            provider.activeWarningMessage!,
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

          // Main Layout
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Header
                _buildHeader(context, isHost, canManage, provider),

                // Audience & Participants Avatar Bar (Shows active listeners & users in real-time)
                _buildAudienceRow(provider, canManage, isDark),

                // PK Battle Banner (If Active)
                if (provider.isPkActive) _buildPkBanner(provider),

                // Audio Mic Stage Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Center(
                    child: _buildStageGrid(provider, currentUser, canManage, isDark),
                  ),
                ),

                // Banners Strip
                const SvipEntryBanner(),

                // Room Entry Mount Banner Widget
                RoomEntryMountBannerWidget(
                  roomId: widget.room.id,
                  currentBanner: _currentMountBanner,
                  onBannerComplete: () {
                    if (mounted) {
                      setState(() {
                        _currentMountBanner = null;
                      });
                    }
                  },
                ),

                // Room Entry Announcement Banner
                RoomEntryAnnouncementBanner(
                  roomId: widget.room.id,
                  roomEntrySessionId: _roomEntrySessionId,
                  isDark: isDark,
                ),

                // Coordinated Room Guidelines Notice & Chat Filters Bar
                _buildRoomNoticeAndFilterBar(provider),

                // Notification & Chat stream directly following the notice bar
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _buildChatFeed(provider),
                  ),
                ),

                // Bottom Controls
                _buildBottomBar(canManage, isHost, provider, isDark),
              ],
            ),
          ),

          // Right-side Floating Action Shortcut (Game Lobby)
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 66 + MediaQuery.of(context).viewInsets.bottom,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => GameCenterSheet.show(context),
              child: Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/party_games_icon.jpg',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)]),
                        ),
                        child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 22),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // TikTok User Join Entrance Banner
          TikTokUserJoinBanner(roomId: provider.activeRoom?.id ?? widget.room.id, bottomOffset: 240),

          // Realtime Animated Emoji Reaction Overlay Layer (Top of Stack)
          EmojiReactionOverlay(roomId: provider.activeRoom?.id ?? widget.room.id),

          // Onscreen 3D Gift Animation Overlay
          GiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    ),
  );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isHost,
    bool canManage,
    LivePartyProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Room Info
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      final activeRoom = provider.activeRoom ?? widget.room;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => RoomInfoSheet(
                          room: activeRoom,
                          canManage: canManage,
                          isDark: Theme.of(context).brightness == Brightness.dark,
                          participants: provider.participants,
                        ),
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        final activeRoom = provider.activeRoom ?? widget.room;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Room Avatar (Square with rounded corners)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildHeaderCover(activeRoom.coverUrl),
                            ),
                            const SizedBox(width: 10),
                            // Room Name and ID
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    activeRoom.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (activeRoom.host.svipLevel > 0 ||
                                          (activeRoom.host.nobleTitle != null &&
                                              activeRoom.host.nobleTitle!.isNotEmpty &&
                                              activeRoom.host.nobleTitle!.toLowerCase() != 'none') ||
                                          (activeRoom.nobleTitle.isNotEmpty &&
                                              activeRoom.nobleTitle.toLowerCase() != 'none' &&
                                              NobleBadgeHelper.getTierFromTitle(activeRoom.nobleTitle) != NobleTier.none)) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.5),
                                          ),
                                          child: Text(
                                            '👑 ${activeRoom.host.svipLevel > 0 ? (activeRoom.host.nobleTitle != null && activeRoom.host.nobleTitle!.toLowerCase().contains("svip") ? activeRoom.host.nobleTitle! : "SVIP ${activeRoom.host.svipLevel}") : (activeRoom.host.nobleTitle?.isNotEmpty == true ? activeRoom.host.nobleTitle! : activeRoom.nobleTitle)}',
                                            style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          'ID:${activeRoom.id.length > 6 ? activeRoom.id.substring(0, 6) : activeRoom.id} • 👥 ${activeRoom.viewerCount}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Follow Button (+)
                if (!isHost)
                  GestureDetector(
                    onTap: () {
                      final auth = context.read<AuthProvider>();
                      auth.toggleFollow(widget.room.host.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✨ Followed ${widget.room.host.name}!')),
                      );
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB524E4), // bright purple matching screenshot
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 6),
          
          // Right: Controls
          // Right: Controls
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy & Points
                  GestureDetector(
                    onTap: () {
                      final activeRoom = provider.activeRoom ?? widget.room;
                      RoomSendingRankingSheet.show(
                        context,
                        roomId: activeRoom.id,
                        roomTitle: activeRoom.title,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            () {
                              final activeRoom = provider.activeRoom ?? widget.room;
                              final pts = activeRoom.host.diamonds;
                              if (pts >= 1000000) return '${(pts / 1000000).toStringAsFixed(1)}M';
                              if (pts >= 1000) return '${(pts / 1000).toStringAsFixed(1)}K';
                              return '$pts';
                            }(),
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Room Tools Button
                  GestureDetector(
                    onTap: () => _showRoomTools(context, canManage, isHost, provider, Theme.of(context).brightness == Brightness.dark),
                    child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
                  ),

                  const SizedBox(width: 8),

                  // Minimize to Floating Overlay
                  GestureDetector(
                    onTap: () {
                      Provider.of<RoomOverlayProvider>(context, listen: false).minimizeRoom(
                        roomType: 'PARTY',
                        room: widget.room,
                      );
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 8),

                  // Close X
                  GestureDetector(
                    onTap: _leaveRoom,
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceRow(LivePartyProvider provider, bool canManage, bool isDark) {
    final audience = provider.participants.where((p) =>
      p.role != ParticipantRole.host &&
      p.user.id != (provider.activeRoom?.host.id ?? widget.room.host.id) &&
      p.user.id != (provider.activeRoom?.creatorUserId ?? widget.room.creatorUserId)
    ).toList();
    final viewerCount = provider.activeRoom != null ? provider.activeRoom!.viewerCount : audience.length;

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, color: Colors.cyanAccent, size: 13),
                const SizedBox(width: 4),
                Text(
                  '$viewerCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: audience.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Waiting for viewers...',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: audience.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final p = audience[i];
                      final onSeat = p.seatNumber != null;
                      return GestureDetector(
                        onTap: () {
                          InRoomProfileCardSheet.show(
                            context,
                            participant: p,
                            canManage: canManage,
                            isDark: isDark,
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: onSeat ? Colors.amberAccent : Colors.purpleAccent.withValues(alpha: 0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: (p.user.avatarUrl.isNotEmpty)
                                    ? Image.network(
                                        p.user.avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildDefaultAvatar(p.user.name),
                                      )
                                    : _buildDefaultAvatar(p.user.name),
                              ),
                            ),
                            if (onSeat)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFB524E4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.mic, color: Colors.white, size: 8),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      color: const Color(0xFF6C5CE7),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPkBanner(LivePartyProvider provider) {
    final scoreA = provider.pkScoreA;
    final scoreB = provider.pkScoreB;
    final total = (scoreA + scoreB) == 0 ? 1 : (scoreA + scoreB);
    final ratioA = (scoreA == 0 && scoreB == 0) ? 0.5 : (scoreA / total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFF416C).withValues(alpha: 0.8), const Color(0xFF2193B0).withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pinkAccent.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔥 Team Host: \$scoreA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text('PK ${provider.pkTimerRemaining}s', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              Text('Team Rival: \$scoreB ⚡', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratioA,
              minHeight: 6,
              backgroundColor: const Color(0xFF2193B0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF416C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageGrid(
    LivePartyProvider provider,
    dynamic currentUser,
    bool canManage,
    bool isDark,
  ) {
    final activeRoom = provider.activeRoom ?? widget.room;
    final gameProvider = Provider.of<GameProvider>(context);

    return MultiRoleSeatGrid(
      participants: provider.participants,
      isDark: isDark,
      capacity: activeRoom.seatCapacity,
      lockedSeats: provider.lockedSeatIndices,
      micSizePreset: gameProvider.roomMicSizePreset,
      onSeatTap: (index) async {
        final occupant = provider.participants.where((p) => p.seatNumber == index).firstOrNull;
        final authUser = context.read<AuthProvider>().currentUser;
        if (occupant == null && !provider.isSeatLocked(index)) {
          final err = await provider.takeMicSeat(index, authUser);
          if (context.mounted && err != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent),
            );
          }
        } else {
          MicSeatManagementSheet.show(
            context,
            micIndex: index,
            occupant: occupant,
            isLocked: provider.isSeatLocked(index),
            isMuted: provider.isSeatMuted(index),
          );
        }
      },
      onParticipantTap: (participant) {
        InRoomProfileCardSheet.show(
          context,
          participant: participant,
          canManage: canManage,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildRoomNoticeAndFilterBar(LivePartyProvider provider) {
    final activeRoom = provider.activeRoom ?? widget.room;
    final announcement = activeRoom.announcement;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Tabs Row (Matching Ahlan reference)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _activeChatFilter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeChatFilter = _activeChatFilter == 'My' ? 'All' : 'My';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeChatFilter == 'My' ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'My',
                    style: TextStyle(
                      color: _activeChatFilter == 'My' ? Colors.amberAccent : Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeChatFilter = _activeChatFilter == 'Radio' ? 'All' : 'Radio';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeChatFilter == 'Radio' ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Radio',
                    style: TextStyle(
                      color: _activeChatFilter == 'Radio' ? Colors.cyanAccent : Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Collapsible chevron toggle for room notice
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isNoticeExpanded = !_isNoticeExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isNoticeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          // Coordinated Room Guidelines Notice (Ahlan Reference Match)
          if (_isNoticeExpanded) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1338).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to ${activeRoom.title}: please respect each other, no vulgar words, no politics, no religion, no violence, no sexual topic etc.',
                    style: const TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (announcement.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notice: 📝 ',
                          style: TextStyle(
                            color: Color(0xFFFFCC80),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            announcement,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatFeed(LivePartyProvider provider) {
    final messages = provider.messages;
    final filteredMessages = messages.where((msg) {
      if (_activeChatFilter == 'My') {
        final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser.id;
        return msg.sender.id == currentUserId;
      } else if (_activeChatFilter == 'Radio') {
        return msg.isGiftMessage || msg.sender.id == 'system';
      }
      return true;
    }).toList();

    return ListView.builder(
      controller: _chatScrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(14, 4, 68, 4), // 68px right-padding ensures floating tools never obscure chat
      itemCount: filteredMessages.length,
      itemBuilder: (context, index) {
        final msg = filteredMessages.reversed.toList()[index];
        final isSystem = msg.sender.id == 'system';
        final isHostMsg = msg.sender.id == widget.room.host.id;
        
        final participantInfo = provider.participants.where((p) => p.user.id == msg.sender.id).firstOrNull;
        final isMod = participantInfo?.role == ParticipantRole.moderator;
        final isVip = msg.sender.wealthLevel >= 10 || msg.sender.isVip;

        final isHost = widget.room.host.id == currentUser.id;
        final canManage = isHost || provider.participants.any((p) => p.user.id == currentUser.id && p.role == ParticipantRole.moderator);
        final isMeMsg = msg.sender.id == currentUser.id;
        final backpack = Provider.of<BackpackProvider>(context, listen: false);
        final equippedBubble = isMeMsg ? backpack.equippedBubbleUrl : (msg.sender.badge.isNotEmpty ? msg.sender.badge : null);
        final equippedFrame = msg.sender.avatarFrame.isNotEmpty
            ? msg.sender.avatarFrame
            : (isMeMsg ? currentUser.avatarFrame : null);

        return AnimatedLiveCommentItem(
          key: ValueKey(msg.id),
          senderId: msg.sender.id,
          senderName: msg.sender.name.isNotEmpty ? msg.sender.name : msg.sender.username,
          avatarUrl: msg.sender.avatarUrl,
          text: msg.text,
          isHost: isHostMsg,
          isMod: isMod,
          isVip: isVip,
          isSystem: isSystem,
          isGift: msg.isGiftMessage,
          nobleTitle: msg.sender.nobleTitle,
          avatarFrame: equippedFrame,
          chatBubble: equippedBubble,
          wealthLevel: msg.sender.wealthLevel,
          onTap: () {
            final participant = provider.participants.where((p) => p.user.id == msg.sender.id).firstOrNull ??
                PartyParticipantModel(user: msg.sender, joinedAt: DateTime.now());
            _showParticipantSheet(context, participant, provider, Theme.of(context).brightness == Brightness.dark, canManage);
          },
        );
      },
    );
  }

  Widget _buildBottomBar(bool canManage, bool isHost, LivePartyProvider provider, bool isDark) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF140D24).withValues(alpha: 0.96),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              // ── Far Left: Standalone 3D "+" Options Button ──
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showRoomTools(context, canManage, isHost, provider, isDark),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      radius: 0.9,
                      colors: [
                        Color(0xFF5A447E),
                        Color(0xFF2C194D),
                        Color(0xFF190C30),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 3,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Center: Dark Pill Input Field with 3D Emoji Icon ──
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          cursorColor: Colors.pinkAccent,
                          readOnly: false,
                          onTap: () {
                            ExpandedMessagePanel.show(
                              context,
                              onOpenStickers: () => _showStickerPanel(context),
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'Say something...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13.5),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _sendChatMessage(),
                          onChanged: (val) {
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      
                      // 3D Emoji Face Logo Button
                      GestureDetector(
                        onTap: () => _showStickerPanel(context),
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.3, -0.4),
                              radius: 0.85,
                              colors: [
                                Color(0xFFFFE082),
                                Color(0xFFFFB300),
                                Color(0xFFFF8F00),
                                Color(0xFFE65100),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFF9C4).withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8F00).withValues(alpha: 0.5),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              color: Color(0xFF5D2800),
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      if (_chatController.text.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFFF416C), size: 18),
                          onPressed: _sendChatMessage,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Send Message',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Far Right Action Icons (3D Sound Speaker, 3D Microphone & 3D Gift Box) ──
              if (!isKeyboardOpen) ...[
                // 3D Room Sound / Speaker Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    provider.toggleSpeakerOutput();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(provider.isSpeakerMuted ? 'Room Audio Off 🔇' : 'Room Audio On 🔊'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 0.9,
                        colors: provider.isSpeakerMuted
                            ? [
                                const Color(0xFFFF8A80),
                                const Color(0xFFFF1744),
                                const Color(0xFFB71C1C),
                              ]
                            : [
                                const Color(0xFF80D8FF),
                                const Color(0xFF00B0FF),
                                const Color(0xFF0D47A1),
                              ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (provider.isSpeakerMuted ? Colors.redAccent : const Color(0xFF00B0FF)).withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        provider.isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3D Microphone Toggle Button
                Builder(
                  builder: (ctx) {
                    final user = ctx.watch<AuthProvider>().currentUser;
                    final isHost = provider.activeRoom?.host.id == user.id || provider.activeRoom?.creatorUserId == user.id;
                    final isSeated = provider.participants.any((p) => (p.user.id == user.id || p.user.username == user.username) && p.seatNumber != null);
                    final canSpeak = isHost || isSeated;

                    final isMuted = provider.isRoomMuted || _isMicMuted || !canSpeak;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleMic,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            radius: 0.9,
                            colors: !canSpeak
                                ? [
                                    const Color(0xFF9E9E9E),
                                    const Color(0xFF616161),
                                    const Color(0xFF212121),
                                  ]
                                : (isMuted
                                    ? [
                                        const Color(0xFFFF8A80),
                                        const Color(0xFFFF1744),
                                        const Color(0xFFB71C1C),
                                      ]
                                    : [
                                        const Color(0xFFB9F6CA),
                                        const Color(0xFF00E676),
                                        const Color(0xFF004D40),
                                      ]),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (!canSpeak
                                      ? Colors.black38
                                      : (isMuted ? Colors.redAccent : const Color(0xFF00E676)))
                                  .withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 20,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1.5)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // 3D Gift Box Button (Upgraded detailed asset with depth, gradient badge & shadow)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openGiftDialog,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4081).withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/party_gift_box.jpg',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFFF4081),
                                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                                );
                              },
                            ),
                          ),
                        ),
                        // Vibrant Glow Ring & Tag
                        Positioned(
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 2),
                              ],
                            ),
                            child: const Text(
                              'GIFT',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomTools(
    BuildContext context,
    bool canManage,
    bool isHost,
    LivePartyProvider provider,
    bool isDark,
  ) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),

              // Header
              const Text('Party Room Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Scrollable Grid of All Functionalities aligned in 3 columns
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                    children: [
                      // Member controls (Upgraded with 3D Glass Option Icons)
                      _buildRoomToolBtn(
                        _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
                        _isMicMuted ? Colors.redAccent : Colors.green,
                        () {
                          Navigator.pop(ctx);
                          _toggleMic();
                        },
                        imageAsset: 'assets/images/party_tool_mic.png',
                      ),
                      _buildRoomToolBtn(
                        provider.isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        provider.isSpeakerMuted ? 'Unmute Room' : 'Mute Room',
                        provider.isSpeakerMuted ? Colors.redAccent : Colors.cyan,
                        () {
                          Navigator.pop(ctx);
                          provider.toggleSpeakerOutput();
                        },
                        imageAsset: 'assets/images/party_tool_mute_room.png',
                      ),
                      _buildRoomToolBtn(
                        Icons.card_giftcard_rounded,
                        'Send Gift',
                        Colors.pinkAccent,
                        () {
                          Navigator.pop(ctx);
                          _openGiftDialog();
                        },
                        imageAsset: 'assets/images/party_tool_gift.png',
                      ),
                      _buildRoomToolBtn(
                        Icons.share_rounded,
                        'Share Link',
                        Colors.lightBlueAccent,
                        () {
                          Navigator.pop(ctx);
                          RoomShareService.shareRoom(
                            context,
                            roomId: widget.room.id,
                            roomTitle: widget.room.title,
                            isParty: true,
                          );
                        },
                        imageAsset: 'assets/images/party_tool_share.png',
                      ),
                      _buildRoomToolBtn(
                        Icons.airline_seat_recline_normal_rounded,
                        'Assign Seat',
                        Colors.tealAccent,
                        () {
                          Navigator.pop(ctx);
                          _showManagementPanel(context, isDark, provider);
                        },
                        imageAsset: 'assets/images/party_tool_seat.png',
                      ),
                      _buildRoomToolBtn(
                        Icons.sports_esports_rounded,
                        'Game Center',
                        Colors.cyanAccent,
                        () {
                          Navigator.pop(ctx);
                          GameCenterSheet.show(context);
                        },
                        imageAsset: 'assets/images/party_tool_game_center.png',
                      ),

                      // Management Controls (CR 38 - Strictly Gated to Owner & Admins)
                      if (canManage) ...[
                        _buildRoomToolBtn(
                          Icons.dashboard_customize_rounded,
                          'Room Type',
                          Colors.amber,
                          () {
                            Navigator.pop(ctx);
                            final activeRoom = provider.activeRoom ?? widget.room;
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => RoomTypeSelectorSheet(
                                initialRoomType: activeRoom.roomType,
                                initialCapacity: activeRoom.seatCapacity,
                                onApply: (roomType, capacity) {
                                  provider.updateRoomTypeAndCapacity(roomType, capacity);
                                },
                              ),
                            );
                          },
                          imageAsset: 'assets/images/party_tool_room_type.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.flash_on_rounded,
                          provider.isPkActive ? 'End PK' : 'PK Match',
                          Colors.deepOrangeAccent,
                          () {
                            Navigator.pop(ctx);
                            if (provider.isPkActive) {
                              provider.endPk();
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PkMatchScreen(currentRoomId: widget.room.id)));
                            }
                          },
                          imageAsset: 'assets/images/party_tool_pk_match.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.group_rounded,
                          'Members',
                          Colors.teal,
                          () {
                            Navigator.pop(ctx);
                            _showManagementPanel(context, isDark, provider);
                          },
                          imageAsset: 'assets/images/party_tool_members.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.lock_rounded,
                          'Lock Seats',
                          Colors.redAccent,
                          () {
                            Navigator.pop(ctx);
                            _showSeatLockDialog(context, provider);
                          },
                          imageAsset: 'assets/images/party_tool_lock_seats.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.wallpaper_rounded,
                          'Backgrounds',
                          Colors.blue,
                          () {
                            Navigator.pop(ctx);
                            _showBackgroundPicker(context);
                          },
                          imageAsset: 'assets/images/party_tool_backgrounds.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.add_photo_alternate_rounded,
                          'Change Cover',
                          Colors.purpleAccent,
                          () {
                            Navigator.pop(ctx);
                            _showCoverPicker(context);
                          },
                          imageAsset: 'assets/images/party_tool_change_cover.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.palette_outlined,
                          'Themes',
                          Colors.purple,
                          () {
                            Navigator.pop(ctx);
                            _showThemePicker(context);
                          },
                          imageAsset: 'assets/images/party_tool_themes.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.music_note_rounded,
                          'Music Player',
                          Colors.pink,
                          () {
                            Navigator.pop(ctx);
                            _showMusicLibrary(context);
                          },
                          imageAsset: 'assets/images/party_tool_music_player.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.auto_awesome_rounded,
                          'Effects Settings',
                          Colors.amberAccent,
                          () {
                            Navigator.pop(ctx);
                            EffectsSettingsSheet.show(context);
                          },
                          imageAsset: 'assets/images/party_tool_effects_settings.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.campaign_rounded,
                          'Announcement',
                          Colors.amber,
                          () {
                            Navigator.pop(ctx);
                            final authUser = context.read<AuthProvider>().currentUser;
                            final isHost = widget.room.host.id == authUser.id;
                            final isAdmin = authUser.role == UserRole.admin || authUser.id == 'admin';
                            RoomAnnouncementEditDialog.show(
                              context,
                              roomId: widget.room.id,
                              isHost: isHost,
                              isAdmin: isAdmin,
                            );
                          },
                          imageAsset: 'assets/images/party_tool_announcement.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.settings_suggest_outlined,
                          'Settings',
                          Colors.orange,
                          () {
                            Navigator.pop(ctx);
                            _showRoomSettings(context);
                          },
                          imageAsset: 'assets/images/party_tool_settings.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.play_circle_fill_rounded,
                          'YouTube',
                          Colors.redAccent,
                          () {
                            Navigator.pop(ctx);
                            _showYouTubeControlDialog(context);
                          },
                          imageAsset: 'assets/images/party_tool_youtube.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.casino_rounded,
                          'Super Wheel',
                          Colors.amberAccent,
                          () {
                            Navigator.pop(ctx);
                            _showSuperWheelControlDialog(context);
                          },
                          imageAsset: 'assets/images/party_tool_superwheel.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.card_giftcard_rounded,
                          'Lucky Bag',
                          Colors.orangeAccent,
                          () {
                            Navigator.pop(ctx);
                            _showLuckyBagControlDialog(context);
                          },
                          imageAsset: 'assets/images/party_tool_luckybag.png',
                        ),
                        _buildRoomToolBtn(
                          Icons.lock_rounded,
                          'Lock Room',
                          Colors.cyanAccent,
                          () {
                            Navigator.pop(ctx);
                            _showLockRoomControlDialog(context);
                          },
                          imageAsset: 'assets/images/party_tool_lockroom.png',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showParticipantSheet(
    BuildContext ctx,
    PartyParticipantModel p,
    LivePartyProvider provider,
    bool isDark,
    bool canManage,
  ) {
    final isMuted = p.micStatus == MicStatus.muted;
    final isHostP = p.role == ParticipantRole.host;
    final isModP = p.role == ParticipantRole.moderator;
    final hasSeat = p.seatNumber != null;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: p.user.id)),
                );
              },
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundImage: NetworkImage(p.user.avatarUrl)),
                  const SizedBox(height: 12),
                  Text(p.user.name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Level ${p.user.wealthLevel} • ID: ${p.user.id.substring(0, p.user.id.length > 8 ? 8 : p.user.id.length)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interaction row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(Icons.person_outline_rounded, 'Profile', isDark, () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: p.user.id)),
                  );
                }),
                _buildActionBtn(Icons.person_add, 'Follow', isDark, () {
                  final auth = context.read<AuthProvider>();
                  final alreadyFollowing = auth.isFollowing(p.user.id);
                  if (alreadyFollowing) {
                    auth.unfollowUser(p.user.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Unfollowed ${p.user.name}')));
                  } else {
                    auth.followUser(p.user.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('✨ Following ${p.user.name}!')));
                  }
                }),
                _buildActionBtn(Icons.chat_bubble_outline, 'Message', isDark, () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => ChatScreen(user: p.user)),
                  );
                }),
                _buildActionBtn(Icons.card_giftcard, 'Gift', isDark, () {
                  Navigator.pop(ctx);
                  _openGiftDialog();
                }),
              ],
            ),
            
            // Admin Tools
            if (canManage && !isHostP) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              Text('Admin Tools', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (hasSeat)
                    _buildAdminBtn(isMuted ? Icons.mic : Icons.mic_off, isMuted ? 'Unmute' : 'Mute', Colors.orange, () {
                      isMuted ? provider.unmuteParticipant(p.user.id) : provider.muteParticipant(p.user.id);
                      Navigator.pop(ctx);
                    }),
                  if (hasSeat)
                    _buildAdminBtn(Icons.person_remove_alt_1, 'Kick Seat', Colors.redAccent, () {
                      provider.kickFromSeat(p.user.id);
                      Navigator.pop(ctx);
                    }),
                  if (canManage && !isModP)
                    _buildAdminBtn(Icons.shield_outlined, 'Make Mod', Colors.blue, () {
                      provider.promoteToModerator(p.user.id);
                      Navigator.pop(ctx);
                    }),
                  if (canManage && isModP)
                    _buildAdminBtn(Icons.remove_moderator, 'Remove Mod', Colors.blueGrey, () {
                      provider.demoteModerator(p.user.id);
                      Navigator.pop(ctx);
                    }),
                  _buildAdminBtn(Icons.block, 'Kick Room', Colors.red, () {
                    provider.removeParticipant(p.user.id);
                    Navigator.pop(ctx);
                  }),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAdminBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showStickerPanel(BuildContext context) {
    int selectedCategoryIndex = 0;
    final categories = ['Popular', 'Smileys', 'Stickers', 'Party'];

    final popularList = ['🔥', '👑', '🎉', '❤️', '👏', '💎', '🚀', '😍', '✨', '💯', '🎙️', '🎸', '🌟', '🏆'];
    final smileysList = ['😂', '😍', '😭', '😎', '🙏', '👍', '🥰', '🥳', '🤩', '😇', '🤔', '😴', '😳', '🥳'];
    final stickersList = ['🎁', '🌹', '👑', '💎', '🚀', '🏆', '🥇', '⚡', '💣', '💖', '⭐', '🎈', '🍾', '🎆'];
    final partyList = ['🎉', '🥳', '🍾', '🍻', '🍹', '🎧', '🎤', '🎷', '💃', '🕺', '🍿', '🎯', '💥', '✨'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPanelState) {
          List<String> activeList;
          switch (selectedCategoryIndex) {
            case 1:
              activeList = smileysList;
              break;
            case 2:
              activeList = stickersList;
              break;
            case 3:
              activeList = partyList;
              break;
            default:
              activeList = popularList;
          }

          return SafeArea(
            child: Container(
              height: 300,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header & Categories Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(categories.length, (idx) {
                        final isSel = selectedCategoryIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(categories[idx]),
                            selected: isSel,
                            selectedColor: Colors.pinkAccent,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              setPanelState(() => selectedCategoryIndex = idx);
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Grid
                  Expanded(
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: activeList.length,
                      itemBuilder: (context, index) {
                        final item = activeList[index];
                        return GestureDetector(
                          onTap: () {
                            _chatController.text += item;
                            Navigator.pop(context);
                          },
                          onLongPress: () {
                            // Quick send sticker immediately to room chat
                            final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                            final provider = Provider.of<LivePartyProvider>(context, listen: false);
                            provider.sendMessage(currentUser, item);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sent sticker $item to room!'),
                                duration: const Duration(milliseconds: 900),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(item, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }





  void _showSeatLockDialog(BuildContext context, LivePartyProvider provider) {
    final activeRoom = provider.activeRoom ?? widget.room;
    final totalSeats = activeRoom.seatCapacity;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (lCtx) => StatefulBuilder(
        builder: (context, setLockState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lock / Unlock Seats', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(lCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap a seat to lock or unlock it. Locked seats cannot be joined by listeners.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: totalSeats,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final isLocked = provider.isSeatLocked(index);
                        final isHostSeat = index == 0;

                        return GestureDetector(
                          onTap: isHostSeat
                              ? null
                              : () {
                                  provider.toggleSeatLock(index);
                                  setLockState(() {});
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isHostSeat
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : (isLocked ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isHostSeat
                                    ? Colors.amber
                                    : (isLocked ? Colors.redAccent : Colors.white24),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isHostSeat
                                      ? Icons.star_rounded
                                      : (isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
                                  color: isHostSeat ? Colors.amber : (isLocked ? Colors.redAccent : Colors.white60),
                                  size: 18,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isHostSeat ? 'Host' : 'Seat ${index + 1}',
                                  style: TextStyle(
                                    color: isHostSeat ? Colors.amber : (isLocked ? Colors.redAccent : Colors.white70),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
          );
        },
      ),
    );
  }

  void _showBackgroundPicker(BuildContext context) {
    final authUser = context.read<AuthProvider>().currentUser;
    final isHost = widget.room.host.id == authUser.id;
    final isAdmin = authUser.role == UserRole.admin || authUser.id == 'admin';
    final isAuthorized = isHost || isAdmin;

    if (!isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You don't have permission to change this room.")),
      );
      return;
    }

    final backgrounds = [
      {'name': 'Deep Cosmic Purple', 'colors': [const Color(0xFF2B1055), const Color(0xFF130924), const Color(0xFF080411)]},
      {'name': 'Midnight Galaxy', 'colors': [const Color(0xFF0A192F), const Color(0xFF020C1B), const Color(0xFF00050D)]},
      {'name': 'Cyberpunk Neon', 'colors': [const Color(0xFF3A0057), const Color(0xFF20002C), const Color(0xFF0D0014)]},
      {'name': 'Royal Emerald Gold', 'colors': [const Color(0xFF063025), const Color(0xFF031913), const Color(0xFF010A07)]},
      {'name': 'Sunset Horizon', 'colors': [const Color(0xFF4A121A), const Color(0xFF2B0A10), const Color(0xFF120306)]},
      {'name': 'Obsidian Stage', 'colors': [const Color(0xFF1A1A24), const Color(0xFF0F0F16), const Color(0xFF08080C)]},
      {'name': 'Aurora Borealis', 'colors': [const Color(0xFF003844), const Color(0xFF00242B), const Color(0xFF001114)]},
      {'name': 'Rose Quartz Luxury', 'colors': [const Color(0xFF4A0E2E), const Color(0xFF290518), const Color(0xFF14020B)]},
      {'name': 'Oceanic Abyss', 'colors': [const Color(0xFF0B2545), const Color(0xFF07172B), const Color(0xFF030B14)]},
      {'name': 'Tokyo Cyber Club', 'colors': [const Color(0xFF5E0B46), const Color(0xFF330426), const Color(0xFF170010)]},
      {'name': 'Sapphire Night', 'colors': [const Color(0xFF1B1B4B), const Color(0xFF0C0C27), const Color(0xFF050512)]},
      {'name': 'Velvet VIP Lounge', 'colors': [const Color(0xFF3D081B), const Color(0xFF23030E), const Color(0xFF0E0105)]},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Party Room Backgrounds', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(bCtx)),
                  ],
                ),
                const SizedBox(height: 12),
                // Gallery Upload Button with Paid Room Theme Fee integration (Module 02)
                Builder(
                  builder: (bCtx) {
                    final gameP = bCtx.watch<GameProvider>();
                    final authP = bCtx.read<AuthProvider>();
                    final userCountry = authP.currentUser.region.isNotEmpty ? authP.currentUser.region : 'Global';
                    final price = gameP.getCustomRoomThemeUploadPrice(userCountry);
                    final isPaid = price > 0;
                    final buttonLabel = isPaid 
                        ? 'Upload Wallpaper from Gallery • ${AppFormatters.formatNumber(price)} Coins'
                        : 'Upload Wallpaper from Gallery';

                    return GestureDetector(
                      onTap: () async {
                        final gameProv = bCtx.read<GameProvider>();
                        final walletProv = bCtx.read<WalletProvider>();
                        final authProv = bCtx.read<AuthProvider>();
                        final currentCountry = authProv.currentUser.region.isNotEmpty ? authProv.currentUser.region : 'Global';
                        final currentPrice = gameProv.getCustomRoomThemeUploadPrice(currentCountry);

                        if (currentPrice > 0) {
                          // 1. Show Confirmation Popup (Section 3 & Section 6)
                          final bool? confirmed = await showDialog<bool>(
                            context: bCtx,
                            builder: (c) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1B2E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text(
                                'Custom Room Theme Upload',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              content: Text(
                                'Cost: ${AppFormatters.formatNumber(currentPrice)} Coins\n\nDo you want to proceed with uploading a custom wallpaper?',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                                  child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return; // User cancelled, 0 coins deducted

                          // 2. Check Wallet Balance (Section 4 & Section 26)
                          if (walletProv.coins < currentPrice) {
                            if (bCtx.mounted) {
                              showDialog(
                                context: bCtx,
                                builder: (c) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1B2E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text(
                                    'Insufficient Coins',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  content: Text(
                                    'Required: ${AppFormatters.formatNumber(currentPrice)} Coins\nYour Balance: ${AppFormatters.formatNumber(walletProv.coins)} Coins',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(c);
                                        Navigator.push(bCtx, MaterialPageRoute(builder: (_) => const RechargeScreen()));
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                                      child: const Text('Recharge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return;
                          }

                          // 3. Process Payment safely & create transaction (Section 5, 11, 12, 13)
                          final payment = await gameProv.processRoomThemePayment(
                            walletProvider: walletProv,
                            userId: authProv.currentUser.id,
                            roomId: widget.room.id,
                            uploadType: 'Party Room Background',
                            userCountry: currentCountry,
                          );

                          if (payment['success'] != true) {
                            if (bCtx.mounted) {
                              ScaffoldMessenger.of(bCtx).showSnackBar(
                                const SnackBar(content: Text('Payment could not be completed. No coins were deducted.')),
                              );
                            }
                            return;
                          }

                          final String txId = payment['transactionId'] as String;

                          // 4. Open Gallery Picker (Section 11, Step 9)
                          try {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              setState(() {
                                _customBackgroundPath = image.path;
                              });
                              gameProv.completeRoomThemeUpload(txId);
                              if (bCtx.mounted) {
                                ScaffoldMessenger.of(bCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Custom Gallery Wallpaper Applied!'),
                                    backgroundColor: Colors.pinkAccent,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.pop(bCtx);
                              }
                            } else {
                              // User cancelled image selection -> Automatic refund! (Section 15 & 16)
                              await gameProv.refundRoomThemePayment(
                                walletProvider: walletProv,
                                transactionId: txId,
                                reason: 'Gallery image selection cancelled',
                              );
                              if (bCtx.mounted) {
                                ScaffoldMessenger.of(bCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('Upload cancelled. Your ${AppFormatters.formatNumber(currentPrice)} Coins have been refunded.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            // Upload error -> Automatic refund!
                            await gameProv.refundRoomThemePayment(
                              walletProvider: walletProv,
                              transactionId: txId,
                              reason: 'Image picker error: $e',
                            );
                            if (bCtx.mounted) {
                              ScaffoldMessenger.of(bCtx).showSnackBar(
                                SnackBar(content: Text('Upload failed. Your ${AppFormatters.formatNumber(currentPrice)} Coins have been refunded.')),
                              );
                            }
                          }
                        } else {
                          // Free upload path when paid uploads are disabled
                          try {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              setState(() {
                                _customBackgroundPath = image.path;
                              });
                              if (bCtx.mounted) {
                                ScaffoldMessenger.of(bCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Custom Gallery Wallpaper Applied!'),
                                    backgroundColor: Colors.pinkAccent,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.pop(bCtx);
                              }
                            }
                          } catch (e) {
                            if (bCtx.mounted) {
                              ScaffoldMessenger.of(bCtx).showSnackBar(
                                SnackBar(content: Text('Error picking image: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFFF4081)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.3), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                buttonLabel,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_customBackgroundPath != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _customBackgroundPath = null;
                      });
                      Navigator.pop(bCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restored Default Gradient Background')),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Reset to Gradient Presets', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Gradient Color Themes', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: backgrounds.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (context, idx) {
                      final bg = backgrounds[idx];
                      final colors = bg['colors'] as List<Color>;
                      final isSelected = _customBackgroundPath == null && _roomBackgroundGradient.first == colors.first;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _customBackgroundPath = null;
                            _roomBackgroundGradient = colors;
                          });
                          Navigator.pop(bCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✨ Applied ${bg['name']} Background!'),
                              backgroundColor: Colors.purpleAccent,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.white24,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 8)] : null,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                bg['name'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.amber : Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
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
      ),
    );
  }

  void _showCoverPicker(BuildContext context) {
    final provider = context.read<LivePartyProvider>();
    final activeRoom = provider.activeRoom ?? widget.room;

    final nichePresets = [
      {'niche': 'Gaming', 'icon': Icons.sports_esports_rounded, 'url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800'},
      {'niche': 'Music & Party', 'icon': Icons.music_note_rounded, 'url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800'},
      {'niche': 'Dating & Love', 'icon': Icons.favorite_rounded, 'url': 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=800'},
      {'niche': 'PK Battle', 'icon': Icons.flash_on_rounded, 'url': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800'},
      {'niche': 'Noble Palace', 'icon': Icons.shield_rounded, 'url': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800'},
      {'niche': 'SVIP Royalty', 'icon': Icons.workspace_premium_rounded, 'url': 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800'},
    ];

    final nobleTitles = [
      {'title': 'Emperor', 'icon': '👑', 'color': Colors.amber},
      {'title': 'Duke', 'icon': '🛡️', 'color': Colors.purpleAccent},
      {'title': 'Marquis', 'icon': '🎖️', 'color': Colors.cyanAccent},
      {'title': 'Earl', 'icon': '⚔️', 'color': Colors.deepOrangeAccent},
      {'title': 'Viscount', 'icon': '💎', 'color': Colors.pinkAccent},
      {'title': 'Knight', 'icon': '🌟', 'color': Colors.blueAccent},
      {'title': 'SVIP Royalty', 'icon': '⚡', 'color': Colors.amberAccent},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Room Picture & Niche Cover 🖼️', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(bCtx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Upload Custom Image from Gallery
                  GestureDetector(
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (image != null) {
                          provider.updateRoomDetails(coverUrl: image.path);
                          if (bCtx.mounted) {
                            Navigator.pop(bCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✨ Custom Room Cover Applied from Gallery! 📸'),
                                backgroundColor: Colors.purpleAccent,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (bCtx.mounted) {
                          ScaffoldMessenger.of(bCtx).showSnackBar(
                            SnackBar(content: Text('Error picking cover: $e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.3), blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Upload Room Cover from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text('Niche Cover Image Presets', style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // 2. Niche Category Cover Image Presets
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nichePresets.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, idx) {
                      final item = nichePresets[idx];
                      final isSelected = activeRoom.coverUrl == item['url'];

                      return GestureDetector(
                        onTap: () {
                          provider.updateRoomDetails(
                            coverUrl: item['url'] as String,
                            category: item['niche'] as String,
                          );
                          Navigator.pop(bCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✨ Niche Cover & Category updated to ${item['niche']}! 🎨'),
                              backgroundColor: Colors.purpleAccent,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.white24,
                              width: isSelected ? 2.5 : 1,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(item['url'] as String),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item['icon'] as IconData, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  item['niche'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),
                  const Text('Noble Titles & Royalty Badges', style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // 3. Noble Badges Selector
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: nobleTitles.map((noble) {
                      final isSelected = activeRoom.nobleTitle == noble['title'];

                      return GestureDetector(
                        onTap: () {
                          provider.updateRoomDetails(nobleTitle: noble['title'] as String);
                          Navigator.pop(bCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${noble['icon']} Noble Title updated to ${noble['title']}!'),
                              backgroundColor: Colors.amber,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? (noble['color'] as Color).withValues(alpha: 0.3) : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? (noble['color'] as Color) : Colors.white24,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(noble['icon'] as String, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                noble['title'] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.amberAccent : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final themes = [
      {'name': 'Cyber Neon', 'glow1': const Color(0xFF9C27B0), 'glow2': const Color(0xFFFF4081)},
      {'name': 'Royal Gold', 'glow1': const Color(0xFFFFB300), 'glow2': const Color(0xFFFF6F00)},
      {'name': 'Electric Ocean', 'glow1': const Color(0xFF00B0FF), 'glow2': const Color(0xFF00E5FF)},
      {'name': 'Emerald Mist', 'glow1': const Color(0xFF00E676), 'glow2': const Color(0xFF00BFA5)},
      {'name': 'Crimson Flame', 'glow1': const Color(0xFFFF1744), 'glow2': const Color(0xFFFF5252)},
      {'name': 'Amethyst Dream', 'glow1': const Color(0xFF8E24AA), 'glow2': const Color(0xFFBA68C8)},
      {'name': 'Sunset Glow', 'glow1': const Color(0xFFFF9100), 'glow2': const Color(0xFFFF4081)},
      {'name': 'Arctic Frost', 'glow1': const Color(0xFF00E5FF), 'glow2': const Color(0xFFE0F7FA)},
      {'name': 'Velvet Midnight', 'glow1': const Color(0xFF3F51B5), 'glow2': const Color(0xFF7E57C2)},
      {'name': 'Golden Sunburst', 'glow1': const Color(0xFFFFEA00), 'glow2': const Color(0xFFFFAB00)},
      {'name': 'Neon Matrix', 'glow1': const Color(0xFF76FF03), 'glow2': const Color(0xFF00E676)},
      {'name': 'Cosmic Nebula', 'glow1': const Color(0xFFD500F9), 'glow2': const Color(0xFF2979FF)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (tCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ambient Atmosphere Themes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(tCtx)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Select dynamic lighting & glow atmosphere', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: themes.length,
                    itemBuilder: (context, idx) {
                      final th = themes[idx];
                      final isSelected = _ambientGlowColor1 == th['glow1'];
                      final glow1 = th['glow1'] as Color;
                      final glow2 = th['glow2'] as Color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          tileColor: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: isSelected ? glow1 : Colors.white12, width: isSelected ? 1.5 : 1),
                          ),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [glow1, glow2]),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: glow1.withValues(alpha: 0.5), blurRadius: 8)],
                            ),
                          ),
                          title: Text(th['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20) : null,
                          onTap: () {
                            setState(() {
                              _ambientGlowColor1 = glow1;
                              _ambientGlowColor2 = glow2;
                            });
                            Navigator.pop(tCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✨ Applied ${th['name']} Theme!'), backgroundColor: glow1, duration: const Duration(seconds: 1)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMusicLibrary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (mCtx) => StatefulBuilder(
        builder: (context, setMusicModalState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🎧 Room Music Library', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(mCtx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Host Add Music from Storage Button
                    GestureDetector(
                      onTap: () {
                        _showImportMusicDialog(context, setMusicModalState);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.deepPurpleAccent]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.3), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.library_music_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Import Music from Storage / Gallery',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Volume Slider
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, color: Colors.white70, size: 18),
                        Expanded(
                          child: Slider(
                            value: _musicVolume,
                            activeColor: Colors.pinkAccent,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() => _musicVolume = val);
                              setMusicModalState(() {});
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _musicPlaylist.length,
                        itemBuilder: (context, idx) {
                          final song = _musicPlaylist[idx];
                          final isPlaying = _currentTrackIndex == idx && _isPlayingMusic;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              tileColor: isPlaying ? Colors.pinkAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: isPlaying ? Colors.pinkAccent : Colors.transparent),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPlaying ? Colors.pinkAccent : Colors.white12,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded, color: Colors.white, size: 18),
                              ),
                              title: Text(song['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${song['genre']} • ${song['duration']}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                              trailing: IconButton(
                                icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.pinkAccent, size: 28),
                                onPressed: () {
                                  setState(() {
                                    if (_currentTrackIndex == idx) {
                                      _isPlayingMusic = !_isPlayingMusic;
                                    } else {
                                      _currentTrackIndex = idx;
                                      _isPlayingMusic = true;
                                    }
                                  });
                                  setMusicModalState(() {});
                                },
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
    );
  }

  void _showImportMusicDialog(BuildContext context, StateSetter setParentState) {
    final titleController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.sd_storage_rounded, color: Colors.pinkAccent, size: 22),
              SizedBox(width: 8),
              Text('Host Audio Storage', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select audio file from phone storage:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  
                  // Real System Audio File Picker Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isUploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.folder_open_rounded, size: 20),
                      label: Text(
                        isUploading ? 'Uploading Audio Track...' : 'Browse Phone Audio (MP3, M4A, WAV)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              try {
                                setDialogState(() => isUploading = true);
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['mp3', 'm4a', 'wav', 'flac'],
                                );

                                if (result != null && result.files.single.path != null) {
                                  final pickedFile = result.files.single;
                                  final filePath = pickedFile.path!;
                                  final fileName = pickedFile.name;
                                  final cleanTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

                                  // Upload file via MediaUploadService
                                  final uploadRes = await MediaUploadService.instance.uploadFile(
                                    filePath: filePath,
                                    folder: 'room_music',
                                  );

                                  if (mounted) {
                                    setState(() {
                                      _musicPlaylist.add({
                                        'title': cleanTitle,
                                        'genre': 'Device Music',
                                        'duration': '3:45',
                                        'url': uploadRes.url.isNotEmpty ? uploadRes.url : filePath,
                                      });
                                      _currentTrackIndex = _musicPlaylist.length - 1;
                                      _isPlayingMusic = true;
                                    });
                                    setParentState(() {});
                                    Navigator.pop(dCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('🎵 Playing Imported Audio: $cleanTitle'),
                                        backgroundColor: Colors.pinkAccent,
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() => isUploading = false);
                                }
                              } catch (e) {
                                setDialogState(() => isUploading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('❌ Failed to import audio: $e'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),

                  const Text('Or Enter Custom Track Title:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. My Favorite Banger',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  setState(() {
                    _musicPlaylist.add({
                      'title': title,
                      'genre': 'Custom Track',
                      'duration': '3:30',
                    });
                    _currentTrackIndex = _musicPlaylist.length - 1;
                    _isPlayingMusic = true;
                  });
                  setParentState(() {});
                  Navigator.pop(dCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎵 Added "$title" to playlist!')),
                  );
                }
              },
              child: const Text('Add & Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sCtx) => StatefulBuilder(
        builder: (context, setSettingsState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('⚙️ Advanced Room Controls', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(sCtx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      activeThumbColor: Colors.pinkAccent,
                      title: const Text('Auto-Mute New Speakers', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('New participants enter muted by default', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                      value: _autoMuteNewSpeakers,
                      onChanged: (val) {
                        setState(() => _autoMuteNewSpeakers = val);
                        setSettingsState(() {});
                      },
                    ),
                    SwitchListTile(
                      activeThumbColor: Colors.pinkAccent,
                      title: const Text('Allow Viewer Seat Requests', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('Audience members can request to take mic', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                      value: _allowSeatRequests,
                      onChanged: (val) {
                        setState(() => _allowSeatRequests = val);
                        setSettingsState(() {});
                      },
                    ),
                    SwitchListTile(
                      activeThumbColor: Colors.pinkAccent,
                      title: const Text('Ultra HD Audio Engine', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('Enable stereo studio acoustics & spatial sound', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                      value: _hdAudioMode,
                      onChanged: (val) {
                        setState(() => _hdAudioMode = val);
                        setSettingsState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('🎉 Stage Audio Soundboard (Broadcast to Room)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Responsive Soundboard Grid
                    Row(
                      children: [
                        Expanded(child: _soundboardBtn('👏 Applause', () => _broadcastSoundEffect('clapped for the room 👏✨'))),
                        const SizedBox(width: 8),
                        Expanded(child: _soundboardBtn('🎺 Fanfare', () => _broadcastSoundEffect('played Victory Fanfare 🎺🔥'))),
                        const SizedBox(width: 8),
                        Expanded(child: _soundboardBtn('🎉 Cheer', () => _broadcastSoundEffect('triggered Party Cheer 🎉🥳'))),
                        const SizedBox(width: 8),
                        Expanded(child: _soundboardBtn('😂 Laugh', () => _broadcastSoundEffect('shared a Laugh 😂🙌'))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _soundboardBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _broadcastSoundEffect(String actionText) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final provider = Provider.of<LivePartyProvider>(context, listen: false);
    provider.sendMessage(user, actionText);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sound Effect: $actionText'),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRoomToolBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    String? imageAsset,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageAsset != null)
            SizedBox(
              width: 52,
              height: 52,
              child: ClipOval(
                child: Image.asset(
                  imageAsset,
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showManagementPanel(BuildContext ctx, bool isDark, LivePartyProvider provider) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (mCtx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (bCtx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF18132B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 20)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Room Management', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('${provider.participants.length} Active in Party', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            for (var p in provider.participants) {
                              if (p.role != ParticipantRole.host) {
                                provider.muteParticipant(p.user.id);
                              }
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('All participants muted 🔇')));
                          },
                          icon: const Icon(Icons.volume_off_rounded, size: 16, color: Colors.orangeAccent),
                          label: const Text('Mute All', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),
                  ],
                ),
              ),
              Expanded(
                child: provider.participants.isEmpty
                    ? const Center(child: Text('No participants yet', style: TextStyle(color: Colors.white60)))
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: provider.participants.length,
                        separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, i) {
                          final p = provider.participants[i];
                          final pIsHost = p.role == ParticipantRole.host;
                          final pIsMod = p.role == ParticipantRole.moderator;
                          final pMuted = p.micStatus == MicStatus.muted;
                          final onSeat = p.seatNumber != null;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            leading: UserAvatarWithStatus(imageUrl: p.user.avatarUrl, radius: 20, isOnline: true),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.user.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (pIsHost)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                if (pIsMod)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('MOD', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              onSeat ? 'Seat ${p.seatNumber! + 1} • @${p.user.username}' : 'Audience • @${p.user.username}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!pIsHost) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (pMuted) {
                                        provider.unmuteParticipant(p.user.id);
                                      } else {
                                        provider.muteParticipant(p.user.id);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: pMuted ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: pMuted ? Colors.red : Colors.green, width: 1),
                                      ),
                                      child: Icon(pMuted ? Icons.mic_off : Icons.mic, size: 16, color: pMuted ? Colors.red : Colors.green),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(mCtx);
                                      _confirmRemove(ctx, p, provider);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.person_remove, size: 16, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: pIsHost ? null : () => _showParticipantSheet(ctx, p, provider, isDark, true),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext ctx2, PartyParticipantModel p, LivePartyProvider prov) {
    showDialog(
      context: ctx2,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${p.user.name}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('They will be kicked out of the party room.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(d);
              prov.removeParticipant(p.user.id);
              ScaffoldMessenger.of(ctx2).showSnackBar(
                SnackBar(content: Text('Removed ${p.user.name} from party')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Module 06: YouTube Shared Control Dialog ──
  void _showYouTubeControlDialog(BuildContext context) {
    final provider = context.read<LivePartyProvider>();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('YouTube Shared Stream', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.youtubeVideoId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active: ${provider.youtubeTitle}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(provider.youtubePlayState == 'playing' ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.amber, size: 36),
                    onPressed: () {
                      provider.setYouTubePlayState(provider.youtubePlayState == 'playing' ? 'paused' : 'playing');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 36),
                    onPressed: () {
                      provider.stopYouTubeTrack();
                      Navigator.pop(d);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
            ],
            const Text('Enter YouTube Link or Search Query:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final query = urlController.text.trim();
              if (query.isNotEmpty) {
                final videoId = query.contains('v=') ? query.split('v=').last.split('&').first : 'dQw4w9WgXcQ';
                final sessionId = 'yt_${DateTime.now().millisecondsSinceEpoch}';
                provider.startYouTubeTrack(videoId: videoId, title: query.length > 20 ? '${query.substring(0, 18)}...' : query, sessionId: sessionId);
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🎉 YouTube video synchronized to room!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Start Playback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Module 06: Super Wheel Control Dialog ──
  void _showSuperWheelControlDialog(BuildContext context) {
    final provider = context.read<LivePartyProvider>();

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.casino_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Super Wheel Game Control', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Spin the Super Wheel for all room members! Results & rewards are server-calculated.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            if (provider.lastSuperWheelResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Column(
                  children: [
                    const Text('Last Winner Result:', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${provider.lastSuperWheelResult!['prize']['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              final authUser = context.read<AuthProvider>().currentUser;
              final sessionId = 'spin_${DateTime.now().millisecondsSinceEpoch}';
              final res = provider.spinSuperWheelServer(userId: authUser.id, sessionId: sessionId, costCoins: 100);
              Navigator.pop(d);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🎉 Super Wheel Spun! Winner won: ${res['prize']['name']}'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Spin Super Wheel 🎰', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Module 06: Lucky Bag Control Dialog ──
  void _showLuckyBagControlDialog(BuildContext context) {
    final provider = context.read<LivePartyProvider>();
    final coinsCtrl = TextEditingController(text: '1000');
    final claimsCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Create Lucky Bag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: coinsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total Coin Amount 🪙',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: claimsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Claims / Users 👥',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              final coins = int.tryParse(coinsCtrl.text.trim()) ?? 1000;
              final claims = int.tryParse(claimsCtrl.text.trim()) ?? 10;
              final bagId = 'bag_${DateTime.now().millisecondsSinceEpoch}';
              final err = provider.createLuckyBag(id: bagId, totalCoins: coins, totalClaims: claims);
              if (err == null) {
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('💰 Lucky Bag of $coins Coins launched for $claims users!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Launch Lucky Bag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Module 06: Lock Room Access Control Dialog ──
  void _showLockRoomControlDialog(BuildContext context) {
    final provider = context.read<LivePartyProvider>();
    final pinCtrl = TextEditingController(text: provider.roomPinCode);
    String selectedMode = provider.roomLockMode;

    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(provider.isRoomLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              const Text('Room Lock Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lock Room Status', style: TextStyle(color: Colors.white, fontSize: 14)),
                  Switch(
                    value: provider.isRoomLocked,
                    activeThumbColor: Colors.cyanAccent,
                    onChanged: (val) {
                      provider.configureRoomLock(isLocked: val, mode: selectedMode, pin: pinCtrl.text);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Access Protection Mode:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['PIN', 'Approval'].map((mode) {
                  final isSel = selectedMode == mode;
                  return ChoiceChip(
                    label: Text(mode, style: TextStyle(color: isSel ? Colors.black : Colors.white)),
                    selected: isSel,
                    selectedColor: Colors.cyanAccent,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          selectedMode = mode;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              if (selectedMode == 'PIN') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '4-Digit Password / PIN',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              onPressed: () {
                provider.configureRoomLock(
                  isLocked: true,
                  mode: selectedMode,
                  pin: pinCtrl.text.trim().isEmpty ? '1234' : pinCtrl.text.trim(),
                );
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔒 Room access configured successfully!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save Lock Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCover(String coverUrl) {
    if (coverUrl.startsWith('http')) {
      return Image.network(
        coverUrl,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 42,
          height: 42,
          color: Colors.purple.withValues(alpha: 0.5),
          child: const Icon(Icons.music_note, color: Colors.white, size: 20),
        ),
      );
    } else if (coverUrl.startsWith('assets')) {
      return Image.asset(coverUrl, width: 42, height: 42, fit: BoxFit.cover);
    } else {
      final file = File(coverUrl);
      if (file.existsSync()) {
        return Image.file(file, width: 42, height: 42, fit: BoxFit.cover);
      }
      return Container(
        width: 42,
        height: 42,
        color: Colors.purple.withValues(alpha: 0.5),
        child: const Icon(Icons.music_note, color: Colors.white, size: 20),
      );
    }
  }
}

