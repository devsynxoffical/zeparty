import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../auth/auth_screen.dart';
import '../wallet/diamonds_wallet_screen.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../providers/social_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_list_sheet.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../core/repositories/backend_repository.dart';
import 'level_center_screen.dart';
import 'modules/gift_showcase_screen.dart';
import 'modules/medal_screen.dart';
import 'modules/activity_screen.dart';
import 'modules/outfit_screen.dart';
import 'modules/mystery_screen.dart';
import '../admin/admin_agency_panel.dart';
import 'modules/invite_code_screen.dart';
import 'modules/title_screen.dart';
import 'modules/relationship_screen.dart';
import '../settings/settings_screen.dart';
import 'user_profile_details_screen.dart';
import '../wallet/wallet_screen.dart';
import '../rewards/rewards_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../host/host_verification_screen.dart';
import '../agency/agency_center_screen.dart';
import '../agency/apply_agency_screen.dart';
import '../live_host/apply_live_host_screen.dart';
import '../live_host/live_host_center_screen.dart';
import '../host/host_center_screen.dart';
import '../recharge_agency/recharge_agency_screen.dart';
import '../merchant/merchant_center_screen.dart';
import '../bd_center/bd_center_dashboard_screen.dart';
import '../../providers/agency_provider.dart';
import '../../providers/live_host_provider.dart';
import '../../providers/live_party_provider.dart';
import '../party_room/live_party_room_screen.dart';
import '../host/host_dashboard_screen.dart';


import '../store/store_screen.dart';
import '../svip/svip_center_screen.dart';
import '../aristocracy/aristocracy_center_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        await context.read<AuthProvider>().updateAvatar(pickedFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Profile picture updated successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarPickerOptions(BuildContext context, bool isDark, Color primary, String? avatarUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.teal),
                    ),
                    title: Text('View Profile Picture', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      FullScreenImageViewer.show(context, imageUrl: avatarUrl, tag: 'my_profile_avatar');
                    },
                  ),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: primary),
                  ),
                  title: Text('Take Photo', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProfileImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                  ),
                  title: Text('Choose from Gallery', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProfileImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final isGuest = !auth.isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: isGuest 
            ? _buildGuestView(isDark) 
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileHeader(user, isDark, primary),
                      const SizedBox(height: 24),
                      _buildUserStatistics(user, isDark),
                      const SizedBox(height: 24),
                      _buildWalletRow(user, wallet, isDark, primary),
                      const SizedBox(height: 24),
                      _buildFeatureGrid(context, user, isDark),
                      const SizedBox(height: 24),
                      _buildIdentityAchievements(user, isDark),
                      const SizedBox(height: 24),
                      _buildProfileOptions(context, user, isDark, primary),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGuestView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(isDark).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(Icons.person_rounded, size: 64, color: AppColors.getPrimary(isDark)),
            ),
            const SizedBox(height: 20),
            Text(
              'Guest Mode Active',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create an account or sign in to access your coins, virtual gifts, levels, VIP privileges, and profile customization.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTextSecondary(isDark),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimary(isDark),
                  foregroundColor: AppColors.onPrimary(isDark: isDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const AuthScreen(initialMode: AuthMode.login)),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Sign In / Register',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isDark, Color primary) {
    String? effectiveAvatar = user.avatarUrl.isNotEmpty ? user.avatarUrl : null;
    if (effectiveAvatar == null || effectiveAvatar.isEmpty) {
      try {
        final social = context.watch<SocialProvider>();
        final myPost = social.posts.cast<PostModel?>().firstWhere(
          (p) => p != null && (
            (user.id.isNotEmpty && p.author.id == user.id) ||
            (user.displayName.isNotEmpty && p.author.displayName.toLowerCase() == user.displayName.toLowerCase()) ||
            (user.username.isNotEmpty && p.author.username.toLowerCase() == user.username.toLowerCase())
          ),
          orElse: () => null,
        );
        if (myPost != null && myPost.author.avatarUrl.isNotEmpty) {
          effectiveAvatar = myPost.author.avatarUrl;
        }
      } catch (_) {}
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar with Image Picker Badge & Click-to-View
        GestureDetector(
          onTap: () => _showAvatarPickerOptions(context, isDark, primary, effectiveAvatar),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: UserAvatar(
                  imageUrl: effectiveAvatar,
                  name: user.displayName,
                  radius: 40,
                  showVipFrame: false,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // User Info (Tapping navigates to profile details)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileDetailsScreen(userId: user.id),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (context.watch<LivePartyProvider>().activeRoom != null) ...[
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFAB47BC).withValues(alpha: 0.5), blurRadius: 6),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'LIVE',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Gender Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.gender.toLowerCase() == 'female' 
                                ? Icons.female_rounded 
                                : Icons.male_rounded,
                            size: 12,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            user.age > 0 ? '${user.age}' : user.gender,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${user.username.isNotEmpty ? user.username : (user.name.isNotEmpty ? user.name : user.id)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.username.isNotEmpty ? user.username : user.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Username copied to clipboard')),
                        );
                      },
                      child: Icon(Icons.copy_rounded, size: 12, color: AppColors.getTextSecondary(isDark)),
                    ),
                    if (user.isVip) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
                if (user.email != null && user.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 12, color: AppColors.getTextSecondary(isDark)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                OnlineStatusBadge(
                  isOnline: user.isOnline,
                  lastSeen: user.isOnline ? null : 'Online 3h ago',
                ),
              ],
            ),
          ),
        ),

        // Action Column: Footprint Profile Visitors Icon + Profile Navigation Arrow
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_walk_rounded, size: 18, color: primary),
              ),
              tooltip: 'Profile Visitors 🐾',
              onPressed: () {
                final popularUsers = BackendRepository.instance.popularUsers;
                UserListSheet.show(context, 'Profile Visitors 🐾', popularUsers.take(6).toList());
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.getTextSecondary(isDark)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileDetailsScreen(userId: user.id),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserStatistics(UserModel user, bool isDark) {
    final popularUsers = BackendRepository.instance.popularUsers;
    int totalLikes = 0;
    try {
      final social = context.watch<SocialProvider>();
      final myPosts = social.posts.where((p) =>
          (user.id.isNotEmpty && p.author.id == user.id) ||
          (user.username.isNotEmpty && p.author.username.toLowerCase() == user.username.toLowerCase())
      ).toList();
      totalLikes = myPosts.fold(0, (acc, p) => acc + p.likes);
    } catch (_) {}

    String formattedLikes;
    if (totalLikes >= 1000000) {
      formattedLikes = '${(totalLikes / 1000000).toStringAsFixed(1)}M';
    } else if (totalLikes >= 1000) {
      formattedLikes = '${(totalLikes / 1000).toStringAsFixed(1)}K';
    } else {
      formattedLikes = '$totalLikes';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          AppFormatters.formatNumber(user.following),
          'Following',
          isDark,
          () => UserListSheet.show(context, 'Following', popularUsers.take(3).toList()),
        ),
        _buildStatItem(
          AppFormatters.formatNumber(user.followers),
          'Followers',
          isDark,
          () => UserListSheet.show(context, 'Followers', popularUsers),
        ),
        _buildStatItem(
          formattedLikes,
          'Likes',
          isDark,
          () {
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
                  'You have total $totalLikes likes across all your videos and posts.',
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
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletRow(UserModel user, WalletProvider wallet, bool isDark, Color primary) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              AuthGuard.require(context, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
              }, reason: 'Sign in to open Wallet');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppFormatters.formatNumber(wallet.coins),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          'Coins',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.getTextSecondary(isDark)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              AuthGuard.require(context, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const DiamondsWalletScreen()));
              }, reason: 'Sign in to view Diamonds');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppFormatters.formatNumber(user.diamonds),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          'Diamonds',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.getTextSecondary(isDark)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid(BuildContext context, UserModel user, bool isDark) {
    final agencyProv = context.watch<AgencyProvider>();
    final liveHostProv = context.watch<LiveHostProvider>();

    final hasAgencyAccess = agencyProv.isAgencyOwner(user.id);
    final hasAudioHostAccess = agencyProv.getAudioHostByUserId(user.id) != null;
    final liveHostApp = liveHostProv.getApplicationByUserId(user.id);
    final hasLiveHostAccess = liveHostProv.activeLiveHost != null || liveHostApp?.status == 'Approved';

    final List<Map<String, dynamic>> features = [
      {
        'title': 'Level Center',
        'imagePath': 'assets/images/profile_level.jpg',
        'badge': 'Lv 30',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LevelCenterScreen())),
      },
      {
        'title': 'Gift',
        'imagePath': 'assets/images/profile_gift.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GiftShowcaseScreen())),
      },
      {
        'title': 'Medal',
        'imagePath': 'assets/images/profile_medal.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MedalScreen())),
      },
      {
        'title': 'Activity',
        'imagePath': 'assets/images/profile_activity.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ActivityScreen())),
      },
      {
        'title': 'Relationship',
        'imagePath': 'assets/images/profile_family.jpg', // Dedicated 3D icon
        'onTap': () {
          AuthGuard.require(context, () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const RelationshipScreen()));
          });
        },
      },
      {
        'title': 'Ranks',
        'imagePath': 'assets/images/profile_rank.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen())),
      },
      {
        'title': 'Store',
        'imagePath': 'assets/images/profile_store.jpg',
        'badge': 'NEW',
        'onTap': () {
          AuthGuard.require(context, () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const StoreScreen()));
          });
        },
      },
      {
        'title': 'My Outfit',
        'imagePath': 'assets/images/profile_outfit.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OutfitScreen())),
      },
      {
        'title': 'Mystery',
        'imagePath': 'assets/images/profile_mystery.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MysteryScreen())),
      },
      {
        'title': 'Agency Center',
        'imagePath': 'assets/images/profile_agency.jpg',
        'onTap': () {
          if (hasAgencyAccess) {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const AgencyCenterScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const ApplyAgencyScreen()));
          }
        },
      },
      {
        'title': 'Host Center',
        'imagePath': 'assets/images/profile_host_center.jpg',
        'badge': hasAudioHostAccess ? 'AUDIO' : null,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => HostCenterScreen())),
      },
      {
        'title': 'BD Center',
        'iconData': Icons.business_center_rounded,
        'badge': 'BD',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BDCenterDashboardScreen())),
      },
      {
        'title': hasLiveHostAccess ? 'Live Host Center' : 'Become a Live Host',
        'imagePath': 'assets/images/profile_livehost.jpg',
        'badge': hasLiveHostAccess ? 'DIRECT' : 'NEW',
        'onTap': () {
          if (hasLiveHostAccess) {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const LiveHostCenterScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const ApplyLiveHostScreen()));
          }
        },
      },
      {
        'title': 'Recharge Agency',
        'imagePath': 'assets/images/profile_recharge_agency.jpg',
        'badge': 'SELLER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RechargeAgencyScreen())),
      },
      {
        'title': 'Merchant Center',
        'imagePath': 'assets/images/profile_merchant.jpg',
        'badge': 'MERCHANT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MerchantCenterScreen())),
      },
      {
        'title': 'Admin',
        'imagePath': 'assets/images/profile_admin.jpg',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAgencyPanel())),
      },
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 24,
      alignment: WrapAlignment.start,
      children: features.map((feature) {
        final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 6 : 4;
        final screenWidth = MediaQuery.of(context).size.width - 32; // padding
        final itemWidth = (screenWidth - (16 * (crossAxisCount - 1))) / crossAxisCount; 

        return GestureDetector(
          onTap: feature['onTap'],
          child: SizedBox(
            width: itemWidth,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: feature['iconData'] != null ? AppColors.getCard(isDark) : null,
                        image: feature['imagePath'] != null ? DecorationImage(
                          image: AssetImage(feature['imagePath'] as String),
                          fit: BoxFit.cover,
                          onError: (e, s) => {},
                        ) : null,
                      ),
                      child: feature['iconData'] != null ? Icon(feature['iconData'] as IconData, size: 28, color: Colors.pinkAccent) : null,
                    ),
                    if (feature['hasDot'] == true)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (feature['badge'] != null)
                      Positioned(
                        top: -8,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            feature['badge'] as String,
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  feature['title'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIdentityAchievements(UserModel user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Identity Achievements',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            Row(
              children: [
                Text(
                  'My Privileges',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.getTextSecondary(isDark)),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildAchievementCard('SVIP 11', 'assets/images/card_vip.jpg', Colors.orangeAccent, isDark, onTap: () {
                AuthGuard.require(context, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const SVIPCenterScreen()));
                });
              }),
              const SizedBox(width: 12),
              _buildAchievementCard('Aristocracy', 'assets/images/card_aristocracy.jpg', Colors.amber, isDark, onTap: () {
                AuthGuard.require(context, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const AristocracyCenterScreen()));
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(String title, String imagePath, Color color, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(imagePath, width: 28, height: 28, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.star, color: color, size: 28)),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOptions(BuildContext context, UserModel user, bool isDark, Color primary) {
    return Column(
      children: [
        _buildOptionRow(
          context,
          icon: Icons.mark_email_read_rounded,
          title: 'Enter invite code',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const InviteCodeScreen())),
        ),
        _buildOptionRow(
          context,
          icon: Icons.military_tech_rounded,
          title: 'Title',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TitleScreen())),
        ),
        _buildOptionRow(
          context,
          icon: Icons.card_giftcard_rounded,
          title: 'Rewards & Referrals',
          isDark: isDark,
          onTap: () {
            AuthGuard.require(context, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const RewardsScreen()));
            }, reason: 'Sign in to view Rewards & Referrals');
          },
        ),
        _buildOptionRow(
          context,
          icon: Icons.video_camera_front_rounded,
          title: user.hostApplicationStatus == 'approved' ? 'Host Center' : 'Become a Live Host',
          isDark: isDark,
          onTap: () {
            AuthGuard.require(context, () {
              if (user.hostApplicationStatus == 'approved') {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const HostDashboardScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const HostVerificationScreen()));
              }
            }, reason: 'Sign in to apply for Host');
          },
        ),
        _buildOptionRow(
          context,
          icon: Icons.settings_rounded,
          title: 'Settings',
          isDark: isDark,
          showBorder: false,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildOptionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    bool showBorder = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.getBorder(isDark).withValues(alpha: 0.5),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.getTextPrimary(isDark).withValues(alpha: 0.8)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTextSecondary(isDark)),
          ],
        ),
      ),
    );
  }
}
