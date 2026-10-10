import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/noble_badge_helper.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/medal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/svip_provider.dart';
import '../../providers/social_provider.dart';
import '../party_room/live_party_room_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_list_sheet.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/gift_dialog.dart';

import '../../core/repositories/social_repository.dart';
import '../../core/services/api_client.dart';
import '../../models/live_room_model.dart';
import '../live/live_room_screen.dart';

import '../svip/svip_center_screen.dart';
import '../aristocracy/aristocracy_center_screen.dart';
// store_screen import removed (unused)
import '../messages/chat_screen.dart';
import '../settings/edit_profile_screen.dart';
import 'level_center_screen.dart';
import 'modules/medal_screen.dart';
import 'modules/relationship_screen.dart';
import 'visitors_screen.dart';
import '../../widgets/report_sheet.dart';

class UserProfileDetailsScreen extends StatefulWidget {
  final String userId;
  final UserModel? user;

  UserProfileDetailsScreen({super.key, String? userId, this.user})
      : userId = userId ?? user?.id ?? '';

  @override
  State<UserProfileDetailsScreen> createState() => _UserProfileDetailsScreenState();
}

class _ExpandedMessagePlayerState extends State<_ExpandedMessagePlayer> {
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => isPlaying = !isPlaying),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.onPrimary(isDark: isDark),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Waveform bars
          Row(
            children: List.generate(14, (i) {
              final heights = [8, 14, 22, 10, 18, 26, 12, 20, 16, 24, 10, 18, 12, 8];
              return Container(
                width: 3,
                height: heights[i % heights.length].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: isPlaying ? AppColors.getPrimary(isDark) : AppColors.getMuted(isDark),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          Text('12"', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ExpandedMessagePlayer extends StatefulWidget {
  const _ExpandedMessagePlayer();

  @override
  State<_ExpandedMessagePlayer> createState() => _ExpandedMessagePlayerState();
}

class _UserProfileDetailsScreenState extends State<UserProfileDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  UserModel? _user;

  bool get _isMe {
    final currentId = context.read<AuthProvider>().currentUser.id;
    final targetId = _user?.id ?? widget.userId;
    return currentId.isNotEmpty && currentId == targetId;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.user != null) {
      _user = widget.user;
    }
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    var user = await auth.getUserById(widget.userId);
    if (user != null && user.id.isNotEmpty && user.id != auth.currentUser.id) {
      try {
        SocialRepository.instance.recordProfileVisit(user.id);
        final profileRes = await SocialRepository.instance.getSocialProfile(user.id);
        final profileData = profileRes['data'] is Map<String, dynamic> ? profileRes['data'] as Map<String, dynamic> : profileRes;
        final isFollowing = profileData['isFollowing'] == true;
        final fCount = profileData['followersCount'] is int ? profileData['followersCount'] as int : user.followers;
        final followingCount = profileData['followingCount'] is int ? profileData['followingCount'] as int : user.following;
        user = user.copyWith(
          followers: fCount,
          following: followingCount,
          isPrivate: profileData['isPrivate'] == true,
        );
        if (isFollowing && !auth.isFollowing(user.id)) {
          auth.syncFollowingList();
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _openUserActiveRoom(BuildContext context, String? roomId) async {
    final effectiveRoomId = roomId ?? _user?.liveRoomId;
    if (effectiveRoomId == null || effectiveRoomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active room found for this user.')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      LiveRoomModel? targetRoom;
      try {
        final res = await ApiClient.instance.get<Map<String, dynamic>>('/v1/rooms/$effectiveRoomId');
        final data = res.data?['data'];
        if (data is Map<String, dynamic>) {
          targetRoom = LiveRoomModel.fromJson(data);
        }
      } catch (e) {
        debugPrint('[UserProfile] Error fetching room details: $e');
      }

      if (context.mounted) Navigator.pop(context); // pop loading

      targetRoom ??= LiveRoomModel(
        id: effectiveRoomId,
        title: '${_user?.displayName ?? 'User'}\'s Room',
        host: _user ?? UserModel.empty,
        coverUrl: _user?.avatarUrl ?? '',
        viewerCount: 1,
        startTime: DateTime.now(),
        roomType: 'AUDIO_PARTY',
        category: 'party',
        status: 'LIVE',
      );

      final isVoiceParty = targetRoom.roomType == 'AUDIO_PARTY' ||
          targetRoom.roomType == 'AUDIO' ||
          targetRoom.category.toLowerCase() == 'party' ||
          targetRoom.id.startsWith('party_');

      if (!context.mounted) return;

      if (isVoiceParty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: targetRoom!)),
        ).then((_) {
          if (mounted) _loadUser();
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LiveRoomScreen(room: targetRoom!)),
        ).then((_) {
          if (mounted) _loadUser();
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open room: $e')),
        );
      }
    }
  }

  // Diagram C & Section 12: Three-Dot Safety Menu (REPORT â†’ BLOCK â†’ CANCEL)
  void _showOverflowMenu(BuildContext context, bool isOtherUser, bool isDark, AuthProvider auth) {
    if (!isOtherUser) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => const EditProfileScreen()),
      ).then((_) {
        if (mounted) _loadUser();
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 1. REPORT ACTION (Section 12 & Diagram C)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 20),
                ),
                title: Text(
                  'REPORT',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                subtitle: const Text('Report inappropriate content or policy violations', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(context, isDark);
                },
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),

              // 2. BLOCK ACTION (Section 12 & Diagram C)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                ),
                title: const Text(
                  'BLOCK',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: const Text('Prevent interaction, messages, and content sharing', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlockConfirmDialog(context, isDark, auth);
                },
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),

              // 3. CANCEL ACTION (Section 12 & Diagram C)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getMuted(isDark).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: AppColors.getTextSecondary(isDark), size: 20),
                ),
                title: Text(
                  'CANCEL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Report Modal Dialog Flow
  void _showReportDialog(BuildContext context, bool isDark) {
    if (_user == null) return;
    ReportSheet.show(
      context,
      targetTitle: _user!.name,
      reportedUserId: _user!.id,
    );
  }

  // Block Confirmation Dialog Flow
  void _showBlockConfirmDialog(BuildContext context, bool isDark, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('Block ${_user!.name}?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          ],
        ),
        content: Text(
          'Are you sure you want to block this user? You will no longer see their posts, messages, or relationship status.',
          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              auth.blockUser(_user!.id).then((_) {
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_user!.name} has been blocked successfully.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to block user: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            },
            child: const Text('Block User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = AppColors.getTextPrimary(isDark);
    final svip = context.watch<SVIPProvider>();
    final currentUserId = auth.currentUser.id;
    final currentUsername = auth.currentUser.username.toLowerCase();
    final currentName = auth.currentUser.name.toLowerCase();
    final targetId = _user?.id ?? widget.userId;
    final targetUsername = _user?.username.toLowerCase() ?? '';
    final targetName = _user?.name.toLowerCase() ?? '';
    final isMyProfile = (targetId.isNotEmpty && (targetId == currentUserId || targetId == 'me')) ||
        (targetUsername.isNotEmpty && currentUsername.isNotEmpty && targetUsername == currentUsername) ||
        (targetName.isNotEmpty && currentName.isNotEmpty && targetName == currentName) ||
        (widget.userId.isNotEmpty && (widget.userId == currentUserId || widget.userId == 'me' || (currentUsername.isNotEmpty && widget.userId.toLowerCase() == currentUsername)));
    final isOtherUser = !isMyProfile;
    final isFollowing = _user != null && auth.isFollowing(_user!.id);
    final isUserBlocked = _user != null && auth.isBlocked(_user!.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_rounded, size: 64, color: AppColors.getMuted(isDark)),
                      const SizedBox(height: 12),
                      Text('User profile not found', style: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Scrollable Diagram B Hierarchy
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. TOP BAR & COVER + IDENTITY
                          _buildCoverAndIdentityHeader(context, isDark, svip, isFollowing),

                          const SizedBox(height: 16),

                          // If User is Blocked, show Block Banner
                          if (isUserBlocked)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.block_rounded, color: Colors.redAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You have blocked this user. Unblock to view interactions.',
                                      style: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      auth.unblockUser(_user!.id).then((_) {
                                        if (mounted) setState(() {});
                                      });
                                    },
                                    child: const Text('Unblock', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                          // 2. MEDAL GALLERY (Featured Medals max 5 | Total Count)
                          _buildMedalGallery(isDark),

                          const SizedBox(height: 20),

                          // 3. BADGE GALLERY
                          _buildBadgeGallery(isDark, svip),

                          const SizedBox(height: 20),

                          // 4. RELATIONSHIP + HONOR
                          _buildRelationshipAndHonor(isDark),

                          const SizedBox(height: 20),

                          // 5. PROFILE TABS & CONTENT
                          _buildProfileContent(isDark),

                          const SizedBox(height: 100), // Bottom padding for sticky action bar
                        ],
                      ),
                    ),

                    // Top Floating Navigation Bar (Safe Area Compliant)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.more_horiz_rounded, size: 20, color: Colors.white),
                                  ),
                                  onPressed: () => _showOverflowMenu(context, isOtherUser, isDark, auth),
                                ),
                                const SizedBox(height: 2),
                                if (_user != null) ...[
                                  // 1. LIVE / IN ROOM Status Badge
                                  if (_user != null && _user!.isLive) ...[
                                    GestureDetector(
                                      onTap: () => _openUserActiveRoom(context, _user!.liveRoomId),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 6, right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF5252)]),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white, width: 1.2),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                                            SizedBox(width: 4),
                                            Text(
                                              '🔴 LIVE',
                                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],

                                  // 2. Online / Last Active Status Badge cleanly below 3-dot overflow menu
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 4,
                                          backgroundColor: _user!.isOnline ? const Color(0xFF00FF88) : Colors.grey,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _user!.isOnline ? 'Online' : _user!.lastActiveText,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

      // 8. ACTIONS: Edit Profile for Owner | Follow/Message/Gift for Visitors
      bottomNavigationBar: _user == null
          ? null
          : !isOtherUser
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    border: Border(top: BorderSide(color: AppColors.getBorder(isDark))),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimary(isDark),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        icon: Icon(Icons.edit_rounded, color: AppColors.onPrimary(isDark: isDark), size: 18),
                        label: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: AppColors.onPrimary(isDark: isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    border: Border(top: BorderSide(color: AppColors.getBorder(isDark))),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                    // Follow / Following Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? AppColors.getSurface(isDark)
                                : AppColors.getPrimary(isDark),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                          ),
                          onPressed: () {
                            AuthGuard.require(context, () {
                              if (isFollowing) {
                                auth.unfollowUser(_user!.id);
                                if (_user != null) {
                                  setState(() {
                                    _user = _user!.copyWith(followers: (_user!.followers > 0 ? _user!.followers - 1 : 0));
                                  });
                                }
                              } else {
                                auth.followUser(_user!.id);
                                if (_user != null) {
                                  setState(() {
                                    _user = _user!.copyWith(followers: _user!.followers + 1);
                                  });
                                }
                              }
                            });
                          },
                          icon: Icon(
                            isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                            color: isFollowing
                                ? AppColors.getTextPrimary(isDark)
                                : AppColors.onPrimary(isDark: isDark),
                            size: 18,
                          ),
                          label: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowing
                                  ? AppColors.getTextPrimary(isDark)
                                  : AppColors.onPrimary(isDark: isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Message Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2A233D) : const Color(0xFFEBE8F3),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                          ),
                          onPressed: () {
                            AuthGuard.require(context, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatScreen(user: _user!)),
                              );
                            });
                          },
                          icon: Icon(Icons.chat_bubble_rounded, color: AppColors.getTextPrimary(isDark), size: 18),
                          label: Text(
                            'Message',
                            style: TextStyle(
                              color: AppColors.getTextPrimary(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send Gift Button
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                        ),
                        onPressed: () {
                          AuthGuard.require(context, () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => GiftDialog(
                                streamerName: _user!.name,
                                targetReceiver: _user,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Gift',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 1 & 2. DIAGRAM B: COVER + IDENTITY & TOP BAR
  Widget _buildCoverAndIdentityHeader(BuildContext context, bool isDark, SVIPProvider svip, bool isFollowing) {
    final displayFollowers = _user!.followers;
    final coverUrl = _user!.effectiveCoverUrl;
    bool isLocalFile = false;
    if (coverUrl.startsWith('/') || coverUrl.contains('\\') || coverUrl.startsWith('file:')) {
      try {
        final f = File(coverUrl);
        isLocalFile = f.existsSync() && f.lengthSync() > 0;
      } catch (_) {
        isLocalFile = false;
      }
    }
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

    final ImageProvider coverImageProvider = isLocalFile
        ? FileImage(File(coverUrl))
        : (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')
            ? NetworkImage(coverUrl)
            : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80'));

    // CP Partner Mini-Avatar Decoration when active
    final hasCpPartner = _user!.cpPartnerId != null && _user!.cpPartnerId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Backdrop Photo with Main Avatar & CP Mini-Avatar Decoration
        Stack(
          children: [
            // Cover Image
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: coverImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      AppColors.getBackground(isDark),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),



            // Avatar with Crown Frame + CP Mini-Avatar Decoration & Followers Count
            Positioned(
              bottom: 0,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Main Avatar Stack with CP Mini Avatar Decoration & Click to view
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Builder(
                        builder: (ctx) {
                          String? effAvatar = _user!.avatarUrl.isNotEmpty ? _user!.avatarUrl : null;
                          if (effAvatar == null || effAvatar.isEmpty) {
                            try {
                              final social = ctx.watch<SocialProvider>();
                              final myPost = social.posts.cast<PostModel?>().firstWhere(
                                (p) => p != null && (
                                  (_user!.id.isNotEmpty && p.author.id == _user!.id) ||
                                  (_user!.displayName.isNotEmpty && p.author.displayName.toLowerCase() == _user!.displayName.toLowerCase()) ||
                                  (_user!.username.isNotEmpty && p.author.username.toLowerCase() == _user!.username.toLowerCase())
                                ),
                                orElse: () => null,
                              );
                              if (myPost != null && myPost.author.avatarUrl.isNotEmpty) {
                                effAvatar = myPost.author.avatarUrl;
                              }
                            } catch (_) {}
                          }

                          final bool isInActiveRoom = _user != null && (_user!.isLive || (_user!.liveRoomId != null && _user!.liveRoomId!.isNotEmpty));

                          Widget avatarWidget = UserAvatar(
                            imageUrl: effAvatar,
                            name: _user!.displayName,
                            radius: 38,
                            showVipFrame: _user!.isVip,
                            frameAsset: _user?.avatarFrame != null && _user!.avatarFrame.isNotEmpty && _user!.avatarFrame != 'none'
                                ? _user!.avatarFrame
                                : (_user?.nobleTitle != null
                                    ? NobleBadgeHelper.getFrameAsset(_user!.nobleTitle)
                                    : (_user != null && _user!.svipLevel > 0 ? NobleBadgeHelper.getFrameAsset('SVIP ${_user!.svipLevel}') : null)),
                          );

                          // Active room glowing ring on DP
                          if (isInActiveRoom) {
                            avatarWidget = Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    Color(0xFFFF007F),
                                    Color(0xFF7B1FA2),
                                    Color(0xFF00E5FF),
                                    Color(0xFFFF007F),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: avatarWidget,
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              if (effAvatar != null && effAvatar.isNotEmpty) {
                                FullScreenImageViewer.show(
                                  context,
                                  imageUrl: effAvatar,
                                  tag: 'user_details_avatar_${_user!.id}',
                                );
                              }
                            },
                            child: avatarWidget,
                          );
                        },
                      ),

                      // CP Partner Mini-Avatar Decoration (Reference Image 15 & Diagram B)
                      if (hasCpPartner)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.pinkAccent,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [BoxShadow(color: Colors.pinkAccent, blurRadius: 6)],
                            ),
                            child: const UserAvatar(
                              imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
                              radius: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Stat Items & Footprints Button inside scrollable Row to prevent overflow
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Footprints / Visitors Button
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_walk_rounded, size: 16, color: Colors.purpleAccent),
                            ),
                            tooltip: 'Profile Visitors',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => VisitorsScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 2),
                          // Followers Tap
                          GestureDetector(
                            onTap: () {
                              UserListSheet.show(
                                context,
                                'Followers',
                                userId: _user?.id ?? widget.userId,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    '${AppFormatters.formatNumber(displayFollowers)} ',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: primaryText),
                                  ),
                                  Text('Followers', style: TextStyle(fontSize: 12, color: secondaryText)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Following Tap
                          GestureDetector(
                            onTap: () {
                              UserListSheet.show(
                                context,
                                'Following',
                                userId: _user?.id ?? widget.userId,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    '${AppFormatters.formatNumber(_isMe ? context.read<AuthProvider>().followingUserIds.length : (_user?.following ?? 0))} ',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: primaryText),
                                  ),
                                  Text('Following', style: TextStyle(fontSize: 12, color: secondaryText)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Likes Tap (TikTok style with interactive popup)
                          GestureDetector(
                            onTap: () {
                              int calculatedLikes = _user?.likesReceived ?? 0;
                              try {
                                final social = context.read<SocialProvider>();
                                final userPosts = social.posts.where((p) =>
                                    (_user != null && _user!.id.isNotEmpty && p.author.id == _user!.id) ||
                                    (_user != null && _user!.username.isNotEmpty && p.author.username.toLowerCase() == _user!.username.toLowerCase())
                                ).toList();
                                final pLikes = userPosts.fold(0, (acc, p) => acc + p.likes);
                                if (pLikes > calculatedLikes) calculatedLikes = pLikes;
                              } catch (_) {}

                              final auth = context.read<AuthProvider>();
                              final isMe = _user != null && (_user!.id == auth.currentUser.id || _user!.username == auth.currentUser.username);

                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.getCard(isDark),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Total Likes',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    isMe
                                        ? 'You have total $calculatedLikes likes across all your videos and posts.'
                                        : '${_user?.name ?? 'User'} has total $calculatedLikes likes across all videos and posts.',
                                    style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(isDark)),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.getPrimary(isDark),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    () {
                                      int count = _user?.likesReceived ?? 0;
                                      try {
                                        final social = context.read<SocialProvider>();
                                        final userPosts = social.posts.where((p) =>
                                            (_user != null && _user!.id.isNotEmpty && p.author.id == _user!.id) ||
                                            (_user != null && _user!.username.isNotEmpty && p.author.username.toLowerCase() == _user!.username.toLowerCase())
                                        ).toList();
                                        final pLikes = userPosts.fold(0, (acc, p) => acc + p.likes);
                                        if (pLikes > count) count = pLikes;
                                      } catch (_) {}
                                      if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M ';
                                      if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K ';
                                      return '$count ';
                                    }(),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: primaryText),
                                  ),
                                  Text('Likes', style: TextStyle(fontSize: 12, color: secondaryText)),
                                ],
                              ),
                            ),
                          ),

                          // In Room Action Button in the Circled Area
                          if (_user != null && (_user!.isLive || (_user!.liveRoomId != null && _user!.liveRoomId!.isNotEmpty))) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _openUserActiveRoom(context, _user!.liveRoomId),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'In Room',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 9),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // User Details (Name | Gender/Age Pill | Bounded User ID + Copy | Country | Email)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _user!.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: NobleBadgeHelper.getColoredNicknameColor(
                          NobleBadgeHelper.getTierFromTitle(_user!.nobleTitle),
                        ),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Gender & Age Pill (â™‚ 21 / â™€ 22)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3897F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _user!.gender.toLowerCase() == 'female' ? Icons.female_rounded : Icons.male_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _user!.age > 0 ? '${_user!.age}' : _user!.gender,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Live Tag Badge (only shown when user is live)
                  if (_user != null && _user!.isLive) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _openUserActiveRoom(context, _user!.liveRoomId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Bounded User ID + Copy Button + Country Flag + Room/Agency Roles
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'ID: ${_user!.id}',
                      style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _user!.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User ID copied to clipboard!')),
                      );
                    },
                    child: Icon(Icons.copy_rounded, color: secondaryText, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(_user!.countryFlag, style: const TextStyle(fontSize: 15)), // Country Flag

                  const SizedBox(width: 8),

                  // Room / Agency Role Tag
                  if (_user!.isHost)
                    _buildRoleTag('Owner / Host', const Color(0xFFFF9800))
                  else if (_user!.isAgency)
                    _buildRoleTag('Agency', const Color(0xFF00ACC1))
                  else if (_user!.isBd)
                    _buildRoleTag('BD Admin', const Color(0xFF8C38FF)),
                ],
              ),

              const SizedBox(height: 12),
              _buildProfileTags(isDark, svip),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level <= 1) return const Color(0xFF607D8B); // Grey for 0 and 1
    if (level < 10) return const Color(0xFF29B6F6);
    if (level < 20) return const Color(0xFF66BB6A);
    if (level < 30) return const Color(0xFFFFA726);
    if (level < 40) return const Color(0xFFAB47BC);
    if (level < 50) return const Color(0xFFEF5350);
    if (level < 60) return const Color(0xFF26A69A);
    if (level < 70) return const Color(0xFFEC407A);
    if (level < 80) return const Color(0xFF5C6BC0);
    if (level < 90) return const Color(0xFFFF7043);
    return const Color(0xFFFFCA28);
  }

  Color _getBgColor(int level) {
    return _getLevelColor(level).withValues(alpha: 0.15);
  }

  // Tag Badges Section -- shows only real earned level indicators & assigned custom titles
  Widget _buildProfileTags(bool isDark, SVIPProvider svip) {
    final svipLvl = svip.currentLevel > 0 ? svip.currentLevel : (_user?.svipLevel ?? 0);
    final wealthLvl = _user?.computedWealthLevel ?? 0;
    final charmLvl = _user?.computedCharmLevel ?? 0;
    final gameLvl = _user?.computedGameLevel ?? 0;
    final accountLvl = _user?.computedAccountLevel ?? 0;
    final hasNobleTitle = _user?.nobleTitle != null && _user!.nobleTitle!.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (svipLvl > 0) ...[
            _buildTagChip(
              icon: Icons.workspace_premium_rounded,
              text: 'SVIP $svipLvl',
              color: const Color(0xFFFFD700),
              bgColor: const Color(0xFF2E2715),
              borderColor: const Color(0xFFFFD700),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen())),
            ),
            const SizedBox(width: 6),
          ],
          _buildTagChip(
            imagePath: 'assets/images/level_logo_wealth.png',
            text: 'Lv.$wealthLvl',
            color: const Color(0xFF00E5FF),
            bgColor: const Color(0xFF321A4C),
            borderColor: const Color(0xFF9042F5),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 0))),
          ),
          const SizedBox(width: 6),
          _buildTagChip(
            imagePath: 'assets/images/level_logo_charm.png',
            text: 'Lv.$charmLvl',
            color: const Color(0xFFFF4081),
            bgColor: const Color(0xFF42152E),
            borderColor: const Color(0xFFFF4081),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 1))),
          ),
          const SizedBox(width: 6),
          _buildTagChip(
            imagePath: 'assets/images/level_logo_game.png',
            text: 'Lv.$gameLvl',
            color: const Color(0xFFB388FF),
            bgColor: const Color(0xFF261842),
            borderColor: const Color(0xFF7C4DFF),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 2))),
          ),
          const SizedBox(width: 6),
          _buildTagChip(
            imagePath: 'assets/images/level_logo_account.png',
            text: 'Lv.$accountLvl',
            color: const Color(0xFF00E676),
            bgColor: const Color(0xFF0E3D1E),
            borderColor: const Color(0xFF00E676),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 3))),
          ),
          if (hasNobleTitle) ...[
            const SizedBox(width: 6),
            _buildTagChip(
              icon: Icons.military_tech_rounded,
              text: _user!.nobleTitle!,
              color: const Color(0xFFFFD700),
              bgColor: const Color(0xFF3B2E05),
              borderColor: const Color(0xFFFFD700),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AristocracyCenterScreen())),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required String text,
    IconData? icon,
    String? imagePath,
    required Color color,
    required Color bgColor,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? color.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Image.asset(imagePath, width: 16, height: 16,
                errorBuilder: (_, __, ___) => icon != null
                    ? Icon(icon, size: 12, color: color)
                    : const SizedBox.shrink())
            else if (icon != null) ...[
              Icon(icon, size: 12, color: color),
            ],
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MEDAL GALLERY (Header + Medal Badges)
  // Shows only medals the user has actually earned (isEarned == true)
  Widget _buildMedalGallery(bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);
    // Filter earned medals based on isEarned flag or user milestone achievements
    final earnedMedals = MedalModel.defaultMedals.where((m) {
      if (m.isEarned) return true;
      if (_user != null) {
        if (m.id == 'm1' && _user!.isHost) return true;
        if (m.id == 'm2' && _user!.wealthLevel >= 3) return true;
        if (m.id == 'm3' && (_user!.followers >= 50 || _user!.charmLevel >= 3)) return true;
        if (m.id == 'm4' && (_user!.svipLevel >= 1 || _user!.nobleTitle != null || _user!.role == UserRole.admin)) return true;
      }
      return false;
    }).toList();
    final medalsCount = earnedMedals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Medal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryText)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedalScreen())),
                child: Row(
                  children: [
                    Text('$medalsCount medals', style: const TextStyle(fontSize: 13, color: Color(0xFF8C38FF), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF8C38FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (medalsCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161224) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Center(
                child: Text(
                  'No medals assigned yet',
                  style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: earnedMedals.take(5).map((medal) {
                return _buildMedalCircleAsset(medal);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMedalCircleAsset(MedalModel medal) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      child: Image.asset(
        'assets/medals/${medal.iconUrl}.webp',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events_rounded, size: 26, color: Colors.amber),
      ),
    );
  }

  // BADGE GALLERY (Shows ONLY active assigned badges & real count)
  Widget _buildBadgeGallery(bool isDark, SVIPProvider svip) {
    final primaryText = AppColors.getTextPrimary(isDark);
    
    // Collect ONLY active assigned badges for this user
    final List<Map<String, dynamic>> activeBadges = [];

    if (_user != null) {
      if (_user!.role == UserRole.admin) {
        activeBadges.add({'asset': 'assets/roles/super_admin_tag.webp', 'label': 'Super Admin', 'color': Colors.redAccent});
      } else if (_user!.isAgency) {
        activeBadges.add({'asset': 'assets/roles/agency_tag.webp', 'label': 'Agency', 'color': Colors.cyan});
      } else if (_user!.isBd) {
        activeBadges.add({'asset': 'assets/roles/bd_tag.webp', 'label': 'BD Manager', 'color': Colors.teal});
      }

      if (_user!.nobleTitle != null && _user!.nobleTitle!.isNotEmpty) {
        final nobleBadge = NobleBadgeHelper.getBadgeAsset(_user!.nobleTitle);
        if (nobleBadge != null) {
          activeBadges.add({'asset': nobleBadge, 'label': _user!.nobleTitle!, 'color': const Color(0xFFFFD700)});
        }
      }

      final currentSvip = svip.currentLevel > 0 ? svip.currentLevel : _user!.svipLevel;
      if (currentSvip > 0) {
        final svipBadge = NobleBadgeHelper.getBadgeAsset('SVIP $currentSvip');
        if (svipBadge != null) {
          activeBadges.add({'asset': svipBadge, 'label': 'SVIP $currentSvip', 'color': Colors.amber});
        }
      }

      if (_user!.isHost) {
        activeBadges.add({'asset': 'assets/roles/host_tag.webp', 'label': 'Official Host', 'color': Colors.orangeAccent});
      }

      if (_user!.isSeller) {
        activeBadges.add({'asset': 'assets/roles/coins_saller_tag.webp', 'label': 'Coin Seller', 'color': Colors.lightGreenAccent});
      }

      if (_user!.badge.isNotEmpty && _user!.badge != 'none') {
        final badgeAsset = NobleBadgeHelper.getBadgeAsset(_user!.badge) ?? 'assets/badges/${_user!.badge}.webp';
        activeBadges.add({'asset': badgeAsset, 'label': _user!.badge, 'color': Colors.amberAccent});
      }
    }

    final badgeCount = activeBadges.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badge & Role Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryText)),
              GestureDetector(
                onTap: () => _showAllBadgesAndRolesSheet(context, isDark, svip),
                child: Row(
                  children: [
                    Text('$badgeCount Badges', style: const TextStyle(fontSize: 13, color: Color(0xFF8C38FF), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF8C38FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (badgeCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161224) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Center(
                child: Text(
                  'No active badges or SVIP assigned',
                  style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final b in activeBadges) ...[
                    _buildGraphicBadge(
                      assetPath: b['asset'] as String,
                      fallbackLabel: b['label'] as String,
                      fallbackColor: b['color'] as Color,
                      onTap: () => _showAllBadgesAndRolesSheet(context, isDark, svip),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraphicBadge({
    required String assetPath,
    required String fallbackLabel,
    required Color fallbackColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset(
          assetPath,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fallbackColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fallbackColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              fallbackLabel,
              style: TextStyle(color: fallbackColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  void _showAllBadgesAndRolesSheet(BuildContext context, bool isDark, SVIPProvider svip) {
    final primaryText = AppColors.getTextPrimary(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nobles, Roles & SVIP Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryText)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SECTION 1: NOBLE ARISTOCRACY
                    _buildSectionHeader('Aristocracy Nobles', () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AristocracyCenterScreen()));
                    }),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildBadgeModalItem('Emperor', 'assets/nobles/emperor_badge.webp', 'assets/nobles/emperor_frame.webp', const Color(0xFFFFD700), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('emperor') == true),
                        _buildBadgeModalItem('King', 'assets/nobles/king_badge.webp', 'assets/nobles/king_frame.webp', const Color(0xFFD4AF37), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('king') == true),
                        _buildBadgeModalItem('Duke', 'assets/nobles/duke_badge.webp', 'assets/nobles/duke_frame.webp', const Color(0xFF8E24AA), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('duke') == true),
                        _buildBadgeModalItem('Marquis', 'assets/nobles/marquis_badge.webp', 'assets/nobles/marquis_frame.webp', const Color(0xFFC2185B), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('marquis') == true),
                        _buildBadgeModalItem('Count', 'assets/nobles/count_badge.webp', 'assets/nobles/count_frame.webp', const Color(0xFF1E88E5), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('count') == true),
                        _buildBadgeModalItem('Viscount', 'assets/nobles/viscount_card.webp', 'assets/nobles/viscount_frame.webp', const Color(0xFFFB8C00), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('viscount') == true),
                        _buildBadgeModalItem('Baron', 'assets/nobles/baron_badge.webp', 'assets/nobles/baron_frame.webp', const Color(0xFF78909C), isUnlocked: _user?.nobleTitle?.toLowerCase().contains('baron') == true),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // SECTION 2: OFFICIAL ROLES & HONORS
                    _buildSectionHeader('Official Roles & Privileges', null),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildBadgeModalItem('Super Admin', 'assets/roles/super_admin_tag.webp', 'assets/roles/super_admin_frame.webp', Colors.redAccent, isUnlocked: _user?.role == UserRole.admin),
                        _buildBadgeModalItem('Admin', 'assets/roles/admin_badge.webp', 'assets/roles/admin_frame.webp', Colors.deepOrangeAccent, isUnlocked: _user?.role == UserRole.admin),
                        _buildBadgeModalItem('Agency', 'assets/roles/agency_badge.webp', 'assets/roles/agency_frame.webp', Colors.cyan, isUnlocked: _user?.isAgency == true),
                        _buildBadgeModalItem('BD Manager', 'assets/roles/bd_badge.webp', 'assets/roles/bd_frame.webp', Colors.teal, isUnlocked: _user?.isBd == true),
                        _buildBadgeModalItem('Game Master', 'assets/roles/game_master_badge.webp', 'assets/roles/game_master_frame.webp', Colors.amber, isUnlocked: _user?.role == UserRole.admin),
                        _buildBadgeModalItem('Official Host', 'assets/roles/host_badge.webp', 'assets/roles/host_frame.webp', Colors.orange, isUnlocked: _user?.isHost == true),
                        _buildBadgeModalItem('Coin Merchant', 'assets/roles/marchent_badge.webp', 'assets/roles/marchent_frame.webp', Colors.blue, isUnlocked: _user?.isSeller == true),
                        _buildBadgeModalItem('Customer Service', 'assets/roles/cs_badge.webp', 'assets/roles/cs_frame.webp', Colors.lightGreen, isUnlocked: _user?.role == UserRole.admin),
                        _buildBadgeModalItem('CP Lover', 'assets/roles/lover_tag.webp', 'assets/roles/lover_frame.webp', Colors.pinkAccent, isUnlocked: _user?.cpPartnerId != null && _user!.cpPartnerId!.isNotEmpty),
                        _buildBadgeModalItem('Top Fan', 'assets/roles/top_fan_badge.webp', 'assets/roles/top_fan_frame.webp', Colors.purpleAccent, isUnlocked: _user != null && (_user!.wealthLevel >= 3 || _user!.charmLevel >= 3)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // SECTION 3: SVIP TIERS
                    _buildSectionHeader('SVIP Royalty Tiers ⭐', () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen()));
                    }),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildBadgeModalItem('SVIP 15', 'assets/svip/svip15_badge.webp', 'assets/svip/svip15_frame.webp', const Color(0xFFFFD700), isUnlocked: (_user?.svipLevel ?? 0) >= 15),
                        _buildBadgeModalItem('SVIP 14', 'assets/svip/svip14_badge.webp', 'assets/svip/svip14_frame.webp', const Color(0xFF26C6DA), isUnlocked: (_user?.svipLevel ?? 0) >= 14),
                        _buildBadgeModalItem('SVIP 12', 'assets/svip/svip12_badge.webp', 'assets/svip/svip12_frame.webp', const Color(0xFF7E57C2), isUnlocked: (_user?.svipLevel ?? 0) >= 12),
                        _buildBadgeModalItem('SVIP 10', 'assets/svip/svip10_badge.webp', 'assets/svip/svip10_frame.webp', const Color(0xFFE91E63), isUnlocked: (_user?.svipLevel ?? 0) >= 10),
                        _buildBadgeModalItem('SVIP 8', 'assets/svip/svip8_badge.webp', 'assets/svip/svip8_frame.webp', const Color(0xFFFFA726), isUnlocked: (_user?.svipLevel ?? 0) >= 8),
                        _buildBadgeModalItem('SVIP 6', 'assets/svip/svip6_badge.webp', 'assets/svip/svip6_frame.webp', const Color(0xFFAB47BC), isUnlocked: (_user?.svipLevel ?? 0) >= 6),
                        _buildBadgeModalItem('SVIP 3', 'assets/svip/svip3_badge.webp', null, const Color(0xFF42A5F5), isUnlocked: (_user?.svipLevel ?? 0) >= 3),
                        _buildBadgeModalItem('SVIP 1', 'assets/svip/svip1_badge.webp', null, const Color(0xFF9E9E9E), isUnlocked: (_user?.svipLevel ?? 0) >= 1),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFEDEDF2)),
        ),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: const Row(
              children: [
                Text('Open Center', style: TextStyle(color: Color(0xFF8C38FF), fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF8C38FF), size: 10),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBadgeModalItem(String name, String badgeAsset, String? frameAsset, Color accentColor, {bool isUnlocked = false}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isUnlocked ? accentColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUnlocked ? accentColor : accentColor.withValues(alpha: 0.25), width: isUnlocked ? 1.5 : 1.0),
        boxShadow: isUnlocked
            ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isUnlocked ? 1.0 : 0.45,
                child: Image.asset(
                  badgeAsset,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.shield_rounded, color: accentColor, size: 32),
                ),
              ),
              if (!isUnlocked)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white54),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              color: isUnlocked ? accentColor : Colors.white54,
              fontSize: 10.5,
              fontWeight: isUnlocked ? FontWeight.w900 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (isUnlocked) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'UNLOCKED',
                style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 6. DIAGRAM B: RELATIONSHIP + HONOR
  Widget _buildRelationshipAndHonor(bool isDark) {
    final hasCp = _user!.cpPartnerId != null && _user!.cpPartnerId!.isNotEmpty;
    final hasCustomTitles = _user!.customTitles.isNotEmpty;
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

    if (!hasCp && !hasCustomTitles) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Relationship & Honor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryText)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelationshipScreen())),
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(fontSize: 13, color: Color(0xFF8C38FF), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF8C38FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (hasCp)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(isDark)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active CP Relationship',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CP Level ${_user!.cpPoints ~/ 100 + 1} • Partner Assigned',
                          style: TextStyle(fontSize: 11, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
          if (hasCustomTitles)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _user!.customTitles.map((titleAsset) {
                return Image.asset(
                  titleAsset,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: Text('Custom Title', style: TextStyle(color: primaryText, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 7. DIAGRAM B: PROFILE TABS (Post (Default) | Relation | Honor | Glory)
  Widget _buildProfileContent(bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs (Post, Relation, Honor, Glory)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF8C38FF),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: primaryText,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Post'),
              Tab(text: 'Relation'),
              Tab(text: 'Honor'),
              Tab(text: 'Glory'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tab Content View
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0) {
                return _buildPostTab(isDark);
              } else if (_tabController.index == 1) {
                return _buildRelationTab(isDark);
              } else if (_tabController.index == 2) {
                return _buildHonorTab(isDark);
              } else {
                return _buildGloryTab(isDark);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostTab(bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);
    final auth = context.watch<AuthProvider>();
    final isMe = auth.currentUser.id.isNotEmpty && (
      auth.currentUser.id == _user!.id ||
      auth.currentUser.username == _user!.username ||
      (auth.currentUser.name.isNotEmpty && _user!.name.isNotEmpty && auth.currentUser.name.toLowerCase() == _user!.name.toLowerCase()) ||
      (auth.currentUser.displayName.isNotEmpty && _user!.displayName.isNotEmpty && auth.currentUser.displayName.toLowerCase() == _user!.displayName.toLowerCase())
    );

    final social = context.watch<SocialProvider>();
    final userPosts = social.posts.where((p) {
      if (p.author.id.isNotEmpty && _user!.id.isNotEmpty && p.author.id == _user!.id) return true;
      if (p.author.username.isNotEmpty && _user!.username.isNotEmpty && p.author.username.toLowerCase() == _user!.username.toLowerCase()) return true;
      if (p.author.displayName.isNotEmpty && _user!.displayName.isNotEmpty && p.author.displayName.toLowerCase() == _user!.displayName.toLowerCase()) return true;
      return false;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bio', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
          _user!.bio.isNotEmpty ? _user!.bio : 'Welcome to my official ZeParty profile! âœ¨',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryText),
        ),

        const SizedBox(height: 24),
        Divider(color: AppColors.getBorder(isDark)),
        const SizedBox(height: 14),

        // Section Title: My Posts & Videos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C38FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.video_collection_rounded, color: Color(0xFF8C38FF), size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  isMe ? 'My Posts & Videos' : 'Posts & Videos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryText),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Text(
                '${userPosts.length} items',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryText),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (userPosts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Column(
              children: [
                Icon(Icons.video_library_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.6)),
                const SizedBox(height: 10),
                Text(
                  isMe ? 'You haven\'t uploaded any posts yet' : 'No posts uploaded yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  isMe ? 'Share videos, photos and moments from the Feed tab!' : 'When this creator uploads videos or photos, they will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: userPosts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final post = userPosts[index];
              return _buildUserPostGridItem(post, isMe, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildUserPostGridItem(PostModel post, bool isMe, bool isDark) {
    final hasMedia = post.imageUrls.isNotEmpty && post.imageUrls.first.isNotEmpty;
    final mediaPath = hasMedia ? post.imageUrls.first : '';
    final cleanPath = mediaPath.replaceFirst('file://', '');
    final lower = cleanPath.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        cleanPath.contains('/videos/');

    final isLocal = !cleanPath.startsWith('http://') && !cleanPath.startsWith('https://');
    final localFile = isLocal && cleanPath.isNotEmpty ? File(cleanPath) : null;

    return GestureDetector(
      onTap: () => _showPostDetailModal(context, post, isMe, isDark),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(isDark)),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media thumbnail or Gradient Fallback
            if (hasMedia && isLocal && localFile != null && localFile.existsSync())
              Image.file(
                localFile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildMediaFallback(post, isDark),
              )
            else if (hasMedia && cleanPath.startsWith('http'))
              Image.network(
                cleanPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildMediaFallback(post, isDark),
              )
            else
              _buildMediaFallback(post, isDark),

            // Top Video Badge
            if (isVideo)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 2),
                      Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),

            // Bottom Gradient Overlay + Content & Stats
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.content.isNotEmpty)
                      Text(
                        post.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likes}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (isMe)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Manage', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
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

  Widget _buildMediaFallback(PostModel post, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A1B4E), const Color(0xFF16102B)]
              : [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)],
        ),
      ),
      child: Center(
        child: Text(
          post.content.isNotEmpty ? post.content : 'ZeParty Moment âœ¨',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showPostDetailModal(BuildContext context, PostModel post, bool isMe, bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);
    final hasMedia = post.imageUrls.isNotEmpty && post.imageUrls.first.isNotEmpty;
    final mediaPath = hasMedia ? post.imageUrls.first : '';
    final cleanPath = mediaPath.replaceFirst('file://', '');
    final lower = cleanPath.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        cleanPath.contains('/videos/');

    final isLocal = !cleanPath.startsWith('http://') && !cleanPath.startsWith('https://');
    final localFile = isLocal && cleanPath.isNotEmpty ? File(cleanPath) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Author Info & Close Button
              Row(
                children: [
                  UserAvatar(
                    imageUrl: post.author.avatarUrl.isNotEmpty ? post.author.avatarUrl : _user?.avatarUrl,
                    name: post.author.displayName,
                    radius: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.displayName.isNotEmpty ? post.author.displayName : (_user?.displayName ?? 'Creator'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryText),
                        ),
                        Text(
                          AppFormatters.formatTimeAgo(post.createdAt),
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Media Player / Viewer
              if (hasMedia) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: isVideo
                      ? _ProfileVideoPlayerWidget(videoUrl: cleanPath)
                      : (isLocal && localFile != null && localFile.existsSync()
                          ? Image.file(localFile, width: double.infinity, height: 260, fit: BoxFit.cover)
                          : Image.network(cleanPath, width: double.infinity, height: 260, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 14),
              ],

              // Post Caption Text
              if (post.content.isNotEmpty) ...[
                Text(
                  post.content,
                  style: TextStyle(fontSize: 14, height: 1.4, color: primaryText),
                ),
                const SizedBox(height: 14),
              ],

              // Stats Row (Likes, Comments, Shares)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 18),
                        const SizedBox(width: 6),
                        Text('${post.likes} Likes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 6),
                        Text('${post.comments} Comments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.share_outlined, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 6),
                        Text('${post.shares} Shares', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // DELETE BUTTON (Available for own uploads)
              if (isMe) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text(
                      'Delete This Upload',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeletePost(context, post);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, PostModel post) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Delete Upload?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this post? The video/media will be removed from your profile, feeds, and server storage.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(d);
              try {
                await context.read<SocialProvider>().deletePost(post.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post deleted successfully'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete post: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationTab(bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.favorite_border_rounded, size: 40, color: secondaryText),
          const SizedBox(height: 10),
          Text(
            'ZeParty CP & Friends',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text('Build CP relationships to unlock special dynamic effects!', style: TextStyle(color: secondaryText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHonorTab(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 44, color: Colors.amber),
          const SizedBox(height: 10),
          Text(
            'ZeParty Honor Hall of Fame',
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text('Top Supporter & Special Seasonal Honors', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGloryTab(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.cyanAccent, size: 44),
          const SizedBox(height: 10),
          Text(
            'ZeParty Seasonal Glory Titles',
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text('Authorized Ranking Badges & Distinctive Badges', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const _ProfileVideoPlayerWidget({required this.videoUrl});

  @override
  State<_ProfileVideoPlayerWidget> createState() => _ProfileVideoPlayerWidgetState();
}

class _ProfileVideoPlayerWidgetState extends State<_ProfileVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final cleanUrl = widget.videoUrl.replaceFirst('file://', '');
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
      } else {
        _controller = VideoPlayerController.file(File(cleanUrl));
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.grey, size: 36),
              SizedBox(height: 6),
              Text('Video unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8C38FF)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 260,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (!_controller!.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
        ],
      ),
    );
  }
}
