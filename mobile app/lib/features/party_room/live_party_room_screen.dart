import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/live_party_provider.dart';
import '../../core/utils/formatters.dart';
import '../recharge/recharge_screen.dart';
import '../../models/party_participant_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/tiktok_gift_overlay.dart';
import '../../providers/live_gift_provider.dart';
import '../games/rocket_game_sheet.dart';
import '../games/game_center_sheet.dart';
import '../pk_battle/pk_match_screen.dart';
import 'widgets/room_info_sheet.dart';
import 'widgets/room_type_selector_sheet.dart';
import 'widgets/room_entry_announcement_banner.dart';
import 'widgets/room_entry_mount_banner.dart';
import '../../core/utils/noble_badge_helper.dart';
import 'widgets/effects_settings_sheet.dart';
import 'widgets/mic_seat_management_sheet.dart';
import 'widgets/in_room_profile_card_sheet.dart';
import 'widgets/expanded_message_panel.dart';
import '../../widgets/multi_role_seat_grid.dart';
import '../../widgets/svip_entry_banner.dart';
import '../live/widgets/high_value_announcement.dart';
import '../messages/chat_screen.dart';
import '../../widgets/emoji_reaction_overlay.dart';
import '../../providers/emoji_reaction_provider.dart';
import '../profile/user_profile_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _roomEntrySessionId = 'session_${widget.room.id}_${DateTime.now().millisecondsSinceEpoch}';
    _requestMicPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      Provider.of<LivePartyProvider>(context, listen: false).joinParty(widget.room, user);
      Provider.of<EmojiReactionProvider>(context, listen: false).setActiveRoom(widget.room.id);
      Provider.of<LiveGiftProvider>(context, listen: false).setActiveRoom(widget.room.id);
      
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
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _leaveRoom() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Party?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to leave this party room?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Stay', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(d);
              Provider.of<LivePartyProvider>(context, listen: false).leaveParty();
              Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _toggleMic() {
    final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
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
        content: Text(_isMicMuted ? 'Mic Muted 🔇' : 'Mic Live 🎙️'),
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

      final participant = partyProv.participants.where((p) => p.user.id == user.id && p.seatNumber != null).firstOrNull;
      final seatId = participant?.seatNumber;

      Provider.of<EmojiReactionProvider>(context, listen: false).sendReaction(
        roomId: widget.room.id,
        senderId: user.id,
        emoji: text,
        seatId: seatId,
        senderName: user.name,
      );

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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      body: Stack(
        children: [
          // TikTok Live Gifting Overlay
          TikTokGiftOverlay(roomId: widget.room.id),
          // Ambient Gradient or Custom Background Image
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                image: _customBackgroundPath != null
                    ? DecorationImage(
                        image: FileImage(File(_customBackgroundPath!)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.5),
                          BlendMode.darken,
                        ),
                      )
                    : null,
                gradient: _customBackgroundPath == null
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _roomBackgroundGradient,
                      )
                    : null,
              ),
            ),
          ),

          // Realtime Animated Emoji Reaction Overlay Layer
          EmojiReactionOverlay(roomId: widget.room.id),

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
            child: Column(
              children: [
                // Top Header
                _buildHeader(context, isHost, canManage, provider),

                // PK Battle Banner (If Active)
                if (provider.isPkActive) _buildPkBanner(provider),

                // 14-Seat Audio Stage (Responsive to prevent overflow)
                Flexible(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Center(
                      child: _buildStageGrid(provider, currentUser, canManage, isDark),
                    ),
                  ),
                ),

                // ── Module 31 Final Correction Anchor: Placed BELOW lowest mic/seat-name boundary ──
                // SVIP Entry Banner Strip
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

                // Room Entry Announcement Banner (Module 03)
                RoomEntryAnnouncementBanner(
                  roomId: widget.room.id,
                  roomEntrySessionId: _roomEntrySessionId,
                  isDark: isDark,
                ),

                // Live Chat Feed pushed to bottom, auto-shrinks on keyboard
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _buildChatFeed(provider),
                      ),
                    ],
                  ),
                ),

                // Bottom Controls
                _buildBottomBar(canManage, isHost, provider, isDark),
              ],
            ),
          ),

          // Right-side Floating Action Shortcuts (Rocket Game & Game Lobby) - Higher position above chat feed
          Positioned(
            right: 14,
            bottom: 270,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rocket Game Floating Icon
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const RocketGameSheet(),
                    );
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF4081), Color(0xFF7C4DFF)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(height: 12),

                // Game Center Lobby Icon
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => GameCenterSheet.show(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // Onscreen 3D Gift Animation Overlay
          GiftAnimationOverlay(key: _giftOverlayKey),
        ],
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.5),
                                        ),
                                        child: Text(
                                          '👑 ${activeRoom.nobleTitle}',
                                          style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'ID:${activeRoom.id.length > 6 ? activeRoom.id.substring(0, 6) : activeRoom.id} • 👥 ${provider.participants.length}',
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
          
          const SizedBox(width: 12),
          
          // Right: Controls
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy & Points
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  const Text('373M', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 14),
              
              // Room Tools Button (Accessible to all users with role-aware options)
              GestureDetector(
                onTap: () => _showRoomTools(context, canManage, isHost, provider, Theme.of(context).brightness == Brightness.dark),
                child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              
              // Close X
              GestureDetector(
                onTap: _leaveRoom,
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
              ),
            ],
          ),
        ],
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
      onSeatTap: (index) {
        if (canManage) {
          MicSeatManagementSheet.show(
            context,
            micIndex: index,
            occupant: null,
            isLocked: provider.isSeatLocked(index),
            isMuted: false,
          );
          return;
        }

        if (provider.isSeatLocked(index)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seat is locked by Host 🔒')),
          );
          return;
        }
        provider.takeSeat(currentUser, index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined Seat ${index + 1} 🎙️'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Widget _buildChatFeed(LivePartyProvider provider) {
    return ListView.builder(
      controller: _chatScrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final msg = provider.messages.reversed.toList()[index];
        final isSystem = msg.sender.id == 'system';
        final isHostMsg = msg.sender.id == widget.room.host.id;
        
        final participantInfo = provider.participants.where((p) => p.user.id == msg.sender.id).firstOrNull;
        final isMod = participantInfo?.role == ParticipantRole.moderator;
        final isVip = msg.sender.wealthLevel >= 10; // Mock VIP logic based on level

        if (isSystem) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          );
        }

        final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
        final isHost = widget.room.host.id == currentUser.id;
        final canManage = isHost || provider.participants.any((p) => p.user.id == currentUser.id && p.role == ParticipantRole.moderator);

        // ── Module 05: Gift Activity Message Custom Renderer ──
        if (msg.isGiftMessage && msg.receiver != null) {
          final senderPart = provider.participants.where((p) => p.user.id == msg.sender.id).firstOrNull ??
              PartyParticipantModel(user: msg.sender, joinedAt: DateTime.now());
          final receiverPart = provider.participants.where((p) => p.user.id == msg.receiver!.id).firstOrNull ??
              PartyParticipantModel(user: msg.receiver!, joinedAt: DateTime.now());

          final senderName = msg.sender.name.length > 18 ? '${msg.sender.name.substring(0, 15)}...' : msg.sender.name;
          final receiverName = msg.receiver!.name.length > 18 ? '${msg.receiver!.name.substring(0, 15)}...' : msg.receiver!.name;
          final giftName = msg.giftName ?? 'Gift';
          final giftIcon = msg.giftIcon ?? '🌹';
          final qty = msg.quantity ?? 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade900.withValues(alpha: 0.6),
                    Colors.pink.shade900.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.2), blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showParticipantSheet(context, senderPart, provider, Theme.of(context).brightness == Brightness.dark, canManage),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(msg.sender.avatarUrl),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: senderName,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showParticipantSheet(context, senderPart, provider, Theme.of(context).brightness == Brightness.dark, canManage),
                          ),
                          TextSpan(
                            text: ' sent $qty × $giftName $giftIcon to ',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          TextSpan(
                            text: receiverName,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showParticipantSheet(context, receiverPart, provider, Theme.of(context).brightness == Brightness.dark, canManage),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            final participant = provider.participants.where((p) => p.user.id == msg.sender.id).firstOrNull ??
                PartyParticipantModel(user: msg.sender, joinedAt: DateTime.now());
            _showParticipantSheet(context, participant, provider, Theme.of(context).brightness == Brightness.dark, canManage);
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(msg.sender.avatarUrl),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHostMsg
                          ? const Color(0xFF8A2387).withValues(alpha: 0.35)
                          : (isMod ? Colors.blue.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.45)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHostMsg
                            ? Colors.amber.withValues(alpha: 0.3)
                            : (isMod ? Colors.blue.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          if (isHostMsg)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Host', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else if (isMod)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Admin', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else if (isVip)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.purple, Colors.pink]), borderRadius: BorderRadius.circular(4)),
                                child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: NobleBadgeChip(user: msg.sender, fontSize: 8),
                          ),
                          TextSpan(
                            text: '${msg.sender.name}: ',
                            style: TextStyle(
                              color: NobleBadgeHelper.getColoredNicknameColor(
                                NobleBadgeHelper.getTierFromTitle(msg.sender.nobleTitle),
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: msg.text,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
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
      },
    );
  }

  Widget _buildBottomBar(bool canManage, bool isHost, LivePartyProvider provider, bool isDark) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF140D24).withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            // ── Far Left: Standalone "+" Options Button ──
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => _showRoomTools(context, canManage, isHost, provider, isDark),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'More Options',
            ),
            const SizedBox(width: 10),

            // ── Center: WhatsApp Dark Pill Input Field ──
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
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
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendChatMessage(),
                        onChanged: (val) {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    
                    // Emoji Face Logo Icon (Amber Gold)
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.amber, size: 22),
                      onPressed: () => _showStickerPanel(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Emojis & Stickers',
                    ),

                    if (_chatController.text.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFFFF416C), size: 20),
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
            const SizedBox(width: 10),

            // ── Far Right Action Icons (Gift & Microphone) ──
            if (!isKeyboardOpen) ...[
              // Gift Icon Button (Pink Accent)
              IconButton(
                icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF4081), size: 25),
                onPressed: _openGiftDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Send Gift',
              ),
              const SizedBox(width: 12),

              // Microphone Toggle Button (Green when Active, Red when Muted)
              IconButton(
                icon: Icon(
                  (provider.isRoomMuted || _isMicMuted) ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: (provider.isRoomMuted || _isMicMuted) ? Colors.redAccent : const Color(0xFF00E676),
                  size: 25,
                ),
                onPressed: _toggleMic,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: (provider.isRoomMuted || _isMicMuted) ? 'Unmute Mic' : 'Mute Mic',
              ),
            ],
          ],
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
                      _buildRoomToolBtn(_isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded, _isMicMuted ? 'Unmute Mic' : 'Mute Mic', _isMicMuted ? Colors.redAccent : Colors.green, () {
                        Navigator.pop(ctx);
                        _toggleMic();
                      }),
                      _buildRoomToolBtn(provider.isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, provider.isSpeakerMuted ? 'Unmute Room' : 'Mute Room', provider.isSpeakerMuted ? Colors.redAccent : Colors.cyan, () {
                        Navigator.pop(ctx);
                        provider.toggleSpeakerOutput();
                      }),
                      _buildRoomToolBtn(Icons.card_giftcard_rounded, 'Send Gift', Colors.pinkAccent, () {
                        Navigator.pop(ctx);
                        _openGiftDialog();
                      }),
                      _buildRoomToolBtn(Icons.rocket_launch_rounded, 'Rocket Game', Colors.indigoAccent, () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const RocketGameSheet(),
                        );
                      }),
                      _buildRoomToolBtn(Icons.dashboard_customize_rounded, 'Room Type', Colors.amber, () {
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
                      }),
                      if (isHost)
                        _buildRoomToolBtn(Icons.flash_on_rounded, provider.isPkActive ? 'End PK' : 'PK Match', Colors.deepOrangeAccent, () {
                          Navigator.pop(ctx);
                          if (provider.isPkActive) {
                            provider.endPk();
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PkMatchScreen()));
                          }
                        }),
                      if (canManage)
                        _buildRoomToolBtn(Icons.group_rounded, 'Members', Colors.teal, () {
                          Navigator.pop(ctx);
                          _showManagementPanel(context, isDark, provider);
                        }),
                      if (canManage)
                        _buildRoomToolBtn(Icons.lock_rounded, 'Lock Seats', Colors.redAccent, () {
                          Navigator.pop(ctx);
                          _showSeatLockDialog(context, provider);
                        }),
                      _buildRoomToolBtn(Icons.wallpaper_rounded, 'Backgrounds', Colors.blue, () {
                        Navigator.pop(ctx);
                        _showBackgroundPicker(context);
                      }),
                      _buildRoomToolBtn(Icons.add_photo_alternate_rounded, 'Change Cover', Colors.purpleAccent, () {
                        Navigator.pop(ctx);
                        _showCoverPicker(context);
                      }),
                      _buildRoomToolBtn(Icons.palette_outlined, 'Themes', Colors.purple, () {
                        Navigator.pop(ctx);
                        _showThemePicker(context);
                      }),
                      _buildRoomToolBtn(Icons.music_note_rounded, 'Music Player', Colors.pink, () {
                        Navigator.pop(ctx);
                        _showMusicLibrary(context);
                      }),
                      _buildRoomToolBtn(Icons.auto_awesome_rounded, 'Effects Settings', Colors.amberAccent, () {
                        Navigator.pop(ctx);
                        EffectsSettingsSheet.show(context);
                      }),
                      _buildRoomToolBtn(Icons.campaign_rounded, 'Announcement', Colors.amber, () {
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
                      }),
                      _buildRoomToolBtn(Icons.settings_suggest_outlined, 'Settings', Colors.orange, () {
                        Navigator.pop(ctx);
                        _showRoomSettings(context);
                      }),
                      if (canManage) ...[
                        _buildRoomToolBtn(Icons.play_circle_fill_rounded, 'YouTube', Colors.redAccent, () {
                          Navigator.pop(ctx);
                          _showYouTubeControlDialog(context);
                        }),
                        _buildRoomToolBtn(Icons.casino_rounded, 'Super Wheel', Colors.amberAccent, () {
                          Navigator.pop(ctx);
                          _showSuperWheelControlDialog(context);
                        }),
                        _buildRoomToolBtn(Icons.card_giftcard_rounded, 'Lucky Bag', Colors.orangeAccent, () {
                          Navigator.pop(ctx);
                          _showLuckyBagControlDialog(context);
                        }),
                        _buildRoomToolBtn(Icons.lock_rounded, 'Lock Room', Colors.cyanAccent, () {
                          Navigator.pop(ctx);
                          _showLockRoomControlDialog(context);
                        }),
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
    final localFiles = [
      {'name': 'Club_Banger_2026.mp3', 'genre': 'Phone Storage / Music', 'duration': '3:45'},
      {'name': 'Acoustic_Guitar_Vibe.wav', 'genre': 'Downloads / Audio', 'duration': '2:30'},
      {'name': 'Podcast_Intro_Session.m4a', 'genre': 'Device Recordings', 'duration': '1:50'},
      {'name': 'Deep_Bass_Drop.flac', 'genre': 'Storage / ZeParty', 'duration': '4:10'},
    ];

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
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
                const SizedBox(height: 10),
                ...localFiles.map((file) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.audio_file_rounded, color: Colors.pinkAccent),
                    title: Text(file['name']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('${file['genre']} • ${file['duration']}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                    trailing: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent, size: 20),
                    onTap: () {
                      setState(() {
                        _musicPlaylist.add({
                          'title': file['name']!.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
                          'genre': 'Device Storage',
                          'duration': file['duration']!,
                        });
                        _currentTrackIndex = _musicPlaylist.length - 1;
                        _isPlayingMusic = true;
                      });
                      setParentState(() {});
                      Navigator.pop(dCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎵 Playing Imported Track: ${file['name']}'),
                          backgroundColor: Colors.pinkAccent,
                        ),
                      );
                    },
                  ),
                )),
                const SizedBox(height: 12),
                const Text('Or Enter Custom Track Title:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. My Favorite Song',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _musicPlaylist.add({
                    'title': title,
                    'genre': 'Local Audio',
                    'duration': '3:30',
                  });
                  _currentTrackIndex = _musicPlaylist.length - 1;
                  _isPlayingMusic = true;
                });
                setParentState(() {});
                Navigator.pop(dCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🎵 Playing "$title" for the room!')),
                );
              }
            },
            child: const Text('Add & Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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

  Widget _buildRoomToolBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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

