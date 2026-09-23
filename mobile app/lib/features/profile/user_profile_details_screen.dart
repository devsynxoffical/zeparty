import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/noble_badge_helper.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/svip_provider.dart';
import '../../providers/live_party_provider.dart';
import '../../providers/social_provider.dart';
import '../party_room/live_party_room_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_list_sheet.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/gift_dialog.dart';
import '../../core/repositories/backend_repository.dart';

import '../svip/svip_center_screen.dart';
import '../messages/chat_screen.dart';
import '../settings/edit_profile_screen.dart';
import 'level_center_screen.dart';
import 'modules/medal_screen.dart';
import 'modules/relationship_screen.dart';
import '../../widgets/report_sheet.dart';

class UserProfileDetailsScreen extends StatefulWidget {
  final String userId;

  const UserProfileDetailsScreen({super.key, required this.userId});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    final user = await context.read<AuthProvider>().getUserById(widget.userId);
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  // Diagram C & Section 12: Three-Dot Safety Menu (REPORT → BLOCK → CANCEL)
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
                    content: Text('🚫 ${_user!.name} has been blocked successfully.'),
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
                              } else {
                                auth.followUser(_user!.id);
                              }
                              setState(() {});
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

            // Online / Last Seen & LIVE Badge Top Right (Diagram 8.1 & Reference Screenshot)
            Positioned(
              top: 54,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LIVE Room Status Badge (Diagram 8.1 & Reference Screenshot)
                  if (_user!.isLive || context.watch<LivePartyProvider>().activeRoom != null) ...[
                    GestureDetector(
                      onTap: () {
                        final partyProv = context.read<LivePartyProvider>();
                        final room = partyProv.activeRoom;
                        if (room != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFAB47BC).withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Online / Last Seen Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: _user!.isOnline ? Colors.greenAccent : Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          _user!.isOnline ? 'Online' : 'Last seen 16m ago',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
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
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent, width: 2.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10),
                                ],
                              ),
                              child: UserAvatar(
                                imageUrl: effAvatar,
                                name: _user!.displayName,
                                radius: 38,
                              ),
                            ),
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
                  const Spacer(),
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
                    tooltip: 'Profile Visitors 🐾',
                    onPressed: () {
                      UserListSheet.show(
                        context,
                        'Profile Visitors 🐾',
                        BackendRepository.instance.popularUsers.take(6).toList(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // Followers Tap
                  GestureDetector(
                    onTap: () {
                      UserListSheet.show(
                        context,
                        'Followers',
                        BackendRepository.instance.popularUsers,
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
                  const SizedBox(width: 12),
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
                  NobleBadgeChip(user: _user!, fontSize: 10),
                  const SizedBox(width: 6),

                  // Gender & Age Pill (♂ 21 / ♀ 22)
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
                ],
              ),

              const SizedBox(height: 6),

              // System-generated 7-Digit ID + Copy Button + Country Flag/Name + Room/Agency Roles
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.getPrimary(isDark).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ID: ${_user!.displayId}',
                          style: TextStyle(
                            color: AppColors.getPrimary(isDark),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _user!.displayId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ID ${_user!.displayId} copied to clipboard!'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Icon(Icons.copy_rounded, color: AppColors.getPrimary(isDark), size: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Country Flag & Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_user!.countryFlag.isNotEmpty ? _user!.countryFlag : '🌍', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          _user!.country.isNotEmpty ? _user!.country : 'Global',
                          style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Room / Agency Role Tag
                  if (_user!.isHost)
                    _buildRoleTag('Owner / Host 👑', const Color(0xFFFF9800))
                  else if (_user!.isAgency)
                    _buildRoleTag('Agency 🏢', const Color(0xFF00ACC1))
                  else if (_user!.isBd)
                    _buildRoleTag('BD Admin 🛡️', const Color(0xFF8C38FF)),
                ],
              ),

              const SizedBox(height: 12),
              _buildProfileTags(isDark, svip),

              const SizedBox(height: 14),
              _buildFourStatusCards(isDark, svip),
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

  // Tag Badges Section — shows only real earned levels
  Widget _buildProfileTags(bool isDark, SVIPProvider svip) {
    final svipLvl = svip.currentLevel;
    final wealthLvl = _user?.wealthLevel ?? 1;
    final charmLvl = _user?.charmLevel ?? 1;
    final gameLvl = _user?.gameLevel ?? 1;
    final accountLvl = _user?.accountLevel ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
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
                icon: Icons.diamond_rounded,
                text: 'Lv.$wealthLvl',
                color: const Color(0xFF00E5FF),
                bgColor: const Color(0xFF321A4C),
                borderColor: const Color(0xFF9042F5),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 0))),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                icon: Icons.favorite_rounded,
                text: '$charmLvl',
                color: const Color(0xFFFF4081),
                bgColor: const Color(0xFF42152E),
                borderColor: const Color(0xFFFF4081),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 1))),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                icon: Icons.sports_esports_rounded,
                text: '$gameLvl',
                color: const Color(0xFFB388FF),
                bgColor: const Color(0xFF261842),
                borderColor: const Color(0xFF7C4DFF),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 2))),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                icon: Icons.stars_rounded,
                text: '$accountLvl',
                color: const Color(0xFF00E676),
                bgColor: const Color(0xFF0E3D1E),
                borderColor: const Color(0xFF00E676),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 3))),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                icon: Icons.emoji_events_rounded,
                text: 'Seeker',
                color: const Color(0xFF1DE9B6),
                bgColor: const Color(0xFF0C3B36),
                borderColor: const Color(0xFF1DE9B6),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                icon: Icons.emoji_events_rounded,
                text: 'III',
                color: const Color(0xFFFF9100),
                bgColor: const Color(0xFF3B1E05),
                borderColor: const Color(0xFFFF9100),
              ),
              const SizedBox(width: 6),
              _buildTagChip(
                text: 'Eligible...',
                color: Colors.white70,
                bgColor: Colors.white.withValues(alpha: 0.1),
                borderColor: Colors.white24,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Row 2: Collector Tags
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildOutlineTagChip(
                icon: Icons.shield_rounded,
                text: 'Trainee Collector',
                color: const Color(0xFF00BFA5),
              ),
              const SizedBox(width: 6),
              _buildOutlineTagChip(
                icon: Icons.shield_rounded,
                text: 'Emerging Collector',
                color: const Color(0xFF29B6F6),
              ),
              const SizedBox(width: 6),
              _buildOutlineTagChip(
                icon: Icons.shield_rounded,
                text: 'Veteran Collector',
                color: const Color(0xFFFF5252),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip({
    required String text,
    IconData? icon,
    required Color color,
    required Color bgColor,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
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

  Widget _buildOutlineTagChip({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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
    );
  }

  // Status Level Cards Strip (SVIP, WEALTH, CHARM, GAME, LEVEL - Compact & Responsive)
  Widget _buildFourStatusCards(bool isDark, SVIPProvider svip) {
    final svipLvl = svip.currentLevel > 0 ? svip.currentLevel : 11;
    final wealthLvl = _user?.wealthLevel ?? 30;
    final charmLvl = _user?.charmLevel ?? 15;
    final gameLvl = _user?.gameLevel ?? 12;
    final accountLvl = _user?.accountLevel ?? 24;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. SVIP Card (Gold)
          SizedBox(
            width: 78,
            child: _buildStatusGridCard(
              headerIcon: Icons.workspace_premium_rounded,
              headerText: 'SVIP $svipLvl',
              title: 'SVIP',
              subtitle: 'Privilege Active',
              accentColor: const Color(0xFFFFB300),
              progress: null,
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen())),
            ),
          ),
          const SizedBox(width: 5),

          // 2. WEALTH Card (Cyan)
          SizedBox(
            width: 78,
            child: _buildStatusGridCard(
              headerIcon: Icons.diamond_rounded,
              headerText: 'Lv. $wealthLvl',
              title: 'WEALTH',
              subtitle: 'Sending',
              accentColor: const Color(0xFF00E5FF),
              progress: ((_user?.wealthXp ?? 823083480) / 1000000000).clamp(0.15, 1.0),
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 0))),
            ),
          ),
          const SizedBox(width: 5),

          // 3. CHARM Card (Pink)
          SizedBox(
            width: 78,
            child: _buildStatusGridCard(
              headerIcon: Icons.favorite_rounded,
              headerText: 'Lv. $charmLvl',
              title: 'CHARM',
              subtitle: 'Receiving',
              accentColor: const Color(0xFFFF4081),
              progress: ((_user?.charmXp ?? 7800) / 10000).clamp(0.15, 1.0),
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 1))),
            ),
          ),
          const SizedBox(width: 5),

          // 4. GAME Card (Purple)
          SizedBox(
            width: 78,
            child: _buildStatusGridCard(
              headerIcon: Icons.sports_esports_rounded,
              headerText: 'Lv. $gameLvl',
              title: 'GAME',
              subtitle: 'Game Level',
              accentColor: const Color(0xFFB388FF),
              progress: ((_user?.gameXp ?? 3200) / 5000).clamp(0.15, 1.0),
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 2))),
            ),
          ),
          const SizedBox(width: 5),

          // 5. LEVEL Card (Green)
          SizedBox(
            width: 78,
            child: _buildStatusGridCard(
              headerIcon: Icons.stars_rounded,
              headerText: 'Lv. $accountLvl',
              title: 'LEVEL',
              subtitle: 'Account Level',
              accentColor: const Color(0xFF00E676),
              progress: ((_user?.accountXp ?? 14200) / 20000).clamp(0.15, 1.0),
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 3))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGridCard({
    required IconData headerIcon,
    required String headerText,
    required String title,
    required String subtitle,
    required Color accentColor,
    double? progress,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171326) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.75),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 5,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Badge (Icon + Level Text)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(headerIcon, size: 10.5, color: accentColor),
                  const SizedBox(width: 2.5),
                  Text(
                    headerText,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Title Label (SVIP / WEALTH / CHARM / GAME)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 1),

            // Subtitle Label
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.65),
                  fontSize: 7.5,
                ),
              ),
            ),

            const SizedBox(height: 5),

            // Progress Bar Indicator at Bottom
            if (progress != null)
              Container(
                height: 2.5,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? const Color(0xFF292238) : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              )
            else
              Container(
                height: 2.5,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // MEDAL GALLERY (Header + 5 Medal Circular Badges)
  Widget _buildMedalGallery(bool isDark) {
    final primaryText = AppColors.getTextPrimary(isDark);

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
                child: const Row(
                  children: [
                    Text('33 medals', style: TextStyle(fontSize: 13, color: Color(0xFF8C38FF), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF8C38FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 5 Featured Medal Circles (Gold Trophy, Blue Chair, Teal Star, Orange Flame, Pink Heart)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMedalCircle(Icons.emoji_events_rounded, const Color(0xFFFFD700)),
              _buildMedalCircle(Icons.chair_rounded, const Color(0xFF29B6F6)),
              _buildMedalCircle(Icons.stars_rounded, const Color(0xFF00E5FF)),
              _buildMedalCircle(Icons.local_fire_department_rounded, const Color(0xFFFF9100)),
              _buildMedalCircle(Icons.favorite_rounded, const Color(0xFFFF4081)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedalCircle(IconData icon, Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      child: Icon(icon, size: 26, color: color),
    );
  }

  // 5. DIAGRAM B: BADGE GALLERY
  Widget _buildBadgeGallery(bool isDark, SVIPProvider svip) {
    final primaryText = AppColors.getTextPrimary(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badge Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryText)),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.getCard(isDark),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('All Assigned Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryText)),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadgeChip('Admin 🛡️', Colors.redAccent),
                                _buildBadgeChip('SVIP ${svip.currentLevel}', Colors.amber),
                                _buildBadgeChip(_user!.nobleTitle ?? 'Aristocracy 👑', Colors.purpleAccent),
                                _buildBadgeChip('Top Host 🔥', Colors.orangeAccent),
                                _buildBadgeChip('Merchant 💎', Colors.lightBlueAccent),
                                _buildBadgeChip('BD Manager 💼', Colors.tealAccent),
                                _buildBadgeChip('Event Winner 🏆', AppColors.goldHighlight),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text('12 Badges', style: TextStyle(fontSize: 13, color: Color(0xFF8C38FF), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF8C38FF)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Priority Sorted Badges Row: Official/Admin -> SVIP/Noble -> Role -> Achievement
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                if (_user!.role == UserRole.admin) _buildBadgeChip('Official Admin 🛡️', Colors.redAccent),
                if (_user!.role == UserRole.admin) const SizedBox(width: 6),

                _buildBadgeChip('SVIP ${svip.currentLevel}', Colors.amber),
                const SizedBox(width: 6),

                if (_user!.nobleTitle != null) ...[
                  _buildBadgeChip(_user!.nobleTitle!, Colors.purpleAccent),
                  const SizedBox(width: 6),
                ],

                if (_user!.isHost) ...[
                  _buildBadgeChip('Top Host 🔥', Colors.orangeAccent),
                  const SizedBox(width: 6),
                ],

                if (_user!.isSeller) ...[
                  _buildBadgeChip('Coin Merchant 💎', Colors.cyanAccent),
                  const SizedBox(width: 6),
                ],

                _buildBadgeChip('Veteran Collector', Colors.pinkAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 6. DIAGRAM B: RELATIONSHIP + HONOR
  Widget _buildRelationshipAndHonor(bool isDark) {
    final hasCp = _user!.cpPartnerId != null && _user!.cpPartnerId!.isNotEmpty;
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

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

          // CP / Relationship Active Card or Reserved Honor Card
          Container(
            padding: const EdgeInsets.all(14),
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
                        hasCp ? 'Active CP Relationship 💕' : 'Seasonal Honor Title 🏆',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasCp
                            ? 'CP Level ${_user!.cpPoints ~/ 100 + 1} • Partner Assigned'
                            : 'Hall of Fame Distinction & Event Titles',
                        style: TextStyle(fontSize: 11, color: secondaryText),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bio', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
          _user!.bio.isNotEmpty ? _user!.bio : 'Welcome to my official ZeParty profile! ✨',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryText),
        ),

        const SizedBox(height: 16),

        const Text('Personality tag', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildTagPill('Unique', const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _buildTagPill('Entrepreneur', const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _buildTagPill('Global Streamer', const Color(0xFFE0F7FA), const Color(0xFF00ACC1)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text('Voice introduction', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        const _ExpandedMessagePlayer(),
      ],
    );
  }

  Widget _buildTagPill(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
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
